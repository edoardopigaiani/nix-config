# Port of the Fedora configuration for tmux, fish and the terminal, which
# was Alacritty there and is foot here.
# Import it from configuration.nix, which today imports:
#   imports = [
#     ./hardware-configuration.nix ./terminal.nix ./nix-builds.nix ./desktop.nix
#   ];
#
# weechat is deliberately not managed here: it rewrites its own config files at
# runtime and irc.conf holds credentials, so it stays as mutable files under
# ~/.config/weechat and ~/.local/share/weechat.

{ config, pkgs, ... }:

let
  # Stem darkening for foot, which is the macOS-like weight: FreeType leaves it
  # off for CFF fonts, and turning it on thickens strokes the way macOS does.
  # The font line in programs.foot below pins JetBrains Mono's OTF build, and
  # CFF outlines are the only kind FreeType darkens. foot's own manual names
  # this env var as the way to get it, having no option of its own. symlinkJoin
  # wraps the cached binary instead of rebuilding it, and the desktop entry's
  # Exec=foot resolves to the wrapper through PATH. It is set on the terminal
  # and the session chrome alone, so GTK applications keep their rendering.
  #
  # This block is the reference copy of the curve: waybar, mako and swaylock
  # set the identical string in desktop.nix, and the four have to agree or the
  # bar and the notifications come out at a different weight from the terminal
  # under them. darkening-parameters goes further than a bare
  # no-stem-darkening=0, because FreeType's default curve is deliberately
  # conservative and macOS pushes harder. The four pairs are (stem width,
  # darkening amount), both in 1/1000 em, interpolated between and tapering to
  # nothing for wide stems; the default is 500,400,1000,275,1667,275,2333,0,
  # and this lifts only the thin-stem end to 500, the ceiling.
  #
  # Two things measured rather than assumed, rendering the alphanumerics
  # through FreeType 2.14.3 and summing coverage:
  #   - 500 really is the ceiling. At 550 FreeType rejects the whole property
  #     and silently falls back to its default curve -- same ink as if the
  #     line were not here -- so a typo upward fails quietly, not loudly.
  #   - The taper is why the curve is not simply flat at 500. Flat gives more
  #     weight at 12 px (445049 ink against 410576) but also +22% at 24 px,
  #     so zooming in with Ctrl+plus would turn text blobby. Tapered, 24 px
  #     comes out at 1216551 against the default's 1216493: unchanged where
  #     it should be, +8% at the size actually in use.
  # Dropping the thin-stem 500 back to 400 restores stock FreeType weight.
  footWrapped = pkgs.symlinkJoin {
    name = "foot-${pkgs.foot.version}";
    paths = [ pkgs.foot ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/foot \
        --set FREETYPE_PROPERTIES \
          "cff:no-stem-darkening=0 cff:darkening-parameters=500,500,1000,400,1667,300,2333,0"
    '';
  };

  # ----------------------------------------------------------- Zed's theme
  # "Noir Essence Dark" for Zed, the last thing in the session that was on a
  # palette of its own. It is ported from the same place everything else is:
  # the VS Code theme's own keys, with foot's colors-dark below as the
  # reference copy, so Zed's editor, its integrated terminal and the foot
  # window next to it are finally one set of colours.
  #
  # Written as Nix rather than as a JSON file for the reason the waybar
  # config in desktop.nix gives: JSON has no syntax Nix would corrupt, and
  # unlike KDL or CSS it has no comments either -- so a hand-written theme
  # would be 170 opaque hex values. Here the palette is named once and every
  # assignment can say which role it serves. pkgs.formats.json turns it back
  # into the file Zed reads.
  #
  # Zed only loads user themes from ~/.config/zed/themes, a path neither /etc
  # nor a flag can reach, so it is linked there with systemd.tmpfiles -- the
  # mechanism micro's colorscheme and mako's config already use. The link is
  # forced on every rebuild, so edit this block and not the file under
  # ~/.config.
  #
  # Selecting it is left to Zed, which keeps the choice in its own mutable
  # settings.json, exactly as micro does. That file is deliberately not
  # managed here: Zed rewrites it whenever a setting changes in the UI.
  zedPalette = {
    # The two backgrounds. black is what foot was asked for and what the
    # editor draws on; strip is editorWidget.background, the one step off
    # black every bar in the session is already on -- waybar, mako, tmux,
    # weechat, Neovim's statusline -- and here it is Zed's status bar and its
    # popups.
    black = "#000000";
    strip = "#161819";

    fg = "#f7f3ea"; # editor.foreground
    muted = "#908e89"; # statusBar.foreground, flattened; dimmed UI text
    dim = "#3e3d3b"; # tab.inactiveForeground, flattened; disabled text
    comment = "#51504d";
    lineNr = "#2e2e2c"; # editorLineNumber.foreground, flattened
    indent = "#1b1b1a"; # editorIndentGuide.background, flattened
    lineHl = "#0a0a0a"; # editor.lineHighlightBackground, flattened

    selection = "#2b2d2d"; # editor.selectionBackground, and the ansi black
    widgetSel = "#1f2121"; # editorSuggestWidget.selectedBackground
    brightBlack = "#434545"; # terminal.ansiBrightBlack: hairlines, scrollbar
    split = "#444444"; # editorGroup.border, the pane divider

    # The hues, named by what the theme calls them rather than by ANSI slot,
    # which is why yellow and orange are two colours here while foot's
    # palette has to put the orange in its yellow slot.
    red = "#ea6962";
    orange = "#e78a4e";
    yellow = "#e7b24e";
    string = "#98c379";
    lime = "#a9b665"; # the accent: the cursor, and foot's ansi cyan
    green = "#89b482"; # terminal.ansiGreen
    blue = "#7daea3"; # operators, escapes, and textLink.foreground
    func = "#7d97ae"; # function names
    purple = "#d3869b";
    warn = "#eac262"; # editorWarning.foreground, without its alpha
    info = "#658ecd"; # editorInfo.foreground, without its alpha

    findMatch = "#4d2e1a"; # editor.findMatchHighlightBackground, flattened
    wordHl = "#3f3f3f"; # editor.wordHighlightBackground, flattened
    wordHlStrong = "#363938"; # editor.wordHighlightStrongBackground
    gutterAdd = "#a8b665"; # editorGutter.addedBackground, a hair off the lime
    diffAdd = "#222414";
    diffDelete = "#2f1514";
    diffChange = "#192321";
    transparent = "#00000000";
  };

  zedTheme =
    let
      p = zedPalette;
      # Zed wants every syntax entry to carry all four fields.
      syn = color: {
        inherit color;
        background_color = null;
        font_style = null;
        font_weight = null;
      };
      synItalic = color: (syn color) // { font_style = "italic"; };
      synBold = color: (syn color) // { font_weight = 700; };
      # A collaboration cursor and the selection it drags behind it, at the
      # 0x40 alpha Zed's own themes use.
      player = color: {
        cursor = color;
        selection = "${color}40";
      };
    in
    (pkgs.formats.json { }).generate "noir-essence-zed.json" {
      "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
      name = "Noir Essence Dark";
      author = "ported from u1145h.u1145h-heme-ark for this configuration";
      themes = [
        {
          name = "Noir Essence Dark";
          appearance = "dark";
          style = {
            # --------------------------------------------------- surfaces
            # The editor is black and the chrome is the strip grey, which is
            # the division the rest of the session already draws: a bar is
            # #161819 and the text under it is black. Tabs are the exception
            # and stay on the editor background, as they do in VS Code and in
            # Neovim's tabline.
            background = p.black;
            "editor.background" = p.black;
            "editor.gutter.background" = p.black;
            "toolbar.background" = p.black;
            "tab_bar.background" = p.black;
            "tab.active_background" = p.black;
            "tab.inactive_background" = p.black;
            "status_bar.background" = p.strip;
            "title_bar.background" = p.strip;
            "surface.background" = p.strip;
            "elevated_surface.background" = p.strip;
            # The file tree is black rather than the panel grey, so it reads
            # as part of the editor -- the same call noir_essence.lua makes
            # for the snacks explorer, overriding snacks' own widget grey.
            "panel.background" = p.black;
            "editor.subheader.background" = p.strip;

            # ---------------------------------------------------- borders
            border = p.split;
            "border.variant" = p.selection;
            "border.focused" = p.blue;
            "border.selected" = p.brightBlack;
            "border.transparent" = p.transparent;
            "border.disabled" = p.selection;
            "panel.focused_border" = p.blue;
            "pane.focused_border" = p.blue;

            # --------------------------------------------------- elements
            "element.background" = p.strip;
            "element.hover" = p.widgetSel;
            "element.active" = p.selection;
            "element.selected" = p.selection;
            "element.disabled" = p.strip;
            "ghost_element.background" = p.transparent;
            "ghost_element.hover" = p.widgetSel;
            "ghost_element.active" = p.selection;
            "ghost_element.selected" = p.selection;
            "ghost_element.disabled" = p.transparent;
            "drop_target.background" = "${p.selection}80";

            # ------------------------------------------------ text, icons
            text = p.fg;
            "text.muted" = p.muted;
            "text.placeholder" = p.comment;
            "text.disabled" = p.dim;
            "text.accent" = p.blue;
            icon = p.fg;
            "icon.muted" = p.muted;
            "icon.placeholder" = p.comment;
            "icon.disabled" = p.dim;
            "icon.accent" = p.blue;
            "link_text.hover" = p.blue;

            # ----------------------------------------------------- editor
            "editor.foreground" = p.fg;
            "editor.active_line.background" = p.lineHl;
            "editor.highlighted_line.background" = p.widgetSel;
            "editor.line_number" = p.lineNr;
            "editor.active_line_number" = p.fg;
            # The theme's editorWhitespace.foreground, which is the lime --
            # loud for an invisible, but it is what Neovim's listchars are
            # drawn in too, so the two agree.
            "editor.invisible" = p.lime;
            "editor.wrap_guide" = p.indent;
            "editor.active_wrap_guide" = p.selection;
            "editor.indent_guide" = p.indent;
            "editor.indent_guide_active" = p.dim;
            "editor.document_highlight.read_background" = p.wordHl;
            "editor.document_highlight.write_background" = p.wordHlStrong;
            "editor.document_highlight.bracket_background" = p.selection;
            "search.match_background" = p.findMatch;

            # -------------------------------------------------- scrollbar
            "scrollbar.thumb.background" = "${p.brightBlack}80";
            "scrollbar.thumb.hover_background" = p.brightBlack;
            "scrollbar.thumb.border" = p.transparent;
            "scrollbar.track.background" = p.transparent;
            "scrollbar.track.border" = p.transparent;

            # --------------------------------------------------- terminal
            # foot's regular0-7 and bright0-7 verbatim, so a shell inside Zed
            # looks like the shell outside it. Note the slots the theme fills
            # oddly: ansi yellow is the orange and ansi cyan is the lime,
            # exactly as colors-dark below has them.
            #
            # The dim_* slots repeat their regular values. foot has no dim
            # block at all -- the theme names no faint half, and writing one
            # would mean inventing colours it does not have -- but Zed has
            # the keys and would fill them itself, so they are pinned to the
            # value they are dimming instead.
            "terminal.background" = p.black;
            "terminal.foreground" = p.fg;
            "terminal.bright_foreground" = p.fg;
            "terminal.dim_foreground" = p.muted;
            "terminal.ansi.black" = p.black;
            "terminal.ansi.bright_black" = p.brightBlack;
            "terminal.ansi.dim_black" = p.black;
            "terminal.ansi.red" = p.red;
            "terminal.ansi.bright_red" = p.red;
            "terminal.ansi.dim_red" = p.red;
            "terminal.ansi.green" = p.green;
            "terminal.ansi.bright_green" = p.green;
            "terminal.ansi.dim_green" = p.green;
            "terminal.ansi.yellow" = p.orange;
            "terminal.ansi.bright_yellow" = p.orange;
            "terminal.ansi.dim_yellow" = p.orange;
            "terminal.ansi.blue" = p.blue;
            "terminal.ansi.bright_blue" = p.blue;
            "terminal.ansi.dim_blue" = p.blue;
            "terminal.ansi.magenta" = p.purple;
            "terminal.ansi.bright_magenta" = p.purple;
            "terminal.ansi.dim_magenta" = p.purple;
            "terminal.ansi.cyan" = p.lime;
            "terminal.ansi.bright_cyan" = p.lime;
            "terminal.ansi.dim_cyan" = p.lime;
            "terminal.ansi.white" = p.fg;
            "terminal.ansi.bright_white" = p.fg;
            "terminal.ansi.dim_white" = p.fg;

            # ----------------------------------------- status and version
            # The backgrounds are the theme's own diff fills where it has
            # them and the strip grey where it does not, rather than an
            # invented tint per state.
            error = p.red;
            "error.background" = p.diffDelete;
            "error.border" = p.red;
            warning = p.warn;
            "warning.background" = p.strip;
            "warning.border" = p.warn;
            info = p.info;
            "info.background" = p.strip;
            "info.border" = p.info;
            hint = p.blue;
            "hint.background" = p.strip;
            "hint.border" = p.blue;
            success = p.green;
            "success.background" = p.diffAdd;
            "success.border" = p.green;
            created = p.gutterAdd;
            "created.background" = p.diffAdd;
            "created.border" = p.gutterAdd;
            deleted = p.red;
            "deleted.background" = p.diffDelete;
            "deleted.border" = p.red;
            modified = p.blue;
            "modified.background" = p.diffChange;
            "modified.border" = p.blue;
            renamed = p.yellow;
            "renamed.background" = p.strip;
            "renamed.border" = p.yellow;
            conflict = p.purple;
            "conflict.background" = p.strip;
            "conflict.border" = p.purple;
            ignored = p.comment;
            "ignored.background" = p.transparent;
            "ignored.border" = p.comment;
            hidden = p.dim;
            "hidden.background" = p.transparent;
            "hidden.border" = p.dim;
            predictive = p.comment;
            "predictive.background" = p.transparent;
            "predictive.border" = p.comment;
            unreachable = p.muted;
            "unreachable.background" = p.transparent;
            "unreachable.border" = p.muted;

            # ---------------------------------------------------- players
            # Collaboration cursors. The first is the theme's accent, the
            # colour the terminal cursor is drawn in; the rest walk the
            # palette's hues so two people are never the same colour.
            players = map player [
              p.lime
              p.blue
              p.purple
              p.orange
              p.red
              p.green
              p.yellow
              p.func
            ];

            # ----------------------------------------------------- syntax
            # The group-for-group counterpart of noir_essence.lua: the same
            # tokenColors assignments, named for Zed's capture names rather
            # than treesitter's.
            syntax = {
              attribute = syn p.yellow; # storage.type.annotation
              boolean = syn p.orange;
              comment = synItalic p.comment;
              "comment.doc" = synItalic p.comment;
              constant = syn p.yellow; # variable.other.constant
              constructor = syn p.yellow; # entity.name.class
              emphasis = synItalic p.purple;
              "emphasis.strong" = synBold p.orange;
              enum = syn p.yellow; # the type itself
              variant = syn p.blue; # its members, per semanticTokenColors
              function = syn p.func;
              hint = syn p.comment; # inlay hints
              keyword = syn p.purple;
              label = syn p.purple;
              link_text = syn p.func;
              link_uri = synItalic p.purple;
              number = syn p.orange;
              operator = syn p.blue;
              predictive = syn p.comment;
              preproc = syn p.purple;
              primary = syn p.fg;
              property = syn p.red; # meta.object-literal.key
              punctuation = syn p.fg;
              "punctuation.bracket" = syn p.fg;
              "punctuation.delimiter" = syn p.fg;
              "punctuation.list_marker" = syn p.red;
              "punctuation.special" = syn p.purple;
              string = syn p.string;
              "string.escape" = syn p.blue;
              "string.regex" = syn p.blue;
              "string.special" = syn p.blue;
              "string.special.symbol" = syn p.blue;
              tag = syn p.red; # entity.name.tag
              "tag.doctype" = syn p.purple;
              "text.literal" = syn p.string;
              title = synBold p.red;
              type = syn p.yellow;
              variable = syn p.red;
              "variable.special" = syn p.yellow; # variable.language
            };
          };
        }
      ];
    };

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
      # kept, the colours are "Noir Essence Dark", and foot's colors-dark
      # below is the reference copy.
      # Applied after fish picks its default theme, so these win.
      #
      # ANSI names are left wherever the slot itself is the right answer:
      # fish then draws whatever palette the terminal is on, which keeps the
      # prompt correct in the TTY as well, where truecolour is ignored. This
      # palette answers more of these roles with a plain slot than the ones
      # before it did -- its operators, escapes and redirections are all the
      # ansi blue -- so hex is left only where the theme names a colour that
      # is not an ANSI one: the two greys, the comment grey and the string
      # green it uses instead of the ansi green. Each is followed by a named
      # fallback, fish's second-argument form, for the 16-colour case.
      set --global fish_color_autosuggestion 51504d brblack # the comment grey
      set --global fish_color_cancel -r
      set --global fish_color_command green
      set --global fish_color_comment 51504d brblack # the theme's comment grey, italic there
      set --global fish_color_cwd brblack
      set --global fish_color_cwd_root red
      set --global fish_color_end green
      set --global fish_color_error red # the ansi red, which is the theme's error
      set --global fish_color_escape blue # constant.character.escape is the ansi blue
      set --global fish_color_history_current --bold
      set --global fish_color_host normal
      set --global fish_color_host_remote yellow
      set --global fish_color_operator blue # keyword.operator, the ansi blue again
      set --global fish_color_normal normal
      set --global fish_color_param green
      set --global fish_color_quote 98c379 green # the theme's string green, not its ansi one
      set --global fish_color_redirection blue
      # Black on the orange, as in foot's search box, fuzzel's matches and the
      # theme's own search highlight; the selection grey is foot's selection.
      set --global fish_color_search_match black --background=e78a4e
      set --global fish_color_selection f7f3ea --bold --background=2b2d2d
      set --global fish_color_status red
      set --global fish_color_user blue
      set --global fish_color_valid_path --underline
      set --global fish_pager_color_completion
      set --global fish_pager_color_description 908e89 brblack # statusBar.foreground, flattened
      set --global fish_pager_color_prefix normal --bold --underline
      # The strip grey, so the pager's progress line reads like every other
      # bar in the session.
      set --global fish_pager_color_progress f7f3ea --background=161819
      set --global fish_pager_color_selected_background -r
    '';
  };

  users.users."edo".shell = pkgs.fish;

  # -------------------------------------------------------------- direnv
  # Per-directory environments: on every cd, direnv looks for an .envrc and
  # loads what it declares, unloading it again on the way out. For a project
  # with a flake that file is one line, `use flake`, and entering the
  # directory then puts its devshell on PATH -- so a project's toolchain
  # never has to be installed system-wide to be usable.
  #
  # One line covers it: the module's nix-direnv and enableFishIntegration
  # options both default to true, so there is nothing to add for either.
  # nix-direnv is the part that makes this worth having -- plain direnv would
  # re-run `nix develop` on every entry, and the result would be
  # garbage-collectable, so `nh os clean` would make the next entry recompile.
  # It caches the environment and keeps a gc root on it instead, which both
  # makes re-entry instant and protects it from the weekly clean in
  # configuration.nix.
  #
  # An .envrc is a shell script that runs on cd, so direnv refuses to load
  # one until `direnv allow` has been run in that directory, and again after
  # every edit. A freshly cloned repo saying ".envrc is blocked" is that
  # working as intended, not a fault.
  #
  # Logging is left on (the module's `silent` default): the "direnv: loading"
  # line is how you know which environment you are in.
  programs.direnv.enable = true;

  # -------------------------------------------------------------- zoxide
  # `z <fragment>` jumps to the directory matching it that has been visited
  # most often and most recently, so `z nix` reaches this repository from
  # anywhere. Fish integration is on by default, as with direnv.
  #
  # It does not replace cd: the module leaves plain cd alone, and fish's own
  # Alt+Up directory history still works. This is the shortcut for the three
  # or four trees actually worked in, which is also why it earns less here
  # than direnv does.
  programs.zoxide.enable = true;

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
      # Without this the bar's hex colours below are quantised to the
      # 256-colour cube: tmux's own terminal is xterm-256color, which it does
      # not credit with RGB on its own.
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
      # The bar grey is #161819, the palette's strip grey
      # (editorWidget.background, what the theme draws its panels on), shared
      # with weechat's title and status bars, Neovim's statusline, micro's
      # inactive one and -- outside the terminal -- waybar, mako and
      # swaylock. Every strip in the session is on it.
      # It is written as a hex here rather than as colour235: tmux takes
      # 24-bit values (RGB is on for foot in terminal-features above), so the
      # bar does not depend on what palette entry 235 happens to hold. weechat
      # cannot do that -- weechat.conf only takes palette indices -- which is
      # why colors-dark below redefines 235, to this same value. The
      # foreground colours are ANSI slots and follow foot's palette on their
      # own.
      set -g status-position bottom
      set -g status-justify centre
      set -g status-style 'bg=#161819 fg=colour7'
      # Only the window list: the time is in waybar, the date in its tooltip.
      set -g status-left ""
      set -g status-right ""

      setw -g window-status-current-style 'fg=colour7 bg=#161819'
      setw -g window-status-current-format '#[fg=colour4]> #[fg=colour7]#W#[fg=colour7]'

      setw -g window-status-style 'fg=colour7 bg=#161819'
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

  # ------------------------------------------------------------------ foot
  # The terminal, and the reference copy of the whole look: the font and the
  # FreeType settings that put it as close to macOS as FreeType gets, and the
  # palette, which is "Noir Essence Dark" on a pure black background (see
  # colors-dark). The session chrome, Neovim, weechat and micro all follow
  # this block, and every one of them is on that palette now. It started as a
  # port of the Alacritty config this file carried before it -- Alacritty and
  # ghostty were both kept alongside for a while and are gone now -- which is
  # why the settings below still name the Alacritty keys they came from.
  # The module writes /etc/xdg/foot/foot.ini, which ~/.config/foot/foot.ini
  # overrides. Settings equal to foot's defaults are left out: Ctrl+Shift+C/V,
  # Shift+Insert, Ctrl+0/+/-, Ctrl+Shift+N, Shift+PageUp/Down, middle-click
  # paste, the hollow unfocused cursor and Alacritty's semantic_escape_chars
  # (foot's word-delimiters) all already matched. foot has no live reload; new
  # windows read the file.
  programs.foot = {
    enable = true;
    package = footWrapped;
    settings = {
      main = {
        # JetBrains Mono at 9 pt: foot converts points at 96 DPI and
        # multiplies by the output's scale factor of 1 (dpi-aware = no, its
        # default), so the face is rasterised at 12 px. The cell is 7x16 px,
        # fcft ceiling FreeType's rounded metrics off a 0.6000 em advance and
        # a 1.3200 em hhea line. The Tamzen 8x15 bitmap this config used to be
        # on is gone, along with the other faces tried before it.
        #
        # Two fonts, in fallback order:
        #   - the plain build for text, pinned to the OTF by fontformat=CFF
        #     because stem darkening -- the macOS-like weight footWrapped turns
        #     on -- applies to CFF outlines alone, and the TTF build is
        #     installed alongside it.
        #   - the Nerd Font's "Mono" cut for the icons the plain build lacks,
        #     that being the cut whose icons fit one cell. It ships TTF only,
        #     so those glyphs are not darkened; they are icons rather than
        #     text, so the weight does not read.
        # Naming the Nerd Font outright matters even though fontconfig would
        # find it anyway: foot searches the configured fonts before the dynamic
        # fontconfig list, and that list -- through the localConf rule below --
        # offers the double-width "Nerd Font" cut first. Glyphs neither build
        # has, braille and the heavy check mark among them, come from DejaVu
        # Sans at the end of that list.
        #
        # The rendering options, spelled in fontconfig terms:
        #   - hintstyle=hintnone, since macOS does not hint. This was
        #     hintslight on the belief that FreeType runs stem darkening inside
        #     light hinting and that hintnone would drop the darkening with it.
        #     Measured through FreeType 2.14.3 that does not hold: rasterising
        #     the alphanumerics at this 12 px through the Adobe CFF engine
        #     gives 410576 units of ink unhinted against 409069 under light
        #     hinting -- the darkening intact either way, the two within 0.4%
        #     -- so the hinting buys no weight and can go, and glyphs keep the
        #     shapes they were drawn with rather than having their baselines
        #     and x-heights snapped to the pixel grid. Setting it here as well
        #     as in localConf is deliberate: it keeps the terminal's rendering
        #     readable in one place, and the two agree.
        #   - antialias=true with rgba=none: greyscale antialiasing, no
        #     subpixel colour fringes, which is what macOS has done since
        #     Mojave.
        # Not set, being foot's defaults already: gamma-correct-blending = no,
        # which keeps light-on-black text as full as macOS draws it, and
        # box-drawings-uses-font-glyphs = no, foot drawing the box characters
        # itself.
        #
        # Bold and italic come from the family's own Bold and Italic faces and
        # inherit these options; unlike Tamzen, it has a real italic, so italic
        # text now slants.
        font = "JetBrains Mono:size=9:fontformat=CFF:antialias=true:rgba=none:hintstyle=hintnone, JetBrainsMono Nerd Font Mono:size=9:antialias=true:rgba=none:hintstyle=hintnone";

        # Alacritty's draw_bold_text_with_bright_colors: bold regular colours
        # switch to their bright palette entry. Under this palette that only
        # ever changes black -- the theme gives its bright slots the same
        # values as its regular ones, so there is no second, lighter half to
        # shift into, unlike the gruvbox, Ayu Classic and Flexoki steps
        # before it. Nothing is lost by that: those ports leaned on bold to
        # lift a 3.84:1 red to 6.10:1, while here the darkest colour in the
        # palette already measures 6.70:1 (see colors-dark). It stays on so
        # that bold black still lands on a visible grey rather than on the
        # background.
        bold-text-in-bright = "palette-based";

        # Alacritty sets TERM=xterm-256color; foot's own entry is more
        # accurate, and ncurses ships it.
        term = "foot";

        # window: padding 10x10 with dynamic_padding, maximized, no decorations.
        pad = "10x10 center";
        initial-window-mode = "maximized";
      };

      # Alacritty's bell was silent (duration = 0, and it had no audible bell).
      bell.system = "no";

      scrollback = {
        lines = 10000;
        multiplier = 3;
      };

      cursor.blink = "no";

      # decorations = "None". foot draws its own title bar unless it is told
      # the compositor will; niri does, and niri.kdl asks every client to let
      # it (prefer-no-csd there). This is foot's half of that agreement, and
      # it is why foot and the GTK apps come out with the same chrome. Under
      # GNOME, which had no server-side decorations at all, this line was
      # what kept the title bar off.
      csd.preferred = "none";

      key-bindings = {
        # Alacritty's Shift+Alt+U / Shift+Alt+D, on top of foot's defaults.
        scrollback-up-page = "Shift+Page_Up Shift+KP_Page_Up Mod1+Shift+u";
        scrollback-down-page = "Shift+Page_Down Shift+KP_Page_Down Mod1+Shift+d";
        # Alacritty's URL hint key, kept alongside foot's Ctrl+Shift+O. URL
        # mode opens with xdg-open by default, like the hint did.
        show-urls-launch = "Control+Shift+o Control+Shift+h";
      };

      # "Noir Essence Dark" (u1145h.u1145h-heme-ark, themes/noir_essence_dark.json
      # in the extension), the VS Code theme this machine is set to, ported
      # slot for slot from the theme's own terminal.ansi* keys, with one
      # departure that was asked for: the background and ansi black are pure
      # #000000 rather than the theme's own #111314. Everything that is not a
      # background is the theme's value unchanged.
      #
      # This block is the reference copy of the palette again, and for the
      # first time in three themes the whole session agrees with it:
      # waybar.css, mako.conf, swayosd.css, fuzzel.ini, niri.kdl, swaylock's
      # flags and console.colors in desktop.nix, Neovim's noir_essence.lua,
      # darkblue.micro, the fish hexes above and tmux's bar below are all on
      # these values.
      #
      # Measured on black, which matters because the theme was drawn against
      # its own #111314 and is being used a step darker here:
      #   - nothing in the palette is marginal: 6.70:1 at the floor (red) up
      #     to 18.96:1 (the foreground), with lime 9.57, green 8.91, blue
      #     8.46, orange 8.14 and magenta 7.65. The gruvbox port this
      #     replaces bottomed out at 3.84:1 and needed bold to clear it.
      #   - the two halves are the same colours, the theme naming no separate
      #     bright set, so bold only moves black (see bold-text-in-bright).
      #   - bright black, 2.18:1, is the one value that is not meant as text:
      #     it is the hairline and dimmed-text grey the whole session borders
      #     with.
      #
      # Roles foot has that the theme does not name as a terminal colour are
      # taken from its UI keys, named per line.
      colors-dark = {
        background = "000000"; # asked for; the theme's own bg is 111314
        foreground = "f7f3ea"; # editor.foreground
        # The theme names both halves of the cursor: the lime block is
        # terminalCursor.foreground and the dark teal under it is
        # terminalCursor.background, which holds the character at 4.51:1
        # where cursor == foreground would have hidden it.
        cursor = "334743 a9b665"; # text, then cursor
        # foot has no CellForeground; the default foreground is what nearly
        # every selected cell would show anyway.
        selection-foreground = "f7f3ea";
        selection-background = "2b2d2d"; # editor.selectionBackground; fg on it is 12.51:1
        # Black on the orange, which is the accent the theme highlights
        # matches with (editor.findMatchHighlightBackground is that colour at
        # 0x55): 8.14:1 under the label.
        jump-labels = "000000 e78a4e";
        search-box-match = "000000 e78a4e";
        search-box-no-match = "000000 ea6962"; # the ansi red, the theme's error
        # The strip grey, one step off black: editorWidget.background, what
        # the theme draws its panels and popups on. The theme's own
        # background (#111314) sits at 1.13:1 and barely reads as a panel
        # against black; this one is 1.18:1 and is the value every bar in the
        # session uses.
        scrollback-indicator = "f7f3ea 161819";
        urls = "7daea3"; # the ansi blue, textLink.foreground

        # weechat draws its title and status bars on palette entry 235
        # (weechat.conf's status.color_bg and title.color_bg), and weechat
        # takes an index, not a hex -- so the only way to move that grey off
        # the xterm default of #262626 is to redefine the entry here.
        # darkblue.micro reads the same entry, for micro's cursor-line,
        # color-column and inactive statusline, so both move together. The
        # strip grey above replaces it, and waybar, mako, swaylock, Neovim
        # and tmux's bar are all on that same value, so every strip in the
        # session matches. 235 sits in the 232..255 greyscale ramp; any
        # program walking that ramp sees this one step shifted.
        "235" = "161819";

        regular0 = "000000"; # the background, as asked; the theme's ansi black is 2b2d2d
        regular1 = "ea6962";
        regular2 = "89b482";
        regular3 = "e78a4e"; # an orange in this palette, not a yellow
        regular4 = "7daea3";
        regular5 = "d3869b";
        regular6 = "a9b665"; # the lime, which is also the cursor and the accent
        regular7 = "f7f3ea";
        # The only slot the theme really brightens, terminal.ansiBrightBlack,
        # so bold black is visible at all.
        bright0 = "434545";
        bright1 = "ea6962";
        bright2 = "89b482";
        bright3 = "e78a4e";
        bright4 = "7daea3";
        bright5 = "d3869b";
        bright6 = "a9b665";
        bright7 = "f7f3ea";

        # No dim* block, as in the gruvbox port before this: the theme names
        # no faint half either, so SGR 2 is left to foot, which blends the
        # current colour towards the background by dim-amount. Writing one
        # out would mean inventing colours the theme does not have.
      };
    };
  };

  # ------------------------------------------------------- micro's theme
  # micro only reads user colorschemes from ~/.config/micro/colorschemes, a
  # path neither /etc nor a command-line flag can reach, so the file is linked
  # there -- the mechanism desktop.nix uses for mako, rather than the /etc/xdg
  # one foot gets. Selecting it is left to micro (`set colorscheme darkblue`),
  # which keeps the choice in its own mutable settings.json. The scheme
  # itself needs no porting: it is written entirely in ANSI names, so micro
  # draws whatever colors-dark above holds, and its bars follow along by
  # reading palette entry 235 like weechat.
  # One list for both editors' colorschemes: this is a single module, so the
  # option cannot be defined twice in it. desktop.nix adds mako's link from
  # its side and the definitions merge.
  systemd.tmpfiles.rules =
    let
      microDir = "${config.users.users.edo.home}/.config/micro/colorschemes";
      zedDir = "${config.users.users.edo.home}/.config/zed/themes";
    in
    [
      "d ${microDir} 0755 edo users -"
      "L+ ${microDir}/darkblue.micro - - - - ${./darkblue.micro}"
      # The Zed theme built in the let block above. Zed scans this directory
      # and offers whatever it finds by the "name" inside the file, which is
      # "Noir Essence Dark" -- the file name itself is not what gets picked.
      "d ${zedDir} 0755 edo users -"
      "L+ ${zedDir}/noir-essence.json - - - - ${zedTheme}"
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
        # The Noir Essence Dark port, as a one-file plugin providing
        # :colorscheme noir_essence. nvim.lua selects it; it is the palette
        # colors-dark above and the whole session chrome are on, so Neovim
        # matches the terminal it is running inside. The only colorscheme
        # installed: the ports of the themes before it (flexoki, ayu_dark,
        # ayu_classic) were kept for comparison until the whole config was on
        # one palette, and were deleted once it was. They are in the history
        # of this file -- this very port among them, from the first time the
        # session was on this theme.
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
  # One family, because everything in the session is on it: foot's font line,
  # swayosd.css, waybar.css, mako.conf, fuzzel.ini and swaylock's flags in
  # desktop.nix all name it, and family names are how they select it. The
  # bitmaps tried before it -- Tamzen, Cozette, Terminus -- are gone, with
  # the OTB advance fixup they needed; they are in the history of this file.
  fonts.packages = with pkgs; [
    jetbrains-mono # "JetBrains Mono", the font of foot, waybar, mako,
    # swaylock, fuzzel and swayosd -- the whole session. Ships OTF (CFF) and
    # TTF builds; fontconfig prefers the OTF one, and foot pins it outright
    # with fontformat=CFF, stem darkening applying to CFF alone. Has box
    # drawing and the classic powerline arrows, but no Nerd Font icons,
    # braille or heavy check mark, so those fall back.
    nerd-fonts.jetbrains-mono # The same font patched with the Nerd Font
    # icons, registered as three separate families: "JetBrainsMono Nerd
    # Font", "... Nerd Font Mono" (icons forced to one cell) and "... Nerd
    # Font Propo" (proportional). Reached two ways: foot's font line names the
    # Mono family outright as its second font, foot searching its configured
    # fonts before fontconfig's list, and the rule below puts it right behind
    # JetBrains Mono for everything that does go through fontconfig, mako
    # included. It ships TTF only, which is why the primary font stays the
    # plain OTF build -- FreeType's stem darkening, the macOS-like weight,
    # applies to CFF outlines only.
  ];

  # Icon fallback for JetBrains Mono. Without this rule fontconfig falls back
  # through its generic sans-serif list, none of which has the icons, and
  # then takes whichever installed font happens to rank best: tested against
  # this config, that was the Nerd Font's NL variant for most icons but
  # Adwaita Mono for the rounded powerline caps, and the ranking moves on its
  # own whenever the installed set changes. Appending
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
      <match target="font">
        <test qual="any" name="family"><string>JetBrains Mono</string></test>
        <edit name="hintstyle" mode="assign"><const>hintnone</const></edit>
      </match>
      <match target="font">
        <test qual="any" name="family"><string>JetBrainsMono Nerd Font Mono</string></test>
        <edit name="hintstyle" mode="assign"><const>hintnone</const></edit>
      </match>
    </fontconfig>
  '';

  # The two hintstyle rules above are what put mako and swaylock on the
  # terminal's unhinted rendering, the last thing that still differed. foot
  # does not depend on them: its font line spells hintstyle=hintnone itself,
  # and a target="font" rule like these would win over the pattern in any
  # case -- the two simply agree. Neither of those two links GTK -- both are
  # cairo and FreeType straight onto a layer surface -- so they take hinting
  # from fontconfig, where fonts.fontconfig.hinting.style leaves it at
  # "slight" for everything. The rules are scoped to this one family rather
  # than set globally, which is why they are here and not a change to that
  # option: the Adwaita faces the GTK applications use are meant to stay as
  # GNOME renders them.
  #
  # target="font" and not "pattern", because hintstyle is a property of the
  # face that came back from matching rather than of the request. Both
  # families are listed since the pattern rule above makes the Nerd Font the
  # fallback for this text: without the second rule an icon inside a
  # notification would come out hinted while the words around it did not.
  #
  # waybar and swayosd read the same fontconfig, so they follow along; being
  # GTK their own settings could in principle override, which would only put
  # them back where they already were. foot takes its load flags from
  # fontconfig too, and asks for the same thing on its own font line.

  # ---------------------------------------------------------------- packages
  environment.systemPackages = with pkgs; [
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
    # zoxide shells out to fzf for its interactive mode (`zi`, and `z` with
    # an ambiguous fragment); the plain `z` jump needs nothing. The binary is
    # all that is wanted here: programs.fzf.keybindings is deliberately NOT
    # set, because on fish that option sources fzf_key_bindings, which takes
    # over Ctrl+R and Alt+C -- and fish's own history pager on Ctrl+R is
    # better than fzf's flat list for a shell with autosuggestions. Enable
    # that option if the trade ever looks worth it.
    fzf
    nixd # Nix language server, enabled in nvim.lua
    nixfmt # what nixd formats with, on save in Neovim
    lua-language-server # lua_ls, enabled in nvim.lua
  ];
}
