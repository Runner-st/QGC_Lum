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
#include "ServoButtonConfiguration.h"

#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>

ManagedLinkConfiguration::ManagedLinkConfiguration(QObject *parent)
    : QObject(parent)
    , _camera1(new CameraConfiguration(this))
    , _camera2(new CameraConfiguration(this))
    , _servoButtons(new QmlObjectListModel(this))
{
}

ManagedLinkConfiguration::ManagedLinkConfiguration(const QString &name, QObject *parent)
    : QObject(parent)
    , _name(name)
    , _camera1(new CameraConfiguration(this))
    , _camera2(new CameraConfiguration(this))
    , _servoButtons(new QmlObjectListModel(this))
{
}

ManagedLinkConfiguration::ManagedLinkConfiguration(const ManagedLinkConfiguration *source, QObject *parent)
    : QObject(parent)
    , _camera1(new CameraConfiguration(this))
    , _camera2(new CameraConfiguration(this))
    , _servoButtons(new QmlObjectListModel(this))
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

void ManagedLinkConfiguration::setCamerasCount(int count)
{
    if (count < 1) count = 1;
    if (count > 2) count = 2;
    if (_camerasCount != count) {
        _camerasCount = count;
        emit camerasCountChanged();
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
    if (_camerasCount >= 2 && _camera2 && !_camera2->stream1()->isEmpty()) {
        urls.append(_camera2->stream1()->rtspUrl());
    }
    if (_camerasCount >= 2 && _camera2 && !_camera2->stream2()->isEmpty()) {
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
    if (_camerasCount >= 2 && _camera2 && !_camera2->stream1()->isEmpty()) {
        QString streamName = _camera2->stream1()->name();
        if (streamName.isEmpty()) {
            streamName = _camera2->name().isEmpty() ? QStringLiteral("Camera 2 - Stream 1") : _camera2->name() + QStringLiteral(" - Stream 1");
        }
        names.append(streamName);
    }
    if (_camerasCount >= 2 && _camera2 && !_camera2->stream2()->isEmpty()) {
        QString streamName = _camera2->stream2()->name();
        if (streamName.isEmpty()) {
            streamName = _camera2->name().isEmpty() ? QStringLiteral("Camera 2 - Stream 2") : _camera2->name() + QStringLiteral(" - Stream 2");
        }
        names.append(streamName);
    }

    return names;
}

QStringList ManagedLinkConfiguration::getAllCameraTypes() const
{
    QStringList types;

    auto cameraTypeToString = [](CameraConfiguration::CameraType type) -> QString {
        switch (type) {
            case CameraConfiguration::GenericIPCamera:
                return QStringLiteral("GenericIPCamera");
            case CameraConfiguration::HerelinkHDMI:
                return QStringLiteral("HerelinkHDMI");
            case CameraConfiguration::SkydroidC12:
                return QStringLiteral("SkydroidC12");
            case CameraConfiguration::TopotekKHP290A609:
                return QStringLiteral("TopotekKHP290A609");
            default:
                return QStringLiteral("GenericIPCamera");
        }
    };

    // Must match the same order as getAllStreamUrls()
    if (_camera1 && !_camera1->stream1()->isEmpty()) {
        types.append(cameraTypeToString(_camera1->cameraType()));
    }
    if (_camera1 && !_camera1->stream2()->isEmpty()) {
        types.append(cameraTypeToString(_camera1->cameraType()));
    }
    if (_camerasCount >= 2 && _camera2 && !_camera2->stream1()->isEmpty()) {
        types.append(cameraTypeToString(_camera2->cameraType()));
    }
    if (_camerasCount >= 2 && _camera2 && !_camera2->stream2()->isEmpty()) {
        types.append(cameraTypeToString(_camera2->cameraType()));
    }

    return types;
}

void ManagedLinkConfiguration::copyFrom(const ManagedLinkConfiguration *source)
{
    if (!source) return;

    setName(source->name());
    setServerAddress(source->serverAddress());
    setServerPort(source->serverPort());
    setAutoConnect(source->isAutoConnect());
    setCamerasCount(source->camerasCount());
    _camera1->copyFrom(source->camera1());
    _camera2->copyFrom(source->camera2());

    // Copy servo buttons
    _servoButtons->clearAndDeleteContents();
    for (int i = 0; i < source->servoButtons()->count(); i++) {
        auto *srcBtn = qobject_cast<ServoButtonConfiguration*>(source->servoButtons()->get(i));
        if (srcBtn) {
            addServoButton(srcBtn->name(), srcBtn->channel(), srcBtn->pulseWidth());
        }
    }
}

ServoButtonConfiguration* ManagedLinkConfiguration::addServoButton(const QString &name, int channel, int pulseWidth)
{
    auto *btn = new ServoButtonConfiguration(name, channel, pulseWidth, this);
    if (btn->isValid()) {
        _servoButtons->append(btn);
        return btn;
    }
    delete btn;
    return nullptr;
}

void ManagedLinkConfiguration::removeServoButton(int index)
{
    if (index >= 0 && index < _servoButtons->count()) {
        QObject *obj = _servoButtons->removeAt(index);
        if (obj) {
            obj->deleteLater();
        }
    }
}

void ManagedLinkConfiguration::updateServoButton(int index, const QString &name, int channel, int pulseWidth)
{
    if (index >= 0 && index < _servoButtons->count()) {
        auto *btn = qobject_cast<ServoButtonConfiguration*>(_servoButtons->get(index));
        if (btn) {
            btn->setName(name);
            btn->setChannel(channel);
            btn->setPulseWidth(pulseWidth);
        }
    }
}

void ManagedLinkConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    settings.beginGroup(root);
    _name = settings.value("name", QString()).toString();
    _serverAddress = settings.value("serverAddress", QString()).toString();
    _serverPort = static_cast<quint16>(settings.value("serverPort", DEFAULT_UDP_PORT).toUInt());
    _autoConnect = settings.value("autoConnect", false).toBool();
    _camerasCount = qBound(1, settings.value("camerasCount", 1).toInt(), 2);
    QString servoJson = settings.value("servoButtons", QString()).toString();
    settings.endGroup();

    _camera1->loadSettings(settings, root + "/Camera0");
    _camera2->loadSettings(settings, root + "/Camera1");

    // Parse servo buttons from JSON
    _servoButtons->clearAndDeleteContents();
    if (!servoJson.isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(servoJson.toUtf8());
        QJsonArray arr = doc.array();
        for (const QJsonValue &val : arr) {
            auto *btn = new ServoButtonConfiguration(this);
            btn->fromJson(val.toObject());
            if (btn->isValid()) {
                _servoButtons->append(btn);
            } else {
                delete btn;
            }
        }
    }
}

void ManagedLinkConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    // Serialize servo buttons to JSON
    QJsonArray servoArray;
    for (int i = 0; i < _servoButtons->count(); i++) {
        auto *btn = qobject_cast<ServoButtonConfiguration*>(_servoButtons->get(i));
        if (btn) {
            servoArray.append(btn->toJson());
        }
    }

    settings.beginGroup(root);
    settings.setValue("name", _name);
    settings.setValue("serverAddress", _serverAddress);
    settings.setValue("serverPort", _serverPort);
    settings.setValue("autoConnect", _autoConnect);
    settings.setValue("camerasCount", _camerasCount);
    settings.setValue("servoButtons", QString::fromUtf8(QJsonDocument(servoArray).toJson(QJsonDocument::Compact)));
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
    json["camerasCount"] = _camerasCount;

    QJsonArray camerasArray;
    camerasArray.append(_camera1->toJson());
    camerasArray.append(_camera2->toJson());
    json["cameras"] = camerasArray;

    // Add servo buttons
    QJsonArray servoArray;
    for (int i = 0; i < _servoButtons->count(); i++) {
        auto *btn = qobject_cast<ServoButtonConfiguration*>(_servoButtons->get(i));
        if (btn) {
            servoArray.append(btn->toJson());
        }
    }
    json["servoButtons"] = servoArray;

    return json;
}

void ManagedLinkConfiguration::fromJson(const QJsonObject &json)
{
    setName(json["name"].toString());
    setServerAddress(json["serverAddress"].toString());
    setServerPort(static_cast<quint16>(json["serverPort"].toInt(DEFAULT_UDP_PORT)));
    setAutoConnect(json["autoConnect"].toBool());
    setCamerasCount(json.contains("camerasCount") ? json["camerasCount"].toInt(1) : 1);

    QJsonArray camerasArray = json["cameras"].toArray();
    if (camerasArray.size() > 0) {
        _camera1->fromJson(camerasArray[0].toObject());
    }
    if (camerasArray.size() > 1) {
        _camera2->fromJson(camerasArray[1].toObject());
    }

    // Load servo buttons
    _servoButtons->clearAndDeleteContents();
    QJsonArray servoArray = json["servoButtons"].toArray();
    for (const QJsonValue &val : servoArray) {
        auto *btn = new ServoButtonConfiguration(this);
        btn->fromJson(val.toObject());
        if (btn->isValid()) {
            _servoButtons->append(btn);
        } else {
            delete btn;
        }
    }
}
