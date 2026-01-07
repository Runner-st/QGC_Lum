/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QStringList>
#include <QtCore/QTimer>

#include "ManagedLinkConfiguration.h"
#include "QmlControls/QmlObjectListModel.h"

Q_DECLARE_LOGGING_CATEGORY(LinksManagerLog)

class LinksManagerController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QmlObjectListModel* managedLinks READ managedLinks CONSTANT)
    Q_PROPERTY(ManagedLinkConfiguration* activeLink READ activeLink NOTIFY activeLinkChanged)
    Q_PROPERTY(bool hasActiveLink READ hasActiveLink NOTIFY activeLinkChanged)

    // Video stream properties for active link
    Q_PROPERTY(QStringList activeStreamNames READ activeStreamNames NOTIFY activeStreamsChanged)
    Q_PROPERTY(QStringList activeStreamUrls READ activeStreamUrls NOTIFY activeStreamsChanged)
    Q_PROPERTY(int mainStreamIndex READ mainStreamIndex WRITE setMainStreamIndex NOTIFY mainStreamIndexChanged)

    // Servo buttons for active link
    Q_PROPERTY(QVariantList activeServoButtons READ activeServoButtons NOTIFY activeServoButtonsChanged)

public:
    explicit LinksManagerController(QObject *parent = nullptr);
    ~LinksManagerController() override;

    QmlObjectListModel* managedLinks() const { return _managedLinks; }

    ManagedLinkConfiguration* activeLink() const { return _activeLink; }
    bool hasActiveLink() const { return _activeLink != nullptr; }

    QStringList activeStreamNames() const { return _activeStreamNames; }
    QStringList activeStreamUrls() const { return _activeStreamUrls; }
    QVariantList activeServoButtons() const { return _activeServoButtons; }

    int mainStreamIndex() const { return _mainStreamIndex; }
    Q_INVOKABLE void setMainStreamIndex(int index);

    // CRUD operations
    Q_INVOKABLE ManagedLinkConfiguration* createConfiguration(const QString &name = QString());
    Q_INVOKABLE ManagedLinkConfiguration* duplicateForEditing(ManagedLinkConfiguration *config);
    Q_INVOKABLE void addConfiguration(ManagedLinkConfiguration *config);
    Q_INVOKABLE void saveConfiguration(ManagedLinkConfiguration *original, ManagedLinkConfiguration *edited);
    Q_INVOKABLE void removeConfiguration(ManagedLinkConfiguration *config);
    Q_INVOKABLE void cancelEditing(ManagedLinkConfiguration *config);

    // Connection management
    Q_INVOKABLE void activateLink(ManagedLinkConfiguration *config);
    Q_INVOKABLE void deactivateLink();
    Q_INVOKABLE void testConnection(ManagedLinkConfiguration *config);

    // Video stream management
    Q_INVOKABLE void swapMainStream(int pipIndex);

    // Import/Export (single link)
    Q_INVOKABLE bool importLinkFromJson(const QString &filePath);
    Q_INVOKABLE bool exportLinkToJson(ManagedLinkConfiguration *config, const QString &filePath);
    Q_INVOKABLE QString exportLinkToJsonString(ManagedLinkConfiguration *config) const;
    Q_INVOKABLE bool importLinkFromJsonString(const QString &jsonString);

signals:
    void activeLinkChanged();
    void activeStreamsChanged();
    void activeServoButtonsChanged();
    void mainStreamIndexChanged();
    void linksChanged();
    void testConnectionResult(ManagedLinkConfiguration *config, bool success, const QString &message);
    void importExportResult(bool success, const QString &message);

private slots:
    void _checkCommLinkState();
    void _onCommLinkDisconnected();

private:
    void _loadConfigurations();
    void _saveConfigurations();
    void _updateActiveStreams();
    void _updateActiveServoButtons();
    void _syncToCommLinks(ManagedLinkConfiguration *config);
    void _removeFromCommLinks(ManagedLinkConfiguration *config);
    void _connectCommLink(ManagedLinkConfiguration *config);
    void _disconnectCommLink(ManagedLinkConfiguration *config);
    void _watchCommLinkForDisconnect(ManagedLinkConfiguration *config);
    ManagedLinkConfiguration* _findManagedLinkByCommLinkName(const QString &commLinkName);
    QString _commLinkName(const QString &managedLinkName) const;

    QmlObjectListModel *_managedLinks = nullptr;
    ManagedLinkConfiguration *_activeLink = nullptr;
    QTimer *_linkStateTimer = nullptr;
    QMetaObject::Connection _disconnectConnection;

    QStringList _activeStreamNames;
    QStringList _activeStreamUrls;
    QStringList _activeCameraTypes;
    QVariantList _activeServoButtons;
    int _mainStreamIndex = 0;

    static constexpr const char* kSettingsGroup = "LinksManager";
    static constexpr const char* kLinkCountKey = "LinkCount";
    static constexpr const char* kActiveLinkKey = "ActiveLinkName";
    static constexpr const char* kCommLinkPrefix = "LM: ";
    static constexpr int kJsonVersion = 1;
};
