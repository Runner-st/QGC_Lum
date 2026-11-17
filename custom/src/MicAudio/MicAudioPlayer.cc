/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "MicAudioPlayer.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QThreadPool>

#ifdef QGC_GST_STREAMING
#include <gst/gst.h>

namespace {

constexpr const char *kFirstBufferMessage = "mic-first-buffer";

// Runs in a streaming thread. Posts one application message on the pipeline
// bus (read by _pollBus in the Qt thread) and removes itself.
GstPadProbeReturn firstBufferProbe(GstPad *, GstPadProbeInfo *, gpointer userData)
{
    GstElement *pipeline = GST_ELEMENT(userData);
    gst_element_post_message(pipeline,
        gst_message_new_application(GST_OBJECT(pipeline), gst_structure_new_empty(kFirstBufferMessage)));
    return GST_PAD_PROBE_REMOVE;
}

} // namespace
#endif

QGC_LOGGING_CATEGORY(MicAudioLog, "gcs.custom.micaudio")

MicAudioPlayer::MicAudioPlayer(QObject *parent)
    : QObject(parent)
{
    _busTimer.setInterval(kBusPollMs);
    connect(&_busTimer, &QTimer::timeout, this, &MicAudioPlayer::_pollBus);

    _connectTimer.setSingleShot(true);
    _connectTimer.setInterval(kConnectTimeoutMs);
    connect(&_connectTimer, &QTimer::timeout, this, [this]() {
        if (_state == State::Connecting) {
            _fail(tr("No audio from the mic (connect timeout)"));
        }
    });
}

MicAudioPlayer::~MicAudioPlayer()
{
    stop();
}

bool MicAudioPlayer::isSupported()
{
#ifdef QGC_GST_STREAMING
    return true;
#else
    return false;
#endif
}

bool MicAudioPlayer::start(const QString &url, bool useTcp, int latencyMs)
{
    stop();

#ifdef QGC_GST_STREAMING
    // rtspsrc properties are set with g_object_set, not in the launch string,
    // so the URL cannot inject pipeline syntax.
    static constexpr const char *kLaunch =
        "rtspsrc name=src ! rtppcmadepay ! alawdec name=dec ! audioconvert ! audioresample "
        "! volume name=vol ! autoaudiosink sync=false";

    GError *error = nullptr;
    GstElement *pipeline = gst_parse_launch(kLaunch, &error);
    if (error) {
        const QString reason = QString::fromUtf8(error->message);
        g_clear_error(&error);
        if (pipeline) {
            gst_object_unref(pipeline);
        }
        qCWarning(MicAudioLog) << "Cannot build audio pipeline:" << reason;
        _fail(tr("Audio pipeline error: %1").arg(reason));
        return false;
    }

    GstElement *src = gst_bin_get_by_name(GST_BIN(pipeline), "src");
    if (!src) {
        gst_object_unref(pipeline);
        _fail(tr("Audio pipeline error: no rtspsrc"));
        return false;
    }
    const QByteArray location = url.toUtf8();
    g_object_set(src,
                 "location", location.constData(),
                 "latency", static_cast<guint>(qMax(0, latencyMs)),
                 // Short limits, so an unreachable board cannot hold the
                 // RTSP connect/TEARDOWN for the default 20 s.
                 "tcp-timeout", static_cast<guint64>(3 * G_USEC_PER_SEC),
                 "teardown-timeout", static_cast<guint64>(500 * GST_MSECOND),
                 nullptr);
    gst_util_set_object_arg(G_OBJECT(src), "protocols", useTcp ? "tcp" : "udp");
    gst_object_unref(src);

    // The probe lives no longer than the pad, and the pad no longer than the
    // pipeline, so the pipeline pointer needs no extra ref.
    GstElement *decoder = gst_bin_get_by_name(GST_BIN(pipeline), "dec");
    if (decoder) {
        GstPad *pad = gst_element_get_static_pad(decoder, "sink");
        if (pad) {
            gst_pad_add_probe(pad, GST_PAD_PROBE_TYPE_BUFFER, firstBufferProbe, pipeline, nullptr);
            gst_object_unref(pad);
        }
        gst_object_unref(decoder);
    }

    _pipeline = pipeline;
    _applyVolume();

    qCDebug(MicAudioLog) << "Start" << url << (useTcp ? "tcp" : "udp") << "latency" << latencyMs;

    _setState(State::Connecting);
    _busTimer.start();
    _connectTimer.start();

    if (gst_element_set_state(_pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        _fail(tr("Cannot start the audio stream"));
        return false;
    }
    return true;
#else
    Q_UNUSED(url)
    Q_UNUSED(useTcp)
    Q_UNUSED(latencyMs)
    _fail(tr("GStreamer is not available in this build"));
    return false;
#endif
}

void MicAudioPlayer::stop()
{
    _busTimer.stop();
    _connectTimer.stop();

#ifdef QGC_GST_STREAMING
    if (_pipeline) {
        // NULL makes rtspsrc send TEARDOWN: the board stops sending RTP.
        // Done off the GUI thread; QCoreApplication waits for the global
        // pool on exit, so the TEARDOWN still goes out on quit.
        GstElement *pipeline = _pipeline;
        _pipeline = nullptr;
        QThreadPool::globalInstance()->start([pipeline]() {
            gst_element_set_state(pipeline, GST_STATE_NULL);
            gst_object_unref(pipeline);
        });
        qCDebug(MicAudioLog) << "Stopped";
    }
#endif

    _setState(State::Off);
}

void MicAudioPlayer::setVolume(double volume)
{
    _volume = qBound(0.0, volume, 2.0);
    _applyVolume();
}

void MicAudioPlayer::setMuted(bool muted)
{
    _muted = muted;
    _applyVolume();
}

void MicAudioPlayer::_applyVolume()
{
#ifdef QGC_GST_STREAMING
    if (!_pipeline) {
        return;
    }
    GstElement *vol = gst_bin_get_by_name(GST_BIN(_pipeline), "vol");
    if (vol) {
        g_object_set(vol, "volume", _volume, "mute", _muted ? TRUE : FALSE, nullptr);
        gst_object_unref(vol);
    }
#endif
}

void MicAudioPlayer::_pollBus()
{
#ifdef QGC_GST_STREAMING
    if (!_pipeline) {
        return;
    }

    GstBus *bus = gst_element_get_bus(_pipeline);
    if (!bus) {
        return;
    }

    QString failReason;
    bool gotFirstBuffer = false;

    const auto types = static_cast<GstMessageType>(GST_MESSAGE_ERROR | GST_MESSAGE_EOS | GST_MESSAGE_APPLICATION);
    while (GstMessage *msg = gst_bus_pop_filtered(bus, types)) {
        switch (GST_MESSAGE_TYPE(msg)) {
        case GST_MESSAGE_ERROR: {
            GError *err = nullptr;
            gchar *debug = nullptr;
            gst_message_parse_error(msg, &err, &debug);
            failReason = err ? QString::fromUtf8(err->message) : tr("Unknown stream error");
            qCWarning(MicAudioLog) << "Stream error:" << failReason << (debug ? debug : "");
            g_clear_error(&err);
            g_free(debug);
            break;
        }
        case GST_MESSAGE_EOS:
            failReason = tr("The mic closed the stream");
            break;
        case GST_MESSAGE_APPLICATION:
            if (gst_message_has_name(msg, kFirstBufferMessage)) {
                gotFirstBuffer = true;
            }
            break;
        default:
            break;
        }
        gst_message_unref(msg);
        if (!failReason.isEmpty()) {
            break;
        }
    }
    gst_object_unref(bus);

    if (!failReason.isEmpty()) {
        _fail(failReason);
        return;
    }
    if (gotFirstBuffer && _state == State::Connecting) {
        // The first RTP audio packet reached the decoder: the sound plays.
        _connectTimer.stop();
        _setState(State::Playing);
    }
#endif
}

void MicAudioPlayer::_fail(const QString &reason)
{
    stop();
    emit failed(reason);
}

void MicAudioPlayer::_setState(State state)
{
    if (_state != state) {
        _state = state;
        emit stateChanged();
    }
}
