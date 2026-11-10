-- "Ayu Dark" for Neovim, ported from ayu-vim (ayu-theme/ayu-vim,
-- colors/ayu.vim), the same palette alacritty.toml and foot are set to --
-- ayu's original dark, not the newer one in Shatur/neovim-ayu (bg #0b0e14,
-- fg #bfbdb6), which would not match the terminal. terminal.nix installs this
-- file as colors/ayu_dark.lua, so it is selected with :colorscheme ayu_dark.
--
-- The background is left to the terminal, so Neovim always matches the shell
-- around it; Alacritty and foot set it to pure black, overriding ayu's own
-- #0f1419. ayu-vim's palette has one entry per role rather than per token, so
-- the groups below assign those roles; where ayu-vim is explicit about a group
-- it is followed, and the few places it is not are noted.

vim.cmd("highlight clear")
vim.g.colors_name = "ayu_dark"
vim.o.background = "dark"

local c = {
  bg = "#000000", -- pure black; ayu's own bg is #0f1419
  fg = "#e6e1cf", -- palette.fg
  accent = "#f29718", -- palette.accent: the amber caret, and search matches
  comment = "#5c6773", -- palette.comment
  markup = "#f07178", -- palette.markup: headings, deletions, terminal magenta
  constant = "#ffee99", -- palette.constant: numbers, booleans, constants
  operator = "#e7c547", -- palette.operator, terminal yellow
  tag = "#36a3d9", -- palette.tag: types, tags, terminal blue
  regexp = "#95e6cb", -- palette.regexp: escapes, regex, terminal cyan
  string = "#b8cc52", -- palette.string, terminal green
  func = "#ffb454", -- palette.function
  special = "#e6b673", -- palette.special: preproc, structures
  keyword = "#ff7733", -- palette.keyword
  error = "#ff3333", -- palette.error, terminal red

  panel = "#14191f", -- palette.panel: floats, popup menu
  line = "#151a1e", -- palette.line: the current line, Alacritty's footer bar
  guide = "#2d3640", -- palette.guide: line numbers, indent guides, borders
  selection = "#253340", -- palette.selection, as in alacritty.toml
  fg_idle = "#3e4b59", -- palette.fg_idle: inactive text
  bright_black = "#323232", -- alacritty.toml's bright black, the pmenu thumb

  bar = "#262626", -- xterm-256 colour 235, weechat's and tmux's bar grey
  -- ayu-vim puts DiffAdd/Change/Text on the flat panel grey, which tells the
  -- three apart by foreground only. These are instead ayu's own diff accents
  -- at 0x33 over the black background, since Neovim highlights take no alpha.
  diff_add = "#252910", -- string at 0x33
  diff_delete = "#301718", -- markup at 0x33
  diff_change = "#0b212b", -- tag at 0x33
  diff_text = "#13394c", -- tag at 0x59, to stand out within a changed line
}

local groups = {
  -- ----------------------------------------------------------------- editor
  Normal = { fg = c.fg },
  NormalFloat = { fg = c.fg, bg = c.panel },
  FloatBorder = { fg = c.guide, bg = c.panel },
  FloatTitle = { fg = c.fg, bg = c.panel, bold = true },
  Cursor = { fg = c.bg, bg = c.accent }, -- alacritty.toml's cursor colours
  CursorLine = { bg = c.line },
  CursorColumn = { link = "CursorLine" },
  ColorColumn = { bg = c.line },
  LineNr = { fg = c.guide },
  CursorLineNr = { fg = c.accent },
  SignColumn = {},
  FoldColumn = { fg = c.guide },
  Folded = { fg = c.fg_idle, bg = c.panel },
  Visual = { bg = c.selection },
  -- alacritty.toml's search colours: the grey for other matches, the amber
  -- for the focused one.
  Search = { fg = c.fg, bg = c.comment },
  CurSearch = { fg = c.bg, bg = c.accent },
  IncSearch = { link = "CurSearch" },
  Substitute = { link = "CurSearch" },
  MatchParen = { bg = c.selection, bold = true },
  NonText = { fg = c.guide },
  EndOfBuffer = { fg = c.guide },
  Whitespace = { fg = c.guide },
  SpecialKey = { fg = c.fg_idle },
  Conceal = { fg = c.guide },
  WinSeparator = { fg = c.guide }, -- ayu-vim hides it against the background
  Directory = { fg = c.tag },
  Title = { fg = c.keyword, bold = true },
  QuickFixLine = { bg = c.selection },

  Pmenu = { fg = c.fg, bg = c.panel },
  PmenuSel = { bg = c.selection },
  PmenuMatch = { fg = c.accent, bg = c.panel },
  PmenuMatchSel = { fg = c.accent, bg = c.selection },
  PmenuSbar = { bg = c.panel },
  PmenuThumb = { bg = c.bright_black },
  WildMenu = { link = "PmenuSel" },

  -- Tabs share the editor background. The statusline instead matches
  -- weechat's and tmux's bars (colour 235 with white text), so the terminal
  -- apps share one look; that grey is a cross-app choice, not an ayu value.
  -- Inactive windows keep the same bar with greyer text.
  StatusLine = { fg = c.fg, bg = c.bar },
  StatusLineNC = { fg = c.fg_idle, bg = c.bar },
  TabLine = { fg = c.fg_idle },
  TabLineSel = { fg = c.fg },
  TabLineFill = {},
  WinBar = { fg = c.fg_idle },
  WinBarNC = { fg = c.fg_idle },

  ErrorMsg = { fg = c.error },
  WarningMsg = { fg = c.accent },
  MoreMsg = { fg = c.string },
  Question = { fg = c.string },
  ModeMsg = { fg = c.fg, bold = true },

  SpellBad = { undercurl = true, sp = c.error },
  SpellCap = { undercurl = true, sp = c.tag },
  SpellRare = { undercurl = true, sp = c.regexp },
  SpellLocal = { undercurl = true, sp = c.keyword },

  DiffAdd = { bg = c.diff_add },
  DiffDelete = { fg = c.markup, bg = c.diff_delete },
  DiffChange = { bg = c.diff_change },
  DiffText = { bg = c.diff_text },
  -- gitsigns' sign column, in ayu-vim's GitGutter colours.
  Added = { fg = c.string },
  Changed = { fg = c.tag },
  Removed = { fg = c.markup },

  -- ----------------------------------------------------- legacy syntax groups
  -- Used by filetypes without a treesitter parser; kept in step with the
  -- treesitter section below so both kinds of buffer look the same.
  Comment = { fg = c.comment, italic = true },
  Constant = { fg = c.constant },
  String = { fg = c.string },
  Character = { fg = c.string },
  Number = { fg = c.constant },
  Boolean = { fg = c.constant },
  Float = { fg = c.constant },
  Identifier = { fg = c.fg }, -- ayu-vim uses tag; ayu's own variables are fg
  Function = { fg = c.func },
  Statement = { fg = c.keyword },
  Keyword = { fg = c.keyword },
  Conditional = { fg = c.keyword },
  Repeat = { fg = c.keyword },
  Label = { fg = c.keyword },
  Exception = { fg = c.keyword },
  Operator = { fg = c.operator },
  PreProc = { fg = c.special },
  Include = { fg = c.keyword },
  Define = { fg = c.keyword },
  Macro = { fg = c.special },
  Type = { fg = c.tag },
  StorageClass = { fg = c.keyword },
  Structure = { fg = c.special },
  Typedef = { fg = c.tag },
  Special = { fg = c.special },
  SpecialChar = { fg = c.regexp },
  Tag = { fg = c.tag },
  Delimiter = { fg = c.fg },
  SpecialComment = { fg = c.comment, italic = true },
  Debug = { fg = c.keyword },
  Underlined = { underline = true },
  Error = { fg = c.error },
  Todo = { fg = c.markup, bold = true }, -- ayu-vim's Todo colour

  -- ------------------------------------------------------------- treesitter
  ["@comment"] = { link = "Comment" },
  ["@string"] = { fg = c.string },
  ["@string.escape"] = { fg = c.regexp },
  ["@string.regexp"] = { fg = c.regexp },
  ["@string.special"] = { fg = c.regexp },
  ["@string.special.url"] = { fg = c.tag, underline = true },
  ["@character"] = { fg = c.string },
  ["@number"] = { fg = c.constant },
  ["@boolean"] = { fg = c.constant },
  ["@constant"] = { fg = c.constant },
  ["@constant.builtin"] = { fg = c.constant },
  ["@constant.macro"] = { fg = c.constant },

  ["@variable"] = { fg = c.fg },
  ["@variable.builtin"] = { fg = c.keyword },
  ["@variable.parameter"] = { fg = c.fg },
  ["@variable.member"] = { fg = c.tag },
  ["@property"] = { fg = c.tag },

  ["@function"] = { fg = c.func },
  ["@function.call"] = { fg = c.func },
  ["@function.method"] = { fg = c.func },
  ["@function.method.call"] = { fg = c.func },
  ["@function.builtin"] = { fg = c.func },
  ["@function.macro"] = { fg = c.func },
  ["@constructor"] = { fg = c.tag },

  ["@keyword"] = { fg = c.keyword },
  ["@keyword.operator"] = { fg = c.keyword },
  ["@operator"] = { fg = c.operator },
  ["@type"] = { fg = c.tag },
  ["@type.builtin"] = { fg = c.tag },
  ["@module"] = { fg = c.tag },
  ["@attribute"] = { fg = c.special },
  ["@label"] = { fg = c.keyword },

  ["@punctuation"] = { fg = c.fg },
  ["@punctuation.delimiter"] = { fg = c.fg },
  ["@punctuation.bracket"] = { fg = c.fg },
  ["@punctuation.special"] = { fg = c.keyword },

  ["@tag"] = { fg = c.tag },
  ["@tag.attribute"] = { fg = c.func },
  ["@tag.delimiter"] = { fg = c.fg },

  ["@markup.heading"] = { fg = c.markup, bold = true },
  ["@markup.strong"] = { fg = c.keyword, bold = true },
  ["@markup.italic"] = { fg = c.markup, italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.raw"] = { fg = c.string },
  ["@markup.link"] = { fg = c.func },
  ["@markup.link.url"] = { fg = c.tag, underline = true },
  ["@markup.link.label"] = { fg = c.func },
  ["@markup.list"] = { fg = c.markup },
  ["@markup.quote"] = { fg = c.comment, italic = true },

  ["@diff.plus"] = { fg = c.string },
  ["@diff.minus"] = { fg = c.markup },
  ["@diff.delta"] = { fg = c.tag },

  ["@lsp.type.enumMember"] = { fg = c.constant },
  ["@lsp.typemod.variable.readonly"] = { fg = c.constant },
  ["@lsp.typemod.variable.defaultLibrary"] = { fg = c.keyword },

  -- -------------------------------------------------------------------- lsp
  DiagnosticError = { fg = c.error },
  DiagnosticWarn = { fg = c.accent },
  DiagnosticInfo = { fg = c.tag },
  DiagnosticHint = { fg = c.regexp },
  DiagnosticOk = { fg = c.string },
  DiagnosticUnderlineError = { undercurl = true, sp = c.error },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.accent },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.tag },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.regexp },
  DiagnosticUnnecessary = { fg = c.comment },
  LspReferenceText = { bg = c.selection },
  LspReferenceRead = { bg = c.selection },
  LspReferenceWrite = { bg = c.diff_text },
  LspInlayHint = { fg = c.comment },
  LspCodeLens = { fg = c.fg_idle },
  LspSignatureActiveParameter = { fg = c.accent, bold = true },

  -- ---------------------------------------------------------------- snacks
  -- The picker and its explorer sidebar. Every picker window links back to
  -- SnacksPicker, which snacks would otherwise point at NormalFloat (the
  -- #14191f panel grey); here it is the terminal's black, so the explorer
  -- reads as part of the editor.
  SnacksPicker = { fg = c.fg, bg = c.bg },
  SnacksPickerBorder = { fg = c.guide, bg = c.bg },
  SnacksPickerTitle = { fg = c.fg, bg = c.bg, bold = true },
  SnacksPickerListCursorLine = { bg = c.selection }, -- the terminal selection
  SnacksPickerPrompt = { fg = c.tag },
  SnacksPickerMatch = { fg = c.accent, bold = true }, -- like search matches
  SnacksPickerDirectory = { fg = c.tag },
  SnacksPickerFile = { fg = c.fg },
  SnacksPickerDir = { fg = c.comment }, -- the dirname part of a path
  SnacksPickerTree = { fg = c.guide },
  SnacksPickerPathHidden = { fg = c.comment },
  SnacksPickerPathIgnored = { fg = c.comment },
  SnacksPickerSelected = { fg = c.string },
  SnacksPickerGitStatus = { fg = c.tag },
  SnacksPickerGitStatusAdded = { fg = c.string },
  SnacksPickerGitStatusModified = { fg = c.tag },
  SnacksPickerGitStatusDeleted = { fg = c.markup },
  SnacksPickerGitStatusUntracked = { fg = c.fg_idle },
  SnacksPickerGitStatusIgnored = { fg = c.comment },
  SnacksPickerGitStatusUnmerged = { fg = c.keyword },
  SnacksPickerGitStatusStaged = { fg = c.string },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

-- Neovim's :terminal, where claudecode.nvim runs Claude, draws with these
-- rather than with the host terminal's palette. They copy alacritty.toml's
-- [colors] exactly, including black set to the background colour -- and,
-- unlike the previous theme, a genuinely lighter bright half, which is what
-- draw_bold_text_with_bright_colors / bold-text-in-bright act on.
local ansi = {
  c.bg, c.error, c.string, c.operator, c.tag, c.markup, c.regexp, "#ffffff",
  c.bright_black, "#ff6565", "#eafe84", "#fff779", "#68d5ff", "#ffa3aa", "#c7fffd", "#ffffff",
}
for i, color in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
