# KVS WebRTC SDK — Build and Patching Notes for Raspberry Pi

These notes document the changes required to build and run the [amazon-kinesis-video-streams-webrtc-sdk-c](https://github.com/awslabs/amazon-kinesis-video-streams-webrtc-sdk-c) on Raspberry Pi OS Bookworm (Debian 12) with `BUILD_DEPENDENCIES=OFF`. This is intended for the SDK engineering team as a summary of issues encountered and workarounds applied.

## 1. Using BUILD_DEPENDENCIES=OFF

Building with `-DBUILD_DEPENDENCIES=OFF` skips the SDK's bundled dependency builds (libsrtp, libusrsctp, libwebsockets) and relies on system-installed packages instead. This significantly reduces compile time on low-powered devices like the Raspberry Pi.

### Dependency compatibility (Raspberry Pi OS Bookworm armhf)

| Dependency | SDK pins | Bookworm provides | Compatible? | Notes |
|---|---|---|---|---|
| libsrtp | `bd0f27ec` (post-v2.5.0) | 2.5.0-3 (`libsrtp2-dev`) | Yes | Minor commit delta, ABI compatible |
| libusrsctp | `1ade45cb` | 0.9.5.0-2 (`libusrsctp-dev`) | Yes | Works at runtime |
| libwebsockets | **v4.3.5** | **4.1.6-3** (`libwebsockets-dev`) | **No** | API changes between 4.1 and 4.3 |
| kvsCommonLws | v1.6.1 | N/A | N/A | Always built from source (outside `if(BUILD_DEPENDENCIES)` block) |
| OpenSSL | — | 3.0.15 (`libssl-dev`) | Yes | Already excluded from bundled build upstream |
| mbedTLS | — | 2.28.3 (`libmbedtls-dev`) | Yes | Already excluded from bundled build upstream |

### The libwebsockets gap

The SDK requires libwebsockets v4.3.5 but Bookworm ships 4.1.6. This is the only dependency that prevents a clean `BUILD_DEPENDENCIES=OFF` build with stock packages. The workaround is to build libwebsockets v4.3.5 from source and install it to `/usr/local` before building the SDK:

```bash
git clone --branch v4.3.5 --depth 1 https://github.com/warmcat/libwebsockets.git
cd libwebsockets && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
  -DLWS_WITH_STATIC=ON -DLWS_WITH_SHARED=ON \
  -DLWS_WITHOUT_TESTAPPS=ON -DLWS_WITHOUT_TEST_SERVER=ON \
  -DLWS_WITHOUT_TEST_PING=ON -DLWS_WITHOUT_TEST_CLIENT=ON
make -j$(nproc) && sudo make install && sudo ldconfig
```

Then build the SDK:

```bash
cmake .. -DBUILD_DEPENDENCIES=OFF -DIOT_CORE_ENABLE_CREDENTIALS=ON -DCMAKE_PREFIX_PATH=/usr/local
make -j$(nproc)
```

### Suggestion for the SDK

Consider adding a `BUILD_LIBWEBSOCKETS` option (defaulting to ON) that can be toggled independently of `BUILD_DEPENDENCIES`, similar to how OpenSSL and mbedTLS are already handled. This would allow users on platforms with compatible libsrtp/libusrsctp packages to skip those builds while still building libwebsockets from source when the system version is too old.

## 2. GStreamer pipeline issues on Bookworm

### Problem: `autovideosrc` does not work with libcamera

Raspberry Pi OS Bookworm replaced the legacy camera stack with `libcamera`. The SDK samples hardcode `autovideosrc` for the `DEVICE_SOURCE` pipeline, which resolves to `v4l2src`. On Bookworm, `v4l2src` opens the unicam device directly and attempts to capture at 1280x720, but the CSI sensor only exposes its native resolution (e.g. 4056x3040 for the IMX477). This produces a kernel error:

```
unicam fe801000.csi: Wrong width or height 1280x720 (remote pad set to 4056x3040)
unicam fe801000.csi: Failed to start media pipeline: -22
```

The fix is to use `libcamerasrc` (from the `gstreamer1.0-libcamera` package), which routes through the ISP and handles resolution scaling.

### Problem: hardcoded pipelines require recompilation to change

The `DEVICE_SOURCE` pipelines in `GstMedia.c` are hardcoded strings. Any change to resolution, framerate, encoder settings, or source element requires recompiling the SDK. This is particularly painful on a Raspberry Pi where compilation takes several minutes.

### Problem: profile mismatch causes grey video

The hardcoded pipeline specifies `profile=baseline` in the output caps filter after `x264enc`, but `x264enc` with default settings produces `high` profile H.264. The caps filter silently drops frames that don't match, resulting in a viewer that receives the first keyframe (which may pass negotiation) but then shows grey for all subsequent frames.

### Our workaround: environment variable override

We patched `GstMedia.c` so that the `DEVICE_SOURCE` case checks an environment variable before falling back to the hardcoded pipeline:

- `KVS_GST_VIDEO_PIPELINE` — for `SAMPLE_STREAMING_VIDEO_ONLY`
- `KVS_GST_AUDIO_VIDEO_PIPELINE` — for `SAMPLE_STREAMING_AUDIO_VIDEO`

The patch adds `#include <stdlib.h>` and wraps each `DEVICE_SOURCE` block:

```c
case DEVICE_SOURCE: {
    {
        const char* envPipeline = getenv("KVS_GST_VIDEO_PIPELINE");
        if (envPipeline != NULL && envPipeline[0] != '\0') {
            DLOGI("[KVS GStreamer Master] Using custom pipeline from KVS_GST_VIDEO_PIPELINE");
            senderPipeline = gst_parse_launch(envPipeline, &gError);
        } else {
            // original hardcoded pipeline
            senderPipeline = gst_parse_launch("autovideosrc ...", &gError);
        }
    }
    break;
}
```

The working pipeline for Raspberry Pi with libcamera:

```
libcamerasrc ! video/x-raw,width=1280,height=720,framerate=30/1 !
queue ! videoconvert ! video/x-raw,format=I420 !
x264enc bframes=0 speed-preset=veryfast bitrate=512 byte-stream=TRUE
  tune=zerolatency key-int-max=30 !
video/x-h264,stream-format=byte-stream,alignment=au !
appsink sync=TRUE emit-signals=TRUE name=appsink-video
```

Key differences from the SDK default:
- `libcamerasrc` instead of `autovideosrc`
- Explicit `format=I420` caps before x264enc (required for correct color encoding)
- `key-int-max=30` for frequent keyframes (one per second at 30fps)
- No `profile=baseline` constraint in output caps (avoids frame dropping)

### Suggestions for the SDK

1. **Add env var support upstream** — the `KVS_GST_VIDEO_PIPELINE` / `KVS_GST_AUDIO_VIDEO_PIPELINE` pattern is minimal and backward-compatible. If the env var isn't set, behavior is unchanged.
2. **Remove `profile=baseline` from output caps** — or set `profile` as an x264enc property instead of a downstream caps filter. The current approach silently drops frames when x264enc produces a different profile.
3. **Add `key-int-max`** — the default x264enc keyframe interval is 250 frames (~10 seconds at 25fps). WebRTC viewers that join mid-stream won't see video until the next keyframe. A 1-2 second interval is more appropriate for real-time streaming.
4. **Document libcamera support** — Raspberry Pi OS Bookworm is the current stable release and uses libcamera exclusively. The SDK samples should document this or detect the platform.
