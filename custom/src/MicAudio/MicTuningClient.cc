/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "MicTuningClient.h"
#include "MicAudioPlayer.h"

#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QUrlQuery>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

MicTuningClient::MicTuningClient(QObject *parent)
    : QObject(parent)
    , _nam(new QNetworkAccessManager(this))
{
}

void MicTuningClient::setEndpoint(const QString &host, int port)
{
    const QString base = host.isEmpty() ? QString() : QStringLiteral("http://%1:%2").arg(host).arg(port);
    if (base == _baseUrl) {
        return;
    }

    _queue.clear();
    if (_current) {
        QNetworkReply *reply = _current;
        _current = nullptr;
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }

    _baseUrl = base;
    _setReachable(false);
}

void MicTuningClient::fetchConfig()
{
    _enqueue({Kind::FetchConfig, {}});
}

void MicTuningClient::applyConfig(const QVariantMap &changes)
{
    if (changes.isEmpty()) {
        return;
    }
    _enqueue({Kind::ApplyConfig, changes});
}

void MicTuningClient::saveConfig()
{
    _enqueue({Kind::Save, {}});
}

void MicTuningClient::resetConfig()
{
    _enqueue({Kind::Reset, {}});
}

bool MicTuningClient::pollStatus()
{
    if (_baseUrl.isEmpty() || isBusy()) {
        return false;
    }
    _enqueue({Kind::Status, {}});
    return true;
}

void MicTuningClient::_enqueue(const Request &request)
{
    if (_baseUrl.isEmpty()) {
        return;
    }

    // Merge only with the last queued request of the same kind, so the order
    // against Save/Reset stays as the user made it.
    if (!_queue.isEmpty() && _queue.last().kind == request.kind) {
        Request &last = _queue.last();
        for (auto it = request.params.cbegin(); it != request.params.cend(); ++it) {
            last.params.insert(it.key(), it.value());
        }
        return;
    }

    _queue.append(request);
    _sendNext();
}

bool MicTuningClient::hasPendingApply() const
{
    if (_current && _currentKind == Kind::ApplyConfig) {
        return true;
    }
    for (const Request &request : _queue) {
        if (request.kind == Kind::ApplyConfig) {
            return true;
        }
    }
    return false;
}

QString MicTuningClient::_encodeValue(const QVariant &value)
{
    if (value.typeId() == QMetaType::Bool) {
        return value.toBool() ? QStringLiteral("1") : QStringLiteral("0");
    }
    if (value.typeId() == QMetaType::Double || value.typeId() == QMetaType::Float) {
        return QString::number(value.toDouble(), 'g', 6);
    }
    return value.toString();
}

void MicTuningClient::_sendNext()
{
    if (_current || _queue.isEmpty() || _baseUrl.isEmpty()) {
        return;
    }

    const Request request = _queue.takeFirst();

    QString path;
    bool post = true;
    switch (request.kind) {
    case Kind::FetchConfig: path = QStringLiteral("/api/config");       post = false; break;
    case Kind::ApplyConfig: path = QStringLiteral("/api/config");       break;
    case Kind::Save:        path = QStringLiteral("/api/config/save");  break;
    case Kind::Reset:       path = QStringLiteral("/api/config/reset"); break;
    case Kind::Status:      path = QStringLiteral("/api/status");       post = false; break;
    }

    QUrl url(_baseUrl + path);
    if (!request.params.isEmpty()) {
        QUrlQuery query;
        for (auto it = request.params.cbegin(); it != request.params.cend(); ++it) {
            query.addQueryItem(it.key(), _encodeValue(it.value()));
        }
        url.setQuery(query);
    }

    QNetworkRequest netRequest(url);
    netRequest.setTransferTimeout(kTimeoutMs);
    netRequest.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);

    QNetworkReply *reply = nullptr;
    if (post) {
        netRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
        reply = _nam->post(netRequest, QByteArray());
    } else {
        reply = _nam->get(netRequest);
    }

    _current = reply;
    _currentKind = request.kind;
    const Kind kind = request.kind;
    connect(reply, &QNetworkReply::finished, this, [this, reply, kind]() {
        _onFinished(reply, kind);
    });
}

void MicTuningClient::_onFinished(QNetworkReply *reply, Kind kind)
{
    reply->deleteLater();
    if (reply != _current) {
        return;
    }
    _current = nullptr;

    if (reply->error() != QNetworkReply::NoError) {
        const QString error = reply->errorString();
        qCDebug(MicAudioLog) << "Tuning request failed:" << reply->url().path() << error;
        _setReachable(false);
        if (kind == Kind::Status) {
            emit statusFailed();
        } else {
            emit requestFailed(error);
        }
        _sendNext();
        return;
    }

    _setReachable(true);

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll(), &parseError);
    const QVariantMap map = doc.isObject() ? doc.object().toVariantMap() : QVariantMap();

    switch (kind) {
    case Kind::FetchConfig:
    case Kind::ApplyConfig:
    case Kind::Reset:
        if (map.isEmpty()) {
            emit requestFailed(tr("Bad reply from the mic"));
        } else {
            emit configReceived(map);
        }
        break;
    case Kind::Save:
        emit saved();
        break;
    case Kind::Status:
        if (map.isEmpty()) {
            emit statusFailed();
        } else {
            emit statusReceived(map);
        }
        break;
    }

    _sendNext();
}

void MicTuningClient::_setReachable(bool reachable)
{
    if (_reachable != reachable) {
        _reachable = reachable;
        emit reachableChanged(reachable);
    }
}
