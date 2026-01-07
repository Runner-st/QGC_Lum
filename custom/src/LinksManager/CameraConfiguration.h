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

#include "CameraStreamConfiguration.h"

class CameraConfiguration : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(CameraType cameraType READ cameraType WRITE setCameraType NOTIFY cameraTypeChanged)
    Q_PROPERTY(CameraStreamConfiguration* stream1 READ stream1 CONSTANT)
    Q_PROPERTY(CameraStreamConfiguration* stream2 READ stream2 CONSTANT)
    Q_PROPERTY(QString c12CameraIp READ c12CameraIp WRITE setC12CameraIp NOTIFY c12CameraIpChanged)
    Q_PROPERTY(QString c12Rtsp1Suffix READ c12Rtsp1Suffix WRITE setC12Rtsp1Suffix NOTIFY c12Rtsp1SuffixChanged)
    Q_PROPERTY(QString c12Rtsp2Suffix READ c12Rtsp2Suffix WRITE setC12Rtsp2Suffix NOTIFY c12Rtsp2SuffixChanged)
    Q_PROPERTY(int c12ControlPort READ c12ControlPort WRITE setC12ControlPort NOTIFY c12ControlPortChanged)

public:
    enum CameraType {
        GenericIPCamera = 0,
        HerelinkHDMI,
        SkydroidC12,
        TopotekKHP290A609
    };
    Q_ENUM(CameraType)

    explicit CameraConfiguration(QObject *parent = nullptr);
    CameraConfiguration(const CameraConfiguration *source, QObject *parent = nullptr);
    ~CameraConfiguration() override = default;

    QString name() const { return _name; }
    void setName(const QString &name);

    CameraType cameraType() const { return _cameraType; }
    void setCameraType(CameraType type);

    CameraStreamConfiguration* stream1() const { return _stream1; }
    CameraStreamConfiguration* stream2() const { return _stream2; }

    QString c12CameraIp() const { return _c12CameraIp; }
    void setC12CameraIp(const QString &ip);

    QString c12Rtsp1Suffix() const { return _c12Rtsp1Suffix; }
    void setC12Rtsp1Suffix(const QString &suffix);

    QString c12Rtsp2Suffix() const { return _c12Rtsp2Suffix; }
    void setC12Rtsp2Suffix(const QString &suffix);

    int c12ControlPort() const { return _c12ControlPort; }
    void setC12ControlPort(int port);

    Q_INVOKABLE void applyPreset();

    bool isEmpty() const;

    void copyFrom(const CameraConfiguration *source);
    void loadSettings(QSettings &settings, const QString &root);
    void saveSettings(QSettings &settings, const QString &root) const;

    QJsonObject toJson() const;
    void fromJson(const QJsonObject &json);

    static QString cameraTypeToString(CameraType type);
    static CameraType stringToCameraType(const QString &str);

    // Preset URLs
    static constexpr const char* HERELINK_STREAM1_URL = "rtsp://192.168.144.108:554/stream=0";
    static constexpr const char* SKYDROID_STREAM1_URL = "rtsp://192.168.144.108:554/stream=1";
    static constexpr const char* SKYDROID_STREAM2_URL = "rtsp://192.168.144.108:555/stream=2";

signals:
    void nameChanged();
    void cameraTypeChanged();
    void c12CameraIpChanged();
    void c12Rtsp1SuffixChanged();
    void c12Rtsp2SuffixChanged();
    void c12ControlPortChanged();

private:
    QString _name;
    CameraType _cameraType = GenericIPCamera;
    CameraStreamConfiguration *_stream1 = nullptr;
    CameraStreamConfiguration *_stream2 = nullptr;
    QString _c12CameraIp = QStringLiteral("192.168.144.108");
    QString _c12Rtsp1Suffix = QStringLiteral("554/stream=1");
    QString _c12Rtsp2Suffix = QStringLiteral("555/stream=2");
    int _c12ControlPort = 5000;
};
