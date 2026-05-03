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
