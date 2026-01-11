/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "TopotekController.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDebug>

QGC_LOGGING_CATEGORY(TopotekControllerLog, "gcs.custom.topotekcontroller")

TopotekController::TopotekController(QObject *parent)
    : QObject(parent)
    , _udpSocket(new QUdpSocket(this))
{
    qCDebug(TopotekControllerLog) << "Topotek Camera Controller created";
}

TopotekController::~TopotekController()
{
    if (_udpSocket) {
        _udpSocket->close();
    }
    qCDebug(TopotekControllerLog) << "Topotek Camera Controller destroyed";
}

void TopotekController::setControlAddress(const QString &address)
{
    if (_controlAddress != address) {
        bool wasConnected = isConnected();
        _controlAddress = address;
        parseControlAddress();
        emit controlAddressChanged();

        bool nowConnected = isConnected();
        if (wasConnected != nowConnected) {
            emit isConnectedChanged();
            // Emit connected() signal when transitioning from disconnected to connected
            if (nowConnected && !wasConnected) {
                qCDebug(TopotekControllerLog) << "Camera connected";
                emit connected();
            }
        }

        qCDebug(TopotekControllerLog) << "Control address updated:" << _cameraAddress.toString() << ":" << _cameraPort;
    }
}

void TopotekController::parseControlAddress()
{
    if (_controlAddress.isEmpty()) {
        _cameraAddress.clear();
        _cameraPort = 9003;
        return;
    }

    // Parse "192.168.144.108:9003" format
    QStringList parts = _controlAddress.split(':');
    if (parts.size() >= 1) {
        _cameraAddress.setAddress(parts[0]);
        if (parts.size() >= 2) {
            bool ok;
            quint16 port = parts[1].toUShort(&ok);
            if (ok) {
                _cameraPort = port;
            }
        }
    }
}

void TopotekController::sendCommand(const QByteArray& command)
{
    if (!_udpSocket || _cameraAddress.isNull()) {
        qCWarning(TopotekControllerLog) << "Cannot send command - no valid camera address";
        return;
    }

    qint64 sent = _udpSocket->writeDatagram(command, _cameraAddress, _cameraPort);

    if (sent == -1) {
        qCWarning(TopotekControllerLog) << "Failed to send UDP command:" << _udpSocket->errorString();
    } else {
        qCDebug(TopotekControllerLog) << "Sent command (" << sent << "bytes)";
    }
}

// === CONTINUOUS COMMANDS ===

// Pan/Tilt Movement
void TopotekController::panLeft()
{
    QByteArray cmd;
    cmd.append("#TPUG2wGSYEC87");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::panRight()
{
    QByteArray cmd;
    cmd.append("#TPUG2wGSY1464");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::tiltUp()
{
    QByteArray cmd;
    cmd.append("#TPUG2wGSPEC7E");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::tiltDown()
{
    QByteArray cmd;
    cmd.append("#TPUG2wGSP145B");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::stopPanTilt()
{
    QByteArray cmd;
    cmd.append("#TPPG2wPTZ0065");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

// Day Zoom
void TopotekController::dayZoomIn()
{
    QByteArray cmd;
    cmd.append("#TPPM2wZMC0259");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::dayZoomOut()
{
    QByteArray cmd;
    cmd.append("#TPPM2wZMC0158");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::stopDayZoom()
{
    QByteArray cmd;
    cmd.append("#TPPM2wZMC0057");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

// Thermal Zoom (note: uses 3 null bytes, not 4)
void TopotekController::thermalZoomIn()
{
    QByteArray cmd;
    cmd.append("#tpPD3wDZM10CD4");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::thermalZoomOut()
{
    QByteArray cmd;
    cmd.append("#tpPD3wDZM10DD5");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::stopThermalZoom()
{
    QByteArray cmd;
    cmd.append("#tpPD3wDZM10ED6");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

// === ONE-TIME COMMANDS ===

void TopotekController::centerGimbal()
{
    QByteArray cmd;
    cmd.append("#TPPG2wPTZ056A");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::tiltDown90()
{
    QByteArray cmd;
    cmd.append("#TPPG2wPTZ0A76");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::setFollowMode()
{
    QByteArray cmd;
    cmd.append("#TPPG2wPTZ076C");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::setLockMode()
{
    QByteArray cmd;
    cmd.append("#TPPG2wPTZ066B");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::toggleIRCut()
{
    QByteArray cmd;
    cmd.append("#TPPD2wIRC0A53");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::cyclePalette()
{
    QByteArray cmd;
    cmd.append("#TPPD2wIMG0A52");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::togglePIP()
{
    QByteArray cmd;
    cmd.append("#TPPD2wPIP0A5E");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::increaseDefog()
{
    QByteArray cmd;
    cmd.append("#tpPD3wDFG2DFD2");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}

void TopotekController::decreaseDefog()
{
    QByteArray cmd;
    cmd.append("#tpPD3wDFG22FC0");
    cmd.append('\x00');
    cmd.append('\x00');
    cmd.append('\x00');
    sendCommand(cmd);
}
