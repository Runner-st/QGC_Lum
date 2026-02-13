/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "HerelinkVideoStreamControl.h"

#include "MAVLinkProtocol.h"
#include "LinkInterface.h"
#include "SettingsManager.h"
#include "VideoSettings.h"
#include "VideoManager.h"

#include <QtCore/QLoggingCategory>

QGC_LOGGING_CATEGORY(HerelinkVideoStreamControlLog, "gcs.custom.herelink")

HerelinkVideoStreamControl::HerelinkVideoStreamControl(QObject *parent)
    : QObject(parent)
{
    _settingTimer.setSingleShot(true);
    _settingTimer.setInterval(15000);
    connect(&_settingTimer, &QTimer::timeout, this, &HerelinkVideoStreamControl::_settingTimerExpired);

    connect(MAVLinkProtocol::instance(), &MAVLinkProtocol::messageReceived,
            this, &HerelinkVideoStreamControl::_mavlinkMessageReceived);
}

void HerelinkVideoStreamControl::switchHdmiSource()
{
    if (_settingInProgress) {
        qCDebug(HerelinkVideoStreamControlLog) << "Switch already in progress, ignoring";
        return;
    }

    auto *videoSettings = SettingsManager::instance()->videoSettings();
    uint32_t currentId = videoSettings->cameraId()->rawValue().toUInt();
    uint32_t newId = (currentId == 0) ? 1 : 0;

    qCDebug(HerelinkVideoStreamControlLog) << "Switching HDMI source from" << currentId << "to" << newId;

    videoSettings->cameraId()->setRawValue(newId);

    if (_cameraLink) {
        _sendVideoStartStreamingCommand(_cameraLink, static_cast<uint8_t>(newId));
    } else {
        qCWarning(HerelinkVideoStreamControlLog) << "No camera link available, command not sent";
    }

    _settingInProgress = true;
    emit settingInProgressChanged();
    _settingTimer.start();

    // Restart video pipeline after a short delay to allow the air unit to switch
    QTimer::singleShot(2000, this, []() {
        VideoManager::instance()->startVideo();
    });
}

void HerelinkVideoStreamControl::_mavlinkMessageReceived(LinkInterface *link, const mavlink_message_t &message)
{
    if (message.msgid != MAVLINK_MSG_ID_HEARTBEAT) {
        return;
    }

    if (message.compid != MAV_COMP_ID_CAMERA) {
        return;
    }

    mavlink_heartbeat_t heartbeat;
    mavlink_msg_heartbeat_decode(&message, &heartbeat);

    // Extract camera count from custom_mode bits 25-31
    int cameraCount = static_cast<int>((heartbeat.custom_mode >> 25) & 0x7F);
    if (cameraCount <= 0) {
        cameraCount = 1;
    }

    bool systemChanged = (_systemId != message.sysid);
    _systemId = message.sysid;
    _cameraLink = link;

    if (cameraCount != _cameraCount) {
        _cameraCount = cameraCount;
        emit cameraCountChanged();
        qCDebug(HerelinkVideoStreamControlLog) << "Camera count updated:" << _cameraCount;
    }

    // Send initial camera selection command on first heartbeat
    if (!_initialCommandSent || systemChanged) {
        _initialCommandSent = true;
        auto *videoSettings = SettingsManager::instance()->videoSettings();
        uint32_t currentId = videoSettings->cameraId()->rawValue().toUInt();
        qCDebug(HerelinkVideoStreamControlLog) << "Sending initial video start streaming command, cameraId:" << currentId;
        _sendVideoStartStreamingCommand(link, static_cast<uint8_t>(currentId));
    }
}

void HerelinkVideoStreamControl::_settingTimerExpired()
{
    _settingInProgress = false;
    emit settingInProgressChanged();
    qCDebug(HerelinkVideoStreamControlLog) << "Setting lock timer expired";
}

void HerelinkVideoStreamControl::_sendVideoStartStreamingCommand(LinkInterface *link, uint8_t cameraId)
{
    if (!link) {
        qCWarning(HerelinkVideoStreamControlLog) << "Cannot send command: no link";
        return;
    }

    mavlink_message_t msg;
    mavlink_msg_command_long_pack_chan(
        static_cast<uint8_t>(MAVLinkProtocol::instance()->getSystemId()),
        MAVLinkProtocol::getComponentId(),
        link->mavlinkChannel(),
        &msg,
        _systemId,
        MAV_COMP_ID_CAMERA,
        MAV_CMD_VIDEO_START_STREAMING,
        0,                              // confirmation
        static_cast<float>(cameraId),   // param1: camera ID (0=HDMI1, 1=HDMI2)
        0, 0, 0, 0, 0, 0               // params 2-7: unused
    );

    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    const int len = mavlink_msg_to_send_buffer(buffer, &msg);
    link->writeBytesThreadSafe(reinterpret_cast<const char*>(buffer), len);

    qCDebug(HerelinkVideoStreamControlLog) << "Sent MAV_CMD_VIDEO_START_STREAMING to sysid:" << _systemId
                                           << "cameraId:" << cameraId;
}
