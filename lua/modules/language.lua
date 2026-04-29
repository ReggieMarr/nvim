-- lua/modules/language.lua
-- Language module: LSP, treesitter, completion, formatting, diagnostics.
--
-- Provides:
--   No new capabilities (consumes picker, notifier)
--
-- Extends capabilities:
--   picker — LSP-specific finders (references, symbols, diagnostics)
--
-- Registers state:
--   lsp.attached_servers   — clients attached to current buffer
--   lsp.diagnostics        — current buffer diagnostic list
--   lsp.current_symbol     — symbol under cursor (for winbar)
--   lsp.capabilities       — server capability map per client
--
-- Registers display:
--   language.diagnostics_signs    — sign column diagnostic indicators
--   language.diagnostics_vtext    — inline diagnostic virtual text
--   language.inlay_hints          — LSP inlay hints
--   language.treesitter_context   — sticky context header
--
-- Domain: language

local env = require 'env'

-- ── Language server definitions ────────────────────────────────────────
-- Each entry describes one LSP server.
-- Kept as a module-level table so the setup() function stays readable
-- and adding a new language means adding one entry here.
--
---@class ServerSpec
---@field mason_name? string    Name in mason registry (if different from lspconfig key)
---@field install boolean       Whether mason should ensure this is installed
---@field config table          lspconfig setup() options
---@field formatters? string[]  mason formatter names to install alongside the LSP

local servers = {

  -- ── Lua ─────────────────────────────────────────────────────────────
  lua_ls = {
    install = true,
    config = {
      cmd = { 'lua-language-server' },
      settings = {
        Lua = {
          runtime = {
            version = 'LuaJIT',
          },
          workspace = {
            checkThirdParty = false,
            -- Make lua_ls aware of the Neovim runtime and config.
            -- Without this, every vim.* call is an "undefined global" warning.
            library = vim.list_extend(vim.api.nvim_get_runtime_file('', true), {
              vim.fn.stdpath 'config' .. '/lua',
              '${3rd}/luv/library',
              '${3rd}/busted/library',
            }),
          },
          completion = {
            callSnippet = 'Replace',
          },
          hint = {
            enable = true,
            arrayIndex = 'Disable', -- too noisy in config files
            setType = true,
          },
          diagnostics = {
            -- Globals that lua_ls doesn't know about
            globals = { 'vim' },
            -- Disable selected diagnostics rather than all
            disable = { 'missing-fields' },
          },
          telemetry = { enable = false },
          format = { enable = false }, -- formatting handled by stylua via conform
        },
      },
    },
    formatters = { 'stylua' },
  },

  -- ── Python ──────────────────────────────────────────────────────────
  -- basedpyright: a community fork of pyright with better defaults
  -- and more complete type narrowing.
  -- uv manages the virtual environment; we detect it and point the LSP at it.
  basedpyright = {
    install = true,
    config = {
      cmd = { 'basedpyright-langserver', '--stdio' },
      -- root_dir: find the project root by walking up from the current file
      -- looking for uv-specific markers before falling back to generic ones
      root_dir = function(fname)
        local lspconfig_util = require 'lspconfig.util'
        return lspconfig_util.root_pattern(
          'uv.lock', -- uv project lockfile: most specific signal
          'pyproject.toml', -- uv and other tools write this
          '.python-version', -- uv and pyenv both use this
          'setup.cfg',
          'setup.py',
          'requirements.txt',
          '.git'
        )(fname)
      end,

      -- before_init: resolve the uv virtual environment before the
      -- server starts so it analyzes the correct interpreter and packages
      before_init = function(_, config)
        local root = config.root_dir
        local venv = nil

        -- uv creates .venv in the project root by default
        local uv_venv = root and (root .. '/.venv')
        if uv_venv and vim.uv.fs_stat(uv_venv) then venv = uv_venv end

        -- If no .venv found, ask uv where the environment is.
        -- This handles `uv run` style projects and non-default venv paths.
        if not venv then
          local result = vim.system({ 'uv', 'python', 'find' }, { cwd = root, text = true }):wait()

          if result.code == 0 and result.stdout then
            -- uv python find returns the python binary path
            -- strip the binary to get the venv root
            local python_path = result.stdout:gsub('%s+$', '')
            -- typical: /path/to/.venv/bin/python
            venv = python_path:match '^(.+)/bin/python' or python_path:match '^(.+)/Scripts/python'
          end
        end

        if venv then
          config.settings.python = config.settings.python or {}
          config.settings.python.pythonPath = venv .. '/bin/python'
          -- Tell basedpyright where to find the venv for import resolution
          config.settings.basedpyright = config.settings.basedpyright or {}
          config.settings.basedpyright.venvPath = vim.fn.fnamemodify(venv, ':h')
          config.settings.basedpyright.venv = vim.fn.fnamemodify(venv, ':t')
        end
      end,

      settings = {
        basedpyright = {
          analysis = {
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
            diagnosticMode = 'workspace',
            typeCheckingMode = 'standard',
            -- Inlay hints configuration
            inlayHints = {
              variableTypes = true,
              functionReturnTypes = true,
              callArgumentNames = true,
              pytestParameters = true,
            },
          },
        },
      },
    },
  },

  -- ── Ruff LSP ──────────────────────────────────────────────────────────
  -- Ruff provides fast linting and import organization as a language server.
  -- Runs alongside basedpyright: pyright handles type checking,
  -- ruff handles linting and formatting.
  ruff = {
    install = true,
    config = {
      cmd = { 'ruff', 'server' },
      root_dir = function(fname) return require('lspconfig.util').root_pattern('ruff.toml', '.ruff.toml', 'pyproject.toml', 'uv.lock', '.git')(fname) end,
      on_attach = function(client, _)
        -- Disable ruff's hover in favor of basedpyright's
        -- ruff hover only shows linting rule docs, not symbol info
        client.server_capabilities.hoverProvider = false
      end,
      init_options = {
        settings = {
          lint = { enable = true },
          format = { enable = true },
          organizeImports = true,
          fixAll = true,
        },
      },
    },
    -- ruff the formatter is installed via the ruff LSP mason package
    -- no separate formatter entry needed
  },
}

-- ── Helper: derive mason package names ──────────────────────────────────
-- mason-lspconfig maps lspconfig server names to mason package names.
-- For servers where the mapping isn't automatic, mason_name overrides.
local function mason_lsp_names()
  local names = {}
  for server, spec in pairs(servers) do
    if spec.install then table.insert(names, spec.mason_name or server) end
  end
  return names
end

local function mason_formatter_names()
  local seen, names = {}, {}
  for _, spec in pairs(servers) do
    for _, fmt in ipairs(spec.formatters or {}) do
      if not seen[fmt] then
        seen[fmt] = true
        table.insert(names, fmt)
      end
    end
  end
  return names
end

-- ── Module registration ──────────────────────────────────────────────────

return env.module.register {
  name = 'language',
  domain = 'language',
  depends_on = { 'interface' },
  optional_deps = { 'filesystem' },

  -- ── Plugin option contributions ────────────────────────────────────
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
      opts = {
        ensure_installed = mason_lsp_names(),
        automatic_installation = true,
      },
    },

    -- nvim-lspconfig: the actual LSP client configuration
    ['neovim/nvim-lspconfig'] = {
      -- No opts: server configuration happens in setup()
      -- where we can reference the servers table and apply
      -- per-server before_init/root_dir functions correctly
    },

    -- mason-tool-installer: installs formatters/linters via mason
    -- Separate from mason-lspconfig which only handles LSPs
    ['WhoIsSethDaniel/mason-tool-installer.nvim'] = {
      dependencies = { 'williamboman/mason.nvim' },
      opts = {
        auto_update = false,
        run_on_start = true,
      },
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

        -- Install parsers (async, idempotent)
        require('nvim-treesitter').install {
          'lua',
          'bash',
          'json',
          'yaml',
          'markdown',
          'vim',
          'python',
          'go',
          'rust',
          'zig',
          'toml',
          'html',
          'css',
          'javascript',
          'typescript',
        }

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
    ['nvim-mini/mini.extra'] = {
      version = false,
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  setup = function()
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
          }

          vim.notify('Formatter tools ensured', vim.log.levels.INFO, {
            title = 'language.mason',
            kind = 'progress',
          })
        end, 0)

        vim.defer_fn(function()
          require('mason-lspconfig').setup {
            automatic_enable = true,
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
    -- TODO this should be defined along with the plugin config and called by an autocmd
    setup_mason()

    vim.keymap.set('n', '<leader>lR', '', {
      desc = 'language.conform_info',
      silent = true,
      callback = function() vim.cmd 'ConformInfo' end,
    })

    -- ── Picker capability extensions ───────────────────────────────
    -- Extend the picker with LSP-specific finders.
    -- vim.ui.picker.lsp_references = function(o) require('snacks').picker.lsp_references(o) end
    vim.ui.picker.lsp_definitions = function(o) require('snacks').picker.lsp_definitions(o) end
    -- vim.ui.picker.lsp_implementations = function(o) require('snacks').picker.lsp_implementations(o) end
    -- vim.ui.picker.lsp_type_definitions = function(o) require('snacks').picker.lsp_type_definitions(o) end
    -- vim.ui.picker.diagnostics = function(o) require('snacks').picker.diagnostics(o) end

    -- ── Shared LSP on_attach ───────────────────────────────────────
    local function on_attach(client, bufnr)
      env.state._update('lsp.attached_servers', vim.lsp.get_clients { bufnr = bufnr })

      -- if client.server_capabilities.inlayHintProvider then vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end
      -- ── Helper ──────────────────────────────────────────────────────
      --- Notify the user that the LSP server does not provide a capability.
      ---@param capability string The capability name as it appears in server_capabilities
      local function missing(capability)
        vim.notify(
          string.format('LSP: %s does not provide %s\nclient_id=%d  root=%s', client.name, capability, client.id, (client.root_dir or '(no root)')),
          vim.log.levels.WARN
        )
      end

      local function format_buffer()
        require('conform').format {
          bufnr = bufnr,
          timeout_ms = 500,
          lsp_format = 'fallback',
        }
      end

      -- ── Always-available keymaps ────────────────────────────────────
      vim.keymap.set('n', '<leader>ld', function() vim.ui.picker.lsp_definitions() end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_definitions',
      })

      vim.keymap.set('n', '<leader>lf', format_buffer, {
        buffer = bufnr,
        silent = true,
        desc = 'language.format_buffer',
      })

      vim.keymap.set('n', '<leader>ll', function() vim.diagnostic.open_float { scope = 'line' } end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.show_diagnostics_line',
      })

      -- Diagnostic navigation follows ]d / [d / ]e / [e conventions
      -- established by vim-unimpaired and adopted widely.
      vim.keymap.set('n', ']d', function() vim.diagnostic.jump { count = 1, float = true } end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.diagnostics_next',
      })

      vim.keymap.set('n', '[d', function() vim.diagnostic.jump { count = -1, float = true } end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.diagnostics_prev',
      })

      vim.keymap.set('n', ']e', function() vim.diagnostic.jump { count = 1, float = true, severity = vim.diagnostic.severity.ERROR } end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.diagnostics_next_error',
      })

      vim.keymap.set('n', '[e', function() vim.diagnostic.jump { count = -1, float = true, severity = vim.diagnostic.severity.ERROR } end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.diagnostics_prev_error',
      })

      -- ── Picker keymaps (conditional) ────────────────────────────────

      -- <leader>ls  — document Symbols (mnemonic: s for symbols, scoped to buffer)
      vim.keymap.set('n', '<leader>ls', function()
        if client.server_capabilities.documentSymbolProvider then
          vim.ui.picker.lsp_document_symbols()
        else
          missing 'documentSymbolProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_symbols_document',
      })

      -- <leader>lS  — workspace Symbols (capital S = wider scope)
      vim.keymap.set('n', '<leader>lS', function()
        if client.server_capabilities.workspaceSymbolProvider then
          vim.ui.picker.lsp_workspace_symbols()
        else
          missing 'workspaceSymbolProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_symbols_workspace',
      })

      -- <leader>lr  — References
      vim.keymap.set('n', '<leader>lr', function()
        if client.server_capabilities.referencesProvider then
          vim.ui.picker.lsp_references()
        else
          missing 'referencesProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_references',
      })

      -- <leader>li  — Implementations
      vim.keymap.set('n', '<leader>li', function()
        if client.server_capabilities.implementationProvider then
          vim.ui.picker.lsp_implementations()
        else
          missing 'implementationProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_implementations',
      })

      -- <leader>lt  — Type definitions
      vim.keymap.set('n', '<leader>lt', function()
        if client.server_capabilities.typeDefinitionProvider then
          vim.ui.picker.lsp_type_definitions()
        else
          missing 'typeDefinitionProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_type_definitions',
      })

      -- <leader>lci — incoming Calls (mnemonic: c for calls, i for incoming)
      vim.keymap.set('n', '<leader>lci', function()
        if client.server_capabilities.callHierarchyProvider then
          vim.ui.picker.lsp_incoming_calls()
        else
          missing 'callHierarchyProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_incoming_calls',
      })

      -- <leader>lco — outgoing Calls (mnemonic: c for calls, o for outgoing)
      vim.keymap.set('n', '<leader>lco', function()
        if client.server_capabilities.callHierarchyProvider then
          vim.ui.picker.lsp_outgoing_calls()
        else
          missing 'callHierarchyProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.find_outgoing_calls',
      })

      -- ── Non-picker LSP actions (conditional) ────────────────────────

      -- gd — go to Definition (gd is a widely established default)
      vim.keymap.set('n', 'gd', function()
        if client.server_capabilities.definitionProvider then
          vim.lsp.buf.definition()
        else
          missing 'definitionProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.go_to_definition',
      })

      -- gD — go to Declaration (capital D, parallel to gd)
      vim.keymap.set('n', 'gD', function()
        if client.server_capabilities.declarationProvider then
          vim.lsp.buf.declaration()
        else
          missing 'declarationProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.go_to_declaration',
      })

      -- K — hover docs (K is the established vim default for keyword lookup)
      vim.keymap.set('n', 'K', function()
        if client.server_capabilities.hoverProvider then
          vim.lsp.buf.hover()
        else
          missing 'hoverProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.hover',
      })

      -- <leader>lh — signature Help (h for help; also available in insert mode)
      vim.keymap.set({ 'n', 'i' }, '<leader>lh', function()
        if client.server_capabilities.signatureHelpProvider then
          vim.lsp.buf.signature_help()
        else
          missing 'signatureHelpProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.signature_help',
      })

      -- <leader>ln — reName symbol
      vim.keymap.set('n', '<leader>ln', function()
        if client.server_capabilities.renameProvider then
          vim.lsp.buf.rename()
        else
          missing 'renameProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.rename',
      })

      -- <leader>la — code Actions (visual + normal for range actions)
      vim.keymap.set({ 'n', 'v' }, '<leader>la', function()
        if client.server_capabilities.codeActionProvider then
          vim.lsp.buf.code_action()
        else
          missing 'codeActionProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.code_action',
      })

      -- <leader>lI — toggle Inlay hints (capital I, distinct from implementations)
      local function toggle_inlay_hints() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }, { bufnr = bufnr }) end

      vim.keymap.set('n', '<leader>lI', function()
        if client.server_capabilities.inlayHintProvider then
          toggle_inlay_hints()
        else
          missing 'inlayHintProvider'
        end
      end, {
        buffer = bufnr,
        silent = true,
        desc = 'language.toggle_inlay_hints',
      })
    end
    -- ── Build shared capabilities for all LSP servers ──────────────
    -- blink.cmp extends LSP capabilities with completion protocol support
    local capabilities = vim.tbl_deep_extend('force', vim.lsp.protocol.make_client_capabilities(), require('blink.cmp').get_lsp_capabilities())

    -- ── Start each server ──────────────────────────────────────────
    for server_name, spec in pairs(servers) do
      local config = vim.tbl_deep_extend('force', {
        capabilities = capabilities,
        on_attach = on_attach,
      }, spec.config or {})

      -- If the server provides its own on_attach, chain it
      -- after our shared on_attach so both run
      if spec.config and spec.config.on_attach then
        local server_on_attach = spec.config.on_attach
        config.on_attach = function(client, bufnr)
          on_attach(client, bufnr)
          server_on_attach(client, bufnr)
        end
      end

      vim.lsp.config(server_name, config)
      vim.lsp.enable(server_name)
    end

    -- ── State providers ────────────────────────────────────────────
    env.state.register_provider {
      id = 'lsp.attached_servers',
      events = { 'LspAttach', 'LspDetach', 'BufEnter' },
      collect = function() return vim.lsp.get_clients { bufnr = 0 } end,
      desc = 'LSP clients attached to the current buffer',
    }

    env.state.register_provider {
      id = 'lsp.diagnostics',
      events = { 'DiagnosticChanged', 'BufEnter' },
      collect = function() return vim.diagnostic.get(0) end,
      desc = 'Diagnostics for the current buffer',
    }

    env.state.register_provider {
      id = 'lsp.current_symbol',
      events = { 'CursorHold' },
      collect = function()
        -- Get the symbol name under cursor for the winbar
        -- Uses treesitter first (fast), falls back to LSP
        local ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
        if ok then
          local node = ts_utils.get_node_at_cursor()
          if node then
            local node_text = vim.treesitter.get_node_text(node, 0)
            if node_text and #node_text < 50 then return node_text end
          end
        end
        return nil
      end,
      desc = 'Symbol name under cursor (for winbar context)',
    }

    env.state.register_provider {
      id = 'lsp.capabilities',
      events = { 'LspAttach', 'LspDetach', 'BufEnter' },
      collect = function()
        local caps = {}
        for _, client in ipairs(vim.lsp.get_clients { bufnr = 0 }) do
          caps[client.name] = client.server_capabilities
        end
        return caps
      end,
      desc = 'Server capabilities map for attached LSP clients',
    }

    -- ── Diagnostic display configuration ──────────────────────────
    vim.diagnostic.config {
      -- Virtual text: show at end of line, abbreviated
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
      underline = true,
      update_in_insert = false, -- only update diagnostics on leaving insert
      severity_sort = true,
      float = {
        border = 'rounded',
        source = true,
        header = '',
        prefix = '',
      },
    }

    -- ── Global LSP articulation (non-buffer-local) ─────────────────
    -- Actions that operate across buffers or don't require
    -- an attached LSP client go here rather than in on_attach
    vim.keymap.set('n', '<leader>lR', '', {
      desc = 'language.restart_lsp_clients',
      silent = true,
      callback = function() vim.cmd 'lsp restart' end,
    })

    -- ── LspAttach autocmd: clean state on detach ───────────────────
    vim.api.nvim_create_autocmd('LspDetach', {
      group = vim.api.nvim_create_augroup('language_lsp_detach', { clear = true }),
      callback = function(event)
        -- Refresh server list immediately on detach
        -- The state provider fires on LspDetach but the client
        -- may still appear in get_clients() briefly; force an update
        vim.schedule(function() env.state._update('lsp.attached_servers', vim.lsp.get_clients { bufnr = event.buf }) end)
      end,
    })
  end,
}
