-- "Noir Essence Dark" for Neovim, ported from the VS Code theme of the same
-- name (u1145h.u1145h-heme-ark, themes/noir_essence_dark.json), the theme
-- alacritty.toml is ported from too. terminal.nix installs this file as
-- colors/noir_essence.lua, so it is selected with :colorscheme noir_essence.
--
-- The background is left to the terminal, so Neovim always matches the shell
-- around it; Alacritty sets it to the theme's #111314. VS Code colours with an
-- alpha channel are flattened onto #111314, since Neovim highlights take no
-- alpha; the source value is noted where it differs.

vim.cmd("highlight clear")
vim.g.colors_name = "noir_essence"
vim.o.background = "dark"

local c = {
  bg = "#111314", -- editor.background
  fg = "#f7f3ea", -- editor.foreground
  red = "#ea6962", -- variables, properties, tags, headings
  orange = "#e78a4e", -- constants, numbers, attributes
  yellow = "#e7b24e", -- types, classes, namespaces, builtin variables
  string = "#98c379", -- strings
  green = "#a9b665", -- cursor, whitespace, suggest-widget matches
  blue = "#7daea3", -- operators, builtin functions, escapes
  func = "#7d97ae", -- function names
  purple = "#d3869b", -- keywords, storage
  comment = "#51504d",
  warn = "#eac262", -- editorWarning.foreground, without its alpha
  info = "#658ecd", -- editorInfo.foreground, without its alpha

  widget = "#161819", -- editorWidget.background
  widget_sel = "#1f2121", -- editorSuggestWidget.selectedBackground
  selection = "#2b2d2d", -- editor.selectionBackground
  bright_black = "#434545", -- terminal.ansiBrightBlack
  widget_border = "#454545", -- editorSuggestWidget.border
  split = "#444444", -- editorGroup.border
  find = "#4f666f", -- editor.findMatchBackground

  line_hl = "#1a1c1d", -- editor.lineHighlightBackground #ffffff0A
  line_nr = "#3c3d3c", -- editorLineNumber.foreground #f7f3ea30
  indent = "#2a2c2b", -- editorIndentGuide.background #f7f3ea1c
  dim = "#4b4b4a", -- tab.inactiveForeground #f7f3ea40
  status = "#979691", -- statusBar.foreground #f7f3ea95
  find_other = "#583b27", -- editor.findMatchHighlightBackground #e78a4e55
  word_hl = "#444444", -- editor.wordHighlightBackground #575757b8
  word_hl_strong = "#3b3e3e", -- editor.wordHighlightStrongBackground #4b4f4eb8
  diff_add = "#2f3424", -- diffEditor.insertedTextBackground #a9b66533
  diff_delete = "#3c2424", -- diffEditor.removedTextBackground #ea696233
  diff_change = "#273231", -- the theme has none; blue at the same 0x33
  diff_text = "#374946", -- blue at 0x59, to stand out within a changed line
}

local groups = {
  -- ----------------------------------------------------------------- editor
  Normal = { fg = c.fg },
  NormalFloat = { fg = c.fg, bg = c.widget },
  FloatBorder = { fg = c.widget_border, bg = c.widget },
  FloatTitle = { fg = c.fg, bg = c.widget, bold = true },
  Cursor = { fg = c.bg, bg = c.fg },
  CursorLine = { bg = c.line_hl },
  CursorColumn = { link = "CursorLine" },
  ColorColumn = { bg = c.line_hl },
  LineNr = { fg = c.line_nr },
  CursorLineNr = { fg = c.fg },
  SignColumn = {},
  FoldColumn = { fg = c.line_nr },
  Folded = { fg = c.comment, bg = c.widget },
  Visual = { bg = c.selection },
  Search = { bg = c.find_other },
  CurSearch = { fg = c.fg, bg = c.find },
  IncSearch = { link = "CurSearch" },
  Substitute = { link = "CurSearch" },
  MatchParen = { bg = c.selection, bold = true },
  NonText = { fg = c.line_nr },
  EndOfBuffer = { fg = c.line_nr },
  Whitespace = { fg = c.green }, -- editorWhitespace.foreground
  SpecialKey = { fg = c.blue },
  Conceal = { fg = c.comment },
  WinSeparator = { fg = c.split },
  Directory = { fg = c.blue },
  Title = { fg = c.red, bold = true },
  QuickFixLine = { bg = c.selection },

  Pmenu = { fg = c.fg, bg = c.widget },
  PmenuSel = { bg = c.widget_sel },
  PmenuMatch = { fg = c.green, bg = c.widget },
  PmenuMatchSel = { fg = c.green, bg = c.widget_sel },
  PmenuSbar = { bg = c.widget },
  PmenuThumb = { bg = c.bright_black },
  WildMenu = { link = "PmenuSel" },

  -- The VS Code status bar and tabs share the editor background.
  StatusLine = { fg = c.status },
  StatusLineNC = { fg = c.dim },
  TabLine = { fg = c.dim },
  TabLineSel = { fg = c.fg },
  TabLineFill = {},
  WinBar = { fg = c.status },
  WinBarNC = { fg = c.dim },

  ErrorMsg = { fg = c.red },
  WarningMsg = { fg = c.warn },
  MoreMsg = { fg = c.green },
  Question = { fg = c.green },
  ModeMsg = { fg = c.fg, bold = true },

  SpellBad = { undercurl = true, sp = c.red },
  SpellCap = { undercurl = true, sp = c.warn },
  SpellRare = { undercurl = true, sp = c.purple },
  SpellLocal = { undercurl = true, sp = c.blue },

  DiffAdd = { bg = c.diff_add },
  DiffDelete = { fg = c.red, bg = c.diff_delete },
  DiffChange = { bg = c.diff_change },
  DiffText = { bg = c.diff_text },
  Added = { fg = "#a8b665" }, -- editorGutter.addedBackground
  Changed = { fg = c.blue }, -- editorGutter.modifiedBackground
  Removed = { fg = c.red }, -- editorGutter.deletedBackground

  -- ----------------------------------------------------- legacy syntax groups
  -- Used by filetypes without a treesitter parser.
  Comment = { fg = c.comment, italic = true },
  Constant = { fg = c.orange },
  String = { fg = c.string },
  Character = { fg = c.string },
  Number = { fg = c.orange },
  Boolean = { fg = c.orange },
  Float = { fg = c.orange },
  Identifier = { fg = c.red },
  Function = { fg = c.func },
  Statement = { fg = c.purple },
  Keyword = { fg = c.purple },
  Conditional = { fg = c.purple },
  Repeat = { fg = c.purple },
  Label = { fg = c.purple },
  Exception = { fg = c.purple },
  Operator = { fg = c.blue },
  PreProc = { fg = c.purple },
  Include = { fg = c.purple },
  Define = { fg = c.purple },
  Macro = { fg = c.yellow },
  Type = { fg = c.yellow },
  StorageClass = { fg = c.purple },
  Structure = { fg = c.yellow },
  Typedef = { fg = c.yellow },
  Special = { fg = c.blue },
  SpecialChar = { fg = c.blue },
  Tag = { fg = c.red },
  Delimiter = { fg = c.fg },
  SpecialComment = { fg = c.comment, italic = true },
  Debug = { fg = c.orange },
  Underlined = { underline = true },
  Error = { fg = c.red },
  Todo = { fg = c.orange, bold = true }, -- todo.bold

  -- ------------------------------------------------------------- treesitter
  ["@comment"] = { link = "Comment" },
  ["@string"] = { fg = c.string },
  ["@string.escape"] = { fg = c.blue }, -- constant.character.escape
  ["@string.regexp"] = { fg = c.blue },
  ["@string.special"] = { fg = c.blue },
  ["@string.special.url"] = { fg = c.purple, underline = true },
  ["@character"] = { fg = c.string },
  ["@number"] = { fg = c.orange },
  ["@boolean"] = { fg = c.orange },
  ["@constant"] = { fg = c.yellow }, -- variable.other.constant
  ["@constant.builtin"] = { fg = c.orange }, -- constant
  ["@constant.macro"] = { fg = c.orange },

  ["@variable"] = { fg = c.red }, -- variable
  ["@variable.builtin"] = { fg = c.yellow }, -- variable.language
  ["@variable.parameter"] = { fg = c.fg }, -- variable.parameter.function
  ["@variable.member"] = { fg = c.red }, -- support.variable.property
  ["@property"] = { fg = c.red }, -- meta.object-literal.key

  ["@function"] = { fg = c.func }, -- entity.name.function
  ["@function.call"] = { fg = c.func },
  ["@function.method"] = { fg = c.func },
  ["@function.method.call"] = { fg = c.func },
  ["@function.builtin"] = { fg = c.blue }, -- support.function
  ["@function.macro"] = { fg = c.func },
  ["@constructor"] = { fg = c.yellow }, -- entity.name.class

  ["@keyword"] = { fg = c.purple },
  ["@keyword.operator"] = { fg = c.purple }, -- keyword.operator.expression.*
  ["@operator"] = { fg = c.blue }, -- keyword.operator.arithmetic etc.
  ["@type"] = { fg = c.yellow }, -- entity.name.type
  ["@type.builtin"] = { fg = c.blue }, -- support.type
  ["@module"] = { fg = c.yellow }, -- entity.name.namespace
  ["@attribute"] = { fg = c.yellow }, -- storage.type.annotation
  ["@label"] = { fg = c.purple },

  ["@punctuation"] = { fg = c.fg },
  ["@punctuation.delimiter"] = { fg = c.fg },
  ["@punctuation.bracket"] = { fg = c.fg },
  ["@punctuation.special"] = { fg = c.purple }, -- punctuation.section.embedded

  ["@tag"] = { fg = c.red }, -- entity.name.tag
  ["@tag.attribute"] = { fg = c.orange }, -- entity.other.attribute-name
  ["@tag.delimiter"] = { fg = c.fg },

  ["@markup.heading"] = { fg = c.red, bold = true },
  ["@markup.strong"] = { fg = c.orange, bold = true },
  ["@markup.italic"] = { fg = c.purple, italic = true },
  ["@markup.strikethrough"] = { strikethrough = true },
  ["@markup.underline"] = { underline = true },
  ["@markup.raw"] = { fg = c.string },
  ["@markup.link"] = { fg = c.func },
  ["@markup.link.url"] = { fg = c.purple, underline = true },
  ["@markup.link.label"] = { fg = c.func },
  ["@markup.list"] = { fg = c.red },
  ["@markup.quote"] = { fg = c.comment, italic = true },

  ["@diff.plus"] = { fg = c.string }, -- markup.inserted.diff
  ["@diff.minus"] = { fg = c.red }, -- markup.deleted.diff
  ["@diff.delta"] = { fg = c.yellow }, -- markup.changed.diff

  -- The theme's semanticTokenColors.
  ["@lsp.type.enumMember"] = { fg = c.blue },
  ["@lsp.typemod.variable.readonly"] = { fg = c.orange },
  ["@lsp.typemod.variable.defaultLibrary"] = { fg = c.yellow },

  -- -------------------------------------------------------------------- lsp
  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.warn },
  DiagnosticInfo = { fg = c.info },
  DiagnosticHint = { fg = c.blue },
  DiagnosticOk = { fg = c.green },
  DiagnosticUnderlineError = { undercurl = true, sp = c.red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.warn },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.info },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.blue },
  DiagnosticUnnecessary = { fg = c.comment },
  LspReferenceText = { bg = c.word_hl },
  LspReferenceRead = { bg = c.word_hl },
  LspReferenceWrite = { bg = c.word_hl_strong },
  LspInlayHint = { fg = c.comment },
  LspCodeLens = { fg = "#999999" }, -- editorCodeLens.foreground
  LspSignatureActiveParameter = { fg = c.green, bold = true },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

-- Neovim's :terminal, where claudecode.nvim runs Claude, draws with these
-- rather than with Alacritty's palette. They copy alacritty.toml's [colors]
-- exactly, including color0 set to the background colour.
local ansi = {
  c.bg, c.red, "#89b482", c.orange, c.blue, c.purple, c.green, c.fg,
  c.bright_black, c.red, "#89b482", c.orange, c.blue, c.purple, c.green, c.fg,
}
for i, color in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
