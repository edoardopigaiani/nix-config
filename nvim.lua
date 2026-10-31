-- Neovim config, loaded through programs.neovim.configure.customLuaRC in
-- terminal.nix. The plugins it calls are installed by Nix there too, so there
-- is no plugin manager and nothing is downloaded at runtime.

-- Set before any mapping below: <leader> is expanded when a mapping is defined,
-- not when it is used.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Alacritty is truecolour, and tmux passes RGB through for it (terminal-features
-- in terminal.nix), so the colorscheme's hex values arrive as they are.
vim.o.termguicolors = true
vim.cmd.colorscheme("noir_essence")

-- ---------------------------------------------------------------- options
vim.o.number = true -- the current line's number...
vim.o.relativenumber = true -- ...and distances on the others, for 5j or d3k
vim.o.cursorline = true
vim.o.signcolumn = "yes" -- always there, so diagnostics do not shift the text
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8

-- Yank and put go straight to the Wayland clipboard, through wl-clipboard.
vim.o.clipboard = "unnamedplus"
vim.o.undofile = true -- undo history survives closing the file

vim.o.ignorecase = true
vim.o.smartcase = true -- ...unless the pattern has a capital

vim.o.splitright = true
vim.o.splitbelow = true

-- Two spaces, as nixfmt does; filetype plugins such as Python's override it.
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.softtabstop = 2

-- Only characters Tamzen has, so none of them falls back to another font.
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "+" }

-- ------------------------------------------------------------ claude code
-- claudecode.nvim speaks the same WebSocket protocol as the VS Code extension,
-- so Claude sees the current file and selection, can read LSP diagnostics, and
-- proposes edits as diffs here. Claude runs in a snacks.nvim terminal split;
-- launched from there it inherits CLAUDE_CODE_SSE_PORT and connects on its
-- own, no /ide needed. terminal_cmd is left at "claude", which is on PATH
-- because claude-code comes from nixpkgs.
--
-- In the terminal, a single <Esc> reaches Claude (interrupt) and a double one
-- drops to Normal mode -- snacks' default. Claude's own Esc-Esc (rewind) is
-- therefore taken; /rewind does the same.
require("claudecode").setup({
  terminal = {
    split_side = "right",
    split_width_percentage = 0.40,
  },
})

local map = vim.keymap.set
map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude" })
map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude" })
map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume Claude" })
map("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continue Claude" })
map("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Select Claude model" })
map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current buffer" })
map("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send selection to Claude" })
map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })
map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Deny diff" })

-- Alt+h / Alt+l move between the code and the Claude split in one key, even
-- while typing to Claude: in terminal mode Ctrl+w goes to the program (Claude
-- reads it as delete-word), so <C-\><C-n> leaves terminal mode first. Ctrl+h
-- and Ctrl+l are avoided, as in a terminal they are Backspace and clear.
map("n", "<M-h>", "<C-w>h", { desc = "Window left" })
map("n", "<M-l>", "<C-w>l", { desc = "Window right" })
map("t", "<M-h>", [[<C-\><C-n><C-w>h]], { desc = "Window left" })
map("t", "<M-l>", [[<C-\><C-n><C-w>l]], { desc = "Window right" })

-- ------------------------------------------------------------------ snacks
-- snacks.nvim is already here as claudecode.nvim's terminal; its picker also
-- takes over vim.ui.select. File icons are off: there is no icon plugin, and
-- the Nerd Font glyphs would have to fall back from Tamzen to Cozette.
require("snacks").setup({
  picker = {
    enabled = true,
    prompt = "> ",
    icons = { files = { enabled = false } },
  },
})

map("n", "<leader><space>", function() Snacks.picker.files() end, { desc = "Find files" })
map("n", "<leader>/", function() Snacks.picker.grep() end, { desc = "Grep" })
map("n", "<leader>b", function() Snacks.picker.buffers() end, { desc = "Buffers" })
map("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent files" })
map("n", "<leader>fh", function() Snacks.picker.help() end, { desc = "Help pages" })
map("n", "<leader>fd", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })

-- --------------------------------------------------------------- gitsigns
-- Changed lines in the sign column, in the colorscheme's Added/Changed/Removed.
require("gitsigns").setup({
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function bmap(mode, lhs, rhs, desc)
      map(mode, lhs, rhs, { buffer = buf, desc = desc })
    end
    bmap("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
    bmap("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")
    bmap("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
    bmap("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
    bmap("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
    bmap("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
  end,
})

-- -------------------------------------------------------------- which-key
-- Pressing <leader> and waiting shows what can follow. Mapping icons are off
-- for the same reason as the picker's.
require("which-key").setup({ icons = { mappings = false } })
require("which-key").add({
  { "<leader>a", group = "Claude" },
  { "<leader>f", group = "Find" },
  { "<leader>h", group = "Git hunk" },
})

-- ------------------------------------------------------------- treesitter
-- The parsers come prebuilt from Nix (nvim-treesitter.withPlugins), since the
-- system has no C compiler for :TSInstall. Highlighting is started by hand so
-- this works with either nvim-treesitter API; filetypes without a parser just
-- keep the regex syntax.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

-- -------------------------------------------------------------------- lsp
-- Server definitions come from nvim-lspconfig's lsp/ directory; the binaries
-- are in environment.systemPackages. Their diagnostics are also what Claude
-- reads through claudecode.nvim.
--
-- Neovim's defaults already map K (hover), grn (rename), gra (code action),
-- grr (references), gri (implementation) and [d / ]d (diagnostics).
vim.lsp.config("nixd", {
  settings = { nixd = { formatting = { command = { "nixfmt" } } } },
})
vim.lsp.config("lua_ls", {
  -- This config is the Lua lua_ls sees most, so teach it about Neovim's.
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim", "Snacks" } },
    },
  },
})
vim.lsp.enable({ "nixd", "lua_ls" })

vim.o.completeopt = "menuone,noselect,popup"

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then
      return
    end

    -- Neovim's own completion, popping up as you type; <C-y> accepts.
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end

    -- Format Nix files on save with nixfmt, through nixd, like the pre-commit
    -- hook does. Only nixd: lua_ls has a formatter too, with its own style.
    if client.name == "nixd" then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = args.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = args.buf, name = "nixd" })
        end,
      })
    end
  end,
})

-- --------------------------------------------------------- local overrides
-- The Nix wrapper starts nvim with -u, which skips ~/.config/nvim/init.lua.
-- Source it here so untracked experiments still have a place to live.
local user_init = vim.fn.stdpath("config") .. "/init.lua"
if vim.uv.fs_stat(user_init) then
  dofile(user_init)
end
