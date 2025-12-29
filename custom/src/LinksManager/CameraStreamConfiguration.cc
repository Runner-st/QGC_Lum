/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CameraStreamConfiguration.h"

CameraStreamConfiguration::CameraStreamConfiguration(QObject *parent)
    : QObject(parent)
{
}

CameraStreamConfiguration::CameraStreamConfiguration(const CameraStreamConfiguration *source, QObject *parent)
    : QObject(parent)
{
    copyFrom(source);
}

void CameraStreamConfiguration::setName(const QString &name)
{
    if (_name != name) {
        _name = name;
        emit nameChanged();
    }
}

void CameraStreamConfiguration::setRtspUrl(const QString &url)
{
    if (_rtspUrl != url) {
        _rtspUrl = url;
        emit rtspUrlChanged();
    }
}

void CameraStreamConfiguration::copyFrom(const CameraStreamConfiguration *source)
{
    if (!source) return;

    setName(source->name());
    setRtspUrl(source->rtspUrl());
}

void CameraStreamConfiguration::loadSettings(QSettings &settings, const QString &root)
{
    settings.beginGroup(root);
    _name = settings.value("name", QString()).toString();
    _rtspUrl = settings.value("rtspUrl", QString()).toString();
    settings.endGroup();
}

void CameraStreamConfiguration::saveSettings(QSettings &settings, const QString &root) const
{
    settings.beginGroup(root);
    settings.setValue("name", _name);
    settings.setValue("rtspUrl", _rtspUrl);
    settings.endGroup();
}

QJsonObject CameraStreamConfiguration::toJson() const
{
    QJsonObject json;
    json["name"] = _name;
    json["rtspUrl"] = _rtspUrl;
    return json;
}

void CameraStreamConfiguration::fromJson(const QJsonObject &json)
{
    setName(json["name"].toString());
    setRtspUrl(json["rtspUrl"].toString());
}
