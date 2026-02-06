/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "LinksManagerController.h"
#include "ManagedLinkConfiguration.h"
#include "CameraConfiguration.h"
#include "CameraStreamConfiguration.h"
#include "ServoButtonConfiguration.h"

#include "QmlObjectListModel.h"
#include "LinkManager.h"
#include "LinkInterface.h"
#include "UDPLink.h"
#include "VideoManager/VideoManager.h"
#include "MultiVehicleManager.h"

#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonArray>
#include <QtCore/QSettings>

Q_LOGGING_CATEGORY(LinksManagerLog, "LinksManagerLog")

LinksManagerController::LinksManagerController(QObject *parent)
    : QObject(parent)
    , _managedLinks(new QmlObjectListModel(this))
    , _linkStateTimer(new QTimer(this))
    , _videoStartTimeoutTimer(new QTimer(this))
{
    // Setup video start timeout timer (single-shot) - must be before _loadConfigurations
    _videoStartTimeoutTimer->setSingleShot(true);
    connect(_videoStartTimeoutTimer, &QTimer::timeout, this, &LinksManagerController::_onVideoStartTimeout);

    // Connect to MultiVehicleManager to know when parameters are ready
    connect(MultiVehicleManager::instance(), &MultiVehicleManager::parameterReadyVehicleAvailableChanged,
            this, &LinksManagerController::_onParameterReadyVehicleAvailableChanged);

    // Load saved configurations (may start pending video timeout)
    _loadConfigurations();

    // Setup timer to check comm link state periodically
    connect(_linkStateTimer, &QTimer::timeout, this, &LinksManagerController::_checkCommLinkState);
    _linkStateTimer->start(1000); // Check every second
}

LinksManagerController::~LinksManagerController()
{
    _saveConfigurations();
}

ManagedLinkConfiguration* LinksManagerController::createConfiguration(const QString &name)
{
    return new ManagedLinkConfiguration(name, this);
}

ManagedLinkConfiguration* LinksManagerController::duplicateForEditing(ManagedLinkConfiguration *config)
{
    if (!config) {
        return nullptr;
    }
    return new ManagedLinkConfiguration(config, this);
}

void LinksManagerController::addConfiguration(ManagedLinkConfiguration *config)
{
    if (!config) {
        return;
    }

    // Take ownership
    config->setParent(this);

    _managedLinks->append(config);
    _syncToCommLinks(config);
    _saveConfigurations();

    emit linksChanged();
}

void LinksManagerController::saveConfiguration(ManagedLinkConfiguration *original, ManagedLinkConfiguration *edited)
{
    if (!original || !edited) {
        return;
    }

    original->copyFrom(edited);
    _syncToCommLinks(original);
    _saveConfigurations();

    // If this is the active link, update streams and servo buttons
    if (_activeLink == original) {
        _updateActiveStreams();
        _updateActiveServoButtons();
    }

    emit linksChanged();

    // Clean up the edited copy
    edited->deleteLater();
}

void LinksManagerController::removeConfiguration(ManagedLinkConfiguration *config)
{
    if (!config) {
        return;
    }

    // If this is the active link, deactivate first
    if (_activeLink == config) {
        deactivateLink();
    }

    // Remove from Comm Links
    _removeFromCommLinks(config);

    // Remove from our list
    _managedLinks->removeOne(config);
    _saveConfigurations();

    emit linksChanged();

    config->deleteLater();
}

void LinksManagerController::activateLink(ManagedLinkConfiguration *config)
{
    if (_activeLink == config) {
        return;
    }

    // Cancel any pending video from previous link
    _cancelPendingVideo();

    _activeLink = config;
    _mainStreamIndex = 0;
    _updateActiveStreams();
    _updateActiveServoButtons();

    // Store pending video config instead of starting immediately
    // This delays video start until FC parameters are loaded to prevent bandwidth contention
    if (_activeStreamUrls.count() > 0 && VideoManager::instance()) {
        _pendingCameraType = (_activeCameraTypes.count() > _mainStreamIndex)
            ? _activeCameraTypes[_mainStreamIndex] : QString();
        _pendingVideoUri = _activeStreamUrls[_mainStreamIndex];
        _pendingVideoStart = true;
        emit videoStartPendingChanged();

        qCDebug(LinksManagerLog) << "Pending video start for URI:" << _pendingVideoUri;

        // Check if parameters are already ready (use property system since getter is private)
        bool parametersReady = MultiVehicleManager::instance()->property("parameterReadyVehicleAvailable").toBool();
        if (parametersReady) {
            qCDebug(LinksManagerLog) << "Parameters already ready, starting video immediately";
            _startPendingVideo();
        } else {
            qCDebug(LinksManagerLog) << "Waiting for parameters, starting" << kVideoStartTimeoutMs << "ms timeout";
            _videoStartTimeoutTimer->start(kVideoStartTimeoutMs);
        }
    }

    // Find and connect the corresponding comm link
    if (config && !config->serverAddress().isEmpty()) {
        _connectCommLink(config);
    }

    _saveConfigurations();

    emit activeLinkChanged();
    emit mainStreamIndexChanged();
}

void LinksManagerController::deactivateLink()
{
    if (!_activeLink) {
        return;
    }

    // Cancel any pending video start
    _cancelPendingVideo();

    // Disconnect the comm link before deactivating
    _disconnectCommLink(_activeLink);

    // Clear VideoManager override to restore default video settings
    if (VideoManager::instance()) {
        VideoManager::instance()->clearOverrideUri();
    }

    _activeLink = nullptr;
    _activeStreamNames.clear();
    _activeStreamUrls.clear();
    _activeCameraTypes.clear();
    _activeServoButtons.clear();
    _mainStreamIndex = 0;

    _saveConfigurations();

    emit activeLinkChanged();
    emit activeStreamsChanged();
    emit activeServoButtonsChanged();
    emit mainStreamIndexChanged();
}

void LinksManagerController::testConnection(ManagedLinkConfiguration *config)
{
    if (!config) {
        emit testConnectionResult(config, false, tr("Invalid configuration"));
        return;
    }

    if (config->serverAddress().isEmpty()) {
        emit testConnectionResult(config, false, tr("Server address is empty"));
        return;
    }

    // For now, just emit success if the address is valid
    // TODO: Implement actual UDP ping test
    emit testConnectionResult(config, true, tr("Configuration looks valid"));
}

void LinksManagerController::swapMainStream(int pipIndex)
{
    if (pipIndex < 0 || pipIndex >= _activeStreamUrls.count()) {
        return;
    }

    // Swap the stream at pipIndex with the main stream (index 0)
    if (_mainStreamIndex != pipIndex) {
        // Swap URLs
        QString tempUrl = _activeStreamUrls[_mainStreamIndex];
        _activeStreamUrls[_mainStreamIndex] = _activeStreamUrls[pipIndex];
        _activeStreamUrls[pipIndex] = tempUrl;

        // Swap names
        QString tempName = _activeStreamNames[_mainStreamIndex];
        _activeStreamNames[_mainStreamIndex] = _activeStreamNames[pipIndex];
        _activeStreamNames[pipIndex] = tempName;

        emit activeStreamsChanged();
    }
}

void LinksManagerController::setMainStreamIndex(int index)
{
    if (_mainStreamIndex != index && index >= 0 && index < _activeStreamUrls.count()) {
        _mainStreamIndex = index;

        // If video start is pending, update the pending values
        if (_pendingVideoStart) {
            _pendingCameraType = (_activeCameraTypes.count() > _mainStreamIndex)
                ? _activeCameraTypes[_mainStreamIndex] : QString();
            _pendingVideoUri = _activeStreamUrls[_mainStreamIndex];
            qCDebug(LinksManagerLog) << "Updated pending video to:" << _pendingVideoUri;
        } else if (VideoManager::instance()) {
            // Video already running, update immediately
            // Note: Set camera type BEFORE URI because setOverrideUri triggers video start
            if (_activeCameraTypes.count() > _mainStreamIndex) {
                VideoManager::instance()->setOverrideCameraType(_activeCameraTypes[_mainStreamIndex]);
            }
            VideoManager::instance()->setOverrideUri(_activeStreamUrls[_mainStreamIndex]);
        }

        emit mainStreamIndexChanged();
    }
}

bool LinksManagerController::importLinkFromJson(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit importExportResult(false, tr("Cannot open file: %1").arg(filePath));
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    return importLinkFromJsonString(QString::fromUtf8(data));
}

bool LinksManagerController::exportLinkToJson(ManagedLinkConfiguration *config, const QString &filePath)
{
    if (!config) {
        emit importExportResult(false, tr("No link selected for export"));
        return false;
    }

    QString jsonString = exportLinkToJsonString(config);
    if (jsonString.isEmpty()) {
        emit importExportResult(false, tr("Failed to generate JSON"));
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit importExportResult(false, tr("Cannot write to file: %1").arg(filePath));
        return false;
    }

    file.write(jsonString.toUtf8());
    file.close();

    emit importExportResult(true, tr("Exported link: %1").arg(config->name()));
    return true;
}

QString LinksManagerController::exportLinkToJsonString(ManagedLinkConfiguration *config) const
{
    if (!config) {
        return QString();
    }

    QJsonObject root;
    root["version"] = kJsonVersion;
    root["link"] = config->toJson();

    QJsonDocument doc(root);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

bool LinksManagerController::importLinkFromJsonString(const QString &jsonString)
{
    QJsonParseError error;
    QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8(), &error);

    if (error.error != QJsonParseError::NoError) {
        emit importExportResult(false, tr("JSON parse error: %1").arg(error.errorString()));
        return false;
    }

    QJsonObject root = doc.object();
    int version = root["version"].toInt();
    if (version > kJsonVersion) {
        emit importExportResult(false, tr("Unsupported JSON version: %1").arg(version));
        return false;
    }

    // Handle single link format
    QJsonObject linkObj = root["link"].toObject();
    if (linkObj.isEmpty()) {
        emit importExportResult(false, tr("Invalid link data in JSON"));
        return false;
    }

    ManagedLinkConfiguration *config = new ManagedLinkConfiguration(this);
    config->fromJson(linkObj);

    // Check for duplicate names
    bool duplicate = false;
    for (int i = 0; i < _managedLinks->count(); i++) {
        ManagedLinkConfiguration *existing = qobject_cast<ManagedLinkConfiguration*>(_managedLinks->get(i));
        if (existing && existing->name() == config->name()) {
            duplicate = true;
            break;
        }
    }

    if (duplicate) {
        config->setName(config->name() + tr(" (imported)"));
    }

    _managedLinks->append(config);
    _syncToCommLinks(config);

    _saveConfigurations();
    emit linksChanged();
    emit importExportResult(true, tr("Imported link: %1").arg(config->name()));

    return true;
}

void LinksManagerController::_loadConfigurations()
{
    QSettings settings;
    settings.beginGroup(kSettingsGroup);

    int count = settings.value(kLinkCountKey, 0).toInt();
    QString activeLinkName = settings.value(kActiveLinkKey, QString()).toString();

    settings.endGroup();

    for (int i = 0; i < count; i++) {
        ManagedLinkConfiguration *config = new ManagedLinkConfiguration(this);
        config->loadSettings(settings, QString("%1/Link%2").arg(kSettingsGroup).arg(i));
        _managedLinks->append(config);

        // Restore active link
        if (!activeLinkName.isEmpty() && config->name() == activeLinkName) {
            _activeLink = config;
        }
    }

    if (_activeLink) {
        _updateActiveStreams();
        _updateActiveServoButtons();

        // Set up pending video state for restored link - don't start video yet
        // Video will start when parameters are ready or timeout occurs
        if (_activeStreamUrls.count() > 0) {
            _pendingCameraType = (_activeCameraTypes.count() > _mainStreamIndex)
                ? _activeCameraTypes[_mainStreamIndex] : QString();
            _pendingVideoUri = _activeStreamUrls[_mainStreamIndex];
            _pendingVideoStart = true;

            qCDebug(LinksManagerLog) << "Restored active link with pending video:" << _pendingVideoUri;

            // Start timeout - parameters ready signal will cancel it if FC connects first
            _videoStartTimeoutTimer->start(kVideoStartTimeoutMs);
        }

        emit activeLinkChanged();
    }

    qCDebug(LinksManagerLog) << "Loaded" << count << "managed links";
}

void LinksManagerController::_saveConfigurations()
{
    QSettings settings;

    // Clear old settings
    settings.remove(kSettingsGroup);

    settings.beginGroup(kSettingsGroup);
    settings.setValue(kLinkCountKey, _managedLinks->count());
    settings.setValue(kActiveLinkKey, _activeLink ? _activeLink->name() : QString());
    settings.endGroup();

    for (int i = 0; i < _managedLinks->count(); i++) {
        ManagedLinkConfiguration *config = qobject_cast<ManagedLinkConfiguration*>(_managedLinks->get(i));
        if (config) {
            config->saveSettings(settings, QString("%1/Link%2").arg(kSettingsGroup).arg(i));
        }
    }

    qCDebug(LinksManagerLog) << "Saved" << _managedLinks->count() << "managed links";
}

void LinksManagerController::_updateActiveStreams()
{
    _activeStreamNames.clear();
    _activeStreamUrls.clear();
    _activeCameraTypes.clear();

    if (_activeLink) {
        _activeStreamUrls = _activeLink->getAllStreamUrls();
        _activeStreamNames = _activeLink->getAllStreamNames();
        _activeCameraTypes = _activeLink->getAllCameraTypes();
    }

    emit activeStreamsChanged();
}

void LinksManagerController::_updateActiveServoButtons()
{
    _activeServoButtons.clear();

    if (_activeLink && _activeLink->servoButtons()) {
        for (int i = 0; i < _activeLink->servoButtons()->count(); i++) {
            auto *btn = qobject_cast<ServoButtonConfiguration*>(_activeLink->servoButtons()->get(i));
            if (btn && btn->isValid()) {
                QVariantMap map;
                map["name"] = btn->name();
                map["channel"] = btn->channel();
                map["pulse"] = btn->pulseWidth();
                _activeServoButtons.append(map);
            }
        }
    }

    emit activeServoButtonsChanged();
}

QString LinksManagerController::_commLinkName(const QString &managedLinkName) const
{
    return QString::fromLatin1(kCommLinkPrefix) + managedLinkName;
}

void LinksManagerController::_syncToCommLinks(ManagedLinkConfiguration *config)
{
    if (!config || config->serverAddress().isEmpty()) {
        return;
    }

    LinkManager *linkManager = LinkManager::instance();
    if (!linkManager) {
        qCWarning(LinksManagerLog) << "LinkManager not available";
        return;
    }

    QString linkName = _commLinkName(config->name());

    // Check if configuration already exists
    SharedLinkConfigurationPtr existingConfig = nullptr;
    for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
        if (cfg && cfg->name() == linkName) {
            existingConfig = cfg;
            break;
        }
    }

    if (existingConfig) {
        // Update existing configuration
        UDPConfiguration *udpConfig = qobject_cast<UDPConfiguration*>(existingConfig.get());
        if (udpConfig) {
            // Clear existing hosts and add the new one
            while (udpConfig->hostList().count() > 0) {
                udpConfig->removeHost(udpConfig->hostList().first());
            }
            udpConfig->addHost(config->serverAddress(), config->serverPort());
            udpConfig->setAutoConnect(config->isAutoConnect());
            linkManager->saveLinkConfigurationList();
            qCDebug(LinksManagerLog) << "Updated existing Comm Link:" << linkName;
        }
    } else {
        // Create new UDP configuration using the public API
        LinkConfiguration *newConfig = linkManager->createConfiguration(LinkConfiguration::TypeUdp, linkName);
        UDPConfiguration *udpConfig = qobject_cast<UDPConfiguration*>(newConfig);
        if (udpConfig) {
            udpConfig->addHost(config->serverAddress(), config->serverPort());
            udpConfig->setAutoConnect(config->isAutoConnect());
            linkManager->endCreateConfiguration(udpConfig);
            linkManager->saveLinkConfigurationList();
            qCDebug(LinksManagerLog) << "Created new Comm Link:" << linkName;
        } else {
            qCWarning(LinksManagerLog) << "Failed to create UDP configuration";
            if (newConfig) {
                delete newConfig;
            }
        }
    }
}

void LinksManagerController::_removeFromCommLinks(ManagedLinkConfiguration *config)
{
    if (!config) {
        return;
    }

    LinkManager *linkManager = LinkManager::instance();
    if (!linkManager) {
        return;
    }

    QString linkName = _commLinkName(config->name());

    // Find and remove the configuration
    for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
        if (cfg && cfg->name() == linkName) {
            linkManager->removeConfiguration(cfg.get());
            qCDebug(LinksManagerLog) << "Removed Comm Link:" << linkName;
            return;
        }
    }

    qCDebug(LinksManagerLog) << "Comm Link not found for removal:" << linkName;
}

void LinksManagerController::_connectCommLink(ManagedLinkConfiguration *config)
{
    if (!config || config->serverAddress().isEmpty()) {
        qCWarning(LinksManagerLog) << "Invalid config for connection";
        return;
    }

    LinkManager *linkManager = LinkManager::instance();
    if (!linkManager) {
        qCWarning(LinksManagerLog) << "LinkManager not available";
        return;
    }

    QString linkName = _commLinkName(config->name());

    // Find the corresponding comm link configuration
    for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
        if (cfg && cfg->name() == linkName) {
            // Check if already connected
            if (cfg->link()) {
                qCDebug(LinksManagerLog) << "Link already connected:" << linkName;
                return;
            }

            // Connect the link
            linkManager->createConnectedLink(cfg.get());
            qCDebug(LinksManagerLog) << "Initiated connection for:" << linkName;
            return;
        }
    }

    // Configuration doesn't exist yet, create and connect it
    qCDebug(LinksManagerLog) << "Comm link not found, creating:" << linkName;
    _syncToCommLinks(config);

    // Now try to connect the newly created link
    for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
        if (cfg && cfg->name() == linkName) {
            linkManager->createConnectedLink(cfg.get());
            qCDebug(LinksManagerLog) << "Created and connected:" << linkName;
            return;
        }
    }
}

void LinksManagerController::_disconnectCommLink(ManagedLinkConfiguration *config)
{
    if (!config) {
        return;
    }

    LinkManager *linkManager = LinkManager::instance();
    if (!linkManager) {
        qCWarning(LinksManagerLog) << "LinkManager not available for disconnect";
        return;
    }

    QString linkName = _commLinkName(config->name());

    // Find the corresponding comm link configuration and disconnect it
    for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
        if (cfg && cfg->name() == linkName) {
            LinkInterface *link = cfg->link();
            if (link) {
                link->disconnect();
                qCDebug(LinksManagerLog) << "Disconnected comm link:" << linkName;
            } else {
                qCDebug(LinksManagerLog) << "Comm link not connected:" << linkName;
            }
            return;
        }
    }

    qCDebug(LinksManagerLog) << "Comm link not found for disconnect:" << linkName;
}

void LinksManagerController::cancelEditing(ManagedLinkConfiguration *config)
{
    if (config) {
        config->deleteLater();
    }
}

void LinksManagerController::_checkCommLinkState()
{
    LinkManager *linkManager = LinkManager::instance();
    if (!linkManager) {
        return;
    }

    // Check each managed link's corresponding comm link state
    for (int i = 0; i < _managedLinks->count(); i++) {
        ManagedLinkConfiguration *config = qobject_cast<ManagedLinkConfiguration*>(_managedLinks->get(i));
        if (!config) continue;

        QString linkName = _commLinkName(config->name());
        bool commLinkConnected = false;

        // Find if comm link exists and is connected
        for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
            if (cfg && cfg->name() == linkName) {
                commLinkConnected = (cfg->link() != nullptr);
                break;
            }
        }

        // Sync state: If comm link connected but not active in LinksManager, activate it
        if (commLinkConnected && _activeLink != config) {
            qCDebug(LinksManagerLog) << "Auto-activating link due to comm link connection:" << config->name();

            // Cancel any pending video from previous link
            _cancelPendingVideo();

            _activeLink = config;
            _mainStreamIndex = 0;
            _updateActiveStreams();
            _updateActiveServoButtons();

            // Store pending video config instead of starting immediately
            // This delays video start until FC parameters are loaded to prevent bandwidth contention
            if (_activeStreamUrls.count() > 0 && VideoManager::instance()) {
                _pendingCameraType = (_activeCameraTypes.count() > _mainStreamIndex)
                    ? _activeCameraTypes[_mainStreamIndex] : QString();
                _pendingVideoUri = _activeStreamUrls[_mainStreamIndex];
                _pendingVideoStart = true;
                emit videoStartPendingChanged();

                qCDebug(LinksManagerLog) << "Pending video start for URI:" << _pendingVideoUri;

                // Check if parameters are already ready (use property system since getter is private)
                bool parametersReady = MultiVehicleManager::instance()->property("parameterReadyVehicleAvailable").toBool();
                if (parametersReady) {
                    qCDebug(LinksManagerLog) << "Parameters already ready, starting video immediately";
                    _startPendingVideo();
                } else {
                    qCDebug(LinksManagerLog) << "Waiting for parameters, starting" << kVideoStartTimeoutMs << "ms timeout";
                    _videoStartTimeoutTimer->start(kVideoStartTimeoutMs);
                }
            }

            _watchCommLinkForDisconnect(config);
            _saveConfigurations();
            emit activeLinkChanged();
            emit mainStreamIndexChanged();
        }
        // If this was active but comm link is now disconnected, deactivate
        else if (!commLinkConnected && _activeLink == config) {
            qCDebug(LinksManagerLog) << "Auto-deactivating link due to comm link disconnection:" << config->name();

            // Cancel any pending video start
            _cancelPendingVideo();

            // Clear VideoManager override to restore default video settings
            if (VideoManager::instance()) {
                VideoManager::instance()->clearOverrideUri();
            }

            _activeLink = nullptr;
            _activeStreamNames.clear();
            _activeStreamUrls.clear();
            _activeCameraTypes.clear();
            _activeServoButtons.clear();
            _mainStreamIndex = 0;
            _saveConfigurations();
            emit activeLinkChanged();
            emit activeStreamsChanged();
            emit activeServoButtonsChanged();
            emit mainStreamIndexChanged();
        }
    }
}

void LinksManagerController::_onCommLinkDisconnected()
{
    qCDebug(LinksManagerLog) << "Comm link disconnected signal received";
    // The timer will pick this up and deactivate
}

void LinksManagerController::_watchCommLinkForDisconnect(ManagedLinkConfiguration *config)
{
    // Disconnect any previous connection
    if (_disconnectConnection) {
        disconnect(_disconnectConnection);
    }

    if (!config) {
        return;
    }

    LinkManager *linkManager = LinkManager::instance();
    if (!linkManager) {
        return;
    }

    QString linkName = _commLinkName(config->name());

    // Find the link and connect to its disconnected signal
    for (SharedLinkConfigurationPtr &cfg : linkManager->configurations()) {
        if (cfg && cfg->name() == linkName) {
            LinkInterface *link = cfg->link();
            if (link) {
                _disconnectConnection = connect(link, &LinkInterface::disconnected,
                                                 this, &LinksManagerController::_onCommLinkDisconnected);
                qCDebug(LinksManagerLog) << "Watching comm link for disconnect:" << linkName;
            }
            break;
        }
    }
}

ManagedLinkConfiguration* LinksManagerController::_findManagedLinkByCommLinkName(const QString &commLinkName)
{
    // Extract managed link name from comm link name (remove prefix)
    QString prefix = QString::fromLatin1(kCommLinkPrefix);
    if (!commLinkName.startsWith(prefix)) {
        return nullptr;
    }

    QString managedName = commLinkName.mid(prefix.length());

    for (int i = 0; i < _managedLinks->count(); i++) {
        ManagedLinkConfiguration *config = qobject_cast<ManagedLinkConfiguration*>(_managedLinks->get(i));
        if (config && config->name() == managedName) {
            return config;
        }
    }

    return nullptr;
}

void LinksManagerController::_startPendingVideo()
{
    if (!_pendingVideoStart) {
        return;
    }

    _videoStartTimeoutTimer->stop();

    qCDebug(LinksManagerLog) << "Starting pending video:" << _pendingVideoUri;

    if (VideoManager::instance()) {
        VideoManager::instance()->setOverrideCameraType(_pendingCameraType);

        // Set port forwarding mode from active camera configuration
        bool portForwarded = false;
        if (_activeLink && _activeLink->camera1()) {
            portForwarded = _activeLink->camera1()->isPortForwarded();
        }
        VideoManager::instance()->setPortForwarded(portForwarded);
        qCDebug(LinksManagerLog) << "Port forwarded mode:" << portForwarded;

        VideoManager::instance()->setOverrideUri(_pendingVideoUri);
    }

    _pendingVideoStart = false;
    _pendingVideoUri.clear();
    _pendingCameraType.clear();

    emit videoStartPendingChanged();
    emit videoStartReady();
}

void LinksManagerController::_cancelPendingVideo()
{
    if (!_pendingVideoStart) {
        return;
    }

    qCDebug(LinksManagerLog) << "Canceling pending video";

    _videoStartTimeoutTimer->stop();
    _pendingVideoStart = false;
    _pendingVideoUri.clear();
    _pendingCameraType.clear();

    emit videoStartPendingChanged();
}

void LinksManagerController::_onParameterReadyVehicleAvailableChanged(bool available)
{
    if (available && _pendingVideoStart) {
        qCDebug(LinksManagerLog) << "Parameters ready, starting pending video";
        _startPendingVideo();
    }
}

void LinksManagerController::_onVideoStartTimeout()
{
    if (_pendingVideoStart) {
        qCDebug(LinksManagerLog) << "Video start timeout reached, starting video without parameters";
        _startPendingVideo();
    }
}
