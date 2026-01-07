/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "C12Controller.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDebug>

QGC_LOGGING_CATEGORY(C12ControllerLog, "gcs.custom.c12controller")

C12Controller::C12Controller(QObject *parent)
    : QObject(parent)
    , _udpSocket(new QUdpSocket(this))
{
    qCDebug(C12ControllerLog) << "C12 Camera Controller created";
}

C12Controller::~C12Controller()
{
    if (_udpSocket) {
        _udpSocket->close();
    }
    qCDebug(C12ControllerLog) << "C12 Camera Controller destroyed";
}

void C12Controller::setControlAddress(const QString &address)
{
    if (_controlAddress != address) {
        _controlAddress = address;
        parseControlAddress();
        emit controlAddressChanged();
        emit isConnectedChanged();

        qCDebug(C12ControllerLog) << "Control address updated:" << _cameraAddress.toString() << ":" << _cameraPort;
    }
}

void C12Controller::parseControlAddress()
{
    if (_controlAddress.isEmpty()) {
        _cameraAddress.clear();
        _cameraPort = 5000;
        return;
    }

    // Parse "192.168.144.108:5000" format
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

void C12Controller::sendCommand(const QString& command)
{
    if (!_udpSocket || _cameraAddress.isNull()) {
        qCWarning(C12ControllerLog) << "Cannot send command - no valid camera address";
        return;
    }

    QByteArray data = command.toUtf8();
    qint64 sent = _udpSocket->writeDatagram(data, _cameraAddress, _cameraPort);

    if (sent == -1) {
        qCWarning(C12ControllerLog) << "Failed to send UDP command:" << _udpSocket->errorString();
    } else {
        qCDebug(C12ControllerLog) << "Sent command:" << command << "(" << sent << "bytes)";
    }
}

void C12Controller::centerCamera()
{
    sendCommand("#TPUG2wPTZ056F");
}

void C12Controller::centerTiltOnly()
{
    sendCommand("#TPUG2wPTZ026C");
}

void C12Controller::zoomIn()
{
    sendCommand("#TPUD2wDZM0A65");
}

void C12Controller::zoomOut()
{
    sendCommand("#TPUD2wDZM0B66");
}

void C12Controller::cyclePalette()
{
    static const QString paletteCommands[] = {
        "#TPUD2wIMG0147",  // WHITE_HOT
        "#TPUD2wIMG0B58",  // BLACK_HOT
        "#TPUD2wIMG0349",  // SEPIA
        "#TPUD2wIMG044A",  // IRONBOW
        "#TPUD2wIMG054B",  // RAINBOW
        "#TPUD2wIMG064C",  // NIGHT
        "#TPUD2wIMG084E",  // RED_HOT
        "#TPUD2wIMG094F",  // JUNGLE
        "#TPUD2wIMG0A57",  // MEDICAL
        "#TPUD2wIMG0C59"   // GLORY_HOT
    };

    static const QString paletteNames[] = {
        "WHITE_HOT", "BLACK_HOT", "SEPIA", "IRONBOW", "RAINBOW",
        "NIGHT", "RED_HOT", "JUNGLE", "MEDICAL", "GLORY_HOT"
    };

    const int paletteCount = 10;

    qCDebug(C12ControllerLog) << "Cycling palette to:" << paletteNames[_currentPaletteIndex];
    sendCommand(paletteCommands[_currentPaletteIndex]);

    _currentPaletteIndex = (_currentPaletteIndex + 1) % paletteCount;
}

void C12Controller::sendVertCommand()
{
    sendCommand("#TPUG6wGAY00001012");
}

void C12Controller::sendCustomCommand(const QString& command)
{
    qCDebug(C12ControllerLog) << "Custom command:" << command;
    sendCommand(command);
}

void C12Controller::moveRight()
{
    sendCommand("#TPUG2wGSY1262");
}

void C12Controller::moveLeft()
{
    sendCommand("#TPUG2wGSYED88");
}

void C12Controller::moveUp()
{
    sendCommand("#TPUG2wGSP145B");
}

void C12Controller::moveDown()
{
    sendCommand("#TPUG2wGSPEC7E");
}
