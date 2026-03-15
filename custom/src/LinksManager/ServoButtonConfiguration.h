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

class ServoButtonConfiguration : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(int channel READ channel WRITE setChannel NOTIFY channelChanged)
    Q_PROPERTY(int pulseWidth READ pulseWidth WRITE setPulseWidth NOTIFY pulseWidthChanged)

public:
    explicit ServoButtonConfiguration(QObject *parent = nullptr);
    ServoButtonConfiguration(const QString &name, int channel, int pulseWidth, QObject *parent = nullptr);
    ServoButtonConfiguration(const ServoButtonConfiguration *source, QObject *parent = nullptr);
    ~ServoButtonConfiguration() override = default;

    QString name() const { return _name; }
    void setName(const QString &name);

    int channel() const { return _channel; }
    void setChannel(int channel);

    int pulseWidth() const { return _pulseWidth; }
    void setPulseWidth(int pulseWidth);

    bool isValid() const;

    void copyFrom(const ServoButtonConfiguration *source);

    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);

    static constexpr int MIN_CHANNEL = 1;
    static constexpr int MAX_CHANNEL = 18;
    static constexpr int MIN_PULSE = 0;
    static constexpr int MAX_PULSE = 3000;
    static constexpr int DEFAULT_PULSE = 1500;

signals:
    void nameChanged();
    void channelChanged();
    void pulseWidthChanged();

private:
    QString _name;
    int _channel = MIN_CHANNEL;
    int _pulseWidth = DEFAULT_PULSE;
};
