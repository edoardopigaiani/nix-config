# The root module: the machine itself, and whatever does not belong to one of
# the four files it imports. Boot and disks, networking, locale, the user, and
# the GUI applications that are installed but configured elsewhere or not at
# all.
#
# What is deliberately NOT here:
#   - terminal.nix   foot, fish, tmux, Neovim, micro and the terminal fonts
#   - nix-builds.nix what a rebuild is allowed to do to a 4-thread laptop
#   - desktop.nix    the niri session and everything that replaced GNOME
#
# The commented-out option stubs NixOS ships in this file are gone; the
# options themselves are at https://search.nixos.org/options, which is a
# better list than a stale copy of eight of them. configuration.nix(5) and
# `nixos-help` are the other two references.

{ pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./terminal.nix
    ./nix-builds.nix
    ./desktop.nix
  ];

  # TRIM through to the NVMe for both encrypted volumes: the root filesystem
  # (declared by hardware-configuration.nix) and the swap partition, whose
  # device node is named below. Off by default, because allowing discards
  # lets an attacker with the disk see which blocks are unused.
  boot.initrd.luks.devices = {
    "luks-8187315b-979b-4665-a691-f00ec33b0965".allowDiscards = true;
    "luks-d0394890-6673-4b1a-9c18-5c910f13aa1c" = {
      allowDiscards = true;
      device = "/dev/disk/by-uuid/d0394890-6673-4b1a-9c18-5c910f13aa1c";
    };
  };

  # Where to write the hibernation image, and where to look for it at boot.
  # Without this the kernel gets no resume= and hibernating loses the session:
  # the image is written and then never read back. systemd-boot and the
  # systemd initrd need nothing else -- the initrd already unlocks this
  # volume (above), so the device exists by the time resume is attempted.
  #
  # This is the swap signature's UUID, not the LUKS container's: the
  # container is d0394890..., and what resume needs is the swap inside it,
  # which is the /dev/mapper device. Named by UUID rather than by
  # /dev/mapper/luks-... so it does not depend on the mapper naming, but note
  # it does change if the partition is ever re-made with mkswap.
  #
  # The image fits: the partition is 8.8 GiB against 5.7 GiB of RAM. zram
  # above is a second, higher-priority swap and is irrelevant here --
  # hibernation goes to the device named here, not to the best-priority one.
  boot.resumeDevice = "/dev/disk/by-uuid/99e9858b-28b3-44ce-8f13-68d3d5f5ab05";

  # Compressed swap in RAM
  zramSwap.enable = true;

  # nh: front-end for nixos-rebuild (`nh os switch`) that shows a package diff
  # before activating. Its flake path lets it run from any directory, and it
  # picks nixosConfigurations.<hostname> by itself.
  programs.nh = {
    enable = true;
    flake = "/home/edo/Projects/nix-config";

    # Automatic cleanup of old generations; replaces nix.gc, which must stay off
    # (the nh module warns when both are enabled). Unlike nix.gc it always keeps
    # the last 5 generations, even if they are older than 14 days.
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 5";
    };
  };
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Limit boot menu entries (prevents the EFI partition from filling up).
  # Ten generations are plenty of way back; this was 30 during the GNOME-to-
  # niri migration, and with GNOME gone (phase 3) it is back to normal. It
  # only trims the menu: the generations themselves are collected by nh clean
  # above.
  boot.loader.systemd-boot.configurationLimit = 10;

  # Seconds the boot menu waits. 5 is systemd-boot's own default; it was 15
  # during the migration, so a GNOME generation was easy to pick. Any key
  # stops the countdown.
  boot.loader.timeout = 5;

  # Graphical boot: Plymouth shows the firmware logo and asks for the LUKS
  # passphrase graphically. This needs the systemd initrd, which is the default.
  # The settings below silence the kernel and systemd messages that would
  # otherwise print over the splash; errors (log level <= 3) still show.
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

  # Give up on a service that does not stop after 10s instead of the default
  # 90s, so a hung unit cannot stall shutdown or reboot for a minute and a half.
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";

  # Firmware updates
  services.fwupd.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "x395";
  networking.networkmanager.enable = true;

  # Tailscale: the only way into the homelab from outside the house.
  services.tailscale = {
    enable = true;
    # Opens UDP 41641 so peers can connect directly instead of going through
    # a DERP relay.
    openFirewall = true;
    extraSetFlags = [
      # Lets edo run `tailscale up`/`status`/`down` without sudo.
      "--operator=edo"
      # Blocks every incoming connection from the tailnet: this laptop only
      # connects out to the homelab, so if another tailnet device is
      # compromised it cannot reach this one. Outgoing traffic is unaffected;
      # receiving files with Taildrop stops working.
      # `tailscale set` persists in tailscaled's state, so removing this line
      # is not enough to undo it: run `tailscale set --shields-up=false`.
      "--shields-up"
    ];
  };

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "it_IT.UTF-8";
    LC_IDENTIFICATION = "it_IT.UTF-8";
    LC_MEASUREMENT = "it_IT.UTF-8";
    LC_MONETARY = "it_IT.UTF-8";
    LC_NAME = "it_IT.UTF-8";
    LC_NUMERIC = "it_IT.UTF-8";
    LC_PAPER = "it_IT.UTF-8";
    LC_TELEPHONE = "it_IT.UTF-8";
    LC_TIME = "it_IT.UTF-8";
  };

  # No desktop environment: the session is niri, with greetd + tuigreet as the
  # login screen, all in desktop.nix. GNOME was removed in migration phase 3;
  # the services and apps worth keeping from it are declared there.

  # The layout for everything that is not niri and not a TTY. No X server
  # runs here, so this looks like dead config and is not: nixpkgs builds
  # /etc/X11/xorg.conf.d/00-keyboard.conf out of it from
  # services.graphical-desktop, which greetd switches on, and localectl
  # reads that file to report the system layout. niri takes its own copy
  # (niri.kdl's xkb block, which says why it has to) and the TTYs take
  # console.keyMap below, so the layout is stated three times for three
  # readers. Keep them in step.
  services.xserver.xkb = {
    layout = "it";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "it2";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."edo" = {
    isNormalUser = true;
    description = "Edo";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    claude-code
    cryptomator
    vlc
    telegram-desktop
    (python3.withPackages (ps: [
      ps.websockets
      ps.pyyaml
    ]))
    github-desktop
    localsend
    spotify
    mpv
    glow
    zed-editor
    btop
    apostrophe
    tor-browser
    yt-dlp
  ];

  programs.nix-ld.enable = true;

  # Steam must come from this module, not environment.systemPackages: it is what
  # enables hardware.graphics.enable32Bit, without which the 32-bit client dies
  # at startup with "glXChooseVisual failed".
  programs.steam.enable = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
