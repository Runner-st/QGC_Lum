/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantMap>

class QNetworkAccessManager;
class QNetworkReply;

// HTTP client for the mic-box tuning API (/api/config, /api/status).
//
// The board runs a single-threaded web server, so only one request is in
// flight at a time. Queued config changes are merged into one request
// ("last value wins" per key). A status poll is skipped while the client
// is busy.
class MicTuningClient : public QObject
{
    Q_OBJECT

public:
    explicit MicTuningClient(QObject *parent = nullptr);

    // Empty host disables the client. Aborts the current request and
    // clears the queue.
    void setEndpoint(const QString &host, int port);

    bool isBusy() const { return _current != nullptr || !_queue.isEmpty(); }
    // True while a config change is queued or in flight.
    bool hasPendingApply() const;

    void fetchConfig();
    void applyConfig(const QVariantMap &changes);
    void saveConfig();
    void resetConfig();
    // Returns false if the poll was skipped (client busy or no endpoint).
    bool pollStatus();

signals:
    // Values as the board applied them (clamped and rounded).
    void configReceived(const QVariantMap &config);
    void statusReceived(const QVariantMap &status);
    void saved();
    void statusFailed();
    void requestFailed(const QString &error);
    void reachableChanged(bool reachable);

private:
    enum class Kind { FetchConfig, ApplyConfig, Save, Reset, Status };

    struct Request {
        Kind kind;
        QVariantMap params;
    };

    void _enqueue(const Request &request);
    void _sendNext();
    void _onFinished(QNetworkReply *reply, Kind kind);
    void _setReachable(bool reachable);
    static QString _encodeValue(const QVariant &value);

    QNetworkAccessManager *_nam = nullptr;
    QNetworkReply *_current = nullptr;
    Kind _currentKind = Kind::Status;
    QList<Request> _queue;
    QString _baseUrl;
    bool _reachable = false;

    static constexpr int kTimeoutMs = 1500;
};
