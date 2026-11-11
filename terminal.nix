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

  # Bitmap fonts with exact advance widths in their OTB files, which Pango
  # (waybar, mako) otherwise spaces too wide: Tamzen by 1 px per glyph,
  # Cozette by half a pixel, rounded unevenly. bitmap-otb-advance.py has the
  # why; it reads each glyph's width from its own bitmap. postFixup rather
  # than postInstall: Tamzen's own installPhase does not run the install
  # hooks. Only the OTBs change; the PCF, BDF and vector files are untouched.
  fixOtbAdvances =
    pkg:
    pkg.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        (pkgs.python3.withPackages (ps: [ ps.fonttools ]))
      ];
      postFixup = (old.postFixup or "") + ''
        python3 ${./bitmap-otb-advance.py} "$out"/share/fonts/misc/*.otb
      '';
    });
  tamzenFixed = fixOtbAdvances pkgs.tamzen;
  cozetteFixed = fixOtbAdvances pkgs.cozette;
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

      # Color theme. Ported from conf.d/fish_frozen_theme.fish, whose hex
      # values (990000 comments, ff0000 errors, 00a6b2 escapes, B3A06D pager
      # descriptions) belonged to no palette; the roles the theme named are
      # kept, the colours are "Ayu Classic OLED" like everything else.
      # Applied after fish picks its default theme, so these win.
      #
      # ANSI names are left wherever the slot itself is the right answer:
      # fish then draws whatever palette the terminal is on, which keeps the
      # prompt correct in the TTY as well, where truecolour is ignored. Hex is
      # used only where the theme has a value that is not an ANSI slot -- the
      # greys, the amber and the syntax hues -- and each one is followed by a
      # named fallback, fish's second-argument form, for the 16-colour case.
      set --global fish_color_autosuggestion 626a73 brblack # the UI grey
      set --global fish_color_cancel -r
      set --global fish_color_command green
      set --global fish_color_comment 626a73 brblack # syntax.comment
      set --global fish_color_cwd brblack
      set --global fish_color_cwd_root red
      set --global fish_color_end green
      set --global fish_color_error d95757 red # the theme's `error`
      set --global fish_color_escape 95e6cb brcyan # syntax.string.escape
      set --global fish_color_history_current --bold
      set --global fish_color_host normal
      set --global fish_color_host_remote yellow
      set --global fish_color_operator d9a97a yellow # syntax.operator
      set --global fish_color_normal normal
      set --global fish_color_param green
      set --global fish_color_quote aad94c green # syntax.string
      set --global fish_color_redirection 59c2ff blue # the bright blue
      # Black on the amber, as in foot's search box, fuzzel's matches and the
      # theme's own active match; the selection grey is foot's selection.
      set --global fish_color_search_match black --background=e6b450
      set --global fish_color_selection d9d7d0 --bold --background=152e3d
      set --global fish_color_status red
      set --global fish_color_user blue
      set --global fish_color_valid_path --underline
      set --global fish_pager_color_completion
      set --global fish_pager_color_description 707a8c brblack # text.muted
      set --global fish_pager_color_prefix normal --bold --underline
      # The strip grey, so the pager's progress line reads like every other
      # bar in the session.
      set --global fish_pager_color_progress d9d7d0 --background=1b1f29
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

    # No plugins (and so no TPM, which could not write into the read-only Nix
    # store anyway): the battery indicator, the one plugin this used, is
    # waybar's job now.
    extraConfig = ''
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
      # The bar grey is #1b1f29, the palette's strip grey, shared with
      # weechat's title and status bars and with Neovim's statusline.
      # It is written as a hex here rather than as colour235: tmux takes
      # 24-bit values (RGB is on for foot in terminal-features above), so the
      # bar does not depend on what palette entry 235 happens to hold. weechat
      # cannot do that -- weechat.conf only takes palette indices -- which is
      # why colors-dark below redefines 235 to the same value. The foreground
      # colours are ANSI slots and follow foot's palette on their own.
      set -g status-position bottom
      set -g status-justify centre
      set -g status-style 'bg=#282726 fg=colour7'
      # Only the window list: the time is in waybar, the date in its tooltip.
      set -g status-left ""
      set -g status-right ""

      setw -g window-status-current-style 'fg=colour7 bg=#282726'
      setw -g window-status-current-format '#[fg=colour4]> #[fg=colour7]#W#[fg=colour7]'

      setw -g window-status-style 'fg=colour7 bg=#282726'
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
  # A port of alacritty.toml to foot, font included, colours now included
  # too: both terminals are on Zed's "Ayu Classic OLED", and this block is the
  # reference copy of it -- alacritty.toml's [colors] follows from here, the
  # direction having reversed when the palette changed. See colors-dark.
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
        # A JetBrains Mono setup with macOS-like rendering (9 pt, CFF build,
        # stem darkening, no gamma-correct blending) is in commit f781361.
        font = "Tamzen:pixelsize=15";

        # Alacritty's draw_bold_text_with_bright_colors: bold regular colours
        # switch to their bright palette entry. Under Noir Essence Dark that
        # only ever changed black; the Ayu Classic values below, like the
        # Flexoki steps before them, are measurably lighter in bright than in
        # regular in all eight slots, so bold shifts colour throughout.
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

      # Zed's "Ayu Classic OLED" (zed-extensions/ayu, themes/ayu.json), the
      # theme the editor is set to, ported slot for slot from the theme's own
      # terminal.ansi.* keys.
      #
      # Note this is not ayu-vim's original dark, which this config was on
      # until the move (red #ff3333, green #b8cc52): the Zed theme follows the
      # newer ayu-colors (red #ea6c73, green #91b362) -- softer, and uniformly
      # higher contrast on black, nothing in the regular half falling below
      # 6.89:1 against the 4.85:1 floor of the Flexoki port in between.
      # Everything else has since followed this block, so it is the one place
      # the palette is defined.
      #
      # The OLED variant specifies pure black for the background, so the
      # override every theme before it needed here is gone. regular0 still
      # follows the background instead of taking the theme's own ansi black
      # (#01060e, a 1.03:1 glow), so a black cell cannot be told from an empty
      # one.
      #
      # Roles foot has and a Zed theme does not are derived from the nearest
      # key it does define, named per line below. ayu's amber accent (#e6b450,
      # the theme's focus rings and active search match) does the work the
      # Flexoki port had to spend yellow-400 on, Flexoki declaring no single
      # accent.
      colors-dark = {
        background = "000000"; # the theme's own value, this being the OLED cut
        foreground = "d9d7d0";
        # Black on the accent, as the pre-Flexoki ayu config had it: it keeps
        # the character under the block readable, which cursor == foreground
        # would not.
        cursor = "000000 e6b450"; # text, then cursor
        # foot has no CellForeground; the default foreground is what nearly
        # every selected cell would show anyway.
        selection-foreground = "d9d7d0";
        # Zed states the selection as players[0].selection, #59c2ff at 24%
        # alpha; foot wants an opaque colour, so this is that blend on black.
        selection-background = "152e3d";
        jump-labels = "000000 e6b450";
        search-box-match = "000000 e6b450"; # search.active_match_background
        search-box-no-match = "000000 d95757"; # the theme's `error`
        # A strip grey one step off black, shared with the weechat bars below:
        # the theme's own surfaces (#050608) sit too close to the background
        # to read as a panel at all. #1b1f29 is its hidden/ignored border,
        # the darkest tone it draws that is still visible on black.
        scrollback-indicator = "d9d7d0 1b1f29";
        urls = "59c2ff"; # link_text.hover

        # weechat draws its title and status bars on palette entry 235
        # (weechat.conf's status.color_bg and title.color_bg), and weechat
        # takes an index, not a hex -- so the only way to move that grey off
        # the xterm default of #262626 is to redefine the entry here.
        # darkblue.micro reads the same entry, for micro's cursor-line,
        # color-column and inactive statusline, so both move together. The
        # strip grey above replaces it, slightly darker and ayu-tinted. 235
        # sits in the 232..255 greyscale ramp; any program walking that ramp
        # sees this one step shifted. waybar and mako still draw their own
        # bars on Flexoki's base-900 (#282726, desktop.nix), so the greys no
        # longer agree to the byte; both are near-neutral at that lightness,
        # and setting this back to 282726 makes them identical again.
        "235" = "1b1f29";

        regular0 = "000000"; # the background; the theme's ansi black is 01060e
        regular1 = "ea6c73";
        regular2 = "91b362";
        regular3 = "f9af4f"; # ayu's yellow is an orange
        regular4 = "53bdfa";
        regular5 = "d2a6ff"; # and its magenta a violet
        regular6 = "90e1c6";
        regular7 = "c7c7c7";
        bright0 = "686868"; # 3.77:1, so bold black is visible at all
        bright1 = "f07178";
        bright2 = "c2d94c";
        bright3 = "e8c783";
        bright4 = "59c2ff";
        bright5 = "ddbcff";
        bright6 = "95e6cb";
        bright7 = "ffffff";

        # SGR 2 (faint). Unset, foot blends the current colour towards black
        # by dim-amount; the theme declares a terminal.ansi.dim_* set of its
        # own, so the faint half comes from the palette instead. These only
        # apply to text already on a regularN colour, which is where dim text
        # lands in practice. dim0 is lighter than regular0 rather than darker,
        # black having nothing left to dim towards.
        dim0 = "30343d";
        dim1 = "ad5c62";
        dim2 = "6e9430";
        dim3 = "b38133";
        dim4 = "3f8ac6";
        dim5 = "926cb8";
        dim6 = "6ea897";
        dim7 = "8f908b";
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
        # The Ayu Classic port, as a one-file plugin providing
        # :colorscheme ayu_classic. nvim.lua selects it; it is the palette
        # both terminals, Zed and the session chrome are on, so Neovim matches
        # whatever it is running inside. The only colorscheme installed: the
        # ports of the themes before it (flexoki, ayu_dark, noir_essence) were
        # kept for comparison until the whole config was on one palette, and
        # were deleted once it was. They are in the history of this file.
        (pkgs.linkFarm "ayu-classic-nvim" [
          {
            name = "colors/ayu_classic.lua";
            path = ./ayu_classic.lua;
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
    tamzenFixed # "Tamzen", the font of Alacritty, foot, waybar, fuzzel and
    # swaylock: bitmap, Regular and Bold at 9 and 12-16 and 20px, as both PCF
    # and OTB (the only bitmap format Pango, and so waybar, still loads).
    # The OTB advances are corrected, see tamzenFixed above. Also registers
    # "TamzenForPowerline", not in use.
    cozetteFixed # "Cozette", the Alacritty font before that: bitmap, 13px
    # ("Medium") and 26px ("HiDpi") only, no bold. Not in use. The OTB
    # advances are corrected, as for Tamzen. Also registers the scalable
    # "CozetteVector", which is a different family and is not in use.
    jetbrains-mono # "JetBrains Mono", the font of mako (and a previous
    # Alacritty and foot one). Ships both OTF (CFF) and TTF
    # builds; fontconfig prefers the OTF one. Has box drawing and the classic
    # powerline arrows, but no Nerd Font icons, braille or heavy check mark,
    # so those fall back.
    nerd-fonts.jetbrains-mono # The same font patched with the Nerd Font
    # icons, registered as three separate families: "JetBrainsMono Nerd
    # Font", "... Nerd Font Mono" (icons forced to one cell) and "... Nerd
    # Font Propo" (proportional). Not selected directly: the fontconfig rule
    # below puts it right behind JetBrains Mono, so the icon glyphs JetBrains
    # Mono lacks come from it when falling back. It ships TTF only, which is why the primary font stays the plain
    # OTF build -- FreeType's stem darkening, the macOS-like weight, applies
    # to CFF outlines only.
    terminus_font_ttf # "Terminus (TTF)", the Alacritty font before that
    terminus_font # Terminus bitmap (PCF/OTB) variants, 12px to 32px
  ];

  # Icon fallback for JetBrains Mono. Without this rule fontconfig falls back
  # through its generic sans-serif list, none of which has the icons, and
  # then takes whichever installed font happens to rank best: tested against
  # this config, that was the Nerd Font's NL variant for most icons but
  # Adwaita Mono for the rounded powerline caps -- and CozetteVector, a
  # pixel-style face that has the icons too, is one ranking away. Appending
  # the Nerd Font right after "JetBrains Mono" in every pattern that asks for
  # it makes it the first font tried for any glyph JetBrains Mono lacks, in
  # mako and anywhere else it is used. "binding=strong" ranks it like the
  # requested family itself, above the generic fallbacks; text itself still
  # resolves to the plain OTF build.
  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="pattern">
        <test qual="any" name="family"><string>JetBrains Mono</string></test>
        <edit name="family" mode="append" binding="strong">
          <string>JetBrainsMono Nerd Font</string>
        </edit>
      </match>
    </fontconfig>
  '';

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
