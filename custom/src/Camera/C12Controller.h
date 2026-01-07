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

class C12Controller : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString controlAddress READ controlAddress WRITE setControlAddress NOTIFY controlAddressChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)

public:
    explicit C12Controller(QObject *parent = nullptr);
    ~C12Controller() override;

    QString controlAddress() const { return _controlAddress; }
    void setControlAddress(const QString &address);

    bool isConnected() const { return !_controlAddress.isEmpty(); }

    // Camera control methods callable from QML
    Q_INVOKABLE void centerCamera();
    Q_INVOKABLE void centerTiltOnly();
    Q_INVOKABLE void zoomIn();
    Q_INVOKABLE void zoomOut();
    Q_INVOKABLE void cyclePalette();
    Q_INVOKABLE void sendVertCommand();
    Q_INVOKABLE void sendCustomCommand(const QString& command);

    // Camera directional movement
    Q_INVOKABLE void moveRight();
    Q_INVOKABLE void moveLeft();
    Q_INVOKABLE void moveUp();
    Q_INVOKABLE void moveDown();

signals:
    void controlAddressChanged();
    void isConnectedChanged();

private:
    void sendCommand(const QString& command);
    void parseControlAddress();

    QUdpSocket *_udpSocket = nullptr;
    QHostAddress _cameraAddress;
    quint16 _cameraPort = 5000;
    int _currentPaletteIndex = 9; // Start with GLORY_HOT
    QString _controlAddress; // Format: "192.168.144.108:5000"
};
