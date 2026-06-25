-- lua/base.lua
-- This contains the core options and keymaps required only for the most
-- basic of functionality.
-- Options, global keymaps, and autocmds.
-- No plugin dependencies. Loaded before lazy.
-- NOTE this file should not introduce dependencies on external plugins

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

local options = {
  -- Editing
  shiftwidth = 2,
  tabstop = 2,
  softtabstop = 4,
  autoindent = true, -- let treesitter handle it
  smartindent = false, -- let treesitter handle it
  cindent = false, -- let treesitter handle it
  -- Convert tabs to spaces
  expandtab = true,
  wrap = false,
  -- Minimal number of screen lines to keep above and below the cursor.
  scrolloff = 8,
  sidescrolloff = 8,
  -- Preview substitutions live, as you type!
  inccommand = 'split',
  -- editing style
  -- Allow visual selection of blocks of text
  -- that don't end on the same column number
  virtualedit = 'block',

  -- Conceal Settings
  -- -- in json files, conceal the quotes
  -- -- In org-mode conceal the links
  -- -- Markdown links can get concealed with this also.
  -- -- NOTE: Moved to org-mode config
  conceallevel = 2,
  concealcursor = 'nc',
  foldenable = true,

  -- Search
  ignorecase = true,
  smartcase = true,
  hlsearch = true,
  incsearch = true,

  -- UI
  list = true,
  listchars = { tab = '» ', trail = '·', nbsp = '␣' },
  winblend = 25,
  number = false,
  relativenumber = false,
  signcolumn = 'yes',
  cursorline = true,
  termguicolors = true,
  splitbelow = true,
  splitright = true,
  pumheight = 10,
  cmdheight = 1,
  --pumblend = 10,
  -- Don't show the mode, since it's already in the status line
  showmode = false,

  -- Behavior
  undofile = true, -- enables persistant undo
  swapfile = false,
  backup = false,
  writebackup = false,
  -- Enable mouse mode, can be useful for resizing splits for example!
  mouse = 'a',
  updatetime = 150,
  timeoutlen = 200,
  completeopt = { 'menuone', 'noselect' },
  fileencoding = 'utf-8',
  autochdir = true,
}

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.opt.clipboard = 'unnamedplus' end)

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

local function augroup(name) return vim.api.nvim_create_augroup('base_' .. name, { clear = true }) end

-- Highlight on yank
vim.api.nvim_create_autocmd('TextYankPost', {
  group = augroup 'yank_highlight',
  callback = function() vim.highlight.on_yank { higroup = 'IncSearch', timeout = 150 } end,
  desc = 'Highlight yanked text',
})

-- Restore cursor position on file open
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup 'restore_cursor',
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
  desc = 'Restore cursor position',
})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'quick_close',
  pattern = { 'help', 'lspinfo', 'man', 'notify', 'qf', 'checkhealth' },
  callback = function(event)
    vim.bo[event.buf].buflisted = false

    vim.keymap.set('n', 'q', '', {
      buffer = event.buf,
      silent = true,
      callback = function() vim.cmd.close() end,
      desc = 'base.close_window',
    })
  end,
  desc = 'Close utility windows with q',
})

-- Resize splits when window is resized
vim.api.nvim_create_autocmd('VimResized', {
  group = augroup 'resize_splits',
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd 'tabdo wincmd ='
    vim.cmd('tabnext ' .. current_tab)
  end,
  desc = 'Equalize splits on resize',
})

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- for make files we need to ensure we're using spaces not tabs
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'make',
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
    vim.opt.expandtab = false
  end,
})

vim.filetype.add {
  extension = {
    env = 'dotenv',
  },
  filename = {
    ['.env'] = 'dotenv',
    ['env'] = 'dotenv',
  },
  pattern = {
    ['[jt]sconfig.*.json'] = 'jsonc',
    ['%.env%.[%w_.-]+'] = 'dotenv',
  },
}

-- ─── Global Keymaps ──────────────────────────────────────────────────────────

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ';'

-- ─── Emacs-style keybindings ─────────────────────────────────────────────────
-- These provide the muscle-memory compatibility layer for Emacs/Doom users.
-- They work across normal, insert, visual, and command-line modes where
-- appropriate, mirroring Emacs behaviour without breaking vim idioms.

-- C-g — universal escape (Emacs muscle memory)
vim.keymap.set({ 'i', 'n', 'v', 'c' }, '<C-g>', '<Esc>', { silent = true, desc = 'emacs.escape' })

-- C-s — save (Doom/Emacs standard)
vim.keymap.set({ 'n', 'i' }, '<C-s>', '<cmd>write<cr>', { silent = true, desc = 'emacs.save' })

-- ── Cursor movement (insert mode) ───────────────────────────────────────────
-- Emacs C-f/C-b/C-n/C-p in insert mode for single-char/line movement
vim.keymap.set('i', '<C-f>', '<Right>', { silent = true, desc = 'emacs.forward_char' })
vim.keymap.set('i', '<C-b>', '<Left>',  { silent = true, desc = 'emacs.backward_char' })
vim.keymap.set('i', '<C-n>', '<Down>',  { silent = true, desc = 'emacs.next_line' })
vim.keymap.set('i', '<C-p>', '<Up>',    { silent = true, desc = 'emacs.previous_line' })

-- C-a / C-e — beginning/end of line (all modes)
vim.keymap.set('n', '<C-a>', '^', { silent = true, desc = 'emacs.beginning_of_line' })
vim.keymap.set('n', '<C-e>', '$', { silent = true, desc = 'emacs.end_of_line' })
vim.keymap.set('i', '<C-a>', '<Home>',  { silent = true, desc = 'emacs.beginning_of_line' })
vim.keymap.set('i', '<C-e>', '<End>',   { silent = true, desc = 'emacs.end_of_line' })
vim.keymap.set('c', '<C-a>', '<Home>',  { desc = 'emacs.beginning_of_line' })
vim.keymap.set('c', '<C-e>', '<End>',   { desc = 'emacs.end_of_line' })

-- ── Word-level movement (Alt/Meta key — Emacs standard) ─────────────────────
vim.keymap.set('n', '<M-f>', 'w',  { silent = true, desc = 'emacs.forward_word' })
vim.keymap.set('n', '<M-b>', 'b',  { silent = true, desc = 'emacs.backward_word' })
vim.keymap.set('i', '<M-f>', '<C-Right>', { silent = true, desc = 'emacs.forward_word' })
vim.keymap.set('i', '<M-b>', '<C-Left>',  { silent = true, desc = 'emacs.backward_word' })
vim.keymap.set('c', '<M-f>', '<C-Right>', { desc = 'emacs.forward_word' })
vim.keymap.set('c', '<M-b>', '<C-Left>',  { desc = 'emacs.backward_word' })

-- ── Editing (insert mode) ───────────────────────────────────────────────────
-- C-d — delete forward char (Emacs)
vim.keymap.set('i', '<C-d>', '<Del>', { silent = true, desc = 'emacs.delete_forward_char' })

-- C-k — kill to end of line (Emacs)
vim.keymap.set('i', '<C-k>', '<C-o>D', { silent = true, desc = 'emacs.kill_line' })
vim.keymap.set('n', '<C-k>', 'D',      { silent = true, desc = 'emacs.kill_line' })

-- M-d — delete word forward (Emacs)
vim.keymap.set('i', '<M-d>', '<C-o>dw', { silent = true, desc = 'emacs.kill_word' })

-- C-y — yank/paste (Emacs; in insert mode)
vim.keymap.set('i', '<C-y>', '<C-r>+', { silent = true, desc = 'emacs.yank' })

-- M-w — copy selection (Emacs kill-ring-save equivalent)
vim.keymap.set('v', '<M-w>', 'y', { silent = true, desc = 'emacs.copy_region' })

-- C-w — kill region (Emacs); visual mode only to avoid conflicting with C-w window prefix
vim.keymap.set('v', '<C-w>', 'd', { silent = true, desc = 'emacs.kill_region' })

-- C-/ — undo (Emacs)
vim.keymap.set('n', '<C-/>', 'u', { silent = true, desc = 'emacs.undo' })
-- NOTE: after loading plugin
-- local pick = require 'mini.pick'
-- local pick_mb = require 'minibuffer.integrations.mini-pick'
-- pick.is_picker_active = pick_mb.is_picker_active
-- pick.set_picker_items = pick_mb.set_picker_items
-- pick.start = pick_mb.start

-- Experimental UI2: floating cmdline and messages
-- No more "hit enter after commands"
require('vim._core.ui2').enable {
  enable = true,
  msg = {
    targets = {
      [''] = 'msg',
      empty = 'cmd',
      bufwrite = 'msg',
      confirm = 'cmd',
      emsg = 'pager',
      echo = 'msg',
      echomsg = 'msg',
      echoerr = 'pager',
      completion = 'cmd',
      list_cmd = 'pager',
      lua_error = 'pager',
      lua_print = 'msg',
      progress = 'pager',
      rpc_error = 'pager',
      quickfix = 'msg',
      search_cmd = 'cmd',
      search_count = 'cmd',
      shell_cmd = 'pager',
      shell_err = 'pager',
      shell_out = 'pager',
      shell_ret = 'msg',
      undo = 'msg',
      verbose = 'pager',
      wildlist = 'cmd',
      wmsg = 'msg',
      typed_cmd = 'cmd',
    },
    cmd = {
      height = 0.5,
    },
    dialog = {
      height = 0.5,
    },
    msg = {
      height = 0.3,
      timeout = 5000,
      target = 'msg',
    },
    pager = {
      height = 0.5,
    },
  },
}

----------------------------------------------------------------
-- Config
-- This should get loaded in all cases
----------------------------------------------------------------
local config_dir = vim.fn.stdpath 'config'

vim.keymap.set('n', '<leader>cf', '', {
  silent = true,
  desc = 'base.config_find_file',
  callback = function() vim.ui.picker.files { cwd = config_dir } end,
})

vim.keymap.set('n', '<leader>cg', '', {
  silent = true,
  desc = 'base.config_grep',
  callback = function() vim.ui.picker.grep { cwd = config_dir } end,
})

vim.keymap.set('n', '<leader>cm', '<cmd>ConfigStatus modules<cr>', {
  silent = true,
  desc = 'base.config_modules',
})

vim.keymap.set('n', '<leader>ck', '<cmd>ConfigStatus keys<cr>', {
  silent = true,
  desc = 'base.config_keys',
})

vim.keymap.set('n', '<leader>cc', '<cmd>ConfigStatus capabilities<cr>', {
  silent = true,
  desc = 'base.config_capabilities',
})

vim.keymap.set('n', '<leader>cs', function() vim.cmd 'ConfigStatus' end, { desc = 'interface.config_status', silent = true })

vim.keymap.set('n', '<leader>cS', function() vim.cmd 'ConfigStatus state' end, { desc = 'interface.config_status_state', silent = true })

vim.keymap.set('n', '<leader>cl', function() require('lazy').home() end, { desc = 'interface.lazy', silent = true })

-- ─── Doom-style top-level shortcuts ──────────────────────────────────────────
-- These are the most-used Doom keybindings that live outside any module's scope.
-- They provide quick access without navigating through which-key menus.

-- SPC . — find file from cwd (Doom: find-file)
vim.keymap.set('n', '<leader>.', '', {
  silent = true,
  desc = 'base.find_file',
  callback = function() vim.ui.picker.files { cwd = vim.fn.getcwd() } end,
})

-- SPC , — switch buffer (Doom: switch-buffer)
vim.keymap.set('n', '<leader>,', '', {
  silent = true,
  desc = 'base.switch_buffer',
  callback = function() vim.ui.picker.buffers() end,
})

-- SPC / — search project (Doom: +default/search-project)
vim.keymap.set('n', '<leader>/', '', {
  silent = true,
  desc = 'base.search_project',
  callback = function()
    local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if vim.v.shell_error ~= 0 or not root then root = vim.fn.getcwd() end
    vim.ui.picker.grep { cwd = root }
  end,
})

-- SPC : — command palette (Doom: M-x)
vim.keymap.set('n', '<leader>:', '', {
  silent = true,
  desc = 'base.command_palette',
  callback = function() vim.ui.picker.commands() end,
})

-- SPC SPC — project find file (Doom: projectile-find-file)
vim.keymap.set('n', '<leader><space>', '', {
  silent = true,
  desc = 'base.project_find_file',
  callback = function()
    local root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
    if vim.v.shell_error ~= 0 or not root then root = vim.fn.getcwd() end
    vim.ui.picker.files { cwd = root }
  end,
})

-- M-x — command palette (Emacs standard, works in all modes)
vim.keymap.set({ 'n', 'v' }, '<M-x>', '', {
  silent = true,
  desc = 'emacs.execute_command',
  callback = function() vim.ui.picker.commands() end,
})

-- ─── Tab/workspace management (SPC TAB — Doom standard) ─────────────────────
vim.keymap.set('n', '<leader><Tab><Tab>', '<cmd>tabnew<cr>',   { silent = true, desc = 'tab.new' })
vim.keymap.set('n', '<leader><Tab>d',     '<cmd>tabclose<cr>', { silent = true, desc = 'tab.close' })
vim.keymap.set('n', '<leader><Tab>n',     '<cmd>tabnext<cr>',  { silent = true, desc = 'tab.next' })
vim.keymap.set('n', '<leader><Tab>p',     '<cmd>tabprev<cr>',  { silent = true, desc = 'tab.prev' })
vim.keymap.set('n', '<leader><Tab>l',     '<cmd>tablast<cr>',  { silent = true, desc = 'tab.last' })
vim.keymap.set('n', '<leader><Tab>f',     '<cmd>tabfirst<cr>', { silent = true, desc = 'tab.first' })
vim.keymap.set('n', '<leader><Tab>]',     '<cmd>tabnext<cr>',  { silent = true, desc = 'tab.next' })
vim.keymap.set('n', '<leader><Tab>[',     '<cmd>tabprev<cr>',  { silent = true, desc = 'tab.prev' })
