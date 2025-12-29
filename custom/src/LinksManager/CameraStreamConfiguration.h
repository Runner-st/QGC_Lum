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

class CameraStreamConfiguration : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QString rtspUrl READ rtspUrl WRITE setRtspUrl NOTIFY rtspUrlChanged)

public:
    explicit CameraStreamConfiguration(QObject *parent = nullptr);
    CameraStreamConfiguration(const CameraStreamConfiguration *source, QObject *parent = nullptr);
    ~CameraStreamConfiguration() override = default;

    QString name() const { return _name; }
    void setName(const QString &name);

    QString rtspUrl() const { return _rtspUrl; }
    void setRtspUrl(const QString &url);

    bool isEmpty() const { return _rtspUrl.isEmpty(); }

    void copyFrom(const CameraStreamConfiguration *source);
    void loadSettings(QSettings &settings, const QString &root);
    void saveSettings(QSettings &settings, const QString &root) const;

    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);

signals:
    void nameChanged();
    void rtspUrlChanged();

private:
    QString _name;
    QString _rtspUrl;
};
