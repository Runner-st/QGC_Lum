/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CameraManagerPlugin.h"

#include "Fact.h"
#include "QGCCorePlugin.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "VideoReceiver.h"
#include "VideoSettings.h"

#include <algorithm>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QPointer>
#include <QtCore/QSettings>
#include <QtCore/QTimer>
#include <QtCore/QVariant>
#include <QtCore/QVariantMap>
#include <QtCore/QtGlobal>
#include <QtQuick/QQuickItem>

#include <cstdint>

QGC_LOGGING_CATEGORY(CustomCameraManagerLog, "gcs.custom.cameramanager")

namespace
{
static constexpr const char *kSettingsGroup = "CustomCameraManager";
static constexpr const char *kStreamsKey = "streams";
static constexpr const char *kPrimaryKey = "primaryIndex";
}

CameraManagerPlugin::CameraManagerPlugin(QObject *parent)
    : QObject(parent)
    , _videoSettings(SettingsManager::instance()->videoSettings())
{
    _load();

    if (_videoSettings) {
        connect(_videoSettings->lowLatencyMode(), &Fact::rawValueChanged, this, &CameraManagerPlugin::_onLowLatencyChanged, Qt::UniqueConnection);
    }

    _updateMainStream();
    _updateSecondaryReceivers();
}

CameraManagerPlugin::~CameraManagerPlugin()
{
    for (CameraEntry &entry : _cameras) {
        _destroyReceiver(entry);
    }
}

QVariantList CameraManagerPlugin::cameras() const
{
    QVariantList result;
    result.reserve(_cameras.size());

    for (int index = 0; index < _cameras.size(); ++index) {
        const CameraEntry &entry = _cameras.at(index);
        QVariantMap map;
        map.insert(QStringLiteral("name"), entry.name);
        map.insert(QStringLiteral("url"), entry.url);
        map.insert(QStringLiteral("index"), index);
        map.insert(QStringLiteral("isPrimary"), index == _primaryIndex);
        result.append(map);
    }

    return result;
}

QVariantList CameraManagerPlugin::secondaryCameras() const
{
    QVariantList result;
    result.reserve(_cameras.size());

    for (int index = 0; index < _cameras.size(); ++index) {
        if (index == _primaryIndex) {
            continue;
        }
        const CameraEntry &entry = _cameras.at(index);
        QVariantMap map;
        map.insert(QStringLiteral("name"), entry.name);
        map.insert(QStringLiteral("url"), entry.url);
        map.insert(QStringLiteral("index"), index);
        result.append(map);
    }

    return result;
}

void CameraManagerPlugin::addCamera(const QString &name, const QString &url)
{
    const QString trimmedName = name.trimmed();
    const QString trimmedUrl = url.trimmed();
    if (trimmedName.isEmpty() || trimmedUrl.isEmpty()) {
        qCWarning(CustomCameraManagerLog) << "Ignoring camera with empty name or URL";
        return;
    }

    CameraEntry entry;
    entry.name = trimmedName;
    entry.url = trimmedUrl;
    _cameras.append(std::move(entry));

    if (_primaryIndex < 0) {
        _primaryIndex = _cameras.size() - 1;
        emit primaryIndexChanged();
    }

    _save();
    _emitListsChanged();
    _updateMainStream();
    _updateSecondaryReceivers();
}

void CameraManagerPlugin::updateCamera(int index, const QString &name, const QString &url)
{
    CameraEntry *entry = _entryForIndex(index);
    if (!entry) {
        qCWarning(CustomCameraManagerLog) << "Attempted to update invalid camera index" << index;
        return;
    }

    const QString trimmedName = name.trimmed();
    const QString trimmedUrl = url.trimmed();
    if (trimmedName.isEmpty() || trimmedUrl.isEmpty()) {
        qCWarning(CustomCameraManagerLog) << "Ignoring update with empty name or URL";
        return;
    }

    entry->name = trimmedName;
    entry->url = trimmedUrl;

    if (entry->receiver) {
        entry->receiver->setUri(entry->url);
    }

    _save();
    _emitListsChanged();

    if (index == _primaryIndex) {
        _updateMainStream();
    }

    _updateSecondaryReceivers();
}

void CameraManagerPlugin::removeCamera(int index)
{
    if (index < 0 || index >= _cameras.size()) {
        qCWarning(CustomCameraManagerLog) << "Attempted to remove invalid camera index" << index;
        return;
    }

    _destroyReceiver(_cameras[index]);
    _cameras.removeAt(index);

    if (_primaryIndex == index) {
        _primaryIndex = -1;
        emit primaryIndexChanged();
    } else if (_primaryIndex > index) {
        _primaryIndex -= 1;
        emit primaryIndexChanged();
    }

    _ensurePrimaryValid();
    _save();
    _emitListsChanged();
    _updateMainStream();
    _updateSecondaryReceivers();
}

QVariantMap CameraManagerPlugin::cameraAt(int index) const
{
    QVariantMap map;
    const CameraEntry *entry = _entryForIndex(index);
    if (!entry) {
        return map;
    }

    map.insert(QStringLiteral("name"), entry->name);
    map.insert(QStringLiteral("url"), entry->url);
    map.insert(QStringLiteral("index"), index);
    map.insert(QStringLiteral("isPrimary"), index == _primaryIndex);

    return map;
}

void CameraManagerPlugin::promoteToPrimary(int index)
{
    if (index == _primaryIndex) {
        return;
    }

    if (!_entryForIndex(index)) {
        qCWarning(CustomCameraManagerLog) << "Attempted to promote invalid camera index" << index;
        return;
    }

    _setPrimaryIndex(index);
    _save();
    _updateMainStream();
    _updateSecondaryReceivers();
    _emitListsChanged();
}

void CameraManagerPlugin::toggleSecondaryStreams()
{
    setSecondaryStreamsVisible(!_secondaryStreamsVisible);
}

void CameraManagerPlugin::registerView(int index, QQuickItem *item)
{
    if (!item) {
        return;
    }

    CameraEntry *entry = _entryForIndex(index);
    if (!entry) {
        qCWarning(CustomCameraManagerLog) << "Attempted to register view for invalid camera index" << index;
        return;
    }

    if (entry->widget && entry->widget != item) {
        unregisterView(index, entry->widget.data());
    }

    if (entry->widget == item) {
        return;
    }

    entry->widget = item;

    if (!entry->receiver) {
        _createReceiver(*entry);
    }

    if (!entry->receiver) {
        return;
    }

    entry->receiver->setWidget(item);

    if (entry->sink) {
        QGCCorePlugin::instance()->releaseVideoSink(entry->sink);
        entry->sink = nullptr;
    }

    entry->sink = QGCCorePlugin::instance()->createVideoSink(item, entry->receiver.get());
    if (!entry->sink) {
        qCWarning(CustomCameraManagerLog) << "Failed to create sink for camera" << entry->name;
        return;
    }

    entry->receiver->setSink(entry->sink);

    if (_secondaryStreamsVisible && index != _primaryIndex) {
        _startReceiver(*entry);
    }
}

void CameraManagerPlugin::unregisterView(int index, QQuickItem *item)
{
    CameraEntry *entry = _entryForIndex(index);
    if (!entry) {
        return;
    }

    if (item && entry->widget != item) {
        return;
    }

    if (entry->receiver) {
        entry->receiver->stopDecoding();
        entry->receiver->stop();
        entry->receiver->setWidget(nullptr);
        entry->receiver->setSink(nullptr);
    }

    if (entry->sink) {
        QGCCorePlugin::instance()->releaseVideoSink(entry->sink);
        entry->sink = nullptr;
    }

    entry->widget = nullptr;
}

void CameraManagerPlugin::setSecondaryStreamsVisible(bool visible)
{
    const bool canShow = visible && hasSecondaryStreams();
    if (canShow == _secondaryStreamsVisible) {
        return;
    }

    _secondaryStreamsVisible = canShow;
    _updateSecondaryReceivers();
    emit secondaryStreamsVisibleChanged();
}

void CameraManagerPlugin::_load()
{
    _cameras.clear();

    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    const QString raw = settings.value(QLatin1String(kStreamsKey)).toString();
    const int storedPrimary = settings.value(QLatin1String(kPrimaryKey), 0).toInt();
    settings.endGroup();

    if (!raw.isEmpty()) {
        const QJsonDocument document = QJsonDocument::fromJson(raw.toUtf8());
        if (document.isArray()) {
            const QJsonArray array = document.array();

            for (const QJsonValue &value : array) {
                if (!value.isObject()) {
                    continue;
                }

                const QJsonObject object = value.toObject();
                CameraEntry entry;
                entry.name = object.value(QStringLiteral("name")).toString();
                entry.url = object.value(QStringLiteral("url")).toString();
                if (entry.name.isEmpty() || entry.url.isEmpty()) {
                    continue;
                }
                _cameras.append(entry);
            }
        } else {
            qCWarning(CustomCameraManagerLog) << "Camera settings payload is not an array";
        }
    }

    if (_cameras.isEmpty()) {
        _primaryIndex = -1;
    } else {
        const int maxIndex = static_cast<int>(_cameras.size() - 1);

        _primaryIndex = qBound(0, storedPrimary, maxIndex);

    }

    emit primaryIndexChanged();
    _emitListsChanged();
}

void CameraManagerPlugin::_save() const
{
    QJsonArray array;

    for (const CameraEntry &entry : _cameras) {
        QJsonObject object;
        object.insert(QStringLiteral("name"), entry.name);
        object.insert(QStringLiteral("url"), entry.url);
        array.append(object);
    }

    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    settings.setValue(QLatin1String(kStreamsKey), QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact)));
    settings.setValue(QLatin1String(kPrimaryKey), _primaryIndex);
    settings.endGroup();
}

void CameraManagerPlugin::_ensurePrimaryValid()
{
    if (_cameras.isEmpty()) {
        if (_primaryIndex != -1) {
            _primaryIndex = -1;
            emit primaryIndexChanged();
        }
        return;
    }

    if (_primaryIndex < 0 || _primaryIndex >= _cameras.size()) {
        _primaryIndex = 0;
        emit primaryIndexChanged();
    }
}

void CameraManagerPlugin::_updateMainStream()
{
    if (!_videoSettings) {
        return;
    }

    if (_primaryIndex < 0 || _primaryIndex >= _cameras.size()) {
        _videoSettings->streamEnabled()->setRawValue(false);
        _videoSettings->videoSource()->setRawValue(VideoSettings::videoDisabled);
        return;
    }

    const CameraEntry &entry = _cameras.at(_primaryIndex);
    _videoSettings->videoSource()->setRawValue(VideoSettings::videoSourceRTSP);
    _videoSettings->rtspUrl()->setRawValue(entry.url);
    _videoSettings->streamEnabled()->setRawValue(true);
}

void CameraManagerPlugin::_updateSecondaryReceivers()
{
    for (int index = 0; index < _cameras.size(); ++index) {
        CameraEntry &entry = _cameras[index];
        if (index == _primaryIndex || !_secondaryStreamsVisible) {
            _stopReceiver(entry);
            continue;
        }

        if (!entry.receiver || !entry.widget || !entry.sink) {
            continue;
        }

        _startReceiver(entry);
    }

    emit secondaryCamerasChanged();
}

void CameraManagerPlugin::_startReceiver(CameraEntry &entry)
{
    if (!entry.receiver || !entry.widget || !entry.sink) {
        return;
    }

    if (entry.url.isEmpty()) {
        return;
    }

    _applyLowLatency(entry);
    entry.receiver->setUri(entry.url);

    uint32_t timeout = 3;
    if (_videoSettings && _videoSettings->rtspTimeout()) {
        timeout = _videoSettings->rtspTimeout()->rawValue().toUInt();
        if (timeout == 0) {
            timeout = 3;
        }
    }

    entry.receiver->start(timeout);
}

void CameraManagerPlugin::_stopReceiver(CameraEntry &entry)
{
    if (!entry.receiver) {
        return;
    }

    entry.receiver->stopDecoding();
    entry.receiver->stop();
}

void CameraManagerPlugin::_createReceiver(CameraEntry &entry)
{
    if (entry.receiver) {
        _applyLowLatency(entry);
        return;
    }

    VideoReceiver *receiver = QGCCorePlugin::instance()->createVideoReceiver(this);
    if (!receiver) {
        qCWarning(CustomCameraManagerLog) << "Unable to create VideoReceiver for camera" << entry.name;
        return;
    }

    receiver->setName(QStringLiteral("camera_%1").arg(entry.name));
    receiver->setUri(entry.url);

    entry.receiver.reset(receiver);
    _applyLowLatency(entry);

    connect(receiver, &VideoReceiver::onStartComplete, this, [this, receiver](VideoReceiver::STATUS status) {
        if (status != VideoReceiver::STATUS_OK) {
            return;
        }

        const int index = _indexForReceiver(receiver);
        if (index < 0 || index == _primaryIndex) {
            return;
        }

        CameraEntry &entry = _cameras[index];
        if (entry.sink) {
            receiver->startDecoding(entry.sink);
        }
    });

    connect(receiver, &VideoReceiver::onStopComplete, this, [this, receiver](VideoReceiver::STATUS status) {
        if (status == VideoReceiver::STATUS_INVALID_URL) {
            return;
        }

        const int index = _indexForReceiver(receiver);
        if (index < 0) {
            return;
        }

        if (!_secondaryStreamsVisible || index == _primaryIndex) {
            return;
        }

        QTimer::singleShot(1000, receiver, [this, receiver]() {
            const int innerIndex = _indexForReceiver(receiver);
            if (innerIndex < 0 || innerIndex == _primaryIndex || !_secondaryStreamsVisible) {
                return;
            }

            CameraEntry &entry = _cameras[innerIndex];
            if (entry.sink && entry.widget) {
                _startReceiver(entry);
            }
        });
    });

    // entry.receiver already owns receiver
}

void CameraManagerPlugin::_destroyReceiver(CameraEntry &entry)
{
    if (entry.receiver) {
        entry.receiver->stopDecoding();
        entry.receiver->stop();
        entry.receiver.reset();
    }

    if (entry.sink) {
        QGCCorePlugin::instance()->releaseVideoSink(entry.sink);
        entry.sink = nullptr;
    }

    entry.widget = nullptr;
}

void CameraManagerPlugin::_applyLowLatency(CameraEntry &entry)
{
    if (!entry.receiver || !_videoSettings) {
        return;
    }

    entry.receiver->setLowLatency(_videoSettings->lowLatencyMode()->rawValue().toBool());
}

void CameraManagerPlugin::_onLowLatencyChanged(const QVariant &value)
{
    Q_UNUSED(value);

    for (CameraEntry &entry : _cameras) {
        _applyLowLatency(entry);
    }
}

void CameraManagerPlugin::_setPrimaryIndex(int index)
{
    if (index == _primaryIndex) {
        return;
    }

    _primaryIndex = index;
    emit primaryIndexChanged();
}

void CameraManagerPlugin::_emitListsChanged()
{
    emit camerasChanged();
    emit secondaryCamerasChanged();

    if (_secondaryStreamsVisible && !hasSecondaryStreams()) {
        _secondaryStreamsVisible = false;
        emit secondaryStreamsVisibleChanged();
    }
}

int CameraManagerPlugin::_indexForReceiver(VideoReceiver *receiver) const
{
    if (!receiver) {
        return -1;
    }

    for (int index = 0; index < _cameras.size(); ++index) {
        const CameraEntry &entry = _cameras.at(index);
        if (entry.receiver.get() == receiver) {
            return index;
        }
    }

    return -1;
}

CameraManagerPlugin::CameraEntry *CameraManagerPlugin::_entryForIndex(int index)
{
    if (index < 0 || index >= _cameras.size()) {
        return nullptr;
    }

    return &_cameras[index];
}

const CameraManagerPlugin::CameraEntry *CameraManagerPlugin::_entryForIndex(int index) const
{
    if (index < 0 || index >= _cameras.size()) {
        return nullptr;
    }

    return &_cameras[index];
}
