/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QJsonObject>
#include <QtCore/QSettings>

#include "CameraConfiguration.h"
#include "QmlControls/QmlObjectListModel.h"

class ServoButtonConfiguration;

class ManagedLinkConfiguration : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString serverAddress READ serverAddress WRITE setServerAddress NOTIFY serverAddressChanged)
    Q_PROPERTY(quint16 serverPort READ serverPort WRITE setServerPort NOTIFY serverPortChanged)
    Q_PROPERTY(bool autoConnect READ isAutoConnect WRITE setAutoConnect NOTIFY autoConnectChanged)
    Q_PROPERTY(int camerasCount READ camerasCount WRITE setCamerasCount NOTIFY camerasCountChanged)
    Q_PROPERTY(CameraConfiguration* camera1 READ camera1 CONSTANT)
    Q_PROPERTY(CameraConfiguration* camera2 READ camera2 CONSTANT)
    Q_PROPERTY(QmlObjectListModel* servoButtons READ servoButtons CONSTANT)

public:
    explicit ManagedLinkConfiguration(QObject *parent = nullptr);
    explicit ManagedLinkConfiguration(const QString &name, QObject *parent = nullptr);
    ManagedLinkConfiguration(const ManagedLinkConfiguration *source, QObject *parent = nullptr);
    ~ManagedLinkConfiguration() override = default;

    QString name() const { return _name; }
    void setName(const QString &name);

    QString serverAddress() const { return _serverAddress; }
    void setServerAddress(const QString &address);

    quint16 serverPort() const { return _serverPort; }
    void setServerPort(quint16 port);

    bool isAutoConnect() const { return _autoConnect; }
    void setAutoConnect(bool autoConnect);

    int camerasCount() const { return _camerasCount; }
    void setCamerasCount(int count);

    CameraConfiguration* camera1() const { return _camera1; }
    CameraConfiguration* camera2() const { return _camera2; }
    QmlObjectListModel* servoButtons() const { return _servoButtons; }

    Q_INVOKABLE ServoButtonConfiguration* addServoButton(const QString &name, int channel, int pulseWidth);
    Q_INVOKABLE void removeServoButton(int index);
    Q_INVOKABLE void updateServoButton(int index, const QString &name, int channel, int pulseWidth);

    QStringList getAllStreamUrls() const;
    QStringList getAllStreamNames() const;
    QStringList getAllCameraTypes() const;

    void copyFrom(const ManagedLinkConfiguration *source);
    void loadSettings(QSettings &settings, const QString &root);
    void saveSettings(QSettings &settings, const QString &root) const;

    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);

    static constexpr quint16 DEFAULT_UDP_PORT = 14550;

signals:
    void nameChanged();
    void serverAddressChanged();
    void serverPortChanged();
    void autoConnectChanged();
    void camerasCountChanged();

private:
    QString _name;
    QString _serverAddress;
    quint16 _serverPort = DEFAULT_UDP_PORT;
    bool _autoConnect = false;
    int _camerasCount = 1;
    CameraConfiguration *_camera1 = nullptr;
    CameraConfiguration *_camera2 = nullptr;
    QmlObjectListModel *_servoButtons = nullptr;
};
