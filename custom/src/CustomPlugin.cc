/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CustomPlugin.h"

#include "CameraManagerPlugin.h"
#include "QGCLoggingCategory.h"
#include "MultiVehicleManager.h"
#include "MAVLinkProtocol.h"
#include "Vehicle.h"
#include "VideoManager.h"

#include "QGCMAVLink.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtCore/QLatin1String>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QSettings>
#include <QtCore/QVariantMap>
#include <QtCore/QUrl>
#include <QtQml/QQmlApplicationEngine>
#include <QtQuick/QQuickWindow>

#include <array>
#include <cstdint>
#include <limits>

QGC_LOGGING_CATEGORY(CustomLog, "gcs.custom.customplugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
    _cameraManager = new CameraManagerPlugin(this);
    _loadServoButtons();

    emit servoButtonsChanged();
}

CustomPlugin::~CustomPlugin()
{
    cleanup();
}

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

QVariantList CustomPlugin::servoButtons() const
{
    return _serializeServoButtons();
}

void CustomPlugin::addServoButton(const QString &name, int channel, int pulseWidth)
{
    const ServoButtonDefinition button = _validatedButton(name, channel, pulseWidth);
    if (button.name.isEmpty()) {
        return;
    }

    _servoButtons.append(button);
    _saveServoButtons();
    emit servoButtonsChanged();
}

void CustomPlugin::updateServoButton(int index, const QString &name, int channel, int pulseWidth)
{
    if (index < 0 || index >= _servoButtons.count()) {
        return;
    }

    const ServoButtonDefinition button = _validatedButton(name, channel, pulseWidth);
    if (button.name.isEmpty()) {
        return;
    }

    _servoButtons[index] = button;
    _saveServoButtons();
    emit servoButtonsChanged();
}

void CustomPlugin::removeServoButton(int index)
{
    if (index < 0 || index >= _servoButtons.count()) {
        return;
    }

    _servoButtons.removeAt(index);
    _saveServoButtons();
    emit servoButtonsChanged();
}

void CustomPlugin::triggerServoCommand(int channel, int pulseWidth)
{
    if (channel < 1) {
        return;
    }

    const int sanitizedChannel = channel;
    const int sanitizedPulse = pulseWidth < 0 ? 0 : pulseWidth;

    MultiVehicleManager *manager = MultiVehicleManager::instance();
    if (!manager) {
        return;
    }

    if (Vehicle *vehicle = manager->activeVehicle()) {
        vehicle->sendMavCommandWithLambdaFallback(
            [vehicle, sanitizedChannel, sanitizedPulse]() {
                if (sanitizedChannel < 1 || sanitizedChannel > QGCMAVLink::maxRcChannels) {
                    qCWarning(CustomLog) << "Servo channel" << sanitizedChannel
                                         << "is outside RC override range";
                    return;
                }

                const auto sharedLink = vehicle->vehicleLinkManager()->primaryLink().lock();
                if (!sharedLink) {
                    qCWarning(CustomLog) << "Unable to send RC override without an active link";
                    return;
                }

                std::array<uint16_t, QGCMAVLink::maxRcChannels> overrideValues;
                overrideValues.fill(UINT16_MAX);

                const int clampedPulse = sanitizedPulse > std::numeric_limits<uint16_t>::max()
                                             ? std::numeric_limits<uint16_t>::max()
                                             : sanitizedPulse;
                overrideValues[sanitizedChannel - 1] = static_cast<uint16_t>(clampedPulse);

                mavlink_message_t message;
                mavlink_msg_rc_channels_override_pack_chan(
                    MAVLinkProtocol::instance()->getSystemId(),
                    MAVLinkProtocol::getComponentId(),
                    sharedLink->mavlinkChannel(),
                    &message,
                    static_cast<uint8_t>(vehicle->id()),
                    static_cast<uint8_t>(vehicle->defaultComponentId()),
                    overrideValues[0],
                    overrideValues[1],
                    overrideValues[2],
                    overrideValues[3],
                    overrideValues[4],
                    overrideValues[5],
                    overrideValues[6],
                    overrideValues[7],
                    overrideValues[8],
                    overrideValues[9],
                    overrideValues[10],
                    overrideValues[11],
                    overrideValues[12],
                    overrideValues[13],
                    overrideValues[14],
                    overrideValues[15],
                    overrideValues[16],
                    overrideValues[17]);

                vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
            },
            vehicle->defaultComponentId(),
            MAV_CMD_DO_SET_SERVO,
            false /* showError */,
            static_cast<float>(sanitizedChannel),
            static_cast<float>(sanitizedPulse));
    }
}

QQmlApplicationEngine *CustomPlugin::createQmlApplicationEngine(QObject *parent)
{
    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    if (!_urlInterceptor) {
        _urlInterceptor = new CustomUrlInterceptor();
    }

    if (_qmlEngine && _urlInterceptor) {
        _qmlEngine->addUrlInterceptor(_urlInterceptor);

        if (_engineObjectCreatedConnection) {
            QObject::disconnect(_engineObjectCreatedConnection);
            _engineObjectCreatedConnection = {};
        }

        _engineObjectCreatedConnection = connect(
            _qmlEngine,
            &QQmlApplicationEngine::objectCreated,
            this,
            [this](QObject *object, const QUrl &)
            {
                if (!object) {
                    return;
                }

                QQuickWindow *window = qobject_cast<QQuickWindow *>(object);
                if (!window) {
                    window = object->findChild<QQuickWindow *>();
                }

                if (!window) {
                    return;
                }

                VideoManager::instance()->init(window);

                QObject::disconnect(_engineObjectCreatedConnection);
                _engineObjectCreatedConnection = {};
            },
            Qt::QueuedConnection);
    }

    return _qmlEngine;
}

void CustomPlugin::cleanup()
{
    if (_qmlEngine && _urlInterceptor) {
        _qmlEngine->removeUrlInterceptor(_urlInterceptor);
    }

    if (_engineObjectCreatedConnection) {
        QObject::disconnect(_engineObjectCreatedConnection);
        _engineObjectCreatedConnection = {};
    }

    delete _urlInterceptor;
    _urlInterceptor = nullptr;
    _qmlEngine = nullptr;
}

QUrl CustomUrlInterceptor::intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type)
{
    using DataType = QQmlAbstractUrlInterceptor::DataType;

    if ((type == DataType::QmlFile || type == DataType::UrlString) && url.scheme() == QStringLiteral("qrc")) {
        const QString originalPath = url.path();
        const QString overridePath = QStringLiteral(":/Custom%1").arg(originalPath);
        if (QFile::exists(overridePath)) {
            QUrl result;
            result.setScheme(QStringLiteral("qrc"));
            result.setPath(QStringLiteral("/Custom%1").arg(originalPath));
            return result;
        }
    }

    return url;
}

QVariantList CustomPlugin::_serializeServoButtons() const
{
    QVariantList serialized;
    serialized.reserve(_servoButtons.size());

    for (const ServoButtonDefinition &button : _servoButtons) {
        QVariantMap map;
        map.insert(QStringLiteral("name"), button.name);
        map.insert(QStringLiteral("channel"), button.channel);
        map.insert(QStringLiteral("pulse"), button.pulseWidth);
        serialized.append(map);
    }

    return serialized;
}

bool CustomPlugin::_loadServoButtons()
{
    QSettings settings;
    settings.beginGroup(QLatin1String(_settingsGroup));
    const bool hasStoredValue = settings.contains(QLatin1String(_settingsKey));
    const QString raw = settings.value(QLatin1String(_settingsKey)).toString();
    settings.endGroup();

    if (!hasStoredValue) {
        _servoButtons.clear();
        return false;
    }

    _servoButtons.clear();

    if (raw.isEmpty()) {
        return true;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (!doc.isArray()) {
        return false;
    }

    const QJsonArray array = doc.array();
    for (const QJsonValue &value : array) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonObject object = value.toObject();
        const ServoButtonDefinition button = _validatedButton(
            object.value(QStringLiteral("name")).toString(),
            object.value(QStringLiteral("channel")).toInt(1),
            object.value(QStringLiteral("pulse")).toInt(1500));

        if (button.name.isEmpty()) {
            continue;
        }

        _servoButtons.append(button);
    }

    return true;
}

void CustomPlugin::_saveServoButtons() const
{
    QJsonArray array;

    for (const ServoButtonDefinition &button : _servoButtons) {
        QJsonObject object;
        object.insert(QStringLiteral("name"), button.name);
        object.insert(QStringLiteral("channel"), button.channel);
        object.insert(QStringLiteral("pulse"), button.pulseWidth);
        array.append(object);
    }

    QSettings settings;
    settings.beginGroup(QLatin1String(_settingsGroup));
    settings.setValue(QLatin1String(_settingsKey), QString::fromUtf8(QJsonDocument(array).toJson(QJsonDocument::Compact)));
    settings.endGroup();
}

CustomPlugin::ServoButtonDefinition CustomPlugin::_validatedButton(const QString &name, int channel, int pulseWidth) const
{
    ServoButtonDefinition button;
    button.name = name.trimmed();
    if (button.name.isEmpty()) {
        return button;
    }

    button.channel = channel < 1 ? 1 : channel;
    button.pulseWidth = pulseWidth < 0 ? 0 : pulseWidth;

    return button;
}
