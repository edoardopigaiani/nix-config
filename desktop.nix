# The graphical session: niri and the utilities that together replace GNOME.
# Import it from configuration.nix:
#   imports = [ ./hardware-configuration.nix ./terminal.nix ./nix-builds.nix ./desktop.nix ];
#
# Migration state: phases 1 and 2 are done. niri is the default session and
# tuigreet has replaced GDM, but GNOME is still installed and still listed by
# the greeter (F3), so it remains one logout away. Phase 3 -- removing GNOME,
# gnome-tweaks and the dconf trackpoint workaround, and swapping
# power-profiles-daemon for tlp -- is deliberately not done here; it is the
# step that is hard to walk back, and nothing forces it.
#
# The two phases are separate commits. Reverting the phase 2 commit alone
# gives GDM back without touching anything else.
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
# Colours everywhere are "Noir Essence Dark"; alacritty.toml's [colors] is the
# reference copy.

{ config, pkgs, ... }:

let
  # ----------------------------------------------------------- niri config
  # The KDL is checked at build time, so a typo fails `nh os switch` with the
  # parse error instead of handing you a compositor that will not start. niri
  # validate needs no display or session.
  niriConfig = pkgs.runCommand "niri-config.kdl" { } ''
    ${pkgs.niri}/bin/niri validate -c ${./niri.kdl}
    cp ${./niri.kdl} $out
  '';

  # ------------------------------------------------------------- swaylock
  # swaylock's own config file lives under its Nix store prefix, which is
  # read-only and not on any search path that matters, so the theme is passed
  # as flags instead. Colours are RRGGBB with no leading '#', which is
  # swaylock's format, and 00000000 is fully transparent.
  #
  # Only swayidle invokes this: `loginctl lock-session` raises logind's Lock
  # signal, swayidle's `lock` event catches it, and Mod+Shift+L in niri.kdl
  # calls loginctl. One definition covers the manual lock, the idle lock and
  # the lock before suspend.
  lockCommand = ''
    ${pkgs.swaylock}/bin/swaylock -f \
      --color 111314 \
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
      --font "JetBrains Mono"
  '';

  # --------------------------------------------------------- waybar config
  # Nix rather than a real file, because unlike waybar.css this has no syntax
  # Nix would corrupt -- the same split terminal.nix makes between the foot
  # module and alacritty.toml.
  #
  # Note what is NOT here: glyph icons. fonts.packages has no Nerd Font, and
  # JetBrains Mono has no symbol coverage, so icon-based formats would render
  # as tofu boxes. The text labels below instead follow the tmux status bar in
  # terminal.nix, which already writes battery as "B: 85%".
  waybarConfig = (pkgs.formats.json { }).generate "waybar-config" {
    layer = "top";
    position = "top";
    height = 26;
    spacing = 2;

    modules-left = [
      "niri/workspaces"
      "niri/window"
    ];
    modules-center = [ "clock" ];
    modules-right = [
      "tray"
      "idle_inhibitor"
      "wireplumber"
      "backlight"
      "network"
      "battery"
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

    # %d-%m and 24h, matching the tmux status bar's own date and clock.
    # LC_TIME is it_IT, so %a comes out in Italian.
    clock = {
      format = "{:%a %d-%m  %H:%M}";
      format-alt = "{:%Y-%m-%d %H:%M:%S}";
      tooltip-format = "<tt>{calendar}</tt>";
      calendar = {
        mode = "month";
        on-scroll = 1;
      };
    };

    battery = {
      states = {
        warning = 25;
        critical = 10;
      };
      format = "B: {capacity}%";
      format-charging = "B: {capacity}% +";
      format-plugged = "B: {capacity}% AC";
      tooltip-format = "{timeTo}\n{power:0.1f}W";
    };

    # wireplumber, not pulseaudio: services.pipewire runs wireplumber as its
    # session manager, and the native module reads it without the pulse
    # compatibility layer in between.
    wireplumber = {
      format = "VOL {volume}%";
      format-muted = "VOL --";
      on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      on-click-right = "foot -a wiremix wiremix";
      scroll-step = 5;
    };

    backlight = {
      format = "LUM {percent}%";
      scroll-step = 5;
    };

    network = {
      format-wifi = "{essid} {signalStrength}%";
      format-ethernet = "eth";
      format-disconnected = "offline";
      tooltip-format = "{ifname}  {ipaddr}";
      # nmtui ships with NetworkManager; no applet needed.
      on-click = "foot -a nmtui nmtui";
    };

    # Inhibits the idle lock below, for a long video or a presentation.
    idle_inhibitor = {
      format = "{status}";
      format-icons = {
        activated = "AWAKE";
        deactivated = "idle";
      };
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
  # Migration phase 2: GDM is off (configuration.nix) and the login screen is
  # tuigreet on VT1. GNOME is still installed and still selectable -- the
  # --sessions path below is the same directory GDM read, holding both
  # gnome.desktop and niri.desktop -- so the fallback survives this phase.
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
      # The session list, which is what keeps GNOME reachable. Same derivation
      # the display-manager module builds for any greeter.
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
      # those 16 slots to Noir Essence, so "cyan" here really is #a9b665.
      "--theme 'container=black;border=lightblack;title=white;greet=white;time=cyan;prompt=green;input=white;action=blue;button=yellow'"
    ];
  };

  # The kernel console palette, set to Noir Essence so the greeter, the TTYs
  # and the terminals inside the session all draw from one set of colours.
  # Values are the ANSI slots from alacritty.toml's [colors.normal] and
  # [colors.bright], in the order the kernel expects and without the leading
  # '#'. The theme defines bright == normal for everything but black, which is
  # why slots 9-15 repeat 1-7.
  console.colors = [
    "111314" # 0  black, and the console background
    "ea6962" # 1  red
    "89b482" # 2  green
    "e78a4e" # 3  yellow (the theme's orange)
    "7daea3" # 4  blue
    "d3869b" # 5  magenta
    "a9b665" # 6  cyan (the theme's lime, used as the accent)
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
  environment.etc."xdg/waybar/config".source = waybarConfig;
  environment.etc."xdg/waybar/style.css".source = ./waybar.css;

  # ---------------------------------------------------------------- fuzzel
  environment.etc."xdg/fuzzel/fuzzel.ini".source = ./fuzzel.ini;

  # ------------------------------------------------------------------ mako
  # The package's unit is used as-is (Type=dbus with the right BusName, which
  # is more correct than a hand-written one); only the target is retargeted.
  # Its config cannot live in /etc, so it is linked into ~/.config -- which
  # also means mako finds it when D-Bus activates it rather than systemd.
  systemd.user.services.mako = sessionService;

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
  # standalone equivalent and also provides the tray menu to unmount them.
  systemd.user.services.udiskie = sessionService // {
    description = "Removable disk automounter";
    serviceConfig = {
      ExecStart = "${pkgs.udiskie}/bin/udiskie --tray --appindicator --no-config";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------------- night light
  # GNOME's Night Light. Rome's coordinates; wlsunset computes the times from
  # them rather than taking fixed hours.
  systemd.user.services.wlsunset = sessionService // {
    description = "Day/night gamma adjustment";
    serviceConfig = {
      ExecStart = "${pkgs.wlsunset}/bin/wlsunset -l 41.9 -L 12.5 -t 3800 -T 6500";
      Restart = "on-failure";
    };
  };

  # ------------------------------------------------- services GNOME implied
  # All four are already on today because the GNOME module pulls them in.
  # Declaring them here is what keeps them once GNOME goes away in phase 3,
  # and documents that the session needs them.
  services.udisks2.enable = true; # the mount backend udiskie drives
  services.gvfs.enable = true; # trash:// and network mounts for yazi/Nautilus
  services.upower.enable = true; # the battery data waybar reads
  services.gnome.gnome-keyring.enable = true; # VSCode and GitHub Desktop secrets

  # power-profiles-daemon stays, and tlp is deliberately NOT enabled yet:
  # NixOS asserts that the two conflict, and ppd is currently on because the
  # GNOME module turns it on. Switching to tlp would break GNOME's power
  # panel, and GNOME is the fallback this whole phase exists to preserve.
  # Phase 3 is where ppd comes out and tlp goes in; `powerprofilesctl` works
  # from the command line under niri in the meantime.

  # ------------------------------------------------------------- brightness
  # brightnessctl's udev rules chgrp the backlight sysfs node to "video" and
  # the keyboard LED node to "input", then make them group-writable; without
  # both the rules and the group membership the XF86MonBrightness keys bound
  # in niri.kdl silently do nothing.
  services.udev.packages = [ pkgs.brightnessctl ];
  users.users.edo.extraGroups = [
    "video"
    "input"
  ];

  # ------------------------------------------------------------- theming
  # GTK4/libadwaita apps read the colour scheme from the portal, which serves
  # it from these gsettings -- so this one block themes both the GTK3 apps
  # (via the settings.ini below) and the GTK4 ones, and keeps working under
  # GNOME. It appends to the dconf database configuration.nix already defines
  # for the trackpoint.
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "adw-gtk3-dark";
        icon-theme = "Adwaita";
        cursor-theme = "Adwaita";
        font-name = "Cantarell 11";
        monospace-font-name = "JetBrains Mono 11";
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
    gtk-font-name=Cantarell 11
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
  # GNOME brought Cantarell and the Noto families along with it; nothing else
  # depends on them, so they have to be declared before GNOME can be removed.
  # The terminal fonts stay in terminal.nix.
  fonts.packages = with pkgs; [
    cantarell-fonts # the UI font the gsettings above name
    noto-fonts # broad coverage for anything the UI font lacks
    noto-fonts-color-emoji # emoji in Telegram and web pages
  ];

  # -------------------------------------------------------------- packages
  environment.systemPackages = with pkgs; [
    fuzzel # launcher (Mod+D)
    mako # notification daemon; also provides makoctl
    swaylock # lock screen, themed in lockCommand above
    swayidle # idle timeouts, see the unit above
    adw-gtk3 # the adw-gtk3-dark theme the gsettings name
    brightnessctl # XF86MonBrightness keys
    playerctl # XF86Audio play/next/prev
    wiremix # TUI mixer, replaces pavucontrol
    udiskie # automount + tray
    yazi # TUI file manager, replaces Nautilus for everyday use
    wlsunset # night light
    xwayland-satellite # XWayland for Steam, see the unit above
    wl-clipboard # already in terminal.nix for tmux; listed as a session dep
  ];
}
