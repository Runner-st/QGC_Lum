/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CameraConfiguration.h"
#include "CameraStreamConfiguration.h"

#include <QtCore/QJsonArray>

CameraConfiguration::CameraConfiguration(QObject *parent)
    : QObject(parent)
    , _stream1(new CameraStreamConfiguration(this))
    , _stream2(new CameraStreamConfiguration(this))
{
}

CameraConfiguration::CameraConfiguration(const CameraConfiguration *source, QObject *parent)
    : QObject(parent)
    , _stream1(new CameraStreamConfiguration(this))
    , _stream2(new CameraStreamConfiguration(this))
{
    copyFrom(source);
}

void CameraConfiguration::setName(const QString &name)
{
    if (_name != name) {
        _name = name;
        emit nameChanged();
    }
}

void CameraConfiguration::setCameraType(CameraType type)
{
    if (_cameraType != type) {
        _cameraType = type;
        emit cameraTypeChanged();
    }
}

void CameraConfiguration::applyPreset()
{
    switch (_cameraType) {
    case HerelinkHDMI:
        _stream1->setName(QStringLiteral("Video"));
        _stream1->setRtspUrl(QString::fromLatin1(HERELINK_STREAM1_URL));
        _stream2->setName(QString());
        _stream2->setRtspUrl(QString());
        break;

    case SkydroidC12:
        _stream1->setName(QStringLiteral("Day"));
        _stream1->setRtspUrl(QString::fromLatin1(SKYDROID_STREAM1_URL));
        _stream2->setName(QStringLiteral("Thermal"));
        _stream2->setRtspUrl(QString::fromLatin1(SKYDROID_STREAM2_URL));
        break;

    case GenericIPCamera:
    default:
        // Don't clear user-entered URLs for generic camera
        break;
    }
}

bool CameraConfiguration::isEmpty() const
{
    return _name.isEmpty() && _stream1->isEmpty() && _stream2->isEmpty();
}

void CameraConfiguration::copyFrom(const CameraConfiguration *source)
{
    if (!source) return;

    setName(source->name());
    setCameraType(source->cameraType());
    _stream1->copyFrom(source->stream1());
    _stream2->copyFrom(source->stream2());
}

void CameraConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    settings.beginGroup(root);
    _name = settings.value("name", QString()).toString();
    _cameraType = static_cast<CameraType>(settings.value("cameraType", GenericIPCamera).toInt());
    settings.endGroup();

    _stream1->loadSettings(settings, root + "/Stream0");
    _stream2->loadSettings(settings, root + "/Stream1");
}

void CameraConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    settings.beginGroup(root);
    settings.setValue("name", _name);
    settings.setValue("cameraType", static_cast<int>(_cameraType));
    settings.endGroup();

    _stream1->saveSettings(settings, root + "/Stream0");
    _stream2->saveSettings(settings, root + "/Stream1");
}

QJsonObject CameraConfiguration::toJson() const
{
    QJsonObject json;
    json["name"] = _name;
    json["type"] = cameraTypeToString(_cameraType);

    QJsonArray streamsArray;
    streamsArray.append(_stream1->toJson());
    streamsArray.append(_stream2->toJson());
    json["streams"] = streamsArray;

    return json;
}

void CameraConfiguration::fromJson(const QJsonObject &json)
{
    setName(json["name"].toString());
    setCameraType(stringToCameraType(json["type"].toString()));

    QJsonArray streamsArray = json["streams"].toArray();
    if (streamsArray.size() > 0) {
        _stream1->fromJson(streamsArray[0].toObject());
    }
    if (streamsArray.size() > 1) {
        _stream2->fromJson(streamsArray[1].toObject());
    }
}

QString CameraConfiguration::cameraTypeToString(CameraType type)
{
    switch (type) {
    case HerelinkHDMI:
        return QStringLiteral("HerelinkHDMI");
    case SkydroidC12:
        return QStringLiteral("SkydroidC12");
    case GenericIPCamera:
    default:
        return QStringLiteral("GenericIPCamera");
    }
}

CameraConfiguration::CameraType CameraConfiguration::stringToCameraType(const QString &str)
{
    if (str == QStringLiteral("HerelinkHDMI")) {
        return HerelinkHDMI;
    } else if (str == QStringLiteral("SkydroidC12")) {
        return SkydroidC12;
    }
    return GenericIPCamera;
}
