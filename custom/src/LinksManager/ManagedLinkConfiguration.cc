/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ManagedLinkConfiguration.h"
#include "CameraConfiguration.h"
#include "CameraStreamConfiguration.h"

#include <QtCore/QJsonArray>

ManagedLinkConfiguration::ManagedLinkConfiguration(QObject *parent)
    : QObject(parent)
    , _camera1(new CameraConfiguration(this))
    , _camera2(new CameraConfiguration(this))
{
}

ManagedLinkConfiguration::ManagedLinkConfiguration(const QString &name, QObject *parent)
    : QObject(parent)
    , _name(name)
    , _camera1(new CameraConfiguration(this))
    , _camera2(new CameraConfiguration(this))
{
}

ManagedLinkConfiguration::ManagedLinkConfiguration(const ManagedLinkConfiguration *source, QObject *parent)
    : QObject(parent)
    , _camera1(new CameraConfiguration(this))
    , _camera2(new CameraConfiguration(this))
{
    copyFrom(source);
}

void ManagedLinkConfiguration::setName(const QString &name)
{
    if (_name != name) {
        _name = name;
        emit nameChanged();
    }
}

void ManagedLinkConfiguration::setServerAddress(const QString &address)
{
    if (_serverAddress != address) {
        _serverAddress = address;
        emit serverAddressChanged();
    }
}

void ManagedLinkConfiguration::setServerPort(quint16 port)
{
    if (_serverPort != port) {
        _serverPort = port;
        emit serverPortChanged();
    }
}

void ManagedLinkConfiguration::setAutoConnect(bool autoConnect)
{
    if (_autoConnect != autoConnect) {
        _autoConnect = autoConnect;
        emit autoConnectChanged();
    }
}

QStringList ManagedLinkConfiguration::getAllStreamUrls() const
{
    QStringList urls;

    if (_camera1 && !_camera1->stream1()->isEmpty()) {
        urls.append(_camera1->stream1()->rtspUrl());
    }
    if (_camera1 && !_camera1->stream2()->isEmpty()) {
        urls.append(_camera1->stream2()->rtspUrl());
    }
    if (_camera2 && !_camera2->stream1()->isEmpty()) {
        urls.append(_camera2->stream1()->rtspUrl());
    }
    if (_camera2 && !_camera2->stream2()->isEmpty()) {
        urls.append(_camera2->stream2()->rtspUrl());
    }

    return urls;
}

QStringList ManagedLinkConfiguration::getAllStreamNames() const
{
    QStringList names;

    if (_camera1 && !_camera1->stream1()->isEmpty()) {
        QString streamName = _camera1->stream1()->name();
        if (streamName.isEmpty()) {
            streamName = _camera1->name().isEmpty() ? QStringLiteral("Camera 1 - Stream 1") : _camera1->name() + QStringLiteral(" - Stream 1");
        }
        names.append(streamName);
    }
    if (_camera1 && !_camera1->stream2()->isEmpty()) {
        QString streamName = _camera1->stream2()->name();
        if (streamName.isEmpty()) {
            streamName = _camera1->name().isEmpty() ? QStringLiteral("Camera 1 - Stream 2") : _camera1->name() + QStringLiteral(" - Stream 2");
        }
        names.append(streamName);
    }
    if (_camera2 && !_camera2->stream1()->isEmpty()) {
        QString streamName = _camera2->stream1()->name();
        if (streamName.isEmpty()) {
            streamName = _camera2->name().isEmpty() ? QStringLiteral("Camera 2 - Stream 1") : _camera2->name() + QStringLiteral(" - Stream 1");
        }
        names.append(streamName);
    }
    if (_camera2 && !_camera2->stream2()->isEmpty()) {
        QString streamName = _camera2->stream2()->name();
        if (streamName.isEmpty()) {
            streamName = _camera2->name().isEmpty() ? QStringLiteral("Camera 2 - Stream 2") : _camera2->name() + QStringLiteral(" - Stream 2");
        }
        names.append(streamName);
    }

    return names;
}

void ManagedLinkConfiguration::copyFrom(const ManagedLinkConfiguration *source)
{
    if (!source) return;

    setName(source->name());
    setServerAddress(source->serverAddress());
    setServerPort(source->serverPort());
    setAutoConnect(source->isAutoConnect());
    _camera1->copyFrom(source->camera1());
    _camera2->copyFrom(source->camera2());
}

void ManagedLinkConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    settings.beginGroup(root);
    _name = settings.value("name", QString()).toString();
    _serverAddress = settings.value("serverAddress", QString()).toString();
    _serverPort = static_cast<quint16>(settings.value("serverPort", DEFAULT_UDP_PORT).toUInt());
    _autoConnect = settings.value("autoConnect", false).toBool();
    settings.endGroup();

    _camera1->loadSettings(settings, root + "/Camera0");
    _camera2->loadSettings(settings, root + "/Camera1");
}

void ManagedLinkConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    settings.beginGroup(root);
    settings.setValue("name", _name);
    settings.setValue("serverAddress", _serverAddress);
    settings.setValue("serverPort", _serverPort);
    settings.setValue("autoConnect", _autoConnect);
    settings.endGroup();

    _camera1->saveSettings(settings, root + "/Camera0");
    _camera2->saveSettings(settings, root + "/Camera1");
}

QJsonObject ManagedLinkConfiguration::toJson() const
{
    QJsonObject json;
    json["name"] = _name;
    json["serverAddress"] = _serverAddress;
    json["serverPort"] = static_cast<int>(_serverPort);
    json["autoConnect"] = _autoConnect;

    QJsonArray camerasArray;
    camerasArray.append(_camera1->toJson());
    camerasArray.append(_camera2->toJson());
    json["cameras"] = camerasArray;

    return json;
}

void ManagedLinkConfiguration::fromJson(const QJsonObject &json)
{
    setName(json["name"].toString());
    setServerAddress(json["serverAddress"].toString());
    setServerPort(static_cast<quint16>(json["serverPort"].toInt(DEFAULT_UDP_PORT)));
    setAutoConnect(json["autoConnect"].toBool());

    QJsonArray camerasArray = json["cameras"].toArray();
    if (camerasArray.size() > 0) {
        _camera1->fromJson(camerasArray[0].toObject());
    }
    if (camerasArray.size() > 1) {
        _camera2->fromJson(camerasArray[1].toObject());
    }
}
