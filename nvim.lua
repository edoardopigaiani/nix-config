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
vim.lsp.enable({ "nixd", "lua_ls" })

-- --------------------------------------------------------- local overrides
-- The Nix wrapper starts nvim with -u, which skips ~/.config/nvim/init.lua.
-- Source it here so untracked experiments still have a place to live.
local user_init = vim.fn.stdpath("config") .. "/init.lua"
if vim.uv.fs_stat(user_init) then
  dofile(user_init)
end
