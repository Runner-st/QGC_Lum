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
#include "LinksManager/LinksManagerController.h"
#include "Camera/C12Controller.h"
#include "Camera/TopotekController.h"

class QQmlApplicationEngine;
class HerelinkVideoStreamControl;

Q_DECLARE_LOGGING_CATEGORY(ServoControlLog)

class ServoControlUrlInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    ServoControlUrlInterceptor() = default;

    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) override;
};

class ServoControlPlugin : public QGCCorePlugin
{
    Q_OBJECT
    Q_PROPERTY(QVariantList servoButtons READ servoButtons NOTIFY servoButtonsChanged FINAL)
    Q_PROPERTY(LinksManagerController* linksManager READ linksManager CONSTANT)
    Q_PROPERTY(C12Controller* c12Controller READ c12Controller CONSTANT)
    Q_PROPERTY(TopotekController* topotekController READ topotekController CONSTANT)
    Q_PROPERTY(HerelinkVideoStreamControl* herelinkVideoStream READ herelinkVideoStream CONSTANT)

public:
    explicit ServoControlPlugin(QObject *parent = nullptr);
    ~ServoControlPlugin() override;

    static QGCCorePlugin *instance();

    QVariantList servoButtons() const;
    LinksManagerController* linksManager() const { return _linksManager; }
    C12Controller* c12Controller() const { return _c12Controller; }
    TopotekController* topotekController() const { return _topotekController; }
    HerelinkVideoStreamControl* herelinkVideoStream() const { return _herelinkVideoStream; }

    Q_INVOKABLE void addServoButton(const QString &name, int channel, int pulseWidth);
    Q_INVOKABLE void updateServoButton(int index, const QString &name, int channel, int pulseWidth);
    Q_INVOKABLE void removeServoButton(int index);
    Q_INVOKABLE void triggerServoCommand(int channel, int pulseWidth);

    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) override;
    void cleanup() override;

signals:
    void servoButtonsChanged();

private slots:
    void _updateC12ControlAddress();
    void _updateTopotekControlAddress();

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

    ServoControlUrlInterceptor *_urlInterceptor = nullptr;
    QQmlApplicationEngine *_qmlEngine = nullptr;
    LinksManagerController *_linksManager = nullptr;
    C12Controller *_c12Controller = nullptr;
    TopotekController *_topotekController = nullptr;
    HerelinkVideoStreamControl *_herelinkVideoStream = nullptr;
};
