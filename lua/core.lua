-- This contains the core options and keymaps required only for the most
-- basic of functionality.
-- NOTE this file should not introduce dependencies on external plugins

-- [[ Base Vim Options ]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ';'

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Conceal Settings
-- -- in json files, conceal the quotes
-- -- In org-mode conceal the links
-- -- Markdown links can get concealed with this also.
-- -- NOTE: Moved to org-mode config
vim.opt.conceallevel = 2
vim.opt.concealcursor = 'nc'
vim.opt.foldenable = true

-- Make line numbers default
vim.opt.number = false

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.opt.showmode = false
vim.opt.backup = false -- Don't create backup files
vim.opt.writebackup = false -- Don't create backup before writing
vim.opt.swapfile = false -- Don't create swap files
vim.opt.undofile = true -- Persistent undo

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.opt.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.opt.breakindent = true
vim.opt.autoindent = true -- Copy indent from current line when starting a new line
vim.opt.smartindent = true -- Do smart autoindenting when starting a new line
vim.opt.cindent = true -- Stricter rules for C programs
-- vim.opt.preserveindent = true -- Preserve kind of whitespace when changing indent
-- vim.opt.copyindent = true  -- Copy the structure of the existing lines indent when autoindenting
-- Enable filetype-based indentation
-- vim.cmd('filetype plugin indent on')

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
-- for all others use 4
vim.opt.tabstop = 4 -- Width of a tab character
vim.opt.shiftwidth = 4 -- Width of indentation (<<, >>)
vim.opt.expandtab = true -- Convert tabs to spaces (optional but recommended)
vim.opt.softtabstop = 4 -- Tab width in insert mode

vim.opt.sessionoptions:remove 'folds' -- Don't save folds in sessions

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 150

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 250

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Change Cwd to current file
vim.opt.autochdir = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with jables.
--   See `:help lua-options`
--   and `:help lua-guide-options`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- By default don't wrap
vim.opt.wrap = false
vim.opt.selection = 'exclusive' -- More like traditional GUI editors

-- editing style
-- Allow visual selection of blocks of text
-- that don't end on the same column number
vim.opt.virtualedit = 'block'

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.opt.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

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

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
vim.keymap.set('n', '<leader>H', '<C-w>H', { desc = 'Move window to the left' })
vim.keymap.set('n', '<leader>L', '<C-w>L', { desc = 'Move window to the right' })
vim.keymap.set('n', '<leader>J', '<C-w>J', { desc = 'Move window to the lower' })
vim.keymap.set('n', '<leader>K', '<C-w>K', { desc = 'Move window to the upper' })

-- Emacs-style line navigation
vim.keymap.set('i', '<C-a>', '<ESC>^i', { desc = 'Beginning of line' })
vim.keymap.set('n', '<C-a>', '^', { desc = 'Beginning of line' })
vim.keymap.set('i', '<C-e>', '<End>', { desc = 'End of line' })
vim.keymap.set('n', '<C-e>', '$', { desc = 'End of line' })

-- Visual mode improvements
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left (keep selection)' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right (keep selection)' })
vim.keymap.set('v', 'p', 'pgv', { desc = 'Paste (keep selection)' })

-- Terminal
vim.keymap.set('t', '<C-x>', '<C-\\><C-N>', { desc = 'Exit terminal mode' })

-- Quit commands
-- ============================================================================
-- Quit Operations
-- ============================================================================
vim.keymap.set('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit all' })
vim.keymap.set('n', '<leader>qQ', '<cmd>qa!<cr>', { desc = 'Quit all (force)' })
vim.keymap.set('n', '<leader>wq', '<cmd>wqa<cr>', { desc = 'Save and quit all' })
vim.keymap.set('n', '<C-x><C-c>', '<cmd>wqa!<cr>', { desc = 'Save and quit (force)' })
-- Toggles
vim.keymap.set('n', '<leader>tn', '<cmd>set number!<CR>', { desc = 'Toggle line numbers' })
vim.keymap.set(
  'n',
  '<leader>tr',
  '<cmd>set relativenumber!<CR>',
  { desc = 'Toggle relative numbers' }
)
vim.keymap.set('n', '<leader>ts', '<cmd>setlocal spell!<CR>', { desc = 'Toggle spell check' })
vim.keymap.set('n', '<leader>tw', '<cmd>set wrap!<CR>', { desc = 'Toggle word wrap' })

-- Support searching through config without plugins
local config_dir = vim.fn.stdpath 'config'

vim.keymap.set('n', '<leader>cf', function()
  -- globpath with 4th arg `true` returns a table directly, no split needed
  local files = vim.fn.globpath(config_dir, '**/*', false, true)
  files = vim.tbl_filter(function(f) return vim.fn.isdirectory(f) == 0 end, files)

  vim.ui.select(files, {
    prompt = 'Find nvim config files:',
    format_item = function(item) return item:gsub(config_dir .. '/', '') end,
  }, function(choice)
    if choice then vim.cmd.edit(choice) end
  end)
end, { desc = 'Find nvim config files' })

vim.keymap.set('n', '<leader>cg', function()
  local query = vim.fn.input 'Grep config> '
  if query == '' then return end

  vim.cmd('silent! vimgrep /' .. query .. '/gj ' .. config_dir .. '/**/*')
  vim.cmd 'copen'
end, { desc = 'Grep nvim config files' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
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
