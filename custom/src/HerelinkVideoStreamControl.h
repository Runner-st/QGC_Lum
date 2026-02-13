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
#include <QtCore/QTimer>

#include "QGCLoggingCategory.h"
#include "MAVLinkLib.h"

Q_DECLARE_LOGGING_CATEGORY(HerelinkVideoStreamControlLog)

class LinkInterface;

class HerelinkVideoStreamControl : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool settingInProgress READ settingInProgress NOTIFY settingInProgressChanged)
    Q_PROPERTY(int  cameraCount       READ cameraCount       NOTIFY cameraCountChanged)

public:
    explicit HerelinkVideoStreamControl(QObject *parent = nullptr);
    ~HerelinkVideoStreamControl() override = default;

    bool settingInProgress() const { return _settingInProgress; }
    int  cameraCount()       const { return _cameraCount; }

    Q_INVOKABLE void switchHdmiSource();

signals:
    void settingInProgressChanged();
    void cameraCountChanged();

private slots:
    void _mavlinkMessageReceived(LinkInterface *link, const mavlink_message_t &message);
    void _settingTimerExpired();

private:
    void _sendVideoStartStreamingCommand(LinkInterface *link, uint8_t cameraId);

    uint8_t _systemId = 0;
    int     _cameraCount = 0;
    bool    _settingInProgress = false;
    bool    _initialCommandSent = false;

    QTimer  _settingTimer;

    LinkInterface *_cameraLink = nullptr;
};
