-- lua/modules/text_editing.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface

local env = require 'env'
local languages = require 'modules.text_editing.languages'

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
      build = ':MasonUpdate',
      lazy = false,
      opts = {
        install_root_dir = vim.fn.stdpath 'data' .. '/mason',
      },
    },

    -- mason-lspconfig: bridges mason and lspconfig
    -- Ensures servers listed in ensure_installed are present
    ['williamboman/mason-lspconfig.nvim'] = {
      dependencies = { 'williamboman/mason.nvim', 'neovim/nvim-lspconfig' },
      lazy = false,
      opts = {
        -- Query is deferred: languages module is loaded once at plugin
        -- resolution time, which is fine — specs are static tables.
        ensure_installed = languages.get_mason_lsp_packages(),
        automatic_enable = true,
      },
    },

    -- mason-tool-installer: installs formatters/linters via mason
    -- Separate from mason-lspconfig which only handles LSPs
    ['WhoIsSethDaniel/mason-tool-installer.nvim'] = {
      dependencies = { 'williamboman/mason.nvim' },
      lazy = false,
      opts = {
        ensure_installed = languages.get_mason_tool_packages(),
        auto_update = false,
        run_on_start = true,
      },
    },

    -- Treesitter: syntax parsing for highlighting, textobjects, context
    ['nvim-treesitter/nvim-treesitter'] = {
      branch = 'main',
      lazy = false,
      build = ':TSUpdate',
      dependencies = { 'nvim-treesitter/nvim-treesitter-textobjects' },
      config = function()
        require('nvim-treesitter').setup {
          install_dir = vim.fn.stdpath 'data' .. '/site',
        }

        -- Single source of truth: language specs + universal set
        local language_parsers = languages.get_treesitter_parsers()
        local all_parsers = vim.tbl_keys(
          vim.tbl_extend(
            'keep',
            vim.tbl_map(function() return true end, vim.iter(languages.universal_parsers):totable()),
            vim.tbl_map(function() return true end, vim.iter(language_parsers):totable())
          )
        )
        -- simpler dedup:
        local seen, parsers = {}, {}
        for _, p in ipairs(languages.universal_parsers) do
          if not seen[p] then
            seen[p] = true
            table.insert(parsers, p)
          end
        end
        for _, p in ipairs(language_parsers) do
          if not seen[p] then
            seen[p] = true
            table.insert(parsers, p)
          end
        end

        require('nvim-treesitter').install(parsers)

        vim.api.nvim_create_autocmd('FileType', {
          callback = function() pcall(vim.treesitter.start) end,
        })
      end,

      -- Textobject keymaps, highlight config, etc. live here in opts
      -- and are passed to the old-api setup if you use it, or configured
      -- via the module directly. Keep them here as they are generic,
      -- not language-specific.
      opts = {
        highlight = {
          enable = true,
          disable = function(_, buf)
            local max = 1.5 * 1024 * 1024
            local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
            return ok and stats and stats.size > max
          end,
        },
        indent = { enable = false },
        incremental_selection = {
          enable = true,
          keymaps = {
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
        -- Derived entirely from language specs
        formatters_by_ft = vim.tbl_extend(
          'keep',
          languages.get_formatters_by_ft(),
          -- Universal fallback: not language-specific, lives here
          { ['_'] = { 'trim_whitespace' } }
        ),
        format_on_save = {
          timeout_ms = 500,
          lsp_format = 'fallback',
        },
        -- Per-formatter config (condition functions, args, etc.)
        formatters = languages.get_conform_formatter_configs(),
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

    local lsp_config = require 'modules.text_editing.lsp'
    lsp_config.setup()
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

    -- local current_buf = vim.api.nvim_get_current_buf()
    -- local current_win = vim.api.nvim_get_current_win()
    --
    -- require('snacks').picker.lines {
    --   buf = current_buf,
    --   layout = {
    --     preset = 'dropdown',
    --     preview = false,
    --     layout = { height = 0.4 },
    --   },
    --
    --   on_change = function(_, item)
    --     if item and vim.api.nvim_win_is_valid(current_win) then
    --       vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
    --       vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
    --     end
    --   end,
    --
    --   confirm = function(picker, item)
    --     picker:close()
    --
    --     if item and vim.api.nvim_win_is_valid(current_win) then
    --       vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
    --       vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
    --     end
    --   end,
    -- }

    -- require 'modules.text_editing.pickers'
    vim.ui.picker.buffer_lines = function()
      local extra = require 'mini.extra'
      -- Capture source buffer before the picker opens
      local source_buf = vim.api.nvim_get_current_buf()
      local source_win = vim.api.nvim_get_current_win()
      require 'modules.text_editing.pickers'
      local shower = BufLinesShow.new(source_buf, source_win)
      extra.pickers.buf_lines({ scope = 'current' }, { source = { show = shower:as_fn() } })
      -- extra.pickers.buf_lines { scope = 'current' }
      -- extra.pickers.buf_lines({ scope = 'current' }, {
      --   source = {
      --     show = function(buf_id, items_to_show)
      --       if items_to_show and items_to_show[1] then
      --         -- Inspect both the text field and any other fields
      --         local item = items_to_show[1]
      --         vim.notify(
      --           string.format(
      --             'text: %q\nlnum: %s\nbufnr: %s\nkeys: %s',
      --             item.text or 'nil',
      --             tostring(item.lnum),
      --             tostring(item.bufnr),
      --             table.concat(vim.tbl_keys(item), ', ')
      --           )
      --         )
      --       end
      --     end,
      --   },
      -- })
    end
    vim.keymap.set('n', '<leader>sb', '', {
      silent = true,
      desc = 'text_editing.search_in_buffer',
      callback = function() vim.ui.picker.buffer_lines() end,
    })

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
