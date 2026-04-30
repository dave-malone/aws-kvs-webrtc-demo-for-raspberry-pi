#!/bin/bash
#
# patch-gst-pipeline.sh
#
# Patches the KVS WebRTC SDK's GstMedia.c so that DEVICE_SOURCE pipelines
# check environment variables before falling back to the hardcoded defaults:
#
#   KVS_GST_VIDEO_PIPELINE       - video-only pipeline
#   KVS_GST_AUDIO_VIDEO_PIPELINE - audio+video pipeline
#
# The pipeline string MUST contain the expected appsink element names:
#   appsink-video (and appsink-audio for audio+video)
#
# Usage:
#   ./patch-gst-pipeline.sh /path/to/samples/common/GstMedia.c
#

set -euo pipefail

GSTMEDIA="${1:?Usage: $0 <path-to-GstMedia.c>}"

if [[ ! -f "${GSTMEDIA}" ]]; then
  echo "Error: ${GSTMEDIA} not found"
  exit 1
fi

if grep -q 'KVS_GST_VIDEO_PIPELINE' "${GSTMEDIA}"; then
  echo "GstMedia.c is already patched, skipping."
  exit 0
fi

# Add stdlib.h for getenv() if not already present
if ! grep -q '#include <stdlib.h>' "${GSTMEDIA}"; then
  sed -i '/#include "Samples.h"/a #include <stdlib.h>' "${GSTMEDIA}"
  echo "Added #include <stdlib.h>"
fi

# Use awk to wrap each DEVICE_SOURCE gst_parse_launch block with an env var check.
# We track which streaming section we're in (VIDEO_ONLY vs AUDIO_VIDEO) to pick
# the right env var name.
awk '
BEGIN {
  section = ""
  in_device_source = 0
  collecting = 0
  block = ""
}

/case SAMPLE_STREAMING_VIDEO_ONLY:/ { section = "video" }
/case SAMPLE_STREAMING_AUDIO_VIDEO:/ { section = "audio_video" }

# Detect start of a DEVICE_SOURCE case block
/case DEVICE_SOURCE: \{/ {
  if (section == "video" || section == "audio_video") {
    in_device_source = 1
  }
  print
  next
}

# Inside DEVICE_SOURCE, look for the gst_parse_launch call
in_device_source && /senderPipeline = gst_parse_launch\(/ && !collecting {
  collecting = 1
  block = $0 "\n"
  next
}

# Continue collecting lines of the gst_parse_launch call until we see break;
collecting && !/break;/ {
  block = block $0 "\n"
  next
}

# We hit break; — emit the wrapped block
collecting && /break;/ {
  collecting = 0
  in_device_source = 0

  if (section == "video") {
    envvar = "KVS_GST_VIDEO_PIPELINE"
  } else {
    envvar = "KVS_GST_AUDIO_VIDEO_PIPELINE"
  }

  printf "                    {\n"
  printf "                        const char* envPipeline = getenv(\"%s\");\n", envvar
  printf "                        if (envPipeline != NULL && envPipeline[0] != '"'"'\\0'"'"') {\n"
  printf "                            DLOGI(\"[KVS GStreamer Master] Using custom pipeline from %s\");\n", envvar
  printf "                            senderPipeline = gst_parse_launch(envPipeline, &gError);\n"
  printf "                        } else {\n"
  # Re-indent the original block by 4 spaces
  n = split(block, lines, "\n")
  for (i = 1; i <= n; i++) {
    if (lines[i] != "") {
      printf "    %s\n", lines[i]
    }
  }
  printf "                        }\n"
  printf "                    }\n"
  print
  next
}

{ print }
' "${GSTMEDIA}" > "${GSTMEDIA}.patched"

mv "${GSTMEDIA}.patched" "${GSTMEDIA}"

# Verify the patch was applied
if grep -q 'KVS_GST_VIDEO_PIPELINE' "${GSTMEDIA}" && grep -q 'KVS_GST_AUDIO_VIDEO_PIPELINE' "${GSTMEDIA}"; then
  echo "Patched GstMedia.c: DEVICE_SOURCE blocks now check KVS_GST_VIDEO_PIPELINE / KVS_GST_AUDIO_VIDEO_PIPELINE"
else
  echo "WARNING: Patch may not have applied correctly. Check GstMedia.c manually."
  exit 1
fi
