-- lua/base.lua
-- This contains the core options and keymaps required only for the most
-- basic of functionality.
-- Options, global keymaps, and autocmds.
-- No plugin dependencies. Loaded before lazy.
-- NOTE this file should not introduce dependencies on external plugins

-- [[ Base Vim Options ]]
local keys = require 'lib.keys'

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

local options = {
  -- Editing
  shiftwidth = 4,
  tabstop = 4,
  softtabstop = 4,
  smartindent = true,
  cindent = true,
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
  number = false,
  relativenumber = false,
  signcolumn = 'yes',
  cursorline = true,
  termguicolors = true,
  splitbelow = true,
  splitright = true,
  pumheight = 10,
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

vim.opt.sessionoptions:remove 'folds' -- Don't save folds in sessions

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.opt.clipboard = 'unnamedplus' end)

-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = vim.diagnostic.severity.ERROR },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Teest shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { float = true },
}

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

-- Trim trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup 'trim_whitespace',
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd [[%s/\s\+$//e]]
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end,
  desc = 'Trim trailing whitespace on save',
})

-- Close certain filetypes with q
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'quick_close',
  pattern = {
    'help',
    'lspinfo',
    'man',
    'notify',
    'qf',
    'checkhealth',
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    keys.map {
      lhs = 'q',
      rhs = '<cmd>close<cr>',
      desc = 'Close window',
      module = 'base',
      buffer = event.buf,
    }
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

-- Groups that span all features - defined here so they
-- always exist in which-key regardless of feature flags
keys.register_group('<leader>b', 'buffers', 'n')
keys.register_group('<leader>c', 'config', 'n')
keys.register_group('<leader>f', 'find', 'n')
keys.register_group('<leader>g', 'git', 'n')
keys.register_group('<leader>l', 'lsp', 'n')
keys.register_group('<leader>p', 'project', 'n')
keys.register_group('<leader>q', 'quit', 'n')
keys.register_group('<leader>t', 'toggle', 'n')
keys.register_group('<leader>w', 'write', 'n')

-- Window zoom toggle (simplified)
local function toggle_zoom()
  local function is_zoomed() return vim.t.zoomed or false end

  local function zoom_session_file()
    if not vim.t.zoom_session_file then
      vim.t.zoom_session_file = vim.fn.tempname() .. '_' .. vim.api.nvim_tabpage_get_number(0)
      vim.api.nvim_create_autocmd('TabClosed', {
        callback = function()
          if vim.t.zoom_session_file then os.remove(vim.t.zoom_session_file) end
        end,
      })
    end
    return vim.t.zoom_session_file
  end

  if is_zoomed() then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd('silent! source ' .. zoom_session_file())
    vim.t.zoomed = false
    vim.api.nvim_win_set_cursor(0, cursor_pos)
  else
    if #vim.api.nvim_tabpage_list_wins(0) == 1 then return end
    local old_sessionoptions = vim.o.sessionoptions
    vim.o.sessionoptions = 'blank,buffers,curdir,terminal,help'
    vim.cmd('mksession! ' .. zoom_session_file())
    vim.cmd 'only'
    vim.t.zoomed = true
    vim.o.sessionoptions = old_sessionoptions
  end
end

local config_dir = vim.fn.stdpath 'config'
keys.map_group('base', {
  -- ── Window navigation ───────────────────────────────────────────────
  {
    lhs = '<leader>wf',
    rhs = function() toggle_zoom() end,
    desc = 'Full screen window',
  },
  {
    lhs = '<leader>wh',
    rhs = '<C-w>h',
    desc = 'Move to left window',
  },
  {
    lhs = '<leader>wj',
    rhs = '<C-w>j',
    desc = 'Move to lower window',
  },
  {
    lhs = '<leader>wk',
    rhs = '<C-w>k',
    desc = 'Move to upper window',
  },
  {
    lhs = '<leader>wl',
    rhs = '<C-w>l',
    desc = 'Move to right window',
  },
  {
    lhs = '<leader>wv',
    rhs = '<cmd>vsplit<cr>',
    desc = 'Vertical Split Window',
  },
  {
    lhs = '<leader>ws',
    rhs = '<cmd>split<cr>',
    desc = 'Horizontal Split Window',
  },

  -- ── Window repositioning ──────────────────────────────────────────────
  {
    lhs = '<leader>H',
    rhs = '<C-w>H',
    desc = 'Move window left',
  },
  {
    lhs = '<leader>J',
    rhs = '<C-w>J',
    desc = 'Move window down',
  },
  {
    lhs = '<leader>K',
    rhs = '<C-w>K',
    desc = 'Move window up',
  },
  {
    lhs = '<leader>L',
    rhs = '<C-w>L',
    desc = 'Move window right',
  },
  {
    lhs = '<leader>wd',
    rhs = '<C-w>c',
    desc = 'Delete window',
  },
  {
    lhs = '<leader>wo',
    rhs = '<C-w>o',
    desc = 'Delete other window',
  },

  -- ── Buffer management ───────────────────────────────────────────────
  {
    lhs = '<S-l>',
    rhs = '<cmd>bnext<cr>',
    desc = 'Next buffer',
  },
  {
    lhs = '<S-h>',
    rhs = '<cmd>bprevious<cr>',
    desc = 'Previous buffer',
  },
  {
    lhs = '<leader>bd',
    rhs = '<cmd>bdelete<cr>',
    desc = 'Delete buffer',
  },

  -- ── Quit ─────────────────────────────────────────────────────────────
  {
    lhs = '<leader>qq',
    rhs = '<cmd>qa<cr>',
    desc = 'Quit all',
  },
  -- {
  --   lhs  = "<leader>qQ",
  --   rhs  = "<cmd>qa!<cr>",
  --   desc = "Quit all (force)",
  -- },
  {
    lhs = '<leader>wq',
    rhs = '<cmd>wqa<cr>',
    desc = 'Save and quit all',
  },

  -- ── Toggle ───────────────────────────────────────────────────────────
  {
    lhs = '<leader>tn',
    rhs = '<cmd>set number!<cr>',
    desc = 'Toggle line numbers',
  },
  {
    lhs = '<leader>tr',
    rhs = '<cmd>set relativenumber!<cr>',
    desc = 'Toggle relative numbers',
  },
  {
    lhs = '<leader>ts',
    rhs = '<cmd>setlocal spell!<cr>',
    desc = 'Toggle spell check',
  },
  {
    lhs = '<leader>tw',
    rhs = '<cmd>set wrap!<cr>',
    desc = 'Toggle word wrap',
  },

  -- ── Config ───────────────────────────────────────────────────────────
  {
    lhs = '<leader>cf',
    rhs = function()
      local files = vim.fn.globpath(config_dir, '**/*', false, true)
      files = vim.tbl_filter(function(f) return vim.fn.isdirectory(f) == 0 end, files)
      vim.ui.select(files, {
        prompt = 'Find config file:',
        format_item = function(item) return item:gsub(config_dir .. '/', '') end,
      }, function(choice)
        if choice then vim.cmd.edit(choice) end
      end)
    end,
    desc = 'Find config file',
  },
  {
    lhs = '<leader>cg',
    rhs = function()
      local query = vim.fn.input 'Grep config> '
      if query == '' then return end
      vim.cmd('silent! vimgrep /' .. query .. '/gj ' .. config_dir .. '/**/*')
      vim.cmd 'copen'
    end,
    desc = 'Grep config files',
  },
  {
    lhs = '<leader>cm',
    rhs = '<cmd>ConfigStatus modules<cr>',
    desc = 'Config module status',
  },
  {
    lhs = '<leader>ck',
    rhs = '<cmd>ConfigStatus keys<cr>',
    desc = 'Config keymap registry',
  },
  {
    lhs = '<leader>cc',
    rhs = '<cmd>ConfigStatus capabilities<cr>',
    desc = 'Config capability registry',
  },

  -- ── Misc ────────────────────────────────────────────────────────────
  {
    lhs = '<Esc>',
    rhs = '<cmd>nohlsearch<cr>',
    desc = 'Clear search highlight',
  },
}, {
  -- Defaults applied to all mappings in this group
  silent = true,
})
