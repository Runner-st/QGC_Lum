/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ServoButtonConfiguration.h"

ServoButtonConfiguration::ServoButtonConfiguration(QObject *parent)
    : QObject(parent)
{
}

ServoButtonConfiguration::ServoButtonConfiguration(const QString &name, int channel, int pulseWidth, QObject *parent)
    : QObject(parent)
    , _name(name.trimmed())
    , _channel(qBound(MIN_CHANNEL, channel, MAX_CHANNEL))
    , _pulseWidth(qBound(MIN_PULSE, pulseWidth, MAX_PULSE))
{
}

ServoButtonConfiguration::ServoButtonConfiguration(const ServoButtonConfiguration *source, QObject *parent)
    : QObject(parent)
{
    copyFrom(source);
}

void ServoButtonConfiguration::setName(const QString &name)
{
    QString trimmed = name.trimmed();
    if (_name != trimmed) {
        _name = trimmed;
        emit nameChanged();
    }
}

void ServoButtonConfiguration::setChannel(int channel)
{
    int bounded = qBound(MIN_CHANNEL, channel, MAX_CHANNEL);
    if (_channel != bounded) {
        _channel = bounded;
        emit channelChanged();
    }
}

void ServoButtonConfiguration::setPulseWidth(int pulseWidth)
{
    int bounded = qBound(MIN_PULSE, pulseWidth, MAX_PULSE);
    if (_pulseWidth != bounded) {
        _pulseWidth = bounded;
        emit pulseWidthChanged();
    }
}

bool ServoButtonConfiguration::isValid() const
{
    return !_name.isEmpty() && _channel >= MIN_CHANNEL && _channel <= MAX_CHANNEL;
}

void ServoButtonConfiguration::copyFrom(const ServoButtonConfiguration *source)
{
    if (!source) return;

    setName(source->name());
    setChannel(source->channel());
    setPulseWidth(source->pulseWidth());
}

QJsonObject ServoButtonConfiguration::toJson() const
{
    QJsonObject json;
    json["name"] = _name;
    json["channel"] = _channel;
    json["pulse"] = _pulseWidth;
    return json;
}

void ServoButtonConfiguration::fromJson(const QJsonObject &json)
{
    setName(json["name"].toString());
    setChannel(json["channel"].toInt(MIN_CHANNEL));
    setPulseWidth(json["pulse"].toInt(DEFAULT_PULSE));
}
