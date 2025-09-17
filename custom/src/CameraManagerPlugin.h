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
#include <QtCore/QPointer>
#include <QtCore/QVariantList>

#include <memory>
#include <vector>

class QQuickItem;
class VideoReceiver;
class VideoSettings;

class CameraManagerPlugin : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList cameras READ cameras NOTIFY camerasChanged FINAL)
    Q_PROPERTY(QVariantList secondaryCameras READ secondaryCameras NOTIFY secondaryCamerasChanged FINAL)
    Q_PROPERTY(int primaryIndex READ primaryIndex NOTIFY primaryIndexChanged FINAL)
    Q_PROPERTY(bool secondaryStreamsVisible READ secondaryStreamsVisible WRITE setSecondaryStreamsVisible NOTIFY secondaryStreamsVisibleChanged FINAL)
    Q_PROPERTY(bool hasCameras READ hasCameras NOTIFY camerasChanged FINAL)
    Q_PROPERTY(bool hasSecondaryStreams READ hasSecondaryStreams NOTIFY camerasChanged FINAL)

public:
    explicit CameraManagerPlugin(QObject *parent = nullptr);
    ~CameraManagerPlugin() override;

    QVariantList cameras() const;
    QVariantList secondaryCameras() const;
    int primaryIndex() const { return _primaryIndex; }
    bool secondaryStreamsVisible() const { return _secondaryStreamsVisible; }
    bool hasCameras() const { return !_cameras.empty(); }
    bool hasSecondaryStreams() const { return _cameras.size() > 1; }

    Q_INVOKABLE void addCamera(const QString &name, const QString &url);
    Q_INVOKABLE void updateCamera(int index, const QString &name, const QString &url);
    Q_INVOKABLE void removeCamera(int index);
    Q_INVOKABLE QVariantMap cameraAt(int index) const;
    Q_INVOKABLE void promoteToPrimary(int index);
    Q_INVOKABLE void toggleSecondaryStreams();
    Q_INVOKABLE void registerView(int index, QQuickItem *item);
    Q_INVOKABLE void unregisterView(int index, QQuickItem *item = nullptr);

    void setSecondaryStreamsVisible(bool visible);

signals:
    void camerasChanged();
    void secondaryCamerasChanged();
    void primaryIndexChanged();
    void secondaryStreamsVisibleChanged();

private:
    struct CameraEntry {
        QString name;
        QString url;
        std::unique_ptr<VideoReceiver> receiver;
        QPointer<QQuickItem> widget;
        void *sink = nullptr;
    };

    void _load();
    void _save() const;
    void _ensurePrimaryValid();
    void _updateMainStream();
    void _updateSecondaryReceivers();
    void _startReceiver(CameraEntry &entry);
    void _stopReceiver(CameraEntry &entry);
    void _createReceiver(CameraEntry &entry);
    void _destroyReceiver(CameraEntry &entry);
    void _applyLowLatency(CameraEntry &entry);
    void _onLowLatencyChanged(const QVariant &value);
    void _setPrimaryIndex(int index);
    void _emitListsChanged();
    int _indexForReceiver(VideoReceiver *receiver) const;
    CameraEntry *_entryForIndex(int index);
    const CameraEntry *_entryForIndex(int index) const;

    std::vector<CameraEntry> _cameras;
    int _primaryIndex = -1;
    bool _secondaryStreamsVisible = false;
    VideoSettings *_videoSettings = nullptr;
};
