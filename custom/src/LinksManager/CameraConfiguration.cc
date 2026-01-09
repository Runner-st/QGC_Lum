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

void CameraConfiguration::setC12CameraIp(const QString &ip)
{
    if (_c12CameraIp != ip) {
        _c12CameraIp = ip;
        emit c12CameraIpChanged();
        // If this is a C12 camera, regenerate URLs
        if (_cameraType == SkydroidC12) {
            applyPreset();
        }
    }
}

void CameraConfiguration::setC12Rtsp1Suffix(const QString &suffix)
{
    if (_c12Rtsp1Suffix != suffix) {
        _c12Rtsp1Suffix = suffix;
        emit c12Rtsp1SuffixChanged();
        if (_cameraType == SkydroidC12) {
            applyPreset();
        }
    }
}

void CameraConfiguration::setC12Rtsp2Suffix(const QString &suffix)
{
    if (_c12Rtsp2Suffix != suffix) {
        _c12Rtsp2Suffix = suffix;
        emit c12Rtsp2SuffixChanged();
        if (_cameraType == SkydroidC12) {
            applyPreset();
        }
    }
}

void CameraConfiguration::setC12ControlPort(int port)
{
    if (_c12ControlPort != port) {
        _c12ControlPort = port;
        emit c12ControlPortChanged();
    }
}

void CameraConfiguration::setTopotekCameraIp(const QString &ip)
{
    if (_topotekCameraIp != ip) {
        _topotekCameraIp = ip;
        emit topotekCameraIpChanged();
        // If this is a Topotek camera, regenerate URLs
        if (_cameraType == TopotekKHP290A609) {
            applyPreset();
        }
    }
}

void CameraConfiguration::setTopotekRtsp1Suffix(const QString &suffix)
{
    if (_topotekRtsp1Suffix != suffix) {
        _topotekRtsp1Suffix = suffix;
        emit topotekRtsp1SuffixChanged();
        if (_cameraType == TopotekKHP290A609) {
            applyPreset();
        }
    }
}

void CameraConfiguration::setTopotekRtsp2Suffix(const QString &suffix)
{
    if (_topotekRtsp2Suffix != suffix) {
        _topotekRtsp2Suffix = suffix;
        emit topotekRtsp2SuffixChanged();
        if (_cameraType == TopotekKHP290A609) {
            applyPreset();
        }
    }
}

void CameraConfiguration::setTopotekControlPort(int port)
{
    if (_topotekControlPort != port) {
        _topotekControlPort = port;
        emit topotekControlPortChanged();
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
        // Generate URLs dynamically from C12 properties
        _stream1->setName(QStringLiteral("Day"));
        _stream1->setRtspUrl(QStringLiteral("rtsp://%1:%2")
            .arg(_c12CameraIp, _c12Rtsp1Suffix));

        _stream2->setName(QStringLiteral("Thermal"));
        _stream2->setRtspUrl(QStringLiteral("rtsp://%1:%2")
            .arg(_c12CameraIp, _c12Rtsp2Suffix));
        break;

    case TopotekKHP290A609:
        // Generate URLs dynamically from Topotek properties
        _stream1->setName(QStringLiteral("EO"));
        _stream1->setRtspUrl(QStringLiteral("rtsp://%1:%2")
            .arg(_topotekCameraIp, _topotekRtsp1Suffix));

        _stream2->setName(QStringLiteral("IR"));
        _stream2->setRtspUrl(QStringLiteral("rtsp://%1:%2")
            .arg(_topotekCameraIp, _topotekRtsp2Suffix));
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

    // Copy C12-specific properties
    setC12CameraIp(source->c12CameraIp());
    setC12Rtsp1Suffix(source->c12Rtsp1Suffix());
    setC12Rtsp2Suffix(source->c12Rtsp2Suffix());
    setC12ControlPort(source->c12ControlPort());

    // Copy Topotek-specific properties
    setTopotekCameraIp(source->topotekCameraIp());
    setTopotekRtsp1Suffix(source->topotekRtsp1Suffix());
    setTopotekRtsp2Suffix(source->topotekRtsp2Suffix());
    setTopotekControlPort(source->topotekControlPort());

    _stream1->copyFrom(source->stream1());
    _stream2->copyFrom(source->stream2());
}

void CameraConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    settings.beginGroup(root);
    _name = settings.value("name", QString()).toString();
    _cameraType = static_cast<CameraType>(settings.value("cameraType", GenericIPCamera).toInt());

    // Load C12-specific settings
    _c12CameraIp = settings.value("c12CameraIp", "192.168.144.108").toString();
    _c12Rtsp1Suffix = settings.value("c12Rtsp1Suffix", "554/stream=1").toString();
    _c12Rtsp2Suffix = settings.value("c12Rtsp2Suffix", "555/stream=2").toString();
    _c12ControlPort = settings.value("c12ControlPort", 5000).toInt();

    // Load Topotek-specific settings
    _topotekCameraIp = settings.value("topotekCameraIp", "192.168.144.108").toString();
    _topotekRtsp1Suffix = settings.value("topotekRtsp1Suffix", "554/stream=0").toString();
    _topotekRtsp2Suffix = settings.value("topotekRtsp2Suffix", "554/stream=1").toString();
    _topotekControlPort = settings.value("topotekControlPort", 9003).toInt();

    settings.endGroup();

    _stream1->loadSettings(settings, root + "/Stream0");
    _stream2->loadSettings(settings, root + "/Stream1");
}

void CameraConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    settings.beginGroup(root);
    settings.setValue("name", _name);
    settings.setValue("cameraType", static_cast<int>(_cameraType));

    // Save C12-specific settings
    settings.setValue("c12CameraIp", _c12CameraIp);
    settings.setValue("c12Rtsp1Suffix", _c12Rtsp1Suffix);
    settings.setValue("c12Rtsp2Suffix", _c12Rtsp2Suffix);
    settings.setValue("c12ControlPort", _c12ControlPort);

    // Save Topotek-specific settings
    settings.setValue("topotekCameraIp", _topotekCameraIp);
    settings.setValue("topotekRtsp1Suffix", _topotekRtsp1Suffix);
    settings.setValue("topotekRtsp2Suffix", _topotekRtsp2Suffix);
    settings.setValue("topotekControlPort", _topotekControlPort);

    settings.endGroup();

    _stream1->saveSettings(settings, root + "/Stream0");
    _stream2->saveSettings(settings, root + "/Stream1");
}

QJsonObject CameraConfiguration::toJson() const
{
    QJsonObject json;
    json["name"] = _name;
    json["type"] = cameraTypeToString(_cameraType);

    // Add C12-specific properties
    if (_cameraType == SkydroidC12) {
        json["c12CameraIp"] = _c12CameraIp;
        json["c12Rtsp1Suffix"] = _c12Rtsp1Suffix;
        json["c12Rtsp2Suffix"] = _c12Rtsp2Suffix;
        json["c12ControlPort"] = _c12ControlPort;
    }

    // Add Topotek-specific properties
    if (_cameraType == TopotekKHP290A609) {
        json["topotekCameraIp"] = _topotekCameraIp;
        json["topotekRtsp1Suffix"] = _topotekRtsp1Suffix;
        json["topotekRtsp2Suffix"] = _topotekRtsp2Suffix;
        json["topotekControlPort"] = _topotekControlPort;
    }

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

    // Load C12-specific properties if present
    if (json.contains("c12CameraIp")) {
        setC12CameraIp(json["c12CameraIp"].toString());
    }
    if (json.contains("c12Rtsp1Suffix")) {
        setC12Rtsp1Suffix(json["c12Rtsp1Suffix"].toString());
    }
    if (json.contains("c12Rtsp2Suffix")) {
        setC12Rtsp2Suffix(json["c12Rtsp2Suffix"].toString());
    }
    if (json.contains("c12ControlPort")) {
        setC12ControlPort(json["c12ControlPort"].toInt(5000));
    }

    // Load Topotek-specific properties if present
    if (json.contains("topotekCameraIp")) {
        setTopotekCameraIp(json["topotekCameraIp"].toString());
    }
    if (json.contains("topotekRtsp1Suffix")) {
        setTopotekRtsp1Suffix(json["topotekRtsp1Suffix"].toString());
    }
    if (json.contains("topotekRtsp2Suffix")) {
        setTopotekRtsp2Suffix(json["topotekRtsp2Suffix"].toString());
    }
    if (json.contains("topotekControlPort")) {
        setTopotekControlPort(json["topotekControlPort"].toInt(9003));
    }

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
    case TopotekKHP290A609:
        return QStringLiteral("TopotekKHP290A609");
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
    } else if (str == QStringLiteral("TopotekKHP290A609")) {
        return TopotekKHP290A609;
    }
    return GenericIPCamera;
}
