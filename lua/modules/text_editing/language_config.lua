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

  lua = {
    lsp = {
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
      },
      formatters = { 'stylua' },
    },
  },

  python = {
    lsp = {
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
    },
  },
    formatters = {
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
