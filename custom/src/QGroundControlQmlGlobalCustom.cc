/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "QGroundControlQmlGlobal.h"

#include <QtCore/QSysInfo>

QString QGroundControlQmlGlobal::qgcVersion()
{
    QString versionStr = QStringLiteral("Limiere QGC v0.1");

    if (QSysInfo::buildAbi().contains("32")) {
        versionStr += QStringLiteral(" %1").arg(tr("32bit"));
    } else if (QSysInfo::buildAbi().contains("64")) {
        versionStr += QStringLiteral(" %1").arg(tr("64bit"));
    }

    return versionStr;
}

QString QGroundControlQmlGlobal::qgcAppDate()
{
    return QString();
}

bool QGroundControlQmlGlobal::qgcDailyBuild()
{
    return false;
}
