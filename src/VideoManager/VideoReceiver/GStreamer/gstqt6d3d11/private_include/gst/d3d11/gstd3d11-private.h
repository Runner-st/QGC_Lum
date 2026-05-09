/* GStreamer
 * Copyright (C) 2020 Seungha Yang <seungha@centricular.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Trimmed copy vendored from upstream gst-plugins-bad 1.24.13 for the
 * QGC-local qt6d3d11 build. The installed GStreamer SDK does not ship
 * private headers; this file contains ONLY the definitions actually
 * referenced by the qt6d3d11 plugin sources (macros + inline C++ helpers).
 * Functions declared GST_D3D11_API in the upstream private header are
 * intentionally omitted — they would require symbols that are not
 * guaranteed to be exported from the installed gstd3d11-1.0.lib.
 */

#pragma once

#include <gst/gst.h>
#include <gst/d3d11/gstd3d11.h>

G_BEGIN_DECLS

#define GST_D3D11_TIER_0_FORMATS \
    "RGBA64_LE, BGRA64_LE, Y412_LE, RGB10A2_LE, Y410, BGR10A2_LE, Y212_LE, " \
    "Y210, VUYA, RGBA, BGRA, RBGA, P016_LE, P012_LE, P010_10LE, RGBx, BGRx, " \
    "YUY2, NV12"

#define GST_D3D11_TIER_1_FORMATS \
    "AYUV64, GBRA_12LE, GBRA_10LE, AYUV, ABGR, ARGB, GBRA, Y444_16LE, " \
    "GBR_16LE, Y444_12LE, GBR_12LE, I422_12LE, I420_12LE, Y444_10LE, GBR_10LE, " \
    "I422_10LE, I420_10LE, Y444, BGRP, GBR, RGBP, xBGR, xRGB, Y42B, NV21, " \
    "I420, YV12, GRAY16_LE, GRAY8"

#define GST_D3D11_TIER_LAST_FORMATS \
    "v216, v210, r210, v308, IYU2, RGB, BGR, UYVY, VYUY, YVYU, RGB16, BGR16, " \
    "RGB15, BGR15"

#define GST_D3D11_COMMON_FORMATS \
    GST_D3D11_TIER_0_FORMATS ", " \
    GST_D3D11_TIER_1_FORMATS ", " \
    GST_D3D11_TIER_LAST_FORMATS

#define GST_D3D11_SINK_FORMATS \
    "{ " GST_D3D11_COMMON_FORMATS " }"

#define GST_D3D11_SRC_FORMATS \
    "{ " GST_D3D11_COMMON_FORMATS " }"

#define GST_D3D11_ALL_FORMATS \
    "{ " GST_D3D11_COMMON_FORMATS " }"

#define GST_D3D11_CLEAR_COM(obj) G_STMT_START { \
    if (obj) { \
      (obj)->Release (); \
      (obj) = NULL; \
    } \
  } G_STMT_END

G_END_DECLS

#ifdef __cplusplus
#include <mutex>

class GstD3D11DeviceLockGuard
{
public:
  explicit GstD3D11DeviceLockGuard(GstD3D11Device * device) : device_ (device)
  {
    gst_d3d11_device_lock (device_);
  }

  ~GstD3D11DeviceLockGuard()
  {
    gst_d3d11_device_unlock (device_);
  }

  GstD3D11DeviceLockGuard(const GstD3D11DeviceLockGuard&) = delete;
  GstD3D11DeviceLockGuard& operator=(const GstD3D11DeviceLockGuard&) = delete;

private:
  GstD3D11Device *device_;
};

class GstD3D11CSLockGuard
{
public:
  explicit GstD3D11CSLockGuard(CRITICAL_SECTION * cs) : cs_ (cs)
  {
    EnterCriticalSection (cs_);
  }

  ~GstD3D11CSLockGuard()
  {
    LeaveCriticalSection (cs_);
  }

  GstD3D11CSLockGuard(const GstD3D11CSLockGuard&) = delete;
  GstD3D11CSLockGuard& operator=(const GstD3D11CSLockGuard&) = delete;

private:
  CRITICAL_SECTION *cs_;
};

class GstD3D11SRWLockGuard
{
public:
  explicit GstD3D11SRWLockGuard(SRWLOCK * lock) : lock_ (lock)
  {
    AcquireSRWLockExclusive (lock_);
  }

  ~GstD3D11SRWLockGuard()
  {
    ReleaseSRWLockExclusive (lock_);
  }

  GstD3D11SRWLockGuard(const GstD3D11SRWLockGuard&) = delete;
  GstD3D11SRWLockGuard& operator=(const GstD3D11SRWLockGuard&) = delete;

private:
  SRWLOCK *lock_;
};

#define GST_D3D11_CALL_ONCE_BEGIN \
    static std::once_flag __once_flag; \
    std::call_once (__once_flag, [&]()

#define GST_D3D11_CALL_ONCE_END )

#endif /* __cplusplus */
