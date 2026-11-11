-- "Ayu Classic" for Neovim, ported from Zed's "Ayu Classic OLED"
-- (zed-extensions/ayu, themes/ayu.json), the theme the editor is set to and
-- the palette foot, Alacritty and the whole session are on. terminal.nix
-- installs this file as colors/ayu_classic.lua, so it is selected with
-- :colorscheme ayu_classic; nvim.lua selects it at startup.
--
-- This is ayu, but the newer ayu-colors line, not the ayu-vim one this
-- config used to be on: same hues, different values (red #ea6c73 against
-- #ff3333). Be careful with values carried over from that era.
--
-- Unlike ayu-vim, a Zed theme names a colour per syntax token rather than per
-- role, so the groups below are the theme's own assignments rather than an
-- interpretation of them -- syntax.keyword, syntax.function and so on map
-- straight across. Two deliberate departures:
--
--   - Normal is editor.foreground (#d9d7d0) while @variable and @text are
--     syntax.variable (#bfbdb6), which is what Zed actually draws: the
--     brighter value is the UI and the fallback for untokenised text, the
--     dimmer one is most of a buffer. The ayu-vim port put both on fg.
--   - The theme's font weights are dropped. It asks for 600 on keywords,
--     functions, types and properties; the terminal font is Tamzen, a bitmap
--     with one Bold strike and no italic, so honouring them would put most of
--     a buffer in Bold. Comments keep italic, which Tamzen renders upright
--     and so costs nothing.
--
-- The background is left to the terminal, so Neovim always matches the shell
-- around it. Both terminals set it to pure black, which is also this theme's
-- own background, the OLED variant having no surface above it.

vim.cmd("highlight clear")
vim.g.colors_name = "ayu_classic"
vim.o.background = "dark"

local c = {
  bg = "#000000", -- the theme's background, this being the OLED cut
  fg = "#d9d7d0", -- editor.foreground, terminal.foreground, text
  code = "#bfbdb6", -- syntax.variable: the colour most of a buffer is in
  accent = "#e6b450", -- search.active_match: the amber, foot's cursor
  warning = "#d8b56f", -- text.accent, border.focused, `warning`
  comment = "#626a73", -- syntax.comment, editor.line_number, `hidden`
  muted = "#707a8c", -- text.muted, terminal.dim_foreground
  idle = "#565b66", -- `unreachable`: inactive text
  guide = "#3a4150", -- editor.indent_guide and wrap_guide, drawn opaque here
  punct = "#5e6469", -- syntax.punctuation, #acb6bf at 55% over black

  string = "#aad94c", -- syntax.string; note the ANSI green is #91b362
  keyword = "#e6b673", -- syntax.keyword, comment.todo
  func = "#e8c783", -- syntax.function, property, number, title, attribute
  constant = "#d2a6ff", -- syntax.constant, parameter, symbol
  operator = "#d9a97a", -- syntax.operator, preproc, the *.builtin tokens
  type = "#59c2ff", -- syntax.type, module, constructor, link_text, `info`
  tag = "#39bae6", -- syntax.tag, `hint`: markup tags, builtin types
  regexp = "#95e6cb", -- syntax.string.escape, regexp, character
  markup = "#f07178", -- syntax.emphasis and punctuation.markup
  error = "#d95757", -- the theme's `error`, and comment.error

  panel = "#10151d", -- element.active: floats and the popup menu
  line = "#0a0e14", -- editor.active_line.background
  selection = "#152e3d", -- players[0].selection at 24% on black, as in foot
  bar = "#1b1f29", -- palette entry 235: weechat, tmux, micro and foot agree
  bright_black = "#686868", -- the ANSI bright black, the pmenu thumb

  added = "#70bf56", -- version_control.added
  modified = "#73b8ff", -- version_control.modified
  deleted = "#f26d78", -- version_control.deleted
  -- The theme states its diff backgrounds with alpha (created.background is
  -- #70bf561a) and Neovim highlights take none, so these are the three
  -- version_control accents flattened on black -- at 0x33 rather than the
  -- theme's own 0x1a, which at 10% is barely a tint on a black background.
  -- The ayu-vim port made the same choice at the same strength.
  diff_add = "#162611", -- added at 0x33
  diff_delete = "#301618", -- deleted at 0x33
  diff_change = "#172533", -- modified at 0x33
  diff_text = "#284059", -- modified at 0x59, to stand out within a change
}

local groups = {
  -- ----------------------------------------------------------------- editor
  Normal = { fg = c.fg },
  NormalFloat = { fg = c.fg, bg = c.panel },
  FloatBorder = { fg = c.guide, bg = c.panel },
  FloatTitle = { fg = c.fg, bg = c.panel, bold = true },
  Cursor = { fg = c.bg, bg = c.accent }, -- foot's cursor colours
  CursorLine = { bg = c.line },
  CursorColumn = { link = "CursorLine" },
  ColorColumn = { bg = c.line },
  LineNr = { fg = c.guide },
  CursorLineNr = { fg = c.warning }, -- editor.active_line_number
  SignColumn = {},
  FoldColumn = { fg = c.guide },
  Folded = { fg = c.idle, bg = c.panel },
  Visual = { bg = c.selection },
  -- The terminals' search colours: the UI grey for other matches, the amber
  -- for the focused one, as in alacritty.toml and foot's search box.
  Search = { fg = c.fg, bg = c.comment },
  CurSearch = { fg = c.bg, bg = c.accent },
  IncSearch = { link = "CurSearch" },
  Substitute = { link = "CurSearch" },
  MatchParen = { bg = c.selection, bold = true },
  NonText = { fg = c.guide },
  EndOfBuffer = { fg = c.guide },
  Whitespace = { fg = c.guide },
  SpecialKey = { fg = c.idle },
  Conceal = { fg = c.guide },
  WinSeparator = { fg = c.guide },
  Directory = { fg = c.type },
  Title = { fg = c.func, bold = true }, -- syntax.title
  QuickFixLine = { bg = c.selection },

  Pmenu = { fg = c.fg, bg = c.panel },
  PmenuSel = { bg = c.selection },
  PmenuMatch = { fg = c.accent, bg = c.panel },
  PmenuMatchSel = { fg = c.accent, bg = c.selection },
  PmenuSbar = { bg = c.panel },
  PmenuThumb = { bg = c.bright_black },
  WildMenu = { link = "PmenuSel" },

  -- Tabs share the editor background. The statusline instead matches
  -- weechat's, tmux's and micro's bars -- palette entry 235, which foot
  -- redefines to this theme's #1b1f29 -- so the terminal apps share one look.
  StatusLine = { fg = c.fg, bg = c.bar },
  StatusLineNC = { fg = c.idle, bg = c.bar },
  TabLine = { fg = c.idle },
  TabLineSel = { fg = c.fg },
  TabLineFill = {},
  WinBar = { fg = c.idle },
  WinBarNC = { fg = c.idle },

  ErrorMsg = { fg = c.error },
  WarningMsg = { fg = c.warning },
  MoreMsg = { fg = c.string },
  Question = { fg = c.string },
  ModeMsg = { fg = c.fg, bold = true },

  SpellBad = { undercurl = true, sp = c.error },
  SpellCap = { undercurl = true, sp = c.type },
  SpellRare = { undercurl = true, sp = c.regexp },
  SpellLocal = { undercurl = true, sp = c.keyword },

  DiffAdd = { bg = c.diff_add },
  DiffDelete = { fg = c.deleted, bg = c.diff_delete },
  DiffChange = { bg = c.diff_change },
  DiffText = { bg = c.diff_text },
  -- gitsigns' sign column, in the theme's version_control colours.
  Added = { fg = c.added },
  Changed = { fg = c.modified },
  Removed = { fg = c.deleted },

  -- ----------------------------------------------------- legacy syntax groups
  -- Used by filetypes without a treesitter parser; kept in step with the
  -- treesitter section below so both kinds of buffer look the same.
  Comment = { fg = c.comment, italic = true },
  Constant = { fg = c.constant },
  String = { fg = c.string },
  Character = { fg = c.regexp }, -- syntax.character, not string
  Number = { fg = c.func },
  Boolean = { fg = c.func },
  Float = { fg = c.func },
  Identifier = { fg = c.code },
  Function = { fg = c.func },
  Statement = { fg = c.keyword },
  Keyword = { fg = c.keyword },
  Conditional = { fg = c.keyword },
  Repeat = { fg = c.keyword },
  Label = { fg = c.type }, -- syntax.label
  Exception = { fg = c.keyword },
  Operator = { fg = c.operator },
  PreProc = { fg = c.operator }, -- syntax.preproc
  Include = { fg = c.keyword },
  Define = { fg = c.constant }, -- syntax.keyword.directive.define
  Macro = { fg = c.constant }, -- syntax.constant.macro
  Type = { fg = c.type },
  StorageClass = { fg = c.keyword },
  Structure = { fg = c.type },
  Typedef = { fg = c.type },
  Special = { fg = c.operator },
  SpecialChar = { fg = c.regexp },
  Tag = { fg = c.tag },
  Delimiter = { fg = c.punct },
  SpecialComment = { fg = c.comment, italic = true },
  Debug = { fg = c.keyword },
  Underlined = { underline = true },
  Error = { fg = c.error },
  Todo = { fg = c.keyword, bold = true }, -- syntax.comment.todo

  -- ------------------------------------------------------------- treesitter
  ["@comment"] = { link = "Comment" },
  ["@comment.error"] = { fg = c.error, italic = true },
  ["@comment.warning"] = { fg = c.warning, italic = true },
  ["@comment.note"] = { fg = c.tag, italic = true },
  ["@comment.todo"] = { fg = c.keyword, italic = true, bold = true },
  ["@string"] = { fg = c.string },
  ["@string.escape"] = { fg = c.regexp, italic = true },
  ["@string.regexp"] = { fg = c.regexp, italic = true },
  ["@string.special"] = { fg = c.regexp, italic = true },
  ["@string.special.url"] = { fg = c.type, italic = true, underline = true },
  ["@string.special.symbol"] = { fg = c.constant },
  ["@character"] = { fg = c.regexp, italic = true },
  ["@number"] = { fg = c.func },
  ["@boolean"] = { fg = c.func },
  ["@constant"] = { fg = c.constant },
  ["@constant.builtin"] = { fg = c.func },
  ["@constant.macro"] = { fg = c.constant },

  ["@variable"] = { fg = c.code },
  ["@variable.builtin"] = { fg = c.operator },
  ["@variable.parameter"] = { fg = c.constant },
  ["@variable.member"] = { fg = c.func },
  ["@property"] = { fg = c.func },
  ["@field"] = { fg = c.func },

  ["@function"] = { fg = c.func },
  ["@function.call"] = { fg = c.func },
  ["@function.method"] = { fg = c.func },
  ["@function.method.call"] = { fg = c.func },
  ["@function.builtin"] = { fg = c.operator },
  ["@function.macro"] = { fg = c.operator },
  ["@constructor"] = { fg = c.type },

  ["@keyword"] = { fg = c.keyword },
  ["@keyword.operator"] = { fg = c.keyword },
  ["@keyword.directive"] = { fg = c.constant },
  ["@keyword.export"] = { fg = c.type },
  ["@operator"] = { fg = c.operator },
  ["@type"] = { fg = c.type },
  ["@type.builtin"] = { fg = c.tag, italic = true },
  ["@module"] = { fg = c.type },
  ["@attribute"] = { fg = c.func },
  ["@label"] = { fg = c.type },

  ["@punctuation"] = { fg = c.punct },
  ["@punctuation.delimiter"] = { fg = c.punct },
  ["@punctuation.bracket"] = { fg = c.punct },
  ["@punctuation.special"] = { fg = c.operator },
  ["@punctuation.list_marker"] = { fg = c.func },

  ["@tag"] = { fg = c.tag },
  ["@tag.attribute"] = { fg = c.func },
  ["@tag.delimiter"] = { fg = c.tag },

  ["@markup.heading"] = { fg = c.func, bold = true }, -- syntax.title
  ["@markup.strong"] = { fg = c.markup, bold = true }, -- emphasis.strong
  ["@markup.italic"] = { fg = c.markup, italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.raw"] = { fg = c.string }, -- syntax.text.literal
  ["@markup.link"] = { fg = c.type }, -- syntax.link_text
  ["@markup.link.url"] = { fg = c.regexp, italic = true }, -- link_uri
  ["@markup.link.label"] = { fg = c.type },
  ["@markup.list"] = { fg = c.func },
  ["@markup.quote"] = { fg = c.comment, italic = true },

  ["@diff.plus"] = { fg = "#7fd962" }, -- syntax.diff.plus
  ["@diff.minus"] = { fg = c.deleted },
  ["@diff.delta"] = { fg = c.modified },

  ["@lsp.type.enumMember"] = { fg = c.regexp, italic = true }, -- syntax.enum
  ["@lsp.typemod.variable.readonly"] = { fg = c.constant },
  ["@lsp.typemod.variable.defaultLibrary"] = { fg = c.operator },

  -- -------------------------------------------------------------------- lsp
  -- The theme's own status colours: `error`, `warning`, `info` and `hint`.
  DiagnosticError = { fg = c.error },
  DiagnosticWarn = { fg = c.warning },
  DiagnosticInfo = { fg = c.type },
  DiagnosticHint = { fg = c.tag },
  DiagnosticOk = { fg = c.added }, -- `success`
  DiagnosticUnderlineError = { undercurl = true, sp = c.error },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.warning },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.type },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.tag },
  DiagnosticUnnecessary = { fg = c.comment },
  -- editor.document_highlight.read_background and .write_background, which
  -- the theme tints blue and amber; flattened, the read one is the selection.
  LspReferenceText = { bg = c.selection },
  LspReferenceRead = { bg = c.selection },
  LspReferenceWrite = { bg = c.diff_text },
  LspInlayHint = { fg = c.comment }, -- syntax.hint
  LspCodeLens = { fg = c.idle },
  LspSignatureActiveParameter = { fg = c.accent, bold = true },

  -- ---------------------------------------------------------------- snacks
  -- The picker and its explorer sidebar. Every picker window links back to
  -- SnacksPicker, which snacks would otherwise point at NormalFloat (the
  -- #10151d panel grey); here it is the terminal's black, so the explorer
  -- reads as part of the editor.
  SnacksPicker = { fg = c.fg, bg = c.bg },
  SnacksPickerBorder = { fg = c.guide, bg = c.bg },
  SnacksPickerTitle = { fg = c.fg, bg = c.bg, bold = true },
  SnacksPickerListCursorLine = { bg = c.selection }, -- the terminal selection
  SnacksPickerPrompt = { fg = c.type },
  SnacksPickerMatch = { fg = c.accent, bold = true }, -- like search matches
  SnacksPickerDirectory = { fg = c.type },
  SnacksPickerFile = { fg = c.fg },
  SnacksPickerDir = { fg = c.comment }, -- the dirname part of a path
  SnacksPickerTree = { fg = c.guide },
  SnacksPickerPathHidden = { fg = c.comment },
  SnacksPickerPathIgnored = { fg = c.comment },
  SnacksPickerSelected = { fg = c.string },
  SnacksPickerGitStatus = { fg = c.modified },
  SnacksPickerGitStatusAdded = { fg = c.added },
  SnacksPickerGitStatusModified = { fg = c.modified },
  SnacksPickerGitStatusDeleted = { fg = c.deleted },
  SnacksPickerGitStatusUntracked = { fg = c.idle },
  SnacksPickerGitStatusIgnored = { fg = c.comment },
  SnacksPickerGitStatusUnmerged = { fg = c.keyword },
  SnacksPickerGitStatusStaged = { fg = c.added },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

-- Neovim's :terminal, where claudecode.nvim runs Claude, draws with these
-- rather than with the host terminal's palette. They are foot's regular0-7
-- and bright0-7 verbatim (terminal.nix), black included, so a shell inside
-- Neovim inside foot looks like the shell outside it.
local ansi = {
  "#000000", "#ea6c73", "#91b362", "#f9af4f", "#53bdfa", "#d2a6ff", "#90e1c6", "#c7c7c7",
  "#686868", "#f07178", "#c2d94c", "#e8c783", "#59c2ff", "#ddbcff", "#95e6cb", "#ffffff",
}
for i, color in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
