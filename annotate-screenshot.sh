# Annotating a screenshot: arrows, boxes, text and blur over what was just
# captured, then back to the clipboard. niri has screenshots built in but
# nothing to draw on them with, the same gap screen-record.sh fills for
# video, and "capture, scribble on it, paste it into a chat" is common enough
# that opening an image editor for it is friction worth removing.
#
# No capture of its own. All three of niri's screenshot actions (niri.kdl)
# put the PNG on the clipboard, so the clipboard is this script's input:
# Print and select a region, then Mod+Shift+Print to draw on it. Which also
# means the window and whole-screen variants are annotatable for free, with
# no second region selection and no temporary file in between.
#
# A real file wrapped by writeShellApplication in desktop.nix, as
# screen-record.sh and control-center.sh are and for the same reason: shell
# is full of ${...}, the syntax Nix would eat.
#
# Why the configuration below is flags rather than a config file, unlike the
# rest of this session: satty reads satty/config.toml under XDG_CONFIG_HOME
# alone. Checked rather than assumed -- with that file placed under
# XDG_CONFIG_DIRS it still says "config file not found" -- so the /etc/xdg
# route is not open here, and these follow the swaylock flags in desktop.nix
# instead.

# What niri puts on the clipboard is image/png, so that is what is asked for
# both here and below. wl-paste exits non-zero on an empty clipboard, which
# errexit would turn into a silent death; a condition context is what keeps
# it from doing so.
if ! wl-paste --list-types 2>/dev/null | grep -q '^image/png$'; then
  notify-send "Nothing to annotate" "Take a screenshot first, with Print."
  exit 0
fi

# niri creates this directory for its own screenshots; satty does not, and
# would fail at save time if the first capture of the session were annotated
# before one had been saved plainly.
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"

# --filename - reads the image from stdin, which is the pipe above.
#
# Enter saves twice: to the clipboard, which is what a screenshot is usually
# for, and to a file under the same name and in the same directory as
# niri.kdl's screenshot-path, so an annotated capture sits beside the plain
# ones. The format specifiers are satty's own, not date's -- it formats the
# name itself. --early-exit then closes satty, so Print, draw, Enter is the
# whole flow and nothing is left on screen to dismiss.
#
# arrow as the initial tool: satty starts on the pointer, which draws
# nothing, and an arrow is what an annotation usually is.
#
# Fullscreen, so a 1920x1080 capture is annotated at its own size rather than
# scaled into a tile. satty's help warns this depends on the compositor;
# niri honours the request. The font is the session's UI face, as the
# gsettings in desktop.nix name it.
wl-paste --type image/png |
  satty --filename - \
    --fullscreen \
    --initial-tool arrow \
    --actions-on-enter save-to-clipboard,save-to-file \
    --early-exit \
    --copy-command wl-copy \
    --output-filename "$dir/Screenshot from %Y-%m-%d %H-%M-%S.png" \
    --font-family "Adwaita Sans"
