# The graphical session: niri and the utilities that together replace GNOME.
# Import it from configuration.nix:
#   imports = [ ./hardware-configuration.nix ./terminal.nix ./nix-builds.nix ./desktop.nix ];
#
# Migration state: all three phases are done. niri is the only session,
# tuigreet replaced GDM (phase 2), and phase 3 removed GNOME itself, together
# with gnome-tweaks and the dconf trackpoint workaround, and swapped
# power-profiles-daemon for tlp. What GNOME used to provide and the session
# still needs is declared below, under "after GNOME".
#
# Each phase is its own commit. The boot menu no longer reaches back that
# far: the last generation that still had gnome-shell was 83, the menu holds
# the newest ten (configurationLimit in configuration.nix), and the count is
# past 150 -- so rolling back to a GNOME session is no longer one reboot
# away. The generations themselves are still on disk until nh clean takes
# them; `ls /nix/var/nix/profiles/` is what remains of them.
#
# Design rules followed throughout, both inherited from terminal.nix:
#
#   - Config goes in /etc where the tool looks there, so ~/.config still wins
#     and can be used for live experimentation without a rebuild. Verified per
#     tool: niri reads /etc/niri/config.kdl, waybar and fuzzel search
#     XDG_CONFIG_DIRS (/etc/xdg). mako is the exception -- mako(5) documents
#     no system path and the binary has no /etc fallback -- so its config is
#     linked into ~/.config with systemd.tmpfiles, as terminal.nix already
#     does for micro's colorscheme.
#
#   - Session services are wanted by niri.service, NOT by
#     graphical-session.target. GNOME starts that target too, so the usual
#     upstream wiring would run waybar and mako inside a GNOME session as
#     well, where mako would fail to claim org.freedesktop.Notifications from
#     gnome-shell. Binding to niri.service scopes them to niri; niri.service
#     is `BindsTo=graphical-session.target`, so they still stop cleanly.
#
# Colours are one palette: "Noir Essence Dark", the theme VS Code is set to
# (marketplace u1145h.u1145h-heme-ark, themes/noir_essence_dark.json in the
# extension). foot's colors-dark block in terminal.nix is the reference copy
# -- it is ported straight from the theme's own terminal keys, and every
# other file follows it: niri.kdl, waybar.css, mako.conf, swayosd.css,
# fuzzel.ini, swaylock below, console.colors below and Neovim's
# noir_essence.lua.
#
# Be careful with values carried over from before the move: this config has
# been on ayu-vim's dark, on Flexoki, on Zed's "Ayu Classic OLED" and on
# gruvbox, and Zed itself is on none of those now. Anything not matching the
# list above is stale.
#
# The palette names three greys by role rather than by ANSI number, and those
# do most of the work in the chrome. #161819 is the strip grey
# (editorWidget.background), filling mako's notification, swaylock's
# indicator and waybar's tooltips and tray menu; foot also puts it on palette
# entry 235, which is how weechat's, tmux's, micro's and Neovim's bars land
# on the same value. #2b2d2d is the theme's selection, for fuzzel's selected
# row, swayosd's trough and waybar's hover fill -- the value the terminal
# highlights with. #434545 is the ansi bright black, the UI grey the
# session's borders and hairlines are drawn in. The one exception is niri's
# focus ring, deliberately quieter than any of the three; niri.kdl says why.

{ config, pkgs, ... }:

let
  # ------------------------------------------------------- stem darkening
  # The macOS-like weight, set on everything in this file that draws
  # JetBrains Mono through FreeType: the launcher's wrapper, the lock
  # screen's script, and the waybar, mako and swayosd units. It was written
  # out five times here before, with each copy's comment warning that they
  # had to agree -- one binding is that warning made structural.
  #
  # terminal.nix's footWrapped is still the reference copy: that is where the
  # curve is explained, where the two measurements behind it are recorded,
  # and where it should be changed. This has to be changed with it, or the
  # chrome comes out at a different weight from the terminal under it. The
  # two cannot share a binding -- they are separate modules, with no `let` in
  # common -- so the duplication that is left is the cross-file one.
  freetypeProperties = "cff:no-stem-darkening=0 cff:darkening-parameters=500,500,1000,400,1667,300,2333,0";

  # ----------------------------------------------------------- niri config
  # The KDL is checked at build time, so a typo fails `nh os switch` with the
  # parse error instead of handing you a compositor that will not start. niri
  # validate needs no display or session.
  niriConfig = pkgs.runCommand "niri-config.kdl" { } ''
    ${pkgs.niri}/bin/niri validate -c ${./niri.kdl}
    cp ${./niri.kdl} $out
  '';

  # --------------------------------------------------------------- fuzzel
  # Wrapped for one variable: the stem darkening that puts its JetBrains Mono
  # at the weight foot, waybar, mako and swaylock draw. fuzzel goes through
  # fcft onto FreeType directly -- it links no GTK and runs under no systemd
  # unit -- so neither a gsettings key nor a drop-in can carry it, and a
  # wrapper is the only hook left. niri spawns the launcher as a bare
  # "fuzzel" off PATH (niri.kdl, Mod+D and the Mod+V clipboard pipe), which
  # is what makes this wrapper the one that runs, the same way foot's resolves
  # in terminal.nix. The curve itself is freetypeProperties above.
  fuzzelWrapped = pkgs.symlinkJoin {
    name = "fuzzel-${pkgs.fuzzel.version}";
    paths = [ pkgs.fuzzel ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/fuzzel \
        --set FREETYPE_PROPERTIES "${freetypeProperties}"
    '';
  };

  # ------------------------------------------------------------- swaylock
  # swaylock's own config file lives under its Nix store prefix, which is
  # read-only and not on any search path that matters, so the theme is passed
  # as flags instead. Colours are RRGGBB with no leading '#', which is
  # swaylock's format, and 00000000 is fully transparent. The font is
  # JetBrains Mono at 12, matching foot, waybar and mako; without
  # --font-size swaylock sizes the text from the indicator radius instead.
  #
  # That 12 is pixels, not points: swaylock hands the number to
  # cairo_set_font_size, which is in user-space units, and the surface is
  # unscaled here. It selects the face with cairo_select_font_face -- the toy
  # API, so --font takes a bare family name and not a Pango description, and
  # fontconfig resolves it to the OTF (CFF) build that the stem darkening
  # exported below needs. The export is the same curve as the terminal's, and
  # it has to be in this script rather than on a unit because swayidle execs
  # this file; it was dropped for a while, when swaylock was on a bitmap
  # FreeType antialiases nothing of, and is live again now.
  #
  # Colours are "Noir Essence Dark", as everywhere else; foot's colors-dark in
  # terminal.nix is the reference copy. The idle ring is 434545, the ansi
  # bright black, the same hairline fuzzel's border and swayosd's border use.
  # That it stays findable is the point: it measures 2.18:1 on black, quieter
  # than the 3.83:1 of the ayu grey it replaces but the only grey this theme
  # offers above its panel values -- the next ones down, 2b2d2d and 161819,
  # sit at 1.52:1 and 1.18:1 and would read as nothing on a black field. Not
  # 2b2d2d, the step niri's focus ring takes: on a lock screen the ring is
  # the only thing on screen, where niri's sits against window content and is
  # meant to stay out of the way. 161819, filling the indicator, is the strip
  # grey, the same value foot puts on palette entry 235.
  #
  # The keystroke tick (--key-hl-color) is the lime and not the orange, which
  # here is spent on the verifying ring: at the same colour, a tick appearing
  # while you type would look like the ring having already flipped to
  # verifying. The lime is the theme's own accent -- its cursor colour -- and
  # the orange is what it highlights matches with, which is the louder, more
  # momentary of the two.
  #
  # Only swayidle invokes this: `loginctl lock-session` raises logind's Lock
  # signal, swayidle's `lock` event catches it, and Mod+Shift+L in niri.kdl
  # calls loginctl. One definition covers the manual lock, the idle lock and
  # the lock before suspend.
  #
  # A script rather than a bare command string, so swayidle's ExecStart gets a
  # single store path. The string version ended in a newline, which put the
  # closing quote of each '...' argument on a line without a backslash; systemd
  # then rejected the unit for "Unbalanced quoting" and swayidle never ran --
  # no idle lock, no lock before suspend, and Mod+Shift+L did nothing.
  lockCommand = pkgs.writeShellScript "lock-screen" ''
    export FREETYPE_PROPERTIES="${freetypeProperties}"
    exec ${pkgs.swaylock}/bin/swaylock -f \
      --color 000000 \
      --inside-color 161819 \
      --inside-clear-color 161819 \
      --inside-ver-color 161819 \
      --inside-wrong-color 161819 \
      --ring-color 434545 \
      --ring-clear-color 7daea3 \
      --ring-ver-color e78a4e \
      --ring-wrong-color ea6962 \
      --key-hl-color a9b665 \
      --bs-hl-color ea6962 \
      --text-color f7f3ea \
      --text-clear-color f7f3ea \
      --text-ver-color f7f3ea \
      --text-wrong-color f7f3ea \
      --line-color 00000000 \
      --separator-color 00000000 \
      --indicator-radius 90 \
      --indicator-thickness 8 \
      --font "JetBrains Mono" \
      --font-size 12
  '';

  # --------------------------------------------------------- waybar config
  # Nix rather than a real file, because unlike waybar.css this has no syntax
  # Nix would corrupt -- the same split terminal.nix makes between the foot
  # module and the files it links instead, nvim.lua and darkblue.micro.
  #
  # The state modules draw Nerd Font glyphs, which resolve without any font
  # being named here: the fontconfig rule in terminal.nix appends
  # JetBrainsMono Nerd Font behind JetBrains Mono for anything that asks for
  # the latter. Under the Tamzen bitmap this file was on before, which
  # covered only ASCII and part of Latin-1, the same formats would have drawn
  # tofu.
  #
  # The two spaces between a glyph and its text are deliberate, not a typo to
  # tidy away. waybar hands the whole format string to Pango as one label,
  # and the proportional Nerd Font cut leaves almost no side bearing on the
  # icons, so a single space reads as none. If two now looks too airy, the
  # other direction is one space plus a thin space (U+2009) rather than going
  # back to one.
  #
  # No module here spawns anything on click, so none of them needs an absolute
  # store path: waybar runs as a systemd user service whose PATH does not
  # include /run/current-system/sw/bin, and a bare "foot" would fail with
  # "command not found". Keep that in mind before adding an on-click.
  waybarConfig = (pkgs.formats.json { }).generate "waybar-config" {
    layer = "top";
    position = "top";
    height = 26;
    spacing = 2;

    modules-left = [
      "niri/workspaces"
      "niri/window"
    ];
    # Deliberately sparse: only what is worth a permanent glance. Volume and
    # brightness are shown by the swayosd indicator when they change, and the
    # rest is managed in a terminal instead of being watched here -- audio
    # with wiremix (Mod+A), bluetooth with `bluetui`, wifi with `nmtui`.
    modules-right = [
      "tray"
      "idle_inhibitor"
      "battery"
      "clock"
    ];

    # niri creates and destroys workspaces dynamically, so the bar shows
    # indices rather than a fixed 1-9 row.
    "niri/workspaces" = {
      format = "{index}";
    };

    "niri/window" = {
      format = "{title}";
      max-length = 55;
      separate-outputs = true;
    };

    # The time only, HH:MM; the date, YYYY-MM-DD, is in the tooltip.
    clock = {
      format = "  {:%H:%M}";
      tooltip-format = "{:%Y-%m-%d}";
    };

    battery = {
      states = {
        warning = 25;
        critical = 10;
      };
      # Five icons, low to high: waybar indexes this list by capacity, so the
      # glyph follows the charge rather than being decoration. They come from
      # the Nerd Font that terminal.nix's fontconfig rule appends behind
      # JetBrains Mono, which is why no font has to be named here.
      format-icons = [
        ""
        ""
        ""
        ""
        ""
      ];
      format = "{icon}  {capacity}%";
      # The bolt replaces the "+" this used to append, and carries the same
      # meaning: plugged in but not charging (held by the tlp thresholds)
      # reads exactly like running on battery, because waybar.css paints
      # every battery state the same white. The bolt is the one thing on the
      # bar that distinguishes the two.
      format-charging = "  {capacity}%";
      format-plugged = "{icon}  {capacity}%";
      tooltip-format = "{timeTo}\n{power:0.1f}W";
    };

    # No bluetooth or network module: both are managed from a terminal, with
    # `bluetui` and `nmtui`. Those two cover scanning, pairing and connecting
    # on demand, which is the only time the state actually matters; nmcli and
    # bluetoothctl are there for scripts.

    # Inhibits the idle lock below, for a long video or a presentation.
    #
    # "{icon}" and not "{status}": waybar-idle-inhibitor(5) defines {status}
    # as the literal words "activated"/"deactivated", while {icon} is what
    # looks up format-icons. With {status} the map below is dead code and the
    # bar reads "deactivated", which says nothing about what the module is.
    # A cup while something is holding the screen awake, a moon while it is
    # free to lock. waybar.css carries the meaning in colour as before --
    # the cup is orange, the moon white -- and these replace the letters C
    # and I, which said the same thing less obviously.
    #
    # The letters were chosen partly so that toggling could not shift the
    # modules to the right of this one. That still holds only if the two
    # glyphs have the same advance, which is likely but not measured: the
    # Nerd Font cut that fontconfig hands waybar is the proportional one, and
    # Pango lays out by each glyph's own width rather than by a cell. If the
    # clock is ever seen to twitch on Mod-nothing, give #idle_inhibitor a
    # min-width in waybar.css and the question goes away.
    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "";
        deactivated = "";
      };
      # 10 min is swayidle's lock timeout below.
      tooltip-format-activated = "Automatic lock disabled";
      tooltip-format-deactivated = "Automatic lock after 10 min";
    };

    # Where Cryptomator, Telegram and Spotify dock now that the GNOME panel
    # is gone. This waybar is built with StatusNotifierItem and libdbusmenu
    # support, so those three keep their indicators.
    tray = {
      spacing = 8;
      icon-size = 16;
    };
  };

  # Shared wiring for every session service. after + wantedBy on niri.service
  # rather than graphical-session.target, for the reason in the header.
  sessionService = {
    after = [ "niri.service" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "niri.service" ];
  };
in
{
  # ---------------------------------------------------------------- niri
  programs.niri.enable = true;
  environment.etc."niri/config.kdl".source = niriConfig;

  # niri has no built-in XWayland; xwayland-satellite provides one as a user
  # service and claims display :0, which niri.kdl's environment block exports
  # as DISPLAY. Steam needs this -- it is a 32-bit X11 client and exits with
  # "cannot open display" otherwise. The package ships its own unit, so only
  # the wiring is declared here.
  systemd.packages = [
    pkgs.xwayland-satellite
    pkgs.mako
  ];
  systemd.user.services.xwayland-satellite = sessionService;

  # --------------------------------------------------------------- greetd
  # Migration phase 2: GDM is gone and the login screen is tuigreet on VT1.
  # Since phase 3 the --sessions path below holds only niri.desktop.
  #
  # Most of the wiring comes from the module and is deliberately not repeated
  # here: it aliases greetd to display-manager.service, sets
  # restartIfChanged = false so a rebuild cannot kill the running session,
  # creates /var/cache/tuigreet for --remember's state, orders itself after
  # plymouth-quit-wait, and sets enableGnomeKeyring from
  # services.gnome.gnome-keyring.enable -- which desktop.nix turns on, so the
  # keyring still unlocks at login the way it did under GDM.
  services.greetd = {
    enable = true;

    # Adjusts the unit's StandardInput/TTYPath so boot messages cannot scribble
    # over a TUI greeter. Without it tuigreet shares VT1 with the kernel log.
    useTextGreeter = true;

    settings.default_session.command = toString [
      "${pkgs.tuigreet}/bin/tuigreet"
      "--time"
      "--asterisks"
      # Remembers the username, and the session each user last picked, so
      # logging in is Enter-password-Enter once niri has been chosen the
      # first time.
      "--remember"
      "--remember-user-session"
      # The session list, the same derivation the display-manager module
      # builds for any greeter. Only niri is in it now.
      "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
      # Used only until --remember-user-session has something stored.
      "--cmd niri-session"
      # Spelled out rather than left to the defaults, so the cheat sheet can
      # state them: F2 command, F3 sessions, F12 power.
      "--kb-command 2"
      "--kb-sessions 3"
      "--kb-power 12"
      # Named ANSI colours rather than hex: the Linux VT is a 16-colour
      # terminal and ignores truecolour escapes. console.colors below remaps
      # those 16 slots to Noir Essence Dark, so "cyan" here really is the
      # theme's lime, #a9b665.
      "--theme 'container=black;border=lightblack;title=white;greet=white;time=cyan;prompt=green;input=white;action=blue;button=yellow'"
    ];
  };

  # The kernel console palette, set to Noir Essence Dark so the greeter, the
  # TTYs and the terminals inside the session all draw from one set of
  # colours. Values are foot's regular0-7 and bright0-7 (terminal.nix), in the
  # order the kernel expects and without the leading '#'. Slot 0 is black
  # rather than the theme's #111314, as in the terminal, and it is also the
  # console background. Bright black is the only slot the theme brightens, so
  # 9-15 repeat 1-7 here -- which is exactly what foot does above.
  console.colors = [
    "000000" # 0  black, and the console background
    "ea6962" # 1  red
    "89b482" # 2  green
    "e78a4e" # 3  yellow, an orange here
    "7daea3" # 4  blue
    "d3869b" # 5  magenta
    "a9b665" # 6  cyan, the theme's lime and its accent
    "f7f3ea" # 7  white
    "434545" # 8  bright black -- the one slot that really differs
    "ea6962" # 9  bright red
    "89b482" # 10 bright green
    "e78a4e" # 11 bright yellow
    "7daea3" # 12 bright blue
    "d3869b" # 13 bright magenta
    "a9b665" # 14 bright cyan
    "f7f3ea" # 15 bright white
  ];

  # ---------------------------------------------------------------- waybar
  programs.waybar = {
    enable = true;
    # The module's own option for exactly this: start with niri, not with
    # every graphical session.
    systemd.target = "niri.service";
  };
  # Stem darkening for the bar's JetBrains Mono, the same macOS-like weight
  # foot draws: freetypeProperties above, which says where the curve lives
  # and why the bar has to agree with the terminal under it. FreeType applies
  # it to CFF outlines only, which is the build fontconfig picks for this
  # family. waybar runs as a systemd user service, so the variable goes on
  # the unit rather than in a wrapper.
  systemd.user.services.waybar.environment.FREETYPE_PROPERTIES = freetypeProperties;
  environment.etc."xdg/waybar/config".source = waybarConfig;
  environment.etc."xdg/waybar/style.css".source = ./waybar.css;

  # ---------------------------------------------------------------- fuzzel
  environment.etc."xdg/fuzzel/fuzzel.ini".source = ./fuzzel.ini;

  # ------------------------------------------------------------------ mako
  # The package's unit is used as-is (Type=dbus with the right BusName, which
  # is more correct than a hand-written one); only the target is retargeted.
  # Its config cannot live in /etc, so it is linked into ~/.config -- which
  # also means mako finds it when D-Bus activates it rather than systemd.
  # FREETYPE_PROPERTIES: stem darkening for its JetBrains Mono, on the same
  # curve foot and waybar draw -- freetypeProperties above. Without it
  # notifications come out at a different weight from the bar and the
  # terminal they sit over. mako links no GTK --
  # it is cairo and pango straight onto a layer surface -- so this is the
  # whole of what governs its weight.
  systemd.user.services.mako = sessionService // {
    environment.FREETYPE_PROPERTIES = freetypeProperties;
  };

  systemd.tmpfiles.rules =
    let
      dir = "${config.users.users.edo.home}/.config/mako";
    in
    [
      "d ${dir} 0755 edo users -"
      "L+ ${dir}/config - - - - ${./mako.conf}"
    ];

  # ----------------------------------------------------------- idle & lock
  systemd.user.services.swayidle = sessionService // {
    description = "Idle management for niri";
    serviceConfig = {
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout 600 '${lockCommand}' \
          timeout 900 '${pkgs.niri}/bin/niri msg action power-off-monitors' \
          resume '${pkgs.niri}/bin/niri msg action power-on-monitors' \
          before-sleep '${lockCommand}' \
          lock '${lockCommand}'
      '';
      Restart = "on-failure";
    };
  };

  # --------------------------------------------------------- polkit agent
  # security.polkit is enabled by the niri module, but nothing provides the
  # agent that shows the authentication dialog. Without it, anything asking
  # for a password through polkit -- GNOME Disks, fwupd, a udiskie mount of an
  # unprivileged device -- fails silently.
  systemd.user.services.polkit-gnome-authentication-agent-1 = sessionService // {
    description = "polkit authentication agent";
    serviceConfig = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # ------------------------------------------------------------- automount
  # GNOME mounted USB sticks through gvfs without being asked; udiskie is the
  # standalone equivalent. No tray icon (--no-tray): it still automounts
  # silently, and unmounting is `udiskie-umount <path>` or yazi.
  #
  # The config file is passed by store path rather than put in /etc or
  # ~/.config: udiskie takes -c, so neither of the usual two mechanisms is
  # needed. It carries nothing but the notification settings -- udiskie.yml
  # says which and why -- and replaces the --no-config this unit used to pass.
  systemd.user.services.udiskie = sessionService // {
    description = "Removable disk automounter";
    serviceConfig = {
      ExecStart = "${pkgs.udiskie}/bin/udiskie --no-tray -c ${./udiskie.yml}";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------------------ wallpaper
  # swaybg draws the image as a background layer surface on every output;
  # niri.kdl's background-color stays as what shows if the file is missing.
  # The image is read from ~/Pictures at runtime rather than copied into the
  # repo, which is public. -m fill scales it to cover the screen, cropping
  # rather than letterboxing.
  #
  # The double quotes around the path are kept even though the file name
  # below no longer needs them. systemd splits ExecStart on whitespace, so a
  # name with a space in it -- which the previous wallpaper had -- would
  # otherwise reach swaybg as two arguments and the wallpaper would silently
  # not appear. Specifiers are expanded inside quotes, so %h still resolves:
  # verified by running the quoted form as a unit and having stat(1) report
  # one argument and the expanded home. Leaving them means the next image can
  # be dropped in without this trap being rediscovered.
  systemd.user.services.swaybg = sessionService // {
    description = "Wallpaper";
    serviceConfig = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg -m fill -c '#000000' -i \"%h/Pictures/hans-iEKg9h5_hd4-unsplash.jpg\"";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------- on-screen indicator
  # swayosd shows a bar with the new level when the volume or brightness keys
  # are pressed; niri.kdl binds those keys to swayosd-client, which changes
  # the value itself (through PipeWire and the backlight sysfs node) and asks
  # this server to draw it. Config and style are passed as store paths
  # rather than installed in /etc/xdg, so they cannot drift from the repo.
  #   - max_volume = 100: no amplification past 100%, as the old wpctl
  #     binding's -l 1.0 did.
  #   - min_brightness = 5: never all the way to a black screen.
  #   - show_percentage: the number next to the bar. waybar has no volume or
  #     brightness module, so this is where the values are read.
  # The package's swayosd-libinput-backend (a root service that shows Caps
  # Lock and the like) is not enabled: nothing here needs it.
  #
  # FREETYPE_PROPERTIES: the percentage is JetBrains Mono now (swayosd.css),
  # so it wants the same stem darkening as the bar and the notifications --
  # freetypeProperties above. swayosd is GTK4, so its text goes through Pango
  # onto FreeType
  # and the variable reaches it; it was not here while the label was a bitmap,
  # which FreeType antialiases nothing of and so cannot darken.
  systemd.user.services.swayosd = sessionService // {
    description = "On-screen display for volume and brightness";
    environment.FREETYPE_PROPERTIES = freetypeProperties;
    serviceConfig = {
      ExecStart =
        let
          config = pkgs.writeText "swayosd-config.toml" ''
            [server]
            max_volume = 100
            min_brightness = 5
            show_percentage = true
          '';
        in
        "${pkgs.swayosd}/bin/swayosd-server --config ${config} --style ${./swayosd.css}";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------------ clipboard history
  # cliphist keeps the last 750 things copied (text and images); Mod+V in
  # niri.kdl lists them in fuzzel and copies the chosen one back. wl-paste
  # --watch runs `cliphist store` on every clipboard change. Copies that a
  # password manager marks as sensitive are skipped (cliphist honours
  # wl-clipboard's CLIPBOARD_STATE=sensitive). The history lives in
  # ~/.cache/cliphist/db; `cliphist wipe` empties it.
  systemd.user.services.cliphist = sessionService // {
    description = "Clipboard history";
    serviceConfig = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------------- night light
  # GNOME's Night Light. Rome's coordinates; wlsunset computes the times from
  # them rather than taking fixed hours. Mod+N in niri.kdl turns it off or
  # back on for the session.
  systemd.user.services.wlsunset = sessionService // {
    description = "Day/night gamma adjustment";
    serviceConfig = {
      ExecStart = "${pkgs.wlsunset}/bin/wlsunset -l 41.9 -L 12.5 -t 3800 -T 6500";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------------------ after GNOME
  # The GNOME module used to turn all of these on; phase 3 removed it, so
  # they are declared here. Found by evaluating this config with and without
  # services.desktopManager.gnome and comparing the result.
  services.udisks2.enable = true; # the mount backend udiskie drives
  services.gvfs.enable = true; # trash:// and network mounts for yazi/Nautilus
  # The battery data waybar reads, and what happens when it runs out.
  # criticalPowerAction defaults to PowerOff, which loses whatever is open;
  # hibernating keeps it, and is possible now that configuration.nix names a
  # resumeDevice. upower fires this at its own last-ditch threshold (2% by
  # default), well after waybar's critical state has been blinking red at
  # 10%.
  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
  };
  # libinput's udev rules (touchpad fuzz overrides, device groups). niri
  # links libinput itself, but nothing else installs the rules.
  services.libinput.enable = true;
  services.gnome.glib-networking.enable = true; # TLS for GIO, so GTK apps can open https
  services.gnome.at-spi2-core.enable = true; # the accessibility bus GTK apps look for at startup
  # mDNS: how cups-browsed and system-config-printer find network printers.
  services.avahi.enable = true;
  programs.system-config-printer.enable = true; # printer setup, ex GNOME Settings panel
  programs.gnome-disks.enable = true; # GNOME Disks: format, ISO images, SMART
  programs.seahorse.enable = true; # browse the keyring; also SSH_ASKPASS
  services.gnome.sushi.enable = true; # Nautilus' space-bar quick preview
  # The GNOME module also made Nautilus the handler for folders.
  xdg.mime.defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";

  # ------------------------------------------------------------- bluetooth
  # Set explicitly: today GNOME's module turns it on with mkDefault, and phase 3
  # would otherwise lose it without a word. Devices are paired and connected
  # with `bluetui` in a terminal; the bar carries no bluetooth module.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # BlueZ's experimental features include the battery level of connected
    # devices, which bluetui shows in its device list.
    settings.General.Experimental = true;
  };
  services.gnome.gnome-keyring.enable = true; # VSCode and GitHub Desktop secrets

  # ------------------------------------------------------------------ power
  # tlp instead of power-profiles-daemon, which GNOME brought and which had
  # nothing to drive here: the Ryzen 3 PRO 3300U (Zen+) runs acpi-cpufreq,
  # with neither amd-pstate EPP nor ACPI platform_profile, so every ppd
  # profile used its "placeholder" driver. tlp tunes what this machine does
  # have -- CPU boost, PCIe/USB/Wi-Fi/NVMe power saving, amdgpu -- switching
  # by itself between AC and battery, and sets the ThinkPad charge thresholds.
  # The rest of its settings stay at tlp's defaults (`sudo tlp-stat` shows
  # them). If a USB device lags after being idle, exclude it from autosuspend
  # with USB_DENYLIST.
  services.tlp = {
    enable = true;
    settings = {
      # Charge only below 75% and stop at 80%: a battery kept full wears out
      # much faster, and this laptop is mostly on its charger. For one full
      # charge before a trip: `sudo tlp fullcharge BAT0`.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
      # No turbo on battery: less heat and power, little difference for
      # everyday use.
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      # Keep the Bluetooth adapter out of USB autosuspend: waking it is the
      # usual cause of headphones dropping and mice lagging. The radios are
      # otherwise left alone -- no DEVICES_TO_DISABLE_* -- so Wi-Fi and
      # Bluetooth are never switched off by tlp.
      USB_EXCLUDE_BTUSB = 1;
    };
  };

  # ------------------------------------------------------------------ yazi
  # The TUI file manager (Mod+E). Through the module rather than a bare
  # package so its theme lives here -- with one catch: the module wraps yazi
  # with YAZI_CONFIG_HOME pointing at the generated config, so unlike the
  # other tools ~/.config/yazi is ignored. Edit this block instead.
  #
  # The preset theme draws Nerd Font glyphs, which are stripped out below.
  # That is a choice, not a limit: the glyphs resolve fine, as the icons now
  # on waybar show. yazi is kept textual anyway, and the dividing line is
  # deliberate -- waybar is desktop chrome, while yazi runs in a terminal
  # grid alongside tmux, weechat and micro, which are all text. The snacks
  # explorer in nvim.lua is held to the same rule for the same reason.
  # Hence:
  programs.yazi = {
    enable = true;
    settings.theme = {
      # No file or folder icons at all: every preset rule is a glyph, and
      # conds holds the generic file/folder fallbacks too. Names keep their
      # colours.
      icon = {
        globs = [ ];
        dirs = [ ];
        files = [ ];
        exts = [ ];
        conds = [ ];
      };
      # The rounded powerline caps around the highlighted entry, the tabs and
      # the status bar segments; empty leaves plain rectangular blocks.
      indicator.padding = {
        open = "";
        close = "";
      };
      tabs = {
        sep_inner = {
          open = "";
          close = "";
        };
        sep_outer = {
          open = "";
          close = "";
        };
      };
      status = {
        sep_left = {
          open = "";
          close = "";
        };
        sep_right = {
          open = "";
          close = "";
        };
      };
      # Notification and completion icons, as plain text.
      notify = {
        icon_info = "i";
        icon_warn = "!";
        icon_error = "E";
      };
      cmp = {
        icon_file = "";
        icon_folder = "/";
        icon_command = ">";
      };
    };
  };

  # ------------------------------------------------------------- brightness
  # brightnessctl's udev rules chgrp the backlight sysfs node to "video" and
  # the keyboard LED node to "input", then make them group-writable; without
  # both the rules and the group membership the XF86MonBrightness keys bound
  # in niri.kdl silently do nothing.
  services.udev.packages = [ pkgs.brightnessctl ];

  # ---------------------------------------------------------------- scanner
  # simple-scan is in the package list below and could not see a device
  # without this: it talks to scanners only through SANE, and nothing else
  # here installs the backends. hardware.sane also brings the udev rules that
  # hand a scanner's USB node to the "scanner" group.
  #
  # sane-airscan covers the driverless protocols (eSCL and WSD) that network
  # and most recent USB multifunction units speak, which is the case a
  # backend-per-model list misses. It is additive: the stock backends still
  # handle everything they handled.
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  # One list, because this is a single module and the option cannot be
  # defined twice in it; configuration.nix adds networkmanager and wheel from
  # its side, which merges. What each one is for:
  users.users.edo.extraGroups = [
    "video" # brightnessctl's backlight node, above
    "input" # and its keyboard-LED node
    "scanner" # SANE's USB scanners, for simple-scan
    "lp" # a scanner built into a printer, which lands under lp instead
  ];

  # ------------------------------------------------------------- theming
  # GTK4/libadwaita apps read the colour scheme from the portal, which serves
  # it from these gsettings -- so this one block themes both the GTK3 apps
  # (via the settings.ini below) and the GTK4 ones.
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "adw-gtk3-dark";
        icon-theme = "Adwaita";
        cursor-theme = "Adwaita";
        # The schema defaults of gsettings-desktop-schemas (GNOME 48 and
        # later) are Adwaita Sans 11 and Adwaita Mono 11; the UI font is one
        # point smaller here. Spelled out so settings.ini below can match.
        font-name = "Adwaita Sans 10";
        monospace-font-name = "Adwaita Mono 11";
      };
    }
  ];

  # GTK3 apps started outside a settings daemon read this instead of dconf.
  # GTK searches XDG_CONFIG_DIRS, so ~/.config/gtk-3.0/settings.ini overrides.
  environment.etc."xdg/gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=adw-gtk3-dark
    gtk-icon-theme-name=Adwaita
    gtk-cursor-theme-name=Adwaita
    gtk-cursor-theme-size=24
    gtk-font-name=Adwaita Sans 10
    gtk-application-prefer-dark-theme=1
  '';

  # VLC is Qt, and without this it renders in the default light Fusion theme
  # against everything else being dark.
  qt = {
    enable = true;
    platformTheme = "gtk2";
    style = "adwaita-dark";
  };

  # ---------------------------------------------------------------- fonts
  # GNOME used to bring the Adwaita and Noto families along; nothing else
  # depends on them, so they are declared here. The terminal fonts stay in
  # terminal.nix.
  fonts.packages = with pkgs; [
    adwaita-fonts # Adwaita Sans and Mono, the fonts the gsettings above name
    noto-fonts # broad coverage for anything the UI font lacks
    noto-fonts-color-emoji # emoji in Telegram and web pages
  ];

  # -------------------------------------------------------------- packages
  environment.systemPackages = with pkgs; [
    fuzzelWrapped # launcher (Mod+D), wrapped for stem darkening
    mako # notification daemon; also provides makoctl
    swaylock # lock screen, themed in lockCommand above
    swayidle # idle timeouts, see the unit above
    adw-gtk3 # the adw-gtk3-dark theme the gsettings name
    adwaita-icon-theme # the icon and cursor theme the gsettings and niri.kdl name
    glib # gsettings and gio
    brightnessctl # XF86MonBrightness keys
    playerctl # XF86Audio play/next/prev
    wiremix # TUI mixer, replaces pavucontrol
    bluetui # TUI Bluetooth manager, replaces the GNOME panel's Bluetooth page
    udiskie # automount; udiskie-umount to unmount
    wlsunset # night light
    swaybg # wallpaper, see the unit above
    swayosd # volume/brightness indicator; swayosd-client is what niri.kdl binds
    cliphist # clipboard history, Mod+V
    xwayland-satellite # XWayland for Steam, see the unit above
    wl-clipboard # already in terminal.nix for tmux; listed as a session dep

    # The GNOME apps kept after phase 3; Disks, Seahorse and the printer
    # tool come from their program modules above.
    nautilus # file manager; yazi stays the everyday one
    papers # PDF viewer
    loupe # image viewer
    gnome-calculator
    simple-scan # scanner
    snapshot # webcam
    baobab # disk usage
    glycin-thumbnailer # image thumbnails in Nautilus
    gst-thumbnailers # audio and video thumbnails in Nautilus
  ];
}
