-- lua/features/syntax.lua
local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  -- ── Indentation ────────────────────────────────────────────────────────────
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
  },
  {
    'NMAC427/guess-indent.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
  },

  -- ── Auto-pairing ───────────────────────────────────────────────────────────
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },
  {
    'kylechui/nvim-surround',
    version = '*',
    event = { 'BufReadPost', 'BufNewFile' },
  },

  -- ── Structural editing ─────────────────────────────────────────────────────
  {
    'Wansmer/treesj',
    cmd = { 'TSJToggle', 'TSJSplit', 'TSJJoin' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },
  {
    'andymass/vim-matchup',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

  -- ── Embedded / aerospace specific ─────────────────────────────────────────
  {
    'monaqa/dial.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
  },
  {
    'danymat/neogen',
    cmd = { 'Neogen' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

  -- ── Visual aids ────────────────────────────────────────────────────────────
  {
    'HiPhish/rainbow-delimiters.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },

  -- ── Text manipulation ──────────────────────────────────────────────────────
  {
    'nvim-mini/mini.trailspace',
    version = '*',
    event = { 'BufReadPost', 'BufNewFile' },
  },
  {
    'nvim-mini/mini.move',
    version = '*',
    event = { 'BufReadPost', 'BufNewFile' },
  },
  {
    'numToStr/Comment.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'JoosepAlviste/nvim-ts-context-commentstring' },
    opts = function()
      return {
        -- Context-aware commenting via treesitter
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),

        toggler = {
          line = '<M-;>', -- Alt-; toggles current line
          block = '<M-:>', -- Alt-: toggles block comment
        },
        opleader = {
          line = '<M-;>', -- Alt-; in visual mode
          block = '<M-:>',
        },
        extra = {
          above = '<M-;>O', -- Add comment above
          below = '<M-;>o', -- Add comment below
          eol = '<M-;>A', -- Add comment at end of line
        },
        mappings = {
          basic = true,
          extra = true,
        },
      }
    end,
  },
  -- ── Documentation ──────────────────────────────────────────────────────────
  {
    'LudoPinelli/comment-box.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
  },
}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Filetypes common in aerospace / embedded work
local EMBEDDED_FILETYPES = {
  'c',
  'cpp',
  'rust',
  'asm',
  'cmake',
  'make',
  'python',
  'lua',
  'bash',
  'sh',
}

-- Filetypes where aggressive auto-pairing causes problems
-- (macro-heavy C headers, assembly, linker scripts)
local AUTOPAIR_DISABLED = {
  'asm',
  'S',
  'ld',
  'dts',
  'dtsi',
}

-- Filetypes where trailing whitespace stripping must be skipped
-- (some binary-adjacent or patch formats are whitespace-sensitive)
local TRAILSPACE_DISABLED = {
  'diff',
  'patch',
  'gitsendemail',
}

-- ============================================================================
-- INDENTATION
-- ============================================================================
function M.setup_indent_blankline()
  local ibl = require 'ibl'
  local hooks = require 'ibl.hooks'

  -- ── Scope highlight colours (inherits from your colorscheme) ──────────────
  local highlight = {
    'RainbowRed',
    'RainbowYellow',
    'RainbowBlue',
    'RainbowOrange',
    'RainbowGreen',
    'RainbowViolet',
    'RainbowCyan',
  }

  hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
    -- Colours are intentionally muted so they don't compete with syntax
    vim.api.nvim_set_hl(0, 'RainbowRed', { fg = '#4a2020' })
    vim.api.nvim_set_hl(0, 'RainbowYellow', { fg = '#4a3e20' })
    vim.api.nvim_set_hl(0, 'RainbowBlue', { fg = '#20304a' })
    vim.api.nvim_set_hl(0, 'RainbowOrange', { fg = '#4a3020' })
    vim.api.nvim_set_hl(0, 'RainbowGreen', { fg = '#20402a' })
    vim.api.nvim_set_hl(0, 'RainbowViolet', { fg = '#38204a' })
    vim.api.nvim_set_hl(0, 'RainbowCyan', { fg = '#20404a' })
  end)

  ibl.setup {
    indent = {
      -- Use a subtle character so guides don't dominate deeply-nested ISR code
      char = '│',
      tab_char = '│',
      highlight = highlight,
    },

    scope = {
      enabled = true,
      highlight = highlight,
      -- Show start and end of scope — useful for long struct initialisers
      show_start = true,
      show_end = true,
      -- TS nodes to treat as scopes
      include = {
        node_type = {
          -- C / C++
          c = { 'compound_statement', 'initializer_list', 'enumerator_list' },
          cpp = {
            'compound_statement',
            'initializer_list',
            'enumerator_list',
            'namespace_definition',
            'template_declaration',
          },
          -- Rust
          rust = {
            'block',
            'match_block',
            'use_list',
            'field_initializer_list',
          },
          -- Python
          python = { 'block', 'argument_list', 'parameters' },
          -- Lua
          lua = { 'block', 'table_constructor' },
        },
      },
    },

    exclude = {
      filetypes = {
        'help',
        'dashboard',
        'NvimTree',
        'Trouble',
        'lazy',
        'mason',
        'notify',
        'toggleterm',
        'lspinfo',
        'TelescopePrompt',
        'TelescopeResults',
        'overseer',
        'OverseerList',
      },
    },
  }

  -- Wire rainbow-delimiters into ibl scope colours
  local ok, rainbow = pcall(require, 'ibl.hooks')
  if ok then
    hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
  end
end

function M.setup_guess_indent()
  require('guess-indent').setup {
    auto_cmd = true, -- Run on BufReadPost automatically
    filetype_exclude = {
      'netrw',
      'tutor',
      'help',
    },
    buftype_exclude = {
      'help',
      'nofile',
      'terminal',
      'prompt',
    },
  }
end

-- ============================================================================
-- AUTO-PAIRING
-- ============================================================================
function M.setup_autopairs()
  local autopairs = require 'nvim-autopairs'
  local Rule = require 'nvim-autopairs.rule'
  local cond = require 'nvim-autopairs.conds'

  autopairs.setup {
    check_ts = true, -- Use treesitter for context
    ts_config = {
      -- Don't pair inside strings or comments
      lua = { 'string', 'source' },
      python = { 'string' },
      c = { 'string', 'comment' },
      cpp = { 'string', 'comment' },
      rust = { 'string' },
    },
    disable_filetype = AUTOPAIR_DISABLED,
    disable_in_macro = true, -- Critical for C macro-heavy codebases
    disable_in_visualblock = true,
    enable_check_bracket_line = true,
    -- Don't pair when the next char is already a closing delimiter
    enable_bracket_in_quote = false,
    -- Fast wrap: press <M-e> to wrap the next expression in a pair
    fast_wrap = {
      map = '<M-e>',
      chars = { '{', '[', '(', '"', "'" },
      pattern = [=[[%'%"%>%]%)%}%,]]=],
      end_key = '$',
      before_key = 'h',
      after_key = 'l',
      cursor_pos_before = true,
      keys = 'qwertyuiopzxcvbnmasdfghjkl',
      manual_position = true,
      highlight = 'Search',
      highlight_grey = 'Comment',
    },
  }

  -- ── Custom rules for embedded / aerospace work ────────────────────────────

  -- C/C++: auto-close angle brackets only in template context, not comparisons
  autopairs.add_rule(Rule('<', '>', { 'cpp', 'rust' })
    :with_pair(cond.before_regex '%a+') -- only after an identifier
    :with_pair(cond.not_after_regex '[%w_]'))

  -- C: auto-insert space inside block comment openers
  autopairs.add_rule(Rule('/*', ' */'):only_cr(false):set_end_pair_length(3))

  -- Rust: lifetime annotations — don't pair after apostrophe
  autopairs.add_rule(Rule("'", "'", 'rust'):with_pair(cond.not_before_regex '%a'))

  -- ── nvim-cmp integration ──────────────────────────────────────────────────
  local cmp_ok, cmp = pcall(require, 'cmp')
  if cmp_ok then
    local cmp_autopairs = require 'nvim-autopairs.completion.cmp'
    cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
  end
end

function M.setup_surround()
  require('nvim-surround').setup {
    keymaps = {
      -- Normal mode
      insert = '<C-g>s', -- Insert surround in insert mode
      insert_line = '<C-g>S',
      normal = 'ys', -- ys<motion><delimiter>
      normal_cur = 'yss', -- yss<delimiter> (current line)
      normal_line = 'yS',
      normal_cur_line = 'ySS',
      -- Visual mode
      visual = 'S', -- S<delimiter>
      visual_line = 'gS',
      -- Edit / delete
      delete = 'ds', -- ds<delimiter>
      change = 'cs', -- cs<old><new>
      change_line = 'cS',
    },

    aliases = {
      -- Shortcuts for common delimiter pairs
      ['a'] = '>', -- angle brackets (templates, generics)
      ['b'] = ')', -- brackets
      ['B'] = '}', -- braces
      ['r'] = ']', -- rect brackets
      -- Doxygen comment blocks
      ['d'] = { '/** ', ' */' },
    },

    highlight = { duration = 150 },

    move_cursor = 'begin',
  }
end

-- ============================================================================
-- STRUCTURAL EDITING
-- ============================================================================
function M.setup_treesj()
  local tsj = require 'treesj'

  tsj.setup {
    -- Use default keymaps (overridden below in setup_keymaps)
    use_default_keymaps = false,
    -- Check for syntax errors before splitting/joining
    check_syntax_error = true,
    -- Maximum line length before auto-splitting is triggered
    max_join_length = 100,
    -- Cursor stays at its original position after operation
    cursor_behavior = 'hold',
    -- Notify on error instead of raising
    notify_on_error = true,
  }
end

function M.setup_matchup()
  -- vim-matchup configuration is done via globals before the plugin loads
  -- Extended matching for preprocessor directives (critical for C/C++)
  vim.g.matchup_matchparen_enabled = 1
  vim.g.matchup_matchparen_deferred = 1 -- Defer to avoid cursor lag
  vim.g.matchup_matchparen_hi_surround_always = 1
  vim.g.matchup_matchparen_offscreen = { method = 'popup' } -- Show match in popup when off-screen

  -- Transmit to treesitter integration
  vim.g.matchup_treesitter_enabled = 1

  -- Performance guards for large generated files (AUTOSAR, etc.)
  vim.g.matchup_matchparen_deferred_show_delay = 100
  vim.g.matchup_matchparen_deferred_hide_delay = 700

  -- Always match these even without treesitter
  -- Covers: C preprocessor, Makefile conditionals, Rust cfg blocks
  vim.g.matchup_override_vimtex = 0
end

-- ============================================================================
-- DIAL (INCREMENT / DECREMENT)
-- ============================================================================
function M.setup_dial()
  local dial_config = require 'dial.config'
  local augend = require 'dial.augend'

  -- ── Augend groups ─────────────────────────────────────────────────────────

  -- Default group: active in all buffers
  local default_group = {
    augend.integer.alias.decimal,
    augend.integer.alias.decimal_int,
    augend.integer.alias.hex, -- 0xFF  ← critical for register work
    augend.integer.alias.octal, -- 0o77
    augend.integer.alias.binary, -- 0b1010
    augend.constant.alias.bool, -- true/false
    augend.semver.alias.semver, -- 1.2.3
    augend.date.alias['%Y/%m/%d'],
    augend.date.alias['%Y-%m-%d'],
  }

  -- C / C++ specific: register masks, bit fields, common constants
  local c_cpp_group = vim.list_extend(vim.deepcopy(default_group), {
    -- Bit-shift amounts (common in register definitions)
    augend.integer.new {
      radix = 16,
      prefix = '0x',
      natural = false,
      case = 'upper', -- 0xFF not 0xff
    },
    -- Common boolean-like macros
    augend.constant.new {
      elements = { 'TRUE', 'FALSE' },
      word = true,
      cyclic = true,
    },
    -- Enable/Disable pattern (AUTOSAR / HAL style)
    augend.constant.new {
      elements = { 'ENABLE', 'DISABLE' },
      word = true,
      cyclic = true,
    },
    -- GPIO pin states
    augend.constant.new {
      elements = { 'GPIO_PIN_SET', 'GPIO_PIN_RESET' },
      word = true,
      cyclic = true,
    },
    -- Access specifiers
    augend.constant.new {
      elements = { 'static', 'extern' },
      word = true,
      cyclic = true,
    },
  })

  -- Rust specific
  local rust_group = vim.list_extend(vim.deepcopy(default_group), {
    augend.constant.new {
      elements = { 'Some', 'None' },
      word = true,
      cyclic = true,
    },
    augend.constant.new {
      elements = { 'Ok', 'Err' },
      word = true,
      cyclic = true,
    },
    -- Rust visibility
    augend.constant.new {
      elements = { 'pub', 'pub(crate)', 'pub(super)' },
      word = false,
      cyclic = true,
    },
  })

  -- Python specific
  local python_group = vim.list_extend(vim.deepcopy(default_group), {
    augend.constant.new {
      elements = { 'True', 'False' },
      word = true,
      cyclic = true,
    },
    augend.constant.new {
      elements = { 'None', 'True', 'False' },
      word = true,
      cyclic = true,
    },
  })

  dial_config.augends:register_group {
    default = default_group,
    c = c_cpp_group,
    cpp = c_cpp_group,
    rust = rust_group,
    python = python_group,
  }
end

-- ============================================================================
-- NEOGEN (DOCUMENTATION GENERATION)
-- ============================================================================
function M.setup_neogen()
  require('neogen').setup {
    enabled = true,
    snippet_engine = 'luasnip', -- Change to 'vsnip' if preferred
    enable_placeholders = true,

    languages = {
      -- ── C: Doxygen ──────────────────────────────────────────────────────
      c = {
        template = {
          annotation_convention = 'doxygen',
          -- Custom Doxygen template suited for DO-178C / MISRA codebases
          -- Includes @req for requirements traceability
          position = 'above',
        },
      },

      -- ── C++: Doxygen ────────────────────────────────────────────────────
      cpp = {
        template = {
          annotation_convention = 'doxygen',
          position = 'above',
        },
      },

      -- ── Rust: rustdoc ───────────────────────────────────────────────────
      rust = {
        template = {
          annotation_convention = 'rustdoc',
        },
      },

      -- ── Python: Google style (common in aerospace tooling) ───────────────
      python = {
        template = {
          annotation_convention = 'google_docstrings',
        },
      },

      -- ── Lua ─────────────────────────────────────────────────────────────
      lua = {
        template = {
          annotation_convention = 'ldoc',
        },
      },
    },
  }
end

-- ============================================================================
-- RAINBOW DELIMITERS
-- ============================================================================
function M.setup_rainbow_delimiters()
  local rainbow = require 'rainbow-delimiters'

  -- Strategy: use treesitter globally, fall back to global for unsupported ft
  vim.g.rainbow_delimiters = {
    strategy = {
      [''] = rainbow.strategy['global'],
      commonlisp = rainbow.strategy['local'],
    },

    query = {
      [''] = 'rainbow-delimiters',
      lua = 'rainbow-blocks',
      -- Use parens query for C/C++ to catch macro argument lists
      c = 'rainbow-delimiters',
      cpp = 'rainbow-delimiters',
      rust = 'rainbow-delimiters',
      python = 'rainbow-delimiters',
    },

    -- Map highlight priority to the same colours as ibl
    highlight = {
      'RainbowDelimiterRed',
      'RainbowDelimiterYellow',
      'RainbowDelimiterBlue',
      'RainbowDelimiterOrange',
      'RainbowDelimiterGreen',
      'RainbowDelimiterViolet',
      'RainbowDelimiterCyan',
    },

    -- Don't colorize when nesting exceeds this (performance guard)
    blacklist = { 'html', 'xml' },
  }
end

-- ============================================================================
-- MINI MODULES
-- ============================================================================
function M.setup_mini_trailspace()
  require('mini.trailspace').setup()

  -- Auto-trim on save for relevant filetypes
  local augroup = vim.api.nvim_create_augroup('TrailspaceTrim', { clear = true })

  vim.api.nvim_create_autocmd('BufWritePre', {
    group = augroup,
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype

      -- Skip filetypes where whitespace is significant
      for _, disabled in ipairs(TRAILSPACE_DISABLED) do
        if ft == disabled then return end
      end

      -- Skip generated / vendored files
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if
        name:match '/vendor/'
        or name:match '/generated/'
        or name:match '%.pb%.'
        or name:match '_autogen'
      then
        return
      end

      require('mini.trailspace').trim()
      require('mini.trailspace').trim_last_lines()
    end,
  })
end

function M.setup_mini_move()
  require('mini.move').setup {
    mappings = {
      -- Move visual selection with Alt+hjkl (Doom drag-stuff equivalent)
      left = '<M-h>',
      right = '<M-l>',
      down = '<M-j>',
      up = '<M-k>',
      -- Move current line in normal mode
      line_left = '<M-h>',
      line_right = '<M-l>',
      line_down = '<M-j>',
      line_up = '<M-k>',
    },
    options = {
      -- Re-indent after move (important for C/Python indentation semantics)
      reindent_linewise = true,
    },
  }
end

-- ============================================================================
-- COMMENT BOX
-- ============================================================================
function M.setup_comment_box()
  require('comment-box').setup {
    doc_width = 80, -- Standard for most aerospace coding standards
    box_width = 80,
    borders = {
      top = '─',
      bottom = '─',
      left = '│',
      right = '│',
      top_left = '╭',
      top_right = '╮',
      bottom_left = '╰',
      bottom_right = '╯',
    },
    line_width = 80,
    lines = {
      line = '─',
      line_start = '├',
      line_end = '┤',
    },
    outer_blank_lines_above = false,
    outer_blank_lines_below = false,
    inner_blank_lines = false,
    line_blank_line_above = false,
    line_blank_line_below = false,
  }
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Manually trigger guess-indent on current buffer
function M.detect_indent()
  require('guess-indent').set_from_buffer 'auto_cmd'
  vim.notify(
    string.format('Indent: %s %d', vim.bo.expandtab and 'spaces' or 'tabs', vim.bo.shiftwidth),
    vim.log.levels.INFO,
    { title = 'syntax' }
  )
end

-- Report current buffer indentation settings
function M.show_indent_info()
  vim.notify(
    string.format(
      'tabstop=%d  shiftwidth=%d  expandtab=%s  filetype=%s',
      vim.bo.tabstop,
      vim.bo.shiftwidth,
      tostring(vim.bo.expandtab),
      vim.bo.filetype
    ),
    vim.log.levels.INFO,
    { title = 'syntax: indent' }
  )
end

-- Toggle indent guides
function M.toggle_indent_guides()
  require('ibl').update { enabled = not require('ibl.config').get_config(0).enabled }
end

-- Toggle rainbow delimiters for current buffer
function M.toggle_rainbow()
  local rainbow = require 'rainbow-delimiters'
  if rainbow.is_enabled(0) then
    rainbow.disable(0)
    vim.notify('Rainbow delimiters disabled', vim.log.levels.INFO, { title = 'syntax' })
  else
    rainbow.enable(0)
    vim.notify('Rainbow delimiters enabled', vim.log.levels.INFO, { title = 'syntax' })
  end
end

-- Generate doc comment for symbol under cursor
function M.generate_doc()
  local ft = vim.bo.filetype
  if not vim.tbl_contains(EMBEDDED_FILETYPES, ft) then
    vim.notify('Neogen: no template for filetype ' .. ft, vim.log.levels.WARN, { title = 'syntax' })
    return
  end
  require('neogen').generate()
end

-- Generate a section comment box (header file section dividers etc.)
function M.insert_section_box() require('comment-box').lcbox(10) end

-- Generate a line divider
function M.insert_divider() require('comment-box').line(1) end

-- Trim trailing whitespace in current buffer immediately
function M.trim_whitespace()
  require('mini.trailspace').trim()
  require('mini.trailspace').trim_last_lines()
  vim.notify('Trailing whitespace removed', vim.log.levels.INFO, { title = 'syntax' })
end

-- Dial helpers: expose named increment/decrement respecting ft-specific groups
function M.dial_increment(mode)
  local map = require 'dial.map'
  local ft = vim.bo.filetype
  local group = ({ c = 'c', cpp = 'cpp', rust = 'rust', python = 'python' })[ft] or 'default'
  return map.inc_normal(group)
end

function M.dial_decrement(mode)
  local map = require 'dial.map'
  local ft = vim.bo.filetype
  local group = ({ c = 'c', cpp = 'cpp', rust = 'rust', python = 'python' })[ft] or 'default'
  return map.dec_normal(group)
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  local map = vim.keymap.set

  -- ── Indentation ─────────────────────────────────────────────────────────
  map('n', '<leader>si', M.show_indent_info, { desc = 'Show Indent Info' })
  map('n', '<leader>sd', M.detect_indent, { desc = 'Detect Indent' })
  map('n', '<leader>sg', M.toggle_indent_guides, { desc = 'Toggle Indent Guides' })

  -- ── Structural editing ──────────────────────────────────────────────────
  map('n', '<leader>sj', '<cmd>TSJToggle<cr>', { desc = 'Split/Join Toggle' })
  map('n', '<leader>sJ', '<cmd>TSJSplit<cr>', { desc = 'Split' })
  map('n', '<leader>sk', '<cmd>TSJJoin<cr>', { desc = 'Join' })

  -- ── Documentation ───────────────────────────────────────────────────────
  map('n', '<leader>nd', M.generate_doc, { desc = 'Generate Doc Comment' })
  map('n', '<leader>nb', M.insert_section_box, { desc = 'Insert Section Box' })
  map('n', '<leader>nl', M.insert_divider, { desc = 'Insert Divider Line' })

  -- ── Whitespace ──────────────────────────────────────────────────────────
  map('n', '<leader>sw', M.trim_whitespace, { desc = 'Trim Whitespace' })

  -- ── Rainbow ─────────────────────────────────────────────────────────────
  map('n', '<leader>sr', M.toggle_rainbow, { desc = 'Toggle Rainbow Delimiters' })

  -- ── Dial: increment / decrement ─────────────────────────────────────────
  -- Normal mode
  map('n', '<C-a>', function() return M.dial_increment() end, { expr = true, desc = 'Increment' })
  map('n', '<C-x>', function() return M.dial_decrement() end, { expr = true, desc = 'Decrement' })
  -- Visual mode (operates on all selected values)
  map(
    'v',
    '<C-a>',
    require('dial.map').inc_visual 'default',
    { expr = true, desc = 'Increment (visual)' }
  )
  map(
    'v',
    '<C-x>',
    require('dial.map').dec_visual 'default',
    { expr = true, desc = 'Decrement (visual)' }
  )
  -- g<C-a> / g<C-x>: sequential increment across visual selection
  map(
    'v',
    'g<C-a>',
    require('dial.map').inc_gvisual 'default',
    { expr = true, desc = 'Sequential Increment' }
  )
  map(
    'v',
    'g<C-x>',
    require('dial.map').dec_gvisual 'default',
    { expr = true, desc = 'Sequential Decrement' }
  )

  -- ── Surround (documented here, configured in setup_surround) ────────────
  -- ys<motion><delim>  : surround
  -- ds<delim>          : delete surround
  -- cs<old><new>       : change surround
  -- S<delim>           : surround visual selection
end

-- ============================================================================
-- MAIN SETUP
-- ============================================================================
function M.setup()
  M.setup_indent_blankline()
  M.setup_guess_indent()
  M.setup_autopairs()
  -- M.setup_surround()
  M.setup_treesj()
  M.setup_matchup()
  M.setup_dial()
  M.setup_neogen()
  M.setup_rainbow_delimiters()
  -- M.setup_mini_trailspace()
  M.setup_mini_move()
  M.setup_comment_box()
  M.setup_keymaps()
end

return M
