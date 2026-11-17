/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QElapsedTimer>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtCore/QVariantMap>

class LinksManagerController;
class ManagedLinkConfiguration;
class MicAudioPlayer;
class MicTuningClient;

// QML front end for the mic-box: listening on/off, tuning and levels.
// The host is the server address of the active Links Manager link
// (the mic is port-forwarded through the router on the vehicle side).
class MicAudioController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int          state           READ state          NOTIFY stateChanged)
    Q_PROPERTY(QString      stateText       READ stateText      NOTIFY stateChanged)
    Q_PROPERTY(QString      errorText       READ errorText      NOTIFY stateChanged)
    Q_PROPERTY(QString      host            READ host           NOTIFY hostChanged)
    Q_PROPERTY(bool         available       READ available      NOTIFY hostChanged)
    Q_PROPERTY(bool         audioSupported  READ audioSupported CONSTANT)
    Q_PROPERTY(QVariantMap  config          READ config         NOTIFY configChanged)
    Q_PROPERTY(bool         configLoaded    READ configLoaded   NOTIFY configChanged)
    // True while newer slider changes are not yet answered by the board:
    // QML does not move sliders to the (older) values in that case.
    Q_PROPERTY(bool         configPending   READ configPending  NOTIFY configChanged)
    Q_PROPERTY(QString      tuningMessage   READ tuningMessage  NOTIFY tuningMessageChanged)
    Q_PROPERTY(bool         reachable       READ reachable      NOTIFY reachableChanged)
    Q_PROPERTY(QVariantMap  status          READ status         NOTIFY statusChanged)
    Q_PROPERTY(bool         statusValid     READ statusValid    NOTIFY statusChanged)
    Q_PROPERTY(bool         panelOpen       READ panelOpen      WRITE setPanelOpen  NOTIFY panelOpenChanged)
    Q_PROPERTY(double       volume          READ volume         WRITE setVolume     NOTIFY volumeChanged)
    Q_PROPERTY(bool         muted           READ muted          WRITE setMuted      NOTIFY mutedChanged)

    // Persistent settings (QSettings group "MicAudio").
    Q_PROPERTY(int          rtspPort        READ rtspPort       WRITE setRtspPort   NOTIFY settingsChanged)
    Q_PROPERTY(int          httpPort        READ httpPort       WRITE setHttpPort   NOTIFY settingsChanged)
    Q_PROPERTY(bool         useTcp          READ useTcp         WRITE setUseTcp     NOTIFY settingsChanged)
    Q_PROPERTY(int          latencyMs       READ latencyMs      WRITE setLatencyMs  NOTIFY settingsChanged)
    Q_PROPERTY(bool         autoStart       READ autoStart      WRITE setAutoStart  NOTIFY settingsChanged)

public:
    enum State {
        Off = 0,
        Connecting,
        Playing,
        Reconnecting,
        Error
    };
    Q_ENUM(State)

    explicit MicAudioController(LinksManagerController *linksManager, QObject *parent = nullptr);
    ~MicAudioController() override;

    int state() const { return _state; }
    QString stateText() const;
    QString errorText() const { return _errorText; }
    QString host() const { return _host; }
    bool available() const { return !_host.isEmpty(); }
    bool audioSupported() const;
    QVariantMap config() const { return _config; }
    bool configLoaded() const { return !_config.isEmpty(); }
    bool configPending() const;
    QString tuningMessage() const { return _tuningMessage; }
    bool reachable() const { return _reachable; }
    QVariantMap status() const { return _status; }
    bool statusValid() const { return !_status.isEmpty(); }
    bool panelOpen() const { return _panelOpen; }
    double volume() const { return _volume; }
    bool muted() const { return _muted; }

    int rtspPort() const { return _rtspPort; }
    int httpPort() const { return _httpPort; }
    bool useTcp() const { return _useTcp; }
    int latencyMs() const { return _latencyMs; }
    bool autoStart() const { return _autoStart; }

    void setPanelOpen(bool open);
    void setVolume(double volume);
    void setMuted(bool muted);
    void setRtspPort(int port);
    void setHttpPort(int port);
    void setUseTcp(bool useTcp);
    void setLatencyMs(int latencyMs);
    void setAutoStart(bool autoStart);

    Q_INVOKABLE void toggle();
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

    // Tuning: changes are debounced (150 ms) and sent in one request.
    Q_INVOKABLE void setConfigValue(const QString &key, const QVariant &value);
    Q_INVOKABLE void refreshConfig();
    Q_INVOKABLE void saveConfig();
    Q_INVOKABLE void resetConfig();

signals:
    void stateChanged();
    void hostChanged();
    void configChanged();
    void tuningMessageChanged();
    void reachableChanged();
    void statusChanged();
    void panelOpenChanged();
    void volumeChanged();
    void mutedChanged();
    void settingsChanged();

private slots:
    void _onActiveLinkChanged();
    void _updateHost();
    void _onPlayerStateChanged();
    void _onPlayerFailed(const QString &reason);
    void _onConfigReceived(const QVariantMap &config);
    void _onStatusReceived(const QVariantMap &status);
    void _retry();

private:
    void _setState(State state, const QString &errorText = QString());
    void _setTuningMessage(const QString &message);
    void _startPlayer();
    void _updatePollTimer();
    void _loadSettings();
    void _saveSettings() const;
    QString _rtspUrl() const;

    LinksManagerController *_linksManager = nullptr;
    QPointer<ManagedLinkConfiguration> _activeLink;
    MicAudioPlayer *_player = nullptr;
    MicTuningClient *_tuning = nullptr;

    State _state = Off;
    QString _errorText;
    QString _host;
    QVariantMap _config;
    QVariantMap _pendingConfig;
    QString _tuningMessage;
    bool _reachable = false;
    QVariantMap _status;
    bool _panelOpen = false;
    double _volume = 1.0;
    bool _muted = false;

    // Clip counters on the board are cumulative: a clip is an increase.
    qint64 _lastInClip = -1;
    qint64 _lastOutClip = -1;

    bool _wantOn = false;
    int _retryCount = 0;
    QElapsedTimer _playingSince;
    QString _lastFailReason;

    QTimer _debounceTimer;
    QTimer _statusTimer;
    QTimer _retryTimer;
    QTimer _messageTimer;

    int _rtspPort = 8888;
    int _httpPort = 8889;
    bool _useTcp = false;
    int _latencyMs = 100;
    bool _autoStart = false;

    static constexpr int kDebounceMs = 150;
    static constexpr int kStatusPollMs = 300;
    static constexpr int kMaxRetries = 5;
    static constexpr int kMaxRetryDelayMs = 10000;
    // The retry counter is reset only after the stream played this long.
    // Two clients that take the mic from each other stop after kMaxRetries.
    static constexpr int kStablePlayMs = 30000;
    static constexpr const char *kSettingsGroup = "MicAudio";
};
