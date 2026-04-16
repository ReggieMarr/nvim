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
        indent = { enable = true },
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

        -- Enable treesitter indentation
        vim.api.nvim_create_autocmd('FileType', {
          callback = function() vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end,
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
  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  setup = function()
    require('mason').setup()
    require('mason-tool-installer').setup {
      ensure_installed = mason_formatter_names(),
    }
    require('mason-lspconfig').setup {
      automatic_enable = true,
    }

    -- ── Shared LSP on_attach ───────────────────────────────────────
    -- Called when any LSP server attaches to a buffer.
    -- Registers buffer-local articulation contributions and
    -- updates env.state for the attached buffer.
    local function on_attach(client, bufnr)
      -- Update state immediately on attach
      env.state._update('lsp.attached_servers', vim.lsp.get_clients { bufnr = bufnr })

      -- Enable inlay hints if the server supports them
      if client.server_capabilities.inlayHintProvider then vim.lsp.inlay_hint.enable(true, { bufnr = bufnr }) end
      -- Register buffer-local LSP actions.
      -- These only exist while LSP is attached to this buffer.
      -- Using buffer-local bindings means they don't pollute global keymap
      -- and are automatically cleaned up when the buffer is wiped.
      env.articulation.register_group('language', {
        {
          id = 'go_to_definition',
          handler = vim.lsp.buf.definition,
          desc = 'Go to definition',
          bindings = { { lhs = '<leader>ld', buffer = bufnr } },
          when = function(_) return client.server_capabilities.definitionProvider == true end,
          allow_override = true,
        },
        {
          id = 'go_to_declaration',
          handler = vim.lsp.buf.declaration,
          desc = 'Go to declaration',
          bindings = { { lhs = '<leader>lD', buffer = bufnr } },
          when = function(_) return client.server_capabilities.declarationProvider == true end,
          allow_override = true,
        },
        {
          id = 'go_to_implementation',
          handler = vim.lsp.buf.implementation,
          desc = 'Go to implementation',
          bindings = { { lhs = '<leader>li', buffer = bufnr } },
          when = function(_) return client.server_capabilities.implementationProvider == true end,
          allow_override = true,
        },
        {
          id = 'go_to_type_definition',
          handler = vim.lsp.buf.type_definition,
          desc = 'Go to type definition',
          bindings = { { lhs = '<leader>lt', buffer = bufnr } },
          when = function(_) return client.server_capabilities.typeDefinitionProvider == true end,
          allow_override = true,
        },
        {
          id = 'find_references',
          handler = function()
            -- Route through picker capability so references appear
            -- in lsp picker, not the quickfix list
            if env.capabilities.has 'picker' and env.use('picker').lsp_references then
              env.use('picker').lsp_references()
            else
              vim.lsp.buf.references()
            end
          end,
          desc = 'Find references',
          bindings = {
            { lhs = 'gr', buffer = bufnr },
            { lhs = '<leader>lr', buffer = bufnr },
          },
          when = function(_) return client.server_capabilities.referencesProvider == true end,
          allow_override = true,
        },
        {
          id = 'hover',
          handler = vim.lsp.buf.hover,
          desc = 'Show hover documentation',
          bindings = { { lhs = '<leader>lh', buffer = bufnr } },
          when = function(_) return client.server_capabilities.hoverProvider == true end,
          allow_override = true,
        },
        {
          id = 'signature_help',
          handler = vim.lsp.buf.signature_help,
          desc = 'Show signature help',
          bindings = {
            { lhs = '<leader>lH', buffer = bufnr, mode = { 'n', 'i' } },
          },
          when = function(_) return client.server_capabilities.signatureHelpProvider ~= nil end,
          allow_override = true,
        },
        {
          id = 'rename',
          handler = vim.lsp.buf.rename,
          desc = 'Rename symbol',
          bindings = { { lhs = '<leader>ln', buffer = bufnr } },
          when = function(_) return client.server_capabilities.renameProvider == true end,
          allow_override = true,
        },
        {
          id = 'code_action',
          handler = vim.lsp.buf.code_action,
          desc = 'Code actions',
          bindings = {
            { lhs = '<leader>la', buffer = bufnr },
            { lhs = '<leader>la', buffer = bufnr, mode = 'v' },
          },
          when = function(_) return client.server_capabilities.codeActionProvider == true end,
          allow_override = true,
        },
        {
          id = 'format_buffer',
          handler = function()
            require('conform').format {
              bufnr = bufnr,
              timeout_ms = 500,
              lsp_format = 'fallback',
            }
          end,
          desc = 'Format buffer',
          bindings = { { lhs = '<leader>lf', buffer = bufnr } },
          allow_override = true,
        },
        {
          id = 'find_symbols_document',
          handler = function()
            if env.use('picker').lsp_symbols then
              env.use('picker').lsp_symbols { filter = 'document' }
            else
              vim.lsp.buf.document_symbol()
            end
          end,
          desc = 'Find document symbols',
          bindings = { { lhs = '<leader>si', buffer = bufnr } },
          when = function(_) return client.server_capabilities.documentSymbolProvider == true end,
          allow_override = true,
        },
        {
          id = 'find_symbols_workspace',
          handler = function()
            if env.use('picker').lsp_symbols then
              env.use('picker').lsp_symbols { filter = 'workspace' }
            else
              vim.lsp.buf.workspace_symbol()
            end
          end,
          desc = 'Find workspace symbols',
          bindings = { { lhs = '<leader>lS', buffer = bufnr } },
          when = function(_) return client.server_capabilities.workspaceSymbolProvider == true end,
          allow_override = true,
        },
        {
          id = 'toggle_inlay_hints',
          handler = function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr }, { bufnr = bufnr }) end,
          desc = 'Toggle inlay hints',
          bindings = { { lhs = '<leader>th', buffer = bufnr } },
          when = function(_) return client.server_capabilities.inlayHintProvider ~= nil end,
          allow_override = true,
        },
        {
          id = 'show_diagnostics_line',
          handler = function() vim.diagnostic.open_float { scope = 'line' } end,
          desc = 'Show line diagnostics',
          bindings = { { lhs = '<leader>ll', buffer = bufnr } },
          allow_override = true,
        },
        {
          id = 'diagnostics_next',
          handler = function() vim.diagnostic.jump { count = 1, float = true } end,
          desc = 'Next diagnostic',
          bindings = { { lhs = ']d', buffer = bufnr } },
          allow_override = true,
        },
        {
          id = 'diagnostics_prev',
          handler = function() vim.diagnostic.jump { count = -1, float = true } end,
          desc = 'Previous diagnostic',
          bindings = { { lhs = '[d', buffer = bufnr } },
          allow_override = true,
        },
        {
          id = 'diagnostics_next_error',
          handler = function()
            vim.diagnostic.jump {
              count = 1,
              float = true,
              severity = vim.diagnostic.severity.ERROR,
            }
          end,
          desc = 'Next error',
          bindings = { { lhs = ']e', buffer = bufnr } },
          allow_override = true,
        },
        {
          id = 'diagnostics_prev_error',
          handler = function()
            vim.diagnostic.jump {
              count = -1,
              float = true,
              severity = vim.diagnostic.severity.ERROR,
            }
          end,
          desc = 'Previous error',
          bindings = { { lhs = '[e', buffer = bufnr } },
          allow_override = true,
        },
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

    -- ── Display contributions ──────────────────────────────────────
    env.display.register {
      id = 'diagnostics_signs',
      module = 'language',
      region = 'signs',
      priority = 100,
      desc = 'Diagnostic severity indicators in sign column',
      when = function(state) return state['buffer.is_real'] == true end,
    }

    env.display.register {
      id = 'diagnostics_vtext',
      module = 'language',
      region = 'virtual_text',
      priority = 100,
      desc = 'Inline diagnostic messages',
      when = function(state)
        local diags = state['lsp.diagnostics']
        return state['buffer.is_real'] == true and diags ~= nil and #diags > 0
      end,
    }

    env.display.register {
      id = 'inlay_hints',
      module = 'language',
      region = 'virtual_text',
      priority = 90,
      desc = 'LSP inlay type and parameter hints',
      when = function(state)
        local caps = state['lsp.capabilities']
        if not caps then return false end
        for _, server_caps in pairs(caps) do
          if server_caps.inlayHintProvider then return true end
        end
        return false
      end,
    }

    env.display.register {
      id = 'language.treesitter_context',
      module = 'language',
      region = 'winbar',
      priority = 80,
      desc = 'Sticky treesitter context header',
      when = function(state) return state['buffer.is_real'] == true end,
    }

    -- ── Picker capability extensions ───────────────────────────────
    -- Extend the picker with LSP-specific finders.
    -- so env.use("picker") is safe here.
    env.capabilities.extend('picker', {
      lsp_references = function(o) require('snacks').picker.lsp_references(o) end,
      lsp_symbols = function(o)
        -- Snacks picker supports document/workspace symbol filtering
        local opts = vim.tbl_extend('force', {}, o or {})
        if opts.filter == 'document' then
          require('snacks').picker.lsp_symbols(opts)
        else
          require('snacks').picker.lsp_workspace_symbols(opts)
        end
      end,
      lsp_definitions = function(o) require('snacks').picker.lsp_definitions(o) end,
      lsp_implementations = function(o) require('snacks').picker.lsp_implementations(o) end,
      lsp_type_definitions = function(o) require('snacks').picker.lsp_type_definitions(o) end,
      diagnostics = function(o) require('snacks').picker.diagnostics(o) end,
    }, 'language')

    -- ── Global LSP articulation (non-buffer-local) ─────────────────
    -- Actions that operate across buffers or don't require
    -- an attached LSP client go here rather than in on_attach
    env.articulation.register_group('language', {
      {
        id = 'find_diagnostics',
        handler = function() env.use('picker').diagnostics() end,
        desc = 'Find all diagnostics',
        bindings = { { lhs = '<leader>lF' } },
      },
      {
        id = 'lsp_restart',
        handler = function() vim.cmd 'lsp restart' end,
        desc = 'Restart LSP clients',
        bindings = { { lhs = '<leader>lR' } },
      },
      {
        id = 'conform_info',
        handler = function() vim.cmd 'ConformInfo' end,
        desc = 'Show formatter info',
        bindings = { { lhs = '<leader>cF' } },
      },
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
