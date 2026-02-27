-- lua/features/treesitter.lua

local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    event = { 'BufReadPost', 'BufNewFile' },
    cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },
    cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },
  },

  -- Text objects using treesitter
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

  -- Show context of current function/class
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

  -- Automatically close and rename HTML/XML tags
  {
    'windwp/nvim-ts-autotag',
    event = 'InsertEnter',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

  -- Better comment detection
  {
    'JoosepAlviste/nvim-ts-context-commentstring',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

function M.setup_treesitter()
  require('nvim-treesitter.config').setup({
    -- Languages to install
    ensure_installed = {
      -- core languages
      'rust',
      'c',
      'cpp',
      'python',
      'bash',

      -- config
      'toml',       -- Cargo.toml, pyproject.toml
      'yaml',       -- Config files
      'json',       -- Config files
      'cmake',      -- C/C++ build system
      'make',       -- Makefiles
      'dockerfile', -- Docker

      -- Documentation
      'markdown',
      'markdown_inline',
      'rst',        -- reStructuredText (Python docs)

      -- Neovim config
      'lua',
      'vim',
      'vimdoc',
      'query',      -- Treesitter queries

      -- Git
      'git_config',
      'git_rebase',
      'gitcommit',
      'gitignore',
      'diff',
    },

    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,

    -- Automatically install missing parsers when entering buffer
    auto_install = true,

    -- List of parsers to ignore installing (for performance)
    ignore_install = {},

    -- ========================================================================
    -- Highlighting
    -- ========================================================================
    highlight = {
      enable = true,

      -- Disable for large files
      disable = function(lang, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok and stats and stats.size > max_filesize then
          return true
        end
      end,

      -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
      -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
      additional_vim_regex_highlighting = true,
    },

    -- ========================================================================
    -- Indentation
    -- ========================================================================
    indent = {
      enable = true,
      -- Disable for specific languages if needed
      disable = { 'python' },  -- Python indentation can be tricky with TS
    },

    -- ========================================================================
    -- Incremental Selection
    -- ========================================================================
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = '<C-space>',
        node_incremental = '<C-space>',
        scope_incremental = '<C-s>',
        node_decremental = '<C-backspace>',
      },
    },

    -- ========================================================================
    -- Text Objects
    -- ========================================================================
    textobjects = {
      select = {
        enable = true,
        lookahead = true, -- Automatically jump forward to textobj

        keymaps = {
          -- Functions
          ['af'] = '@function.outer',
          ['if'] = '@function.inner',

          -- Classes
          ['ac'] = '@class.outer',
          ['ic'] = '@class.inner',

          -- Conditionals
          ['ai'] = '@conditional.outer',
          ['ii'] = '@conditional.inner',

          -- Loops
          ['al'] = '@loop.outer',
          ['il'] = '@loop.inner',

          -- Parameters/Arguments
          ['aa'] = '@parameter.outer',
          ['ia'] = '@parameter.inner',

          -- Comments
          ['a/'] = '@comment.outer',

          -- Blocks
          ['ab'] = '@block.outer',
          ['ib'] = '@block.inner',
        },
      },

      swap = {
        enable = true,
        swap_next = {
          ['<leader>a'] = '@parameter.inner',
        },
        swap_previous = {
          ['<leader>A'] = '@parameter.inner',
        },
      },

      move = {
        enable = true,
        set_jumps = true, -- Add jumps to jumplist

        goto_next_start = {
          [']f'] = '@function.outer',
          [']c'] = '@class.outer',
          [']a'] = '@parameter.inner',
        },
        goto_next_end = {
          [']F'] = '@function.outer',
          [']C'] = '@class.outer',
        },
        goto_previous_start = {
          ['[f'] = '@function.outer',
          ['[c'] = '@class.outer',
          ['[a'] = '@parameter.inner',
        },
        goto_previous_end = {
          ['[F'] = '@function.outer',
          ['[C'] = '@class.outer',
        },
      },

      lsp_interop = {
        enable = true,
        border = 'rounded',
        peek_definition_code = {
          ['<leader>df'] = '@function.outer',
          ['<leader>dF'] = '@class.outer',
        },
      },
    },

    -- ========================================================================
    -- Auto-tag (for HTML/XML-like languages)
    -- ========================================================================
    autotag = {
      enable = true,
      enable_rename = true,
      enable_close = true,
      enable_close_on_slash = true,
    },
  })
end

function M.setup_context()
  require('treesitter-context').setup({
    enable = true,
    max_lines = 3,            -- How many lines the window should span
    min_window_height = 0,    -- Minimum editor window height to enable context
    line_numbers = true,
    multiline_threshold = 20, -- Maximum number of lines to show for a single context
    trim_scope = 'outer',     -- Which context lines to discard if `max_lines` is exceeded
    mode = 'cursor',          -- Line used to calculate context ('cursor' or 'topline')
    separator = nil,          -- Separator between context and content
    zindex = 20,
    on_attach = nil,          -- Callback when attaching to a buffer
  })
end

function M.setup_context_commentstring()
  require('ts_context_commentstring').setup({
    enable_autocmd = false,
  })

  -- Integrate with Comment.nvim if available
  local ok, comment = pcall(require, 'Comment')
  if ok then
    comment.setup({
      pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
    })
  end
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Show installed parsers
function M.show_parsers()
  local parsers = require('nvim-treesitter.info').installed_parsers()
  print('Installed parsers:')
  for _, parser in ipairs(parsers) do
    print('  - ' .. parser)
  end
end

-- Check treesitter status for current buffer
function M.check_status()
  local ts_utils = require('nvim-treesitter.ts_utils')
  local highlighter = require('vim.treesitter.highlighter')

  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype

  print('Filetype: ' .. ft)
  print('Treesitter active: ' .. tostring(highlighter.active[buf] ~= nil))

  local parser = vim.treesitter.get_parser(buf)
  if parser then
    print('Parser: ' .. parser:lang())
  else
    print('No parser found')
  end
end

-- Toggle treesitter context
function M.toggle_context()
  require('treesitter-context').toggle()
end

-- Toggle treesitter highlight
function M.toggle_highlight()
  vim.cmd('TSToggle highlight')
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================

function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup('Treesitter', { clear = true })

  -- Folding using treesitter
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = { 'rust', 'c', 'cpp', 'python', 'lua', 'bash' },
    callback = function()
      vim.opt_local.foldmethod = 'expr'
      vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      vim.opt_local.foldenable = false  -- Don't fold by default
    end,
  })

  -- Better commenting for embedded languages (e.g., Rust macros, C++ templates)
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = '*',
    callback = function()
      -- Integration with Comment.nvim if available
      pcall(function()
        vim.bo.commentstring = require('ts_context_commentstring.internal').calculate_commentstring()
      end)
    end,
  })
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================

function M.setup_keymaps()
  local map = vim.keymap.set

  -- Treesitter commands
  map('n', '<leader>ts', M.show_parsers, { desc = 'Show TS Parsers' })
  map('n', '<leader>tc', M.check_status, { desc = 'Check TS Status' })
  map('n', '<leader>th', M.toggle_highlight, { desc = 'Toggle TS Highlight' })

  -- Context
  map('n', '<leader>tC', M.toggle_context, { desc = 'Toggle TS Context' })
  map('n', '[x', function()
    require('treesitter-context').go_to_context()
  end, { desc = 'Jump to Context' })

  -- Incremental selection (defined in config, but documented here)
  -- <C-space>     : Init selection
  -- <C-space>     : Increment selection
  -- <C-s>         : Increment scope
  -- <C-backspace> : Decrement selection

  -- Text objects (defined in config, documented here)
  -- af/if : function outer/inner
  -- ac/ic : class outer/inner
  -- ai/ii : conditional outer/inner
  -- al/il : loop outer/inner
  -- aa/ia : argument outer/inner
  -- ab/ib : block outer/inner

  -- Navigation
  -- ]f/[f : Next/prev function start
  -- ]F/[F : Next/prev function end
  -- ]c/[c : Next/prev class start
  -- ]C/[C : Next/prev class end
  -- ]a/[a : Next/prev argument

  -- Swap parameters
  -- <leader>a : Swap with next parameter
  -- <leader>A : Swap with previous parameter

  -- Peek definition
  -- <leader>df : Peek function definition
  -- <leader>dF : Peek class definition
end

-- ============================================================================
-- MAIN SETUP FUNCTION
-- ============================================================================

function M.setup()
  -- Setup main treesitter
  M.setup_treesitter()

  -- Setup context
  M.setup_context()

  -- Setup context commentstring
  M.setup_context_commentstring()

  -- Setup autocmds and keymaps
  M.setup_autocmds()
  M.setup_keymaps()
end

return M
