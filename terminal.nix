# Port of the Fedora configuration for tmux, fish and alacritty.
# Import it from configuration.nix:
#   imports = [ ./hardware-configuration.nix ./terminal.nix ];
#
# weechat is deliberately not managed here: it rewrites its own config files at
# runtime and irc.conf holds credentials, so it stays as mutable files under
# ~/.config/weechat and ~/.local/share/weechat.

{ config, pkgs, ... }:

let
  # FreeType leaves stem darkening off for CFF fonts; turning it on thickens
  # strokes the way macOS does. It is set on the terminals alone so the rest of
  # GNOME keeps its rendering. symlinkJoin wraps the cached binary instead of
  # rebuilding it, and the desktop entries' Exec=alacritty / Exec=foot resolve
  # to the wrappers through PATH.
  #
  # Note this is currently inert: alacritty.toml selects the Tamzen bitmap, for
  # which FreeType reports render_mode "Mono" and antialiases nothing, so there
  # are no greyscale edges to darken. It is kept for the scalable fonts -- the
  # font.size/font.normal comments there spell out how narrow the bitmap's
  # usable sizes are, and switching back makes this matter again.
  alacrittyWrapped = pkgs.symlinkJoin {
    name = "alacritty-${pkgs.alacritty.version}";
    paths = [ pkgs.alacritty ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/alacritty \
        --set FREETYPE_PROPERTIES "cff:no-stem-darkening=0"
    '';
  };

  # The same wrapper for foot, and inert for the same reason: foot uses the
  # Tamzen bitmap too. Kept so a switch back to a scalable CFF font, such as
  # JetBrains Mono's OTF build, renders with stem darkening again.
  footWrapped = pkgs.symlinkJoin {
    name = "foot-${pkgs.foot.version}";
    paths = [ pkgs.foot ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/foot \
        --set FREETYPE_PROPERTIES "cff:no-stem-darkening=0"
    '';
  };

  # Tamzen with exact advance widths in its OTB files, which Pango (waybar,
  # mako) otherwise spaces 1 px too wide; tamzen-otb-advance.py has the why.
  # postFixup rather than postInstall: the package's own installPhase does
  # not run the install hooks. Only the OTBs change; the PCFs are untouched.
  tamzenFixed = pkgs.tamzen.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      (pkgs.python3.withPackages (ps: [ ps.fonttools ]))
    ];
    postFixup = (old.postFixup or "") + ''
      python3 ${./tamzen-otb-advance.py} "$out"/share/fonts/misc/*.otb
    '';
  });
in
{
  # ---------------------------------------------------------------- fish
  programs.fish = {
    enable = true;

    # Equivalent of the old config.fish plus fish_user_paths.
    # Runs in non-interactive shells too, so scripts see the same PATH.
    shellInit = ''
      fish_add_path --global $HOME/.local/bin $HOME/go/bin $HOME/.cargo/bin
    '';

    interactiveShellInit = ''
      function fish_greeting
        fortune -s | cowsay
      end

      # Color theme, ported from conf.d/fish_frozen_theme.fish.
      # Applied after fish picks its default theme, so these win.
      set --global fish_color_autosuggestion 555 brblack
      set --global fish_color_cancel -r
      set --global fish_color_command green
      set --global fish_color_comment 990000
      set --global fish_color_cwd brblack
      set --global fish_color_cwd_root red
      set --global fish_color_end 009900
      set --global fish_color_error ff0000
      set --global fish_color_escape 00a6b2
      set --global fish_color_history_current --bold
      set --global fish_color_host normal
      set --global fish_color_host_remote yellow
      set --global fish_color_normal normal
      set --global fish_color_operator white
      set --global fish_color_param green
      set --global fish_color_quote 999900
      set --global fish_color_redirection 00afff
      set --global fish_color_search_match white --background=brblack
      set --global fish_color_selection white --bold --background=brblack
      set --global fish_color_status red
      set --global fish_color_user blue
      set --global fish_color_valid_path --underline
      set --global fish_pager_color_completion
      set --global fish_pager_color_description B3A06D yellow
      set --global fish_pager_color_prefix normal --bold --underline
      set --global fish_pager_color_progress brwhite --background=cyan
      set --global fish_pager_color_selected_background -r
    '';
  };

  users.users."edo".shell = pkgs.fish;

  # ---------------------------------------------------------------- tmux
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";

    # The NixOS module defaults differ from tmux's own; realign them.
    escapeTime = 10;
    clock24 = true;

    # Replaces TPM, which cannot write into the read-only Nix store.
    plugins = [ pkgs.tmuxPlugins.battery ];

    # Must run before the plugins: tmux-battery rewrites the #{battery_*}
    # placeholders in status-right when it loads.
    extraConfigBeforePlugins = ''
      set -as terminal-features ",alacritty*:RGB"
      set -as terminal-features ",foot*:RGB"

      # remap prefix from 'C-b' to 'C-a'
      unbind C-b
      set-option -g prefix C-a
      bind-key C-a send-prefix

      # reload config file (now generated by NixOS)
      bind r source-file /etc/tmux.conf

      # Enable mouse mode (tmux 2.1 and above)
      set -g mouse on

      # Send every copy-mode selection to the Wayland clipboard, so text picked
      # with the mouse can be pasted into GUI apps with Ctrl+V.
      #
      # One option covers all of it: tmux's default copy bindings (drag release,
      # double-click word, triple-click line, C-w, M-w) all call
      # copy-pipe-and-cancel with no argument, and that falls back to
      # copy-command. Without it they relied solely on set-clipboard, which
      # emits OSC 52 and needs the window to hold the keyboard focus.
      #
      # The store path is used instead of a bare `wl-copy` because the command
      # runs through /bin/sh from the tmux server, which does not necessarily
      # have the user's PATH. WAYLAND_DISPLAY does reach it: the server has it
      # and update-environment refreshes it on re-attach.
      set -g copy-command '${pkgs.wl-clipboard}/bin/wl-copy'

      # Pass terminal focus in/out events to programs in the panes
      # (requested by Claude Code)
      set -g focus-events on

      # don't rename windows automatically
      set-option -g allow-rename off

      # panes
      set -g pane-border-style 'fg=colour0 bg=colour0'
      set -g pane-active-border-style 'bg=colour0 fg=colour8'

      # bar
      # colour235 is weechat's title/status bar grey (#262626), which
      # noir_essence.lua also uses for Neovim's statusline; only the
      # background changed, the foreground colours are as they were.
      set -g status-position bottom
      set -g status-justify centre
      set -g status-style 'bg=colour235 fg=colour7'
      set -g status-left '%d#[fg=colour4]-#[fg=colour7]%m'
      # #{battery_status_bg} was dropped by tmux-battery and already rendered
      # empty on Fedora, so it is left out here.
      set -g status-right ' B#[fg=colour4]:#[fg=colour7] #{battery_percentage} | %H#[fg=colour4]:#[fg=colour7]%M '
      set -g status-right-length 50
      set -g status-left-length 18

      setw -g window-status-current-style 'fg=colour7 bg=colour235'
      setw -g window-status-current-format '#[fg=colour4]> #[fg=colour7]#W#[fg=colour7]'

      setw -g window-status-style 'fg=colour7 bg=colour235'
      setw -g window-status-format '#[fg=colour8]> #[fg=colour7]#W#[fg=colour7]'

      setw -g window-status-bell-style 'fg=colour255 bg=colour4 bold'

      # Two-row status bar: row 0 is a blank spacer, row 1 mirrors the real
      # format. status-format is reset first, so the copy reads tmux's default
      # even on a reload (prefix r): otherwise row 0 is already blank from the
      # previous load and row 1 copies the empty string, leaving the whole bar
      # empty. The spacer is filled with colour0, the terminal background, so
      # only the real row shows status-style's grey.
      set -gu status-format
      set -Fg 'status-format[1]' '#{status-format[0]}'
      set -g 'status-format[0]' '#[fill=colour0]'
      set -g status 2

      # messages
      set -g message-style 'fg=colour232 bg=colour46 bold'

      set -g bell-action none
      set -g visual-bell off
      set -g monitor-bell off
    '';
  };

  # ------------------------------------------------------------- alacritty
  # NixOS has no programs.alacritty module, so the config is installed by hand.
  #
  # It stays a real TOML file instead of a Nix string: the URL hint regex
  # contains \u escapes, a form Nix strings do not support and would corrupt.
  #
  # /etc/xdg is on XDG_CONFIG_DIRS, which Alacritty 0.17 searches right after
  # the user config (verified with strace; the /etc/alacritty path named in
  # alacritty(5) is only the last fallback). A user file at
  # ~/.config/alacritty/alacritty.toml therefore still takes precedence.
  environment.etc."xdg/alacritty/alacritty.toml".source = ./alacritty.toml;

  # ------------------------------------------------------------------ foot
  # A port of alacritty.toml to foot, font included.
  # The module writes /etc/xdg/foot/foot.ini, which ~/.config/foot/foot.ini
  # overrides. Settings equal to foot's defaults are left out: Ctrl+Shift+C/V,
  # Shift+Insert, Ctrl+0/+/-, Ctrl+Shift+N, Shift+PageUp/Down, middle-click
  # paste, the hollow unfocused cursor and Alacritty's semantic_escape_chars
  # (foot's word-delimiters) all already match. foot has no live reload; new
  # windows read the file.
  programs.foot = {
    enable = true;
    package = footWrapped;
    settings = {
      main = {
        # Tamzen's 8x15 strike, as in alacritty.toml (size = 11.25 there is the
        # same 15 px). pixelsize rather than size: a bitmap is only sharp at
        # the sizes it was drawn at, and pixelsize is not run through DPI
        # scaling, so it names the strike exactly. Bold comes from Tamzen's
        # own Bold strike; there is no italic, so italic text stays upright.
        font = "Tamzen:pixelsize=15";

        # Alacritty's draw_bold_text_with_bright_colors: bold regular colours
        # switch to their bright palette entry. That only changes black here,
        # as the theme's bright and normal colours are otherwise equal.
        bold-text-in-bright = "palette-based";

        # Alacritty sets TERM=xterm-256color; foot's own entry is more
        # accurate, and ncurses ships it.
        term = "foot";

        # window: padding 10x10 with dynamic_padding, maximized, no decorations.
        pad = "10x10 center";
        initial-window-mode = "maximized";
      };

      # Alacritty's bell is silent (duration = 0, and it has no audible bell).
      bell.system = "no";

      scrollback = {
        lines = 10000;
        multiplier = 3;
      };

      cursor.blink = "no";

      # decorations = "None". GNOME has no server-side decorations, so without
      # this foot would draw its own title bar.
      csd.preferred = "none";

      key-bindings = {
        # Alacritty's Shift+Alt+U / Shift+Alt+D, on top of foot's defaults.
        scrollback-up-page = "Shift+Page_Up Shift+KP_Page_Up Mod1+Shift+u";
        scrollback-down-page = "Shift+Page_Down Shift+KP_Page_Down Mod1+Shift+d";
        # Alacritty's URL hint key, kept alongside foot's Ctrl+Shift+O. URL
        # mode opens with xdg-open by default, like the hint did.
        show-urls-launch = "Control+Shift+o Control+Shift+h";
      };

      # Noir Essence Dark, the same values as alacritty.toml's [colors],
      # including the pure-black background and color0.
      colors-dark = {
        background = "000000";
        foreground = "f7f3ea";
        cursor = "334743 a9b665"; # text, then cursor
        # foot has no CellForeground; the default foreground is what nearly
        # every selected cell would show anyway.
        selection-foreground = "f7f3ea";
        selection-background = "2b2d2d";
        # Alacritty's hint and search-match colours.
        jump-labels = "000000 e78a4e";
        search-box-match = "000000 e78a4e";
        search-box-no-match = "000000 ea6962";
        scrollback-indicator = "f7f3ea 161819";
        urls = "7daea3";

        regular0 = "000000";
        regular1 = "ea6962";
        regular2 = "89b482";
        regular3 = "e78a4e";
        regular4 = "7daea3";
        regular5 = "d3869b";
        regular6 = "a9b665";
        regular7 = "f7f3ea";
        bright0 = "434545";
        bright1 = "ea6962";
        bright2 = "89b482";
        bright3 = "e78a4e";
        bright4 = "7daea3";
        bright5 = "d3869b";
        bright6 = "a9b665";
        bright7 = "f7f3ea";
      };
    };
  };

  # ---------------------------------------------------------------- micro
  # micro only reads user colorschemes from ~/.config/micro/colorschemes, so the
  # Alacritty-matching scheme is linked there. Selecting it is left to micro
  # (`set colorscheme darkblue`), which keeps the choice in its own mutable
  # settings.json.
  systemd.tmpfiles.rules =
    let
      dir = "${config.users.users.edo.home}/.config/micro/colorschemes";
    in
    [
      "d ${dir} 0755 edo users -"
      "L+ ${dir}/darkblue.micro - - - - ${./darkblue.micro}"
    ];

  # -------------------------------------------------------------- neovim
  # Plugins and config are both declared here, so the wrapper starts nvim with
  # -u pointing at the generated init; nvim.lua sources ~/.config/nvim/init.lua
  # itself for anything untracked. wl-clipboard below is what backs the "+
  # register on Wayland.
  programs.neovim = {
    enable = true;
    configure = {
      customLuaRC = builtins.readFile ./nvim.lua;
      packages.default.start = with pkgs.vimPlugins; [
        claudecode-nvim
        snacks-nvim # claudecode.nvim's terminal provider, and the picker
        gitsigns-nvim
        which-key-nvim
        nvim-lspconfig # server definitions for vim.lsp.enable
        # The Noir Essence port, as a one-file plugin providing
        # :colorscheme noir_essence.
        (pkgs.linkFarm "noir-essence-nvim" [
          {
            name = "colors/noir_essence.lua";
            path = ./noir_essence.lua;
          }
        ])
        # Neovim already bundles c, lua, markdown, query, vim and vimdoc.
        (nvim-treesitter.withPlugins (
          p: with p; [
            nix
            bash
            fish
            python
            toml
            json
            yaml
            diff
            gitcommit
            git_rebase
          ]
        ))
      ];
    };
  };

  # ---------------------------------------------------------------- fonts
  # The terminal font belongs here rather than in environment.systemPackages:
  # fonts.packages is the option that registers a font with fontconfig, while
  # systemPackages only happened to work because NixOS also scans the system
  # profile.
  fonts.packages = with pkgs; [
    # Family names matter here, because alacritty.toml selects by family and
    # style, and one package can register several families.
    tamzenFixed # "Tamzen", the font of Alacritty, foot, waybar, fuzzel, mako
    # and swaylock: bitmap, Regular and Bold at 9 and 12-16 and 20px, as both
    # PCF and OTB (the only bitmap format Pango, and so waybar, still loads).
    # The OTB advances are corrected, see tamzenFixed above. Also registers
    # "TamzenForPowerline", not in use.
    cozette # "Cozette", the Alacritty font before that: bitmap, 13px
    # ("Medium") and 26px ("HiDpi") only, no bold. Also registers the scalable
    # "CozetteVector", which is a different family and is not in use.
    jetbrains-mono # "JetBrains Mono", a previous Alacritty and foot font,
    # kept as a scalable option. Ships both OTF (CFF) and TTF builds. Has no
    # braille or check marks, so those fall back.
    terminus_font_ttf # "Terminus (TTF)", the Alacritty font before that
    terminus_font # Terminus bitmap (PCF/OTB) variants, 12px to 32px
  ];

  # ---------------------------------------------------------------- packages
  environment.systemPackages = with pkgs; [
    alacrittyWrapped
    micro
    wget
    git
    gh # GitHub CLI; ships its own fish completions
    jq
    weechat
    fortune # fish greeting
    cowsay # fish greeting
    libnotify # notify-send, used by weechat/python/notify_send.py
    wl-clipboard # wl-copy/wl-paste; backs tmux's copy-command above
    ripgrep # rg, for snacks' and Claude's searches
    fd
    nixd # Nix language server, enabled in nvim.lua
    nixfmt # what nixd formats with, on save in Neovim
    lua-language-server # lua_ls, enabled in nvim.lua
  ];
}
