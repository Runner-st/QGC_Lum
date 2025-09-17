/****************************************************************************
*
* (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
*
* QGroundControl is licensed according to the terms in the file
* COPYING.md in the root of the source code directory.
*
**************************************************************************/

#pragma once

#include <QtCore/QList>
#include <QtCore/QVariantList>
#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"
#include "CameraManagerPlugin.h"

class CameraManagerPlugin;

class QQmlApplicationEngine;

Q_DECLARE_LOGGING_CATEGORY(CustomLog)

class CustomUrlInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    CustomUrlInterceptor() = default;

    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) override;
};

class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT
    Q_PROPERTY(QVariantList servoButtons READ servoButtons NOTIFY servoButtonsChanged FINAL)
    Q_PROPERTY(CameraManagerPlugin *cameraManager READ cameraManager CONSTANT FINAL)

public:
    explicit CustomPlugin(QObject *parent = nullptr);
    ~CustomPlugin() override;

    static QGCCorePlugin *instance();

    QVariantList servoButtons() const;
    CameraManagerPlugin *cameraManager() const { return _cameraManager; }

    Q_INVOKABLE void addServoButton(const QString &name, int channel, int pulseWidth);
    Q_INVOKABLE void updateServoButton(int index, const QString &name, int channel, int pulseWidth);
    Q_INVOKABLE void removeServoButton(int index);
    Q_INVOKABLE void triggerServoCommand(int channel, int pulseWidth);

    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) override;
    void cleanup() override;

signals:
    void servoButtonsChanged();

private:
    struct ServoButtonDefinition {
        QString name;
        int channel = 0;
        int pulseWidth = 0;
    };

   QVariantList _serializeServoButtons() const;
    bool _loadServoButtons();
    void _saveServoButtons() const;
    ServoButtonDefinition _validatedButton(const QString &name, int channel, int pulseWidth) const;

    QList<ServoButtonDefinition> _servoButtons;

    static constexpr const char *_settingsGroup = "CustomServoControl";
    static constexpr const char *_settingsKey = "buttons";

    CustomUrlInterceptor *_urlInterceptor = nullptr;
    QQmlApplicationEngine *_qmlEngine = nullptr;
    CameraManagerPlugin *_cameraManager = nullptr;
};
