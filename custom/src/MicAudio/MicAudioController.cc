/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "MicAudioController.h"
#include "MicAudioPlayer.h"
#include "MicTuningClient.h"

#include "LinksManager/LinksManagerController.h"
#include "LinksManager/ManagedLinkConfiguration.h"

#include <QtCore/QCoreApplication>
#include <QtCore/QSettings>

MicAudioController::MicAudioController(LinksManagerController *linksManager, QObject *parent)
    : QObject(parent)
    , _linksManager(linksManager)
    , _player(new MicAudioPlayer(this))
    , _tuning(new MicTuningClient(this))
{
    _loadSettings();
    _player->setVolume(_volume);

    connect(_player, &MicAudioPlayer::stateChanged, this, &MicAudioController::_onPlayerStateChanged);
    connect(_player, &MicAudioPlayer::failed, this, &MicAudioController::_onPlayerFailed);

    connect(_tuning, &MicTuningClient::configReceived, this, &MicAudioController::_onConfigReceived);
    connect(_tuning, &MicTuningClient::statusReceived, this, &MicAudioController::_onStatusReceived);
    connect(_tuning, &MicTuningClient::statusFailed, this, [this]() {
        if (!_status.isEmpty()) {
            _status.clear();
            emit statusChanged();
        }
    });
    connect(_tuning, &MicTuningClient::requestFailed, this, [this](const QString &error) {
        _setTuningMessage(tr("Mic not reachable: %1").arg(error));
    });
    connect(_tuning, &MicTuningClient::saved, this, [this]() {
        _setTuningMessage(tr("Saved to flash"));
    });
    connect(_tuning, &MicTuningClient::reachableChanged, this, [this](bool reachable) {
        _reachable = reachable;
        emit reachableChanged();
    });

    _debounceTimer.setSingleShot(true);
    _debounceTimer.setInterval(kDebounceMs);
    connect(&_debounceTimer, &QTimer::timeout, this, [this]() {
        _tuning->applyConfig(_pendingConfig);
        _pendingConfig.clear();
    });

    _statusTimer.setInterval(kStatusPollMs);
    connect(&_statusTimer, &QTimer::timeout, _tuning, &MicTuningClient::pollStatus);

    _retryTimer.setSingleShot(true);
    connect(&_retryTimer, &QTimer::timeout, this, &MicAudioController::_retry);

    _messageTimer.setSingleShot(true);
    _messageTimer.setInterval(4000);
    connect(&_messageTimer, &QTimer::timeout, this, [this]() { _setTuningMessage(QString()); });

    if (_linksManager) {
        connect(_linksManager, &LinksManagerController::activeLinkChanged,
                this, &MicAudioController::_onActiveLinkChanged);
    }
    _onActiveLinkChanged();

    // Send RTSP TEARDOWN while the network and the event loop still exist.
    connect(qApp, &QCoreApplication::aboutToQuit, this, &MicAudioController::stop);
}

MicAudioController::~MicAudioController()
{
    _player->stop();
}

bool MicAudioController::configPending() const
{
    return _debounceTimer.isActive() || !_pendingConfig.isEmpty() || _tuning->hasPendingApply();
}

bool MicAudioController::audioSupported() const
{
    return MicAudioPlayer::isSupported();
}

QString MicAudioController::stateText() const
{
    switch (_state) {
    case Off:          return tr("Off");
    case Connecting:   return tr("Connecting");
    case Playing:      return tr("Live");
    case Reconnecting: return tr("Reconnecting %1/%2").arg(_retryCount).arg(kMaxRetries);
    case Error:        return tr("Error");
    }
    return QString();
}

// ---------------------------------------------------------------------------
// Listening

void MicAudioController::toggle()
{
    if (_state == Off || _state == Error) {
        start();
    } else {
        stop();
    }
}

void MicAudioController::start()
{
    if (!available()) {
        _setState(Error, tr("No active link: the mic address is not known"));
        return;
    }
    _wantOn = true;
    _retryCount = 0;
    _retryTimer.stop();
    _startPlayer();
}

void MicAudioController::stop()
{
    _wantOn = false;
    _retryTimer.stop();
    _player->stop();
    _setState(Off);
}

void MicAudioController::_startPlayer()
{
    _playingSince.invalidate();
    _setState(_retryCount > 0 ? Reconnecting : Connecting, _errorText);
    _player->start(_rtspUrl(), _useTcp, _latencyMs);
}

void MicAudioController::_retry()
{
    if (_wantOn) {
        _startPlayer();
    }
}

void MicAudioController::_onPlayerStateChanged()
{
    if (!_wantOn) {
        return;
    }
    if (_player->state() == MicAudioPlayer::State::Playing) {
        _playingSince.start();
        _setState(Playing);
    }
}

void MicAudioController::_onPlayerFailed(const QString &reason)
{
    if (!_wantOn) {
        return;
    }

    qCDebug(MicAudioLog) << "Stream failed:" << reason;

    if (_playingSince.isValid() && _playingSince.elapsed() >= kStablePlayMs) {
        _retryCount = 0;
    }
    _playingSince.invalidate();

    if (_retryCount >= kMaxRetries) {
        _wantOn = false;
        // The board serves one RTSP client; a new client takes the mic.
        // rtsp_playing can also be our own dead session, so it is only a hint.
        const bool busy = _status.value(QStringLiteral("rtsp_playing")).toBool();
        _setState(Error, busy ? tr("%1 (another client may be listening)").arg(reason) : reason);
        return;
    }

    const int delayMs = qMin(1000 << _retryCount, kMaxRetryDelayMs);
    _retryCount++;
    _setState(Reconnecting, reason);
    _retryTimer.start(delayMs);
}

void MicAudioController::_setState(State state, const QString &errorText)
{
    // The Reconnecting text includes the try number, so it changes on each try.
    const bool changed = (_state != state) || (_errorText != errorText) || state == Reconnecting;
    _state = state;
    _errorText = errorText;
    if (changed) {
        emit stateChanged();
    }
    _updatePollTimer();
}

QString MicAudioController::_rtspUrl() const
{
    return QStringLiteral("rtsp://%1:%2/mic").arg(_host).arg(_rtspPort);
}

void MicAudioController::setVolume(double volume)
{
    volume = qBound(0.0, volume, 2.0);
    if (qFuzzyCompare(_volume, volume)) {
        return;
    }
    _volume = volume;
    _player->setVolume(volume);
    _saveSettings();
    emit volumeChanged();
}

void MicAudioController::setMuted(bool muted)
{
    if (_muted != muted) {
        _muted = muted;
        _player->setMuted(muted);
        emit mutedChanged();
    }
}

// ---------------------------------------------------------------------------
// Host from the active link

void MicAudioController::_onActiveLinkChanged()
{
    if (_activeLink) {
        disconnect(_activeLink, nullptr, this, nullptr);
    }
    _activeLink = _linksManager ? _linksManager->activeLink() : nullptr;
    if (_activeLink) {
        connect(_activeLink, &ManagedLinkConfiguration::serverAddressChanged,
                this, &MicAudioController::_updateHost);
    }
    _updateHost();
}

void MicAudioController::_updateHost()
{
    const QString host = _activeLink ? _activeLink->serverAddress().trimmed() : QString();
    if (host == _host) {
        return;
    }

    if (_state != Off) {
        stop();
    }

    _host = host;
    _config.clear();
    _pendingConfig.clear();
    _debounceTimer.stop();
    _status.clear();
    _lastInClip = -1;
    _lastOutClip = -1;
    _tuning->setEndpoint(_host, _httpPort);

    emit hostChanged();
    emit configChanged();
    emit statusChanged();

    if (_panelOpen) {
        refreshConfig();
    }
    _updatePollTimer();
}

// ---------------------------------------------------------------------------
// Tuning and levels

void MicAudioController::setPanelOpen(bool open)
{
    if (_panelOpen == open) {
        return;
    }
    _panelOpen = open;
    emit panelOpenChanged();

    if (open) {
        // Sliders stay disabled until the board answers.
        _config.clear();
        emit configChanged();
        refreshConfig();
    }
    _updatePollTimer();
}

void MicAudioController::_updatePollTimer()
{
    const bool needed = available() && (_panelOpen || _state == Playing || _state == Reconnecting);
    if (needed && !_statusTimer.isActive()) {
        _statusTimer.start();
    } else if (!needed && _statusTimer.isActive()) {
        _statusTimer.stop();
    }
}

void MicAudioController::setConfigValue(const QString &key, const QVariant &value)
{
    if (!available()) {
        return;
    }
    _pendingConfig.insert(key, value);
    _debounceTimer.start();
}

void MicAudioController::refreshConfig()
{
    _tuning->fetchConfig();
}

void MicAudioController::saveConfig()
{
    // Send the last slider change first; the queue keeps the order.
    if (_debounceTimer.isActive()) {
        _debounceTimer.stop();
        _tuning->applyConfig(_pendingConfig);
        _pendingConfig.clear();
    }
    _tuning->saveConfig();
}

void MicAudioController::resetConfig()
{
    _debounceTimer.stop();
    _pendingConfig.clear();
    _tuning->resetConfig();
}

void MicAudioController::_onConfigReceived(const QVariantMap &config)
{
    _config = config;
    emit configChanged();
}

void MicAudioController::_onStatusReceived(const QVariantMap &status)
{
    const qint64 inClip = status.value(QStringLiteral("in_clip")).toLongLong();
    const qint64 outClip = status.value(QStringLiteral("out_clip")).toLongLong();

    QVariantMap map = status;
    // A smaller value means the board rebooted: no clip for this poll.
    map.insert(QStringLiteral("in_clip_now"), _lastInClip >= 0 && inClip > _lastInClip);
    map.insert(QStringLiteral("out_clip_now"), _lastOutClip >= 0 && outClip > _lastOutClip);
    _lastInClip = inClip;
    _lastOutClip = outClip;

    _status = map;
    emit statusChanged();
}

void MicAudioController::_setTuningMessage(const QString &message)
{
    if (_tuningMessage != message) {
        _tuningMessage = message;
        emit tuningMessageChanged();
    }
    if (!message.isEmpty()) {
        _messageTimer.start();
    }
}

// ---------------------------------------------------------------------------
// Settings

void MicAudioController::setRtspPort(int port)
{
    port = qBound(1, port, 65535);
    if (_rtspPort != port) {
        _rtspPort = port;
        _saveSettings();
        emit settingsChanged();
    }
}

void MicAudioController::setHttpPort(int port)
{
    port = qBound(1, port, 65535);
    if (_httpPort != port) {
        _httpPort = port;
        _tuning->setEndpoint(_host, _httpPort);
        _saveSettings();
        emit settingsChanged();
        if (_panelOpen) {
            refreshConfig();
        }
    }
}

void MicAudioController::setUseTcp(bool useTcp)
{
    if (_useTcp != useTcp) {
        _useTcp = useTcp;
        _saveSettings();
        emit settingsChanged();
    }
}

void MicAudioController::setLatencyMs(int latencyMs)
{
    latencyMs = qBound(0, latencyMs, 2000);
    if (_latencyMs != latencyMs) {
        _latencyMs = latencyMs;
        _saveSettings();
        emit settingsChanged();
    }
}

void MicAudioController::setAutoStart(bool autoStart)
{
    if (_autoStart != autoStart) {
        _autoStart = autoStart;
        _saveSettings();
        emit settingsChanged();
    }
}

void MicAudioController::_loadSettings()
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    _rtspPort  = qBound(1, settings.value(QStringLiteral("rtspPort"), 8888).toInt(), 65535);
    _httpPort  = qBound(1, settings.value(QStringLiteral("httpPort"), 8889).toInt(), 65535);
    _useTcp    = settings.value(QStringLiteral("useTcp"), false).toBool();
    _latencyMs = qBound(0, settings.value(QStringLiteral("latencyMs"), 100).toInt(), 2000);
    _autoStart = settings.value(QStringLiteral("autoStart"), false).toBool();
    _volume    = qBound(0.0, settings.value(QStringLiteral("volume"), 1.0).toDouble(), 2.0);
    settings.endGroup();
}

void MicAudioController::_saveSettings() const
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    settings.setValue(QStringLiteral("rtspPort"), _rtspPort);
    settings.setValue(QStringLiteral("httpPort"), _httpPort);
    settings.setValue(QStringLiteral("useTcp"), _useTcp);
    settings.setValue(QStringLiteral("latencyMs"), _latencyMs);
    settings.setValue(QStringLiteral("autoStart"), _autoStart);
    settings.setValue(QStringLiteral("volume"), _volume);
    settings.endGroup();
}
