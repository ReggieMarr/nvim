-- lua/modules/text_editing.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface

local env = require 'env'

-- ── Mason setup (async with progress) ───────────────────────────
local function setup_mason()
  vim.schedule(function()
    vim.notify('Initializing Mason tools…', vim.log.levels.INFO, {
      title = 'language.mason',
      kind = 'progress',
    })
    require('mason').setup()

    vim.defer_fn(function()
      require('mason-tool-installer').setup {
        ensure_installed = mason_formatter_names(),
        auto_update = false,
        run_on_start = true,
      }

      vim.notify('Formatter tools ensured', vim.log.levels.INFO, {
        title = 'language.mason',
        kind = 'progress',
      })
    end, 0)

    vim.defer_fn(function()
      require('mason-lspconfig').setup {
        automatic_enable = true,
        ensure_installed = mason_lsp_names(),
      }

      vim.notify('LSP servers configured', vim.log.levels.INFO, {
        title = 'language.mason',
        kind = 'progress',
      })
    end, 0)

    vim.defer_fn(
      function()
        vim.notify('Mason setup complete', vim.log.levels.INFO, {
          title = 'language.mason',
          kind = 'progress',
        })
      end,
      50
    )
  end)
end

return env.module.register {
  name = 'text_editing',
  domain = 'text_editing',
  depends_on = {},
  optional_deps = {},

  -- ── Plugin option contributions ──────────────────────────────────────
  -- Each key is a plugin string. Values are merged across all modules
  -- before being passed to lazy. No config functions here: setup() below
  -- handles all env surface registrations after plugins are loaded.

  plugins = {
    -- Mason: LSP/formatter/linter installer
    ['williamboman/mason.nvim'] = {
      -- Build step ensures mason's internal registry is compiled
      build = ':MasonUpdate',
      opts = {
        -- Install mason packages to a stable path so lazy
        -- changes don't trigger reinstalls
        install_root_dir = vim.fn.stdpath 'data' .. '/mason',
      },
    },

    -- mason-lspconfig: bridges mason and lspconfig
    -- Ensures servers listed in ensure_installed are present
    ['williamboman/mason-lspconfig.nvim'] = {
      dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
    },

    -- mason-tool-installer: installs formatters/linters via mason
    -- Separate from mason-lspconfig which only handles LSPs
    ['WhoIsSethDaniel/mason-tool-installer.nvim'] = {
      dependencies = { 'williamboman/mason.nvim' },
    },
    -- Treesitter: syntax parsing for highlighting, textobjects, context
    ['nvim-treesitter/nvim-treesitter'] = {
      branch = 'main',
      lazy = false,
      build = ':TSUpdate',
      dependencies = {
        'nvim-treesitter/nvim-treesitter-textobjects',
      },
      opts = {
        ensure_installed = {
          'lua',
          'luadoc',
          'python',
          'vim',
          'vimdoc',
          'markdown',
          'markdown_inline',
          'bash',
          'json',
          'jsonc',
          'toml',
          'yaml',
          'regex',
        },
        auto_install = true,
        highlight = {
          enable = true,
          disable = function(_, buf)
            -- Disable on large files: checked via state if available,
            -- otherwise fall back to direct size check
            local max = 1.5 * 1024 * 1024
            local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
            return ok and stats and stats.size > max
          end,
        },
        indent = { enable = false },
        incremental_selection = {
          enable = true,
          keymaps = {
            -- These are the only keymaps set directly rather than
            -- through env.articulation: treesitter's incremental
            -- selection is modal and doesn't map cleanly to the
            -- action registry model
            init_selection = '<C-space>',
            node_incremental = '<C-space>',
            scope_incremental = '<C-S-space>',
            node_decremental = '<BS>',
          },
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              [']f'] = '@function.outer',
              [']c'] = '@class.outer',
            },
            goto_previous_start = {
              ['[f'] = '@function.outer',
              ['[c'] = '@class.outer',
            },
          },
        },
      },
      config = function()
        require('nvim-treesitter').setup {
          install_dir = vim.fn.stdpath 'data' .. '/site',
        }

        -- -- Install parsers (async, idempotent)
        -- require('nvim-treesitter').install {
        --   'lua',
        --   'bash',
        --   'json',
        --   'yaml',
        --   'markdown',
        --   'vim',
        --   'python',
        --   'go',
        --   'rust',
        --   'zig',
        --   'toml',
        --   'html',
        --   'css',
        --   'javascript',
        --   'typescript',
        -- }

        -- Enable treesitter highlighting
        vim.api.nvim_create_autocmd('FileType', {
          callback = function() pcall(vim.treesitter.start) end,
        })
      end,
    },

    -- Treesitter context: sticky function/class header at top of window
    ['nvim-treesitter/nvim-treesitter-context'] = {
      dependencies = { 'nvim-treesitter/nvim-treesitter' },
      opts = {
        enable = true,
        max_lines = 4,
        trim_scope = 'outer',
        mode = 'cursor',
        separator = '─',
      },
    },
    ['nmac427/guess-indent.nvim'] = {
      config = function() require('guess-indent').setup {} end,
    },
    -- conform.nvim: formatting
    ['stevearc/conform.nvim'] = {
      event = { 'BufWritePre' },
      cmd = { 'ConformInfo' },
      opts = {
        formatters_by_ft = {
          lua = { 'stylua' },
          python = {
            'ruff_format', -- fast, uv-aware
            'ruff_organize_imports',
          },
          -- Fallback for any filetype with an LSP that can format
          ['_'] = { 'trim_whitespace' },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_format = 'fallback', -- use LSP if no conform formatter
        },
        formatters = {
          stylua = {
            -- stylua reads StyLua.toml from the project root
            -- no extra config needed; uv projects have pyproject.toml
            -- stylua has its own config discovery
          },
          ruff_format = {
            -- ruff respects pyproject.toml [tool.ruff] automatically
            condition = function(_, ctx)
              -- only run ruff in python projects
              return vim.fs.find({ 'pyproject.toml', 'ruff.toml', '.ruff.toml' }, { path = ctx.filename, upward = true })[1] ~= nil
            end,
          },
        },
      },
    },
    -- Completion engine
    ['saghen/blink.cmp'] = {
      version = '*',
      dependencies = {
        'rafamadriz/friendly-snippets',
      },
      opts = {
        keymap = {
          -- blink's keymap system is internal to the completion UI
          -- not routed through env.articulation (completion is modal)
          preset = 'default',
          ['<Tab>'] = { 'select_next', 'snippet_forward', 'fallback' },
          ['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
          ['<CR>'] = { 'accept', 'fallback' },
          ['<C-e>'] = { 'hide' },
          ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        },
        completion = {
          accept = { auto_brackets = { enabled = true } },
          documentation = {
            auto_show = true,
            auto_show_delay_ms = 200,
            window = { border = 'rounded' },
          },
          menu = {
            border = 'rounded',
            draw = {
              treesitter = { 'lsp' },
              columns = {
                { 'label', 'label_description', gap = 1 },
                { 'kind_icon', 'kind' },
              },
            },
          },
          ghost_text = { enabled = true },
        },
        sources = {
          default = { 'lsp', 'path', 'snippets', 'buffer' },
        },
        signature = {
          enabled = true,
          window = { border = 'rounded' },
        },
      },
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.

  setup = function()
    -- ── Text Editing ────────────────────────────────────────────────

    -- Async call to setup dependencies
    -- setup_mason()
    -- ── Diagnostic display configuration ──────────────────────────
    vim.diagnostic.config {
      -- Can switch between these as you prefer
      virtual_lines = false, -- Teest shows up underneath the line, with virtual lines

      -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
      jump = { float = true },
      virtual_text = {
        enabled = true,
        spacing = 4,
        format = function(diagnostic)
          -- Truncate long messages to keep virtual text readable
          local msg = diagnostic.message
          if #msg > 60 then msg = msg:sub(1, 57) .. '...' end
          -- Include source when multiple servers are attached
          local source = diagnostic.source
          if source then msg = string.format('%s [%s]', msg, source) end
          return msg
        end,
      },
      -- Signs in the sign column
      underline = { severity = vim.diagnostic.severity.ERROR },
      update_in_insert = false, -- only update diagnostics on leaving insert
      severity_sort = true,
      float = {
        border = 'rounded',
        source = 'if_many',
        header = '',
        prefix = '',
      },
    }
    vim.ui.picker.diagnostics = function(o) require('snacks').picker.diagnostics(o) end

    vim.keymap.set('n', '<leader>lD', function() vim.ui.picker.diagnostics() end, {
      silent = true,
      desc = 'language.find_diagnostics',
    })

    vim.keymap.set(
      'n',
      '<leader>ud',
      function() vim.diagnostic.enable(not vim.diagnostic.is_enabled()) end,
      { desc = 'interface.toggle_diagnostics', silent = true }
    )

    ----------------------------------------------------------------
    -- Buffer search (Snacks picker)
    ----------------------------------------------------------------


    -- vim.ui.pickers.buffer_lines = function()
    --     local current_buf = vim.api.nvim_get_current_buf()
    --     local current_win = vim.api.nvim_get_current_win()
    --
    --     require('snacks').picker.lines {
    --       buf = current_buf,
    --       layout = {
    --         preset = 'dropdown',
    --         preview = false,
    --         layout = { height = 0.4 },
    --       },
    --
    --       on_change = function(_, item)
    --         if item and vim.api.nvim_win_is_valid(current_win) then
    --           vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
    --           vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
    --         end
    --       end,
    --
    --       confirm = function(picker, item)
    --         picker:close()
    --
    --         if item and vim.api.nvim_win_is_valid(current_win) then
    --           vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
    --           vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
    --         end
    --      end,
    --     }
    -- end
    -- vim.keymap.set('n', '<leader>sb', '', {
    --   silent = true,
    --   desc = 'text_editing.search_in_buffer',
    --   callback = function()
    --     vim.ui.pickers.buffer_lines()
    --   end,
    -- })

    ----------------------------------------------------------------
    -- Emacs-style navigation
    ----------------------------------------------------------------

    vim.keymap.set('n', '<C-a>', '^', {
      silent = true,
      desc = 'text_editing.emacs_beginning_of_line',
    })

    ----------------------------------------------------------------
    -- Emacs-style save
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>fs', '<cmd>write<cr>', {
      silent = true,
      desc = 'text_editing.save_buffer',
    })
  end,
}
