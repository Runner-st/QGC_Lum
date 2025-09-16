/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CustomPlugin.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtQml/QQmlApplicationEngine>

QGC_LOGGING_CATEGORY(CustomLog, "gcs.custom.customplugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
}

CustomPlugin::~CustomPlugin()
{
    cleanup();
}

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

QQmlApplicationEngine *CustomPlugin::createQmlApplicationEngine(QObject *parent)
{
    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    if (!_urlInterceptor) {
        _urlInterceptor = new CustomUrlInterceptor();
        _qmlEngine->addUrlInterceptor(_urlInterceptor);
    }

    return _qmlEngine;
}

void CustomPlugin::cleanup()
{
    if (_qmlEngine && _urlInterceptor) {
        _qmlEngine->removeUrlInterceptor(_urlInterceptor);
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
