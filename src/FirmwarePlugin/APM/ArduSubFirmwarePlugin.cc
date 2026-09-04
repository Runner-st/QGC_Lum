/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "ArduSubFirmwarePlugin.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"

QGC_LOGGING_CATEGORY(APMSubmarineFactGroupLog, "qgc.firmwareplugin.apm.ardusubfirmwareplugin")

APMSubmarineFactGroup::APMSubmarineFactGroup(QObject *parent)
    : FactGroup(300, QStringLiteral(":/json/Vehicle/SubmarineFact.json"), parent)
{
    // qCDebug(APMSubmarineFactGroupLog) << Q_FUNC_INFO << this;

    _addFact(&_camTiltFact);
    _addFact(&_tetherTurnsFact);
    _addFact(&_lightsLevel1Fact);
    _addFact(&_lightsLevel2Fact);
    _addFact(&_pilotGainFact);
    _addFact(&_inputHoldFact);
    _addFact(&_rollPitchToggleFact);
    _addFact(&_rangefinderDistanceFact);
    _addFact(&_rangefinderTargetFact);

    _camTiltFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _tetherTurnsFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _lightsLevel1Fact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _lightsLevel2Fact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _pilotGainFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _inputHoldFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _rollPitchToggleFact.setRawValue(2); // 2 shows "Unavailable" in older firmwares
    _rangefinderDistanceFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
    _rangefinderTargetFact.setRawValue(std::numeric_limits<float>::quiet_NaN());
}

APMSubmarineFactGroup::~APMSubmarineFactGroup()
{
    // qCDebug(APMSubmarineFactGroupLog) << Q_FUNC_INFO << this;
}

QString ArduSubFirmwarePlugin::vehicleImageOutline(const Vehicle *vehicle) const
{
    return vehicleImageOpaque(vehicle);
}

void ArduSubFirmwarePlugin::adjustMetaData(MAV_TYPE vehicleType, FactMetaData *metaData)
{
    Q_UNUSED(vehicleType);

    if (!metaData) {
        return;
    }

    if (_factRenameMap.contains(metaData->name())) {
        metaData->setShortDescription(QString(_factRenameMap[metaData->name()]));
    }
}

QString ArduSubFirmwarePlugin::stabilizedFlightMode() const
{
    return _modeEnumToString.value(APMSubMode::STABILIZE, _stabilizeFlightMode);
}

QString ArduSubFirmwarePlugin::motorDetectionFlightMode() const
{
    return _modeEnumToString.value(APMSubMode::MOTORDETECTION, _motorDetectionFlightMode);
}

void ArduSubFirmwarePlugin::updateAvailableFlightModes(FlightModeList &modeList)
{
    for (FirmwareFlightMode &mode: modeList) {
        mode.fixedWing = false;
        mode.multiRotor = true;
    }

    _updateFlightModeList(modeList);
}

uint32_t ArduSubFirmwarePlugin::_convertToCustomFlightModeEnum(uint32_t val) const
{
    switch (val) {
    case APMCustomMode::AUTO:
        return APMSubMode::AUTO;
    case APMCustomMode::GUIDED:
        return APMSubMode::GUIDED;
    default:
        return UINT32_MAX;
    }
}

/*===========================================================================*/

bool ArduSubFirmwarePlugin::_remapParamNameIntialized = false;
FirmwarePlugin::remapParamNameMajorVersionMap_t ArduSubFirmwarePlugin::_remapParamName;

ArduSubFirmwarePlugin::ArduSubFirmwarePlugin(QObject *parent)
    : APMFirmwarePlugin(parent)
    , _infoFactGroup(this)
{
    _setModeEnumToModeStringMapping({
        { APMSubMode::MANUAL            , _manualFlightMode         },
        { APMSubMode::STABILIZE         , _stabilizeFlightMode      },
        { APMSubMode::ACRO              , _acroFlightMode           },
        { APMSubMode::ALT_HOLD          , _altHoldFlightMode        },
        { APMSubMode::AUTO              , _autoFlightMode           },
        { APMSubMode::GUIDED            , _guidedFlightMode         },
        { APMSubMode::CIRCLE            , _circleFlightMode         },
        { APMSubMode::SURFACE           , _surfaceFlightMode        },
        { APMSubMode::POSHOLD           , _posHoldFlightMode        },
        { APMSubMode::MOTORDETECTION    , _motorDetectionFlightMode },
        { APMSubMode::SURFTRAK          , _surftrakFlightMode       },
    });

    static FlightModeList availableFlightModes = {
        // Mode Name                , Custom Mode                  CanBeSet  adv
        { _manualFlightMode         , APMSubMode::MANUAL            , true , true },
        { _stabilizeFlightMode      , APMSubMode::STABILIZE         , true , true },
        { _acroFlightMode           , APMSubMode::ACRO              , true , true },
        { _altHoldFlightMode        , APMSubMode::ALT_HOLD          , true , true },
        { _autoFlightMode           , APMSubMode::AUTO              , true , true },
        { _guidedFlightMode         , APMSubMode::GUIDED            , true , true },
        { _circleFlightMode         , APMSubMode::CIRCLE            , true , true },
        { _surfaceFlightMode        , APMSubMode::SURFACE           , true , true },
        { _posHoldFlightMode        , APMSubMode::POSHOLD           , true , true },
        { _motorDetectionFlightMode , APMSubMode::MOTORDETECTION    , true , true },
        { _surftrakFlightMode       , APMSubMode::SURFTRAK          , true , true },
    };
    updateAvailableFlightModes(availableFlightModes);

    if (!_remapParamNameIntialized) {
        // ArduPilot 4.7 renamed many parameters and converted them to SI units (cm -> m, cm/s -> m/s).
        // Keys are the new 4.7 names, values the pre-4.7 names. Only parameters referenced by QGC are
        // listed. Sub has no 4.6 release - it goes straight from 4.5 to 4.7.
        // Note: ARMING_CHECK -> ARMING_SKIPCHK is deliberately not remapped here - that rename also
        // inverts the bitmask, so it is handled explicitly in APMSafetyComponentSub.qml.
        FirmwarePlugin::remapParamNameMap_t &remapV4_7 = _remapParamName[4][7];

        remapV4_7["LOIT_SPEED_MS"]      = QStringLiteral("LOIT_SPEED");
        remapV4_7["LOIT_ACC_MAX_M"]     = QStringLiteral("LOIT_ACC_MAX");
        remapV4_7["LOIT_BRK_ACC_M"]     = QStringLiteral("LOIT_BRK_ACCEL");
        remapV4_7["LOIT_BRK_JRK_M"]     = QStringLiteral("LOIT_BRK_JERK");
        remapV4_7["PSC_D_ACC_P"]        = QStringLiteral("PSC_ACCZ_P");
        remapV4_7["PSC_D_ACC_I"]        = QStringLiteral("PSC_ACCZ_I");
        remapV4_7["PSC_D_ACC_D"]        = QStringLiteral("PSC_ACCZ_D");
        remapV4_7["PSC_D_ACC_IMAX"]     = QStringLiteral("PSC_ACCZ_IMAX");
        remapV4_7["PSC_D_ACC_FLTD"]     = QStringLiteral("PSC_ACCZ_FLTD");
        remapV4_7["PSC_D_ACC_FLTE"]     = QStringLiteral("PSC_ACCZ_FLTE");
        remapV4_7["PSC_D_ACC_FLTT"]     = QStringLiteral("PSC_ACCZ_FLTT");
        remapV4_7["PSC_NE_POS_P"]       = QStringLiteral("PSC_POSXY_P");
        remapV4_7["PSC_D_POS_P"]        = QStringLiteral("PSC_POSZ_P");
        remapV4_7["PSC_NE_VEL_P"]       = QStringLiteral("PSC_VELXY_P");
        remapV4_7["PSC_NE_VEL_I"]       = QStringLiteral("PSC_VELXY_I");
        remapV4_7["PSC_NE_VEL_IMAX"]    = QStringLiteral("PSC_VELXY_IMAX");
        remapV4_7["PSC_D_VEL_P"]        = QStringLiteral("PSC_VELZ_P");
        remapV4_7["WP_SPD"]             = QStringLiteral("WPNAV_SPEED");
        remapV4_7["WP_SPD_UP"]          = QStringLiteral("WPNAV_SPEED_UP");
        remapV4_7["WP_SPD_DN"]          = QStringLiteral("WPNAV_SPEED_DN");
        remapV4_7["WP_ACC"]             = QStringLiteral("WPNAV_ACCEL");
        remapV4_7["WP_ACC_Z"]           = QStringLiteral("WPNAV_ACCEL_Z");
        remapV4_7["WP_RADIUS_M"]        = QStringLiteral("WPNAV_RADIUS");

        _remapParamNameIntialized = true;
    }

    _nameToFactGroupMap.insert("apmSubInfo", &_infoFactGroup);

    _factRenameMap[QStringLiteral("altitudeRelative")] = QStringLiteral("Depth");
    _factRenameMap[QStringLiteral("flightTime")] = QStringLiteral("Dive Time");
    _factRenameMap[QStringLiteral("altitudeAMSL")] = QStringLiteral("");
    _factRenameMap[QStringLiteral("hobbs")] = QStringLiteral("");
    _factRenameMap[QStringLiteral("airSpeed")] = QStringLiteral("");
}

ArduSubFirmwarePlugin::~ArduSubFirmwarePlugin()
{

}

int ArduSubFirmwarePlugin::remapParamNameHigestMinorVersionNumber(int majorVersionNumber) const
{
    return ((majorVersionNumber == 4) ? 7 : Vehicle::versionNotSetValue);
}

void ArduSubFirmwarePlugin::initializeStreamRates(Vehicle *vehicle)
{
    vehicle->requestDataStream(MAV_DATA_STREAM_RAW_SENSORS, 2);
    vehicle->requestDataStream(MAV_DATA_STREAM_EXTENDED_STATUS, 2);
    vehicle->requestDataStream(MAV_DATA_STREAM_RC_CHANNELS, 2);
    vehicle->requestDataStream(MAV_DATA_STREAM_POSITION, 3);
    vehicle->requestDataStream(MAV_DATA_STREAM_EXTRA1, 20);
    vehicle->requestDataStream(MAV_DATA_STREAM_EXTRA2, 10);
    vehicle->requestDataStream(MAV_DATA_STREAM_EXTRA3, 3);
}

bool ArduSubFirmwarePlugin::isCapable(const Vehicle *vehicle, FirmwareCapabilities capabilities) const
{
    Q_UNUSED(vehicle);
    constexpr uint32_t available = SetFlightModeCapability | PauseVehicleCapability | GuidedModeCapability;
    return ((capabilities & available) == capabilities);
}

const QVariantList &ArduSubFirmwarePlugin::toolIndicators(const Vehicle *vehicle)
{
    Q_UNUSED(vehicle);
    //-- Sub specific list of indicators (Enter your modified list here)
    if (_toolIndicators.isEmpty()) {
        _toolIndicators = QVariantList({
            QVariant::fromValue(QUrl::fromUserInput("qrc:/qml/QGroundControl/Controls/BatteryIndicator.qml")),
            QVariant::fromValue(QUrl::fromUserInput("qrc:/qml/QGroundControl/Toolbar/JoystickIndicator.qml")),
        });
    }
    return _toolIndicators;
}

const QVariantList& ArduSubFirmwarePlugin::modeIndicators(const Vehicle *vehicle)
{
    Q_UNUSED(vehicle);
    //-- Sub specific list of indicators (Enter your modified list here)
    if (_modeIndicators.isEmpty()) {
        _modeIndicators = QVariantList({
            QVariant::fromValue(QUrl::fromUserInput("qrc:/qml/QGroundControl/Toolbar/ModeIndicator.qml")),
            QVariant::fromValue(QUrl::fromUserInput("qrc:/qml/QGroundControl/Toolbar/ArmedIndicator.qml")),
            QVariant::fromValue(QUrl::fromUserInput("qrc:/qml/QGroundControl/Toolbar/MultiVehicleSelector.qml")),
        });
    }
    return _modeIndicators;
}

void ArduSubFirmwarePlugin::_handleNamedValueFloat(mavlink_message_t *message)
{
    mavlink_named_value_float_t value{};
    mavlink_msg_named_value_float_decode(message, &value);

    const QString name = QString(value.name);

    if (name == "CamTilt") {
        _infoFactGroup.getFact("cameraTilt")->setRawValue(value.value * 100);
    } else if (name == "TetherTrn") {
        _infoFactGroup.getFact("tetherTurns")->setRawValue(value.value);
    } else if (name == "Lights1") {
        _infoFactGroup.getFact("lights1")->setRawValue(value.value * 100);
    } else if (name == "Lights2") {
        _infoFactGroup.getFact("lights2")->setRawValue(value.value * 100);
    } else if (name == "PilotGain") {
        _infoFactGroup.getFact("pilotGain")->setRawValue(value.value * 100);
    } else if (name == "InputHold") {
        _infoFactGroup.getFact("inputHold")->setRawValue(value.value);
    } else if (name == "RollPitch") {
        _infoFactGroup.getFact("rollPitchToggle")->setRawValue(value.value);
    } else if (name == "RFTarget") {
        _infoFactGroup.getFact("rangefinderTarget")->setRawValue(value.value);
    }
}

void ArduSubFirmwarePlugin::_handleMavlinkMessage(mavlink_message_t *message)
{
    switch (message->msgid) {
    case (MAVLINK_MSG_ID_NAMED_VALUE_FLOAT):
        _handleNamedValueFloat(message);
        break;
    case (MAVLINK_MSG_ID_RANGEFINDER):
    {
        mavlink_rangefinder_t msg{};
        mavlink_msg_rangefinder_decode(message, &msg);
        _infoFactGroup.getFact("rangefinderDistance")->setRawValue(msg.distance);
        break;
    }
    default:
        break;
    }
}

bool ArduSubFirmwarePlugin::adjustIncomingMavlinkMessage(Vehicle *vehicle, mavlink_message_t *message)
{
    _handleMavlinkMessage(message);
    return APMFirmwarePlugin::adjustIncomingMavlinkMessage(vehicle, message);
}

QMap<QString, FactGroup*>* ArduSubFirmwarePlugin::factGroups()
{
    return &_nameToFactGroupMap;
}
