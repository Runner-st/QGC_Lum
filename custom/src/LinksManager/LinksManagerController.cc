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

#include "QmlObjectListModel.h"
#include "LinkManager.h"
#include "UDPLink.h"

#include <QtCore/QFile>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonArray>
#include <QtCore/QSettings>

Q_LOGGING_CATEGORY(LinksManagerLog, "LinksManagerLog")

LinksManagerController::LinksManagerController(QObject *parent)
    : QObject(parent)
    , _managedLinks(new QmlObjectListModel(this))
{
    _loadConfigurations();
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

    // If this is the active link, update streams
    if (_activeLink == original) {
        _updateActiveStreams();
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

    _activeLink = config;
    _mainStreamIndex = 0;
    _updateActiveStreams();

    _saveConfigurations();

    emit activeLinkChanged();
    emit mainStreamIndexChanged();
}

void LinksManagerController::deactivateLink()
{
    if (!_activeLink) {
        return;
    }

    _activeLink = nullptr;
    _activeStreamNames.clear();
    _activeStreamUrls.clear();
    _mainStreamIndex = 0;

    _saveConfigurations();

    emit activeLinkChanged();
    emit activeStreamsChanged();
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
        emit mainStreamIndexChanged();
    }
}

bool LinksManagerController::importFromJson(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit importExportResult(false, tr("Cannot open file: %1").arg(filePath));
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    return importFromJsonString(QString::fromUtf8(data));
}

bool LinksManagerController::exportToJson(const QString &filePath)
{
    QString jsonString = exportToJsonString();
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

    emit importExportResult(true, tr("Exported %1 links").arg(_managedLinks->count()));
    return true;
}

QString LinksManagerController::exportToJsonString() const
{
    QJsonObject root;
    root["version"] = kJsonVersion;

    QJsonArray linksArray;
    for (int i = 0; i < _managedLinks->count(); i++) {
        ManagedLinkConfiguration *config = qobject_cast<ManagedLinkConfiguration*>(_managedLinks->get(i));
        if (config) {
            linksArray.append(config->toJson());
        }
    }
    root["links"] = linksArray;

    QJsonDocument doc(root);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

bool LinksManagerController::importFromJsonString(const QString &jsonString)
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

    QJsonArray linksArray = root["links"].toArray();
    int importedCount = 0;

    for (const QJsonValue &value : linksArray) {
        ManagedLinkConfiguration *config = new ManagedLinkConfiguration(this);
        config->fromJson(value.toObject());

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
        importedCount++;
    }

    _saveConfigurations();
    emit linksChanged();
    emit importExportResult(true, tr("Imported %1 links").arg(importedCount));

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

    if (_activeLink) {
        _activeStreamUrls = _activeLink->getAllStreamUrls();
        _activeStreamNames = _activeLink->getAllStreamNames();
    }

    emit activeStreamsChanged();
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

    // Create new UDP configuration using the public API
    LinkConfiguration *newConfig = linkManager->createConfiguration(LinkConfiguration::TypeUdp, linkName);
    UDPConfiguration *udpConfig = qobject_cast<UDPConfiguration*>(newConfig);
    if (udpConfig) {
        udpConfig->addHost(config->serverAddress(), config->serverPort());
        udpConfig->setAutoConnect(config->isAutoConnect());
        linkManager->endCreateConfiguration(udpConfig);
        linkManager->saveLinkConfigurationList();
        qCDebug(LinksManagerLog) << "Synced to Comm Links:" << linkName;
    } else {
        qCWarning(LinksManagerLog) << "Failed to create UDP configuration";
        if (newConfig) {
            delete newConfig;
        }
    }
}

void LinksManagerController::_removeFromCommLinks(ManagedLinkConfiguration *config)
{
    Q_UNUSED(config)
    // Note: The current LinkManager API doesn't provide public access to iterate configurations.
    // Comm Links created via Links Manager will persist until manually deleted by the user
    // through the Comm Links settings page, or when the application is restarted and they
    // are recreated via _syncToCommLinks.
    qCDebug(LinksManagerLog) << "Remove from Comm Links - manual deletion required";
}
