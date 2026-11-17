/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTimer>

Q_DECLARE_LOGGING_CATEGORY(MicAudioLog)

struct _GstElement;

// Plays the mic-box RTSP audio stream (G.711 A-law, 8 kHz mono) with its own
// GStreamer pipeline, separate from the video receivers:
//   rtspsrc ! rtppcmadepay ! alawdec ! audioconvert ! audioresample ! volume ! autoaudiosink
//
// start() sends RTSP PLAY (the board starts to send RTP); stop() sets the
// pipeline to NULL, which sends RTSP TEARDOWN (the board stops sending).
// The NULL transition runs in QThreadPool::globalInstance(): when the link is
// lost, rtspsrc waits for its TEARDOWN and must not block the GUI thread.
// "Playing" is reported on the first audio buffer (a pad probe on alawdec),
// not on the PLAYING state: a live pipeline is PLAYING right after the RTSP
// handshake, before any RTP arrives.
// The bus is read by a QTimer in the Qt thread: QGC has no GLib main loop,
// so gst_bus_add_watch() would never fire, and no thread hops are needed.
class MicAudioPlayer : public QObject
{
    Q_OBJECT

public:
    enum class State { Off, Connecting, Playing };

    explicit MicAudioPlayer(QObject *parent = nullptr);
    ~MicAudioPlayer() override;

    // Returns false (and emits failed()) if the pipeline cannot be built.
    bool start(const QString &url, bool useTcp, int latencyMs);
    void stop();

    State state() const { return _state; }

    void setVolume(double volume);
    void setMuted(bool muted);

    static bool isSupported();

signals:
    void stateChanged();
    // The stream stopped by itself (error, EOS or connect timeout).
    // The pipeline is already stopped when this is emitted.
    void failed(const QString &reason);

private:
    void _pollBus();
    void _setState(State state);
    void _fail(const QString &reason);
    void _applyVolume();

    _GstElement *_pipeline = nullptr;
    QTimer _busTimer;
    QTimer _connectTimer;
    State _state = State::Off;
    double _volume = 1.0;
    bool _muted = false;

    static constexpr int kBusPollMs = 100;
    // Time allowed to reach PLAYING (RTSP handshake + first audio buffer).
    static constexpr int kConnectTimeoutMs = 10000;
};
