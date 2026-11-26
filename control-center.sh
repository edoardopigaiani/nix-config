# Control centre for the niri session: the toggles and panels GNOME kept in
# its quick settings menu, plus screen recording and screenshot annotation,
# which GNOME had and niri has no action for, and the hotkey overlay, which
# nothing else in the session advertises. As a fuzzel list. Mod+S opens it
# (niri.kdl), the same key GNOME used.
#
# A real file rather than a string in desktop.nix, for the reason the waybar
# config states in reverse: a shell script is full of ${...}, which is
# exactly the syntax Nix would eat. desktop.nix wraps it with
# writeShellApplication, whose runtimeInputs supply PATH -- so the bare
# command names below resolve without a single store path in this file. The
# wrapper also lints this script at build time, so a typo fails
# `nh os switch` rather than producing a menu that half works -- the trade
# niriConfig makes with `niri validate`.
#
# One quirk of that linter: a comment line starting with the tool's own name
# is parsed as a directive, not as prose, and fails the build. Keep such a
# word away from the start of a line.
#
# Every row is "key<TAB>label". fuzzel is asked to show only the label
# (--with-nth=2) and to print back only the key (--accept-nth=1), so the
# dispatch below matches on a stable word while the label is free to carry
# live state. The Mod+V clipboard binding uses the same --with-nth trick.
#
# Text only, no glyphs, unlike waybar: fuzzel.ini pins its font to the OTF
# build with fontformat=CFF, and the Nerd Font ships TTF only, so fontconfig
# cannot satisfy both and an icon would come out here as tofu. Checked with
#   fc-match "JetBrains Mono:size=9:fontformat=CFF:charset=F0F4"
# which answers with plain JetBrains Mono rather than the Nerd Font. Adding
# the Nerd Font as a second font on fuzzel's font line, the way foot does,
# is what would change that.
#
# What is deliberately NOT here: volume and brightness sliders. A dmenu row
# cannot be dragged, and stepping them one selection at a time is worse than
# the keys already bound in niri.kdl, which swayosd draws. Audio instead
# opens wiremix, which is the real mixer.

# --------------------------------------------------------------- state

wifi_state() {
  if [ "$(nmcli radio wifi)" != "enabled" ]; then
    echo "off"
    return
  fi
  # The active connection whose type is wireless; there is at most one.
  ssid=$(nmcli --terse --fields NAME,TYPE connection show --active |
    awk -F: '$2 == "802-11-wireless" { print $1; exit }')
  if [ -n "$ssid" ]; then
    echo "$ssid"
  else
    echo "on, not connected"
  fi
}

bluetooth_state() {
  powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ { print $2; exit }')
  if [ "$powered" != "yes" ]; then
    echo "off"
    return
  fi
  # wc -l rather than grep -c, which exits non-zero on no match and would
  # trip errexit; the braces keep a failing bluetoothctl from doing the same
  # through pipefail.
  connected=$({ bluetoothctl devices Connected 2>/dev/null || true; } | wc -l)
  if [ "$connected" -gt 0 ]; then
    echo "$connected connected"
  else
    echo "on"
  fi
}

audio_state() {
  volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0")
  percent=$(echo "$volume" | awk '{ printf "%d%%", $2 * 100 }')
  case "$volume" in
  *MUTED*) echo "$percent, muted" ;;
  *) echo "$percent" ;;
  esac
}

night_light_state() {
  if systemctl --user is-active --quiet wlsunset.service; then
    echo "on"
  else
    echo "off"
  fi
}

recording_state() {
  if pgrep -x wf-recorder >/dev/null; then
    echo "recording"
  else
    echo "off"
  fi
}

notifications_state() {
  case "$({ makoctl mode 2>/dev/null || true; })" in
  *do-not-disturb*) echo "silenced" ;;
  *) echo "on" ;;
  esac
}

# ---------------------------------------------------------------- menu

# A row carrying state puts it in a second column, so the values line up
# under each other rather than trailing each label. 16 is the width of the
# longest label that has state, "Screen recording", and the two spaces are a
# separate gutter rather than part of the field: at exactly 16 characters
# %-16s pads with nothing, which glued that row's state to its label until
# the gutter was pulled out of the field. A longer label now pushes its own
# state right instead of touching it.
row() {
  if [ "$#" -eq 3 ]; then
    printf '%s\t%-16s  %s\n' "$1" "$2" "$3"
  else
    printf '%s\t%s\n' "$1" "$2"
  fi
}

main_menu() {
  row wifi "Wi-Fi" "$(wifi_state)"
  row bluetooth "Bluetooth" "$(bluetooth_state)"
  row audio "Audio" "$(audio_state)"
  row night "Night light" "$(night_light_state)"
  row dnd "Notifications" "$(notifications_state)"
  row rec "Screen recording" "$(recording_state)"
  row shot "Screenshot"
  row annotate "Annotate screenshot"
  row keys "Shortcuts"
  row lock "Lock"
  row power "Power..."
}

power_menu() {
  row suspend "Suspend"
  row hibernate "Hibernate"
  row logout "Log out"
  row reboot "Reboot"
  row poweroff "Power off"
}

pick() {
  fuzzel --dmenu --with-nth=2 --accept-nth=1 --prompt "$1"
}

# ------------------------------------------------------------ dispatch

# Night light is stopped rather than signalled, as Mod+N does: SIGUSR1 cycles
# wlsunset through forced-day, forced-night and automatic, while this is a
# plain switch.
toggle_night_light() {
  if systemctl --user is-active --quiet wlsunset.service; then
    systemctl --user stop wlsunset.service
  else
    systemctl --user start wlsunset.service
  fi
}

# The power actions sit behind a second menu so that Power off is never one
# keystroke away from Wi-Fi.
power_submenu() {
  choice=$(power_menu | pick 'power> ') || return 0
  case "$choice" in
  suspend) exec systemctl suspend ;;
  hibernate) exec systemctl hibernate ;;
  logout) exec niri msg action quit ;;
  reboot) exec systemctl reboot ;;
  poweroff) exec systemctl poweroff ;;
  esac
}

# The three TUIs open as floating panels, which niri.kdl arranges by matching
# the app-ids given here with -a. Two flags make that work:
#
#   -o main.initial-window-mode=windowed  terminal.nix starts foot maximized,
#     and a maximised floating window is just a window covering the screen.
#     foot has no --windowed flag, so the config option is overridden instead.
#   -W  the size, in characters. Without it a windowed foot opens at its
#     default 80x24 regardless of what the TUI inside wants.
#
# Sizes are the smallest that do not make the tool fiddly: nmtui is a small
# ncurses dialog, bluetui needs room for its device list, and wiremix is the
# widest, being a mixer with a column per stream.
panel() {
  app=$1
  size=$2
  shift 2
  exec foot -a "$app" -o main.initial-window-mode=windowed -W "$size" "$@"
}

# The launchers exec, replacing this script, so nothing is left waiting on
# them. The toggles fall through and the loop redraws the menu with the new
# state, which is the whole reason this is a loop.
while :; do
  choice=$(main_menu | pick 'control> ') || exit 0
  case "$choice" in
  wifi) panel nmtui 80x24 nmtui ;;
  bluetooth) panel bluetui 100x30 bluetui ;;
  audio) panel wiremix 110x32 wiremix ;;
  night) toggle_night_light ;;
  dnd) makoctl mode -t do-not-disturb >/dev/null ;;
  rec) screen-record ;;
  shot) exec niri msg action screenshot ;;
  # Annotation reads the screenshot off the clipboard rather than taking one
  # (annotate-screenshot.sh), so reaching it from here is the slow path by
  # design: shoot first with Print, then come back. It notifies and exits if
  # the clipboard holds no image.
  annotate) exec annotate-screenshot ;;
  # niri's own list of every binding in niri.kdl, which is otherwise reachable
  # only by knowing that Mod+F1 shows it -- the overlay is set to
  # skip-at-startup, so nothing ever offers it. The one row here that answers
  # a question instead of changing something.
  keys) exec niri msg action show-hotkey-overlay ;;
  lock) exec loginctl lock-session ;;
  power) power_submenu ;;
  *) exit 0 ;;
  esac
done
