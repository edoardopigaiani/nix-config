# Screen recording, as a toggle: Mod+Print starts it, Mod+Print again stops
# it. niri has screenshots built in but no recording, which is the one thing
# GNOME had that the session was missing.
#
# A real file wrapped by writeShellApplication in desktop.nix, for the reason
# control-center.sh gives: shell is full of ${...}, the syntax Nix would eat.
# PATH comes from runtimeInputs there.
#
# Encoding is on the GPU. The Vega 6 has two VAAPI encode entrypoints --
# vainfo lists VAEntrypointEncSlice for H.264 and for HEVC Main -- so the
# encode costs almost no CPU, which is the difference between a usable
# recording and a stuttering one on four threads. The invocation is the one
# wf-recorder's own manual gives for GPU encoding:
#
#   wf-recorder -f out.mkv -c h264_vaapi -d /dev/dri/renderD128
#
# /dev/dri/renderD128 is world-writable here (crw-rw-rw-), so this needs no
# group membership, unlike the card1 node next to it.
#
# Tested on this machine before being committed: a two-second capture came
# back as "Video: h264 (High), vaapi(pc), 1920x1080" over DMA-BUF, in a
# valid mp4 with its trailer written. Note what the log also showed --
# wf-recorder inserts "scale_vaapi=format=nv12:out_range=full" by itself, so
# the filter its manual says VAAPI requires does not have to be passed here.
#
# If a recording ever does come out black or refused, the manual's remaining
# escapes, in the order worth trying:
#   -x yuv420      convert in software first, for drivers that claim rgb0
#                  support but really only do yuv
#   --no-dmabuf    force a CPU copy of the frames instead of a GPU one
#
# Not enabled, and each a documented flag away:
#   -a    record audio too. Off because capturing the laptop microphone by
#         default is a surprise, not a feature.
#   -g    record part of the screen. Needs slurp for interactive selection,
#         which this config does not install -- niri's own screenshots cover
#         the region case.
#   -o    pick an output. With one display wf-recorder takes it by itself;
#         this is the knob if a second monitor ever shows up.

dir="$HOME/Videos/Recordings"
# The same shape as niri.kdl's screenshot-path, so the two sit side by side in
# the file manager: "Recording from 2026-11-22 23-40-01.mp4".
#
# mp4 rather than the mkv of wf-recorder's example. Stopping with SIGINT lets
# it write the trailer properly, so the usual path produces a valid file, and
# mp4 is the one that plays everywhere a recording gets sent. The trade is
# that a recording killed outright -- a crash, a hard logout -- leaves an mp4
# with no index and so unplayable, where mkv would have survived. Change the
# extension here if that ever happens more than once.
file="$dir/Recording from $(date +'%Y-%m-%d %H-%M-%S').mp4"

# pkill -INT, not -TERM: wf-recorder finalises the file on SIGINT and simply
# dies on SIGTERM, which would leave the recording unplayable.
if pkill -INT -x wf-recorder; then
  notify-send "Screen recording stopped" "Saved in ~/Videos/Recordings"
  exit 0
fi

mkdir -p "$dir"

# Detached with setsid so the recorder outlives this script: niri spawns the
# script, the script would otherwise be the parent of a process that has to
# keep running until the next keypress.
setsid wf-recorder \
  --file="$file" \
  --codec=h264_vaapi \
  --device=/dev/dri/renderD128 \
  >/dev/null 2>&1 &

# wf-recorder fails late -- it opens the output and the encoder before it can
# complain -- so a moment's grace separates "started" from "refused" instead
# of reporting success for a process that is already gone.
sleep 1
if pgrep -x wf-recorder >/dev/null; then
  notify-send "Screen recording started" "Mod+Print again to stop"
else
  notify-send -u critical "Screen recording failed" \
    "wf-recorder exited at once; see the VAAPI escapes in screen-record.sh"
fi
