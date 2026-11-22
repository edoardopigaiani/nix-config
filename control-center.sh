# Control centre for the niri session: the toggles and panels GNOME kept in
# its quick settings menu, as a fuzzel list. Mod+S opens it (niri.kdl), the
# same key GNOME used.
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

notifications_state() {
  case "$({ makoctl mode 2>/dev/null || true; })" in
  *do-not-disturb*) echo "silenced" ;;
  *) echo "on" ;;
  esac
}

# ---------------------------------------------------------------- menu

row() {
  if [ "$#" -eq 3 ]; then
    printf '%s\t%-16s%s\n' "$1" "$2" "$3"
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
  row shot "Screenshot"
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

# The launchers exec, replacing this script, so nothing is left waiting on
# them. The toggles fall through and the loop redraws the menu with the new
# state, which is the whole reason this is a loop.
while :; do
  choice=$(main_menu | pick 'control> ') || exit 0
  case "$choice" in
  wifi) exec foot -a nmtui nmtui ;;
  bluetooth) exec foot -a bluetui bluetui ;;
  audio) exec foot -a wiremix wiremix ;;
  night) toggle_night_light ;;
  dnd) makoctl mode -t do-not-disturb >/dev/null ;;
  shot) exec niri msg action screenshot ;;
  lock) exec loginctl lock-session ;;
  power) power_submenu ;;
  *) exit 0 ;;
  esac
done
