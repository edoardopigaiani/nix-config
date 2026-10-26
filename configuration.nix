# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./terminal.nix
    ./nix-builds.nix
  ];

  boot.initrd.luks.devices."luks-8187315b-979b-4665-a691-f00ec33b0965".allowDiscards = true;
  boot.initrd.luks.devices."luks-d0394890-6673-4b1a-9c18-5c910f13aa1c".allowDiscards = true;

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

  # Limit boot menu entries (prevents the EFI partition from filling up)
  boot.loader.systemd-boot.configurationLimit = 10;

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

  boot.initrd.luks.devices."luks-d0394890-6673-4b1a-9c18-5c910f13aa1c".device =
    "/dev/disk/by-uuid/d0394890-6673-4b1a-9c18-5c910f13aa1c";
  networking.hostName = "x395"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
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

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # The X395 trackpoint is an Elantech device, so hardware.trackpoint's sysfs
  # knobs don't exist for it; set the speed through GNOME instead.
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/peripherals/pointingstick" = {
        speed = 1.0; # -1.0 .. 1.0 (default 0.0)
      };
    }
  ];

  # Configure keymap in X11
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
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."edo" = {
    isNormalUser = true;
    description = "Edo";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vscode
    claude-code
    gnome-tweaks
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
  ];

  programs.nix-ld.enable = true;

  # Steam must come from this module, not environment.systemPackages: it is what
  # enables hardware.graphics.enable32Bit, without which the 32-bit client dies
  # at startup with "glXChooseVisual failed".
  programs.steam.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

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
