## 📹 GStreamer для відео в QGroundControl

Ця збірка QGroundControl має підтримку **GStreamer** для роботи з відеопотоками.  
Щоб відео працювало коректно, потрібно встановити GStreamer Runtime / Plugins у системі.

### Windows
1. Завантажте **GStreamer 1.0 MSVC x86_64 Runtime (All-in-one bundle)** з [офіційного сайту](https://gstreamer.freedesktop.org/download/).
2. Встановіть **Runtime** (SDK не потрібен для користувачів).
3. Перезапустіть QGroundControl.

> ⚠️ Без GStreamer Runtime відео у QGC працювати не буде.

### Linux
AppImage включає базові бібліотеки GStreamer, але для підтримки більшості кодеків потрібно встановити додаткові пакети у систему:

```bash
sudo apt-get install \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav \
  gstreamer1.0-tools
