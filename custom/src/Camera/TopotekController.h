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
#include <QtNetwork/QUdpSocket>
#include <QtNetwork/QHostAddress>

class TopotekController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString controlAddress READ controlAddress WRITE setControlAddress NOTIFY controlAddressChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)

public:
    explicit TopotekController(QObject *parent = nullptr);
    ~TopotekController() override;

    QString controlAddress() const { return _controlAddress; }
    void setControlAddress(const QString &address);

    bool isConnected() const { return !_controlAddress.isEmpty(); }

    // === CONTINUOUS COMMANDS (require STOP) ===

    // Pan/Tilt Movement
    Q_INVOKABLE void panLeft();
    Q_INVOKABLE void panRight();
    Q_INVOKABLE void tiltUp();
    Q_INVOKABLE void tiltDown();
    Q_INVOKABLE void stopPanTilt();

    // Day Zoom
    Q_INVOKABLE void dayZoomIn();
    Q_INVOKABLE void dayZoomOut();
    Q_INVOKABLE void stopDayZoom();

    // Thermal Zoom (uses 3 null bytes)
    Q_INVOKABLE void thermalZoomIn();
    Q_INVOKABLE void thermalZoomOut();
    Q_INVOKABLE void stopThermalZoom();

    // === ONE-TIME COMMANDS (no stop needed) ===

    Q_INVOKABLE void centerGimbal();
    Q_INVOKABLE void tiltDown90();      // Look down 90 degrees (Tilt button)
    Q_INVOKABLE void setFollowMode();
    Q_INVOKABLE void setLockMode();
    Q_INVOKABLE void toggleIRCut();
    Q_INVOKABLE void cyclePalette();
    Q_INVOKABLE void togglePIP();
    Q_INVOKABLE void increaseDefog();
    Q_INVOKABLE void decreaseDefog();

signals:
    void controlAddressChanged();
    void isConnectedChanged();
    void connected();  // Emitted when connection state changes to connected

private:
    void sendCommand(const QByteArray& command);
    void parseControlAddress();

    QUdpSocket *_udpSocket = nullptr;
    QHostAddress _cameraAddress;
    quint16 _cameraPort = 9003;  // Topotek default port
    QString _controlAddress;     // Format: "192.168.144.108:9003"
    bool _wasConnected = false;  // Track connection state for connected() signal
};
