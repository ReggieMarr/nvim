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

----------------------------------------------------------------
-- Window navigation
----------------------------------------------------------------

vim.keymap.set('n', '<leader>wf', '', {
  silent = true,
  callback = toggle_zoom,
  desc = 'base.window_zoom',
})

vim.keymap.set('n', '<leader>wh', '<C-w>h', { silent = true, desc = 'base.window_left' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { silent = true, desc = 'base.window_down' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { silent = true, desc = 'base.window_up' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { silent = true, desc = 'base.window_right' })

vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<cr>', { silent = true, desc = 'base.window_vsplit' })
vim.keymap.set('n', '<leader>ws', '<cmd>split<cr>', { silent = true, desc = 'base.window_split' })

----------------------------------------------------------------
-- Window repositioning
----------------------------------------------------------------

vim.keymap.set('n', '<leader>H', '<C-w>H', { silent = true, desc = 'base.window_move_left' })
vim.keymap.set('n', '<leader>J', '<C-w>J', { silent = true, desc = 'base.window_move_down' })
vim.keymap.set('n', '<leader>K', '<C-w>K', { silent = true, desc = 'base.window_move_up' })
vim.keymap.set('n', '<leader>L', '<C-w>L', { silent = true, desc = 'base.window_move_right' })

vim.keymap.set('n', '<leader>wd', '<C-w>c', { silent = true, desc = 'base.window_delete' })
vim.keymap.set('n', '<leader>wo', '<C-w>o', { silent = true, desc = 'base.window_delete_others' })

----------------------------------------------------------------
-- Buffer
----------------------------------------------------------------

vim.keymap.set('n', '<S-l>', '<cmd>bnext<cr>', { silent = true, desc = 'base.buffer_next' })
vim.keymap.set('n', '<S-h>', '<cmd>bprevious<cr>', { silent = true, desc = 'base.buffer_prev' })
vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<cr>', { silent = true, desc = 'base.buffer_delete' })

----------------------------------------------------------------
-- Quit
----------------------------------------------------------------

vim.keymap.set('n', '<leader>qq', '<cmd>qa<cr>', { silent = true, desc = 'base.quit_all' })
vim.keymap.set('n', '<leader>wq', '<cmd>wqa<cr>', { silent = true, desc = 'base.write_quit_all' })

----------------------------------------------------------------
-- Toggles
----------------------------------------------------------------

vim.keymap.set('n', '<leader>tn', '<cmd>set number!<cr>', { silent = true, desc = 'base.toggle_number' })
vim.keymap.set('n', '<leader>tr', '<cmd>set relativenumber!<cr>', { silent = true, desc = 'base.toggle_relnumber' })
vim.keymap.set('n', '<leader>ts', '<cmd>setlocal spell!<cr>', { silent = true, desc = 'base.toggle_spell' })
vim.keymap.set('n', '<leader>tw', '<cmd>set wrap!<cr>', { silent = true, desc = 'base.toggle_wrap' })

----------------------------------------------------------------
-- Config
----------------------------------------------------------------

---@defgroup vim.ui.picker
---
---@brief Pickers ~
---
--- |vim.ui.picker| is a registry of named pickers that can be overridden by
--- plugins to provide custom implementations.
---
--- Plugins can override individual pickers: >lua
---
---   -- Override a single picker
---   vim.ui.picker.files = function(opts)
---     -- custom implementation
---   end
---
---   -- Extend with a new picker
---   vim.ui.picker.my_picker = function(opts)
---     -- custom implementation
---   end
--- <
---
--- To preserve original pickers: >lua
---
---   local orig_files = vim.ui.picker.files
---   require('myplugin').setup()
---   vim.ui.picker.files = orig_files
--- <
vim.ui.picker = vim.ui.picker or {}

--- Default file picker relative to a given directory using the built-in vim.ui.select.
---
---@param opts table|nil Optional parameters
---   - cwd (string): Directory to search from. Default: |getcwd()|
---   - show_hidden (boolean): Include hidden files. Default: false
vim.ui.picker.files = vim.ui.picker.files
  or function(local_opts)
    local_opts = local_opts or {} -- guard nil (called from registry.registry)
    local directory = vim.fn.resolve(vim.fn.expand(local_opts.cwd or vim.fn.getcwd()))
    local show_hidden = local_opts.show_hidden or false

    -- Build find command
    local cmd = { 'find', directory, '-type', 'f' }
    if not show_hidden then
      table.insert(cmd, '-not')
      table.insert(cmd, '-path')
      table.insert(cmd, '*/.*')
    end

    local files = vim.fn.systemlist(cmd)

    if vim.v.shell_error ~= 0 or #files == 0 then
      vim.notify('vim.ui.picker.files: no files found in ' .. directory, vim.log.levels.WARN)
      return
    end

    -- Show relative paths for readability
    local relative = vim.tbl_map(function(f) return vim.fn.fnamemodify(f, ':~:.') end, files)

    vim.ui.select(relative, {
      prompt = 'Files: ' .. vim.fn.fnamemodify(directory, ':~'),
      kind = 'file',
    }, function(choice)
      if choice then vim.cmd.edit(choice) end
    end)
  end

vim.keymap.set('n', '<leader>cf', '', {
  silent = true,
  desc = 'base.config_find_file',
  callback = function() vim.ui.picker.files { cwd = config_dir } end,
})

vim.keymap.set('n', '<leader>cg', '', {
  silent = true,
  desc = 'base.config_grep',
  callback = function()
    local query = vim.fn.input 'Grep config> '
    if query == '' then return end
    vim.cmd('silent! vimgrep /' .. query .. '/gj ' .. config_dir .. '/**/*')
    vim.cmd 'copen'
  end,
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

----------------------------------------------------------------
-- Misc
----------------------------------------------------------------

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>', {
  silent = true,
  desc = 'base.clear_search_highlight',
})
