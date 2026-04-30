-- lua/languages/python.lua

---@type LanguageSpec
return {
  ft = { 'python' },

  treesitter = {
    parsers = { 'python' },
  },

  lsp = {
    basedpyright = {
      install = true,
      config = {
        cmd = { 'basedpyright-langserver', '--stdio' },
        root_dir = function(fname)
          return require('lspconfig.util').root_pattern(
            'uv.lock',
            'pyproject.toml',
            '.python-version',
            'setup.cfg',
            'setup.py',
            'requirements.txt',
            '.git'
          )(fname)
        end,
        before_init = function(_, config)
          local root = config.root_dir
          local venv = nil

          local uv_venv = root and (root .. '/.venv')
          if uv_venv and vim.uv.fs_stat(uv_venv) then
            venv = uv_venv
          end

          if not venv then
            local result = vim.system(
              { 'uv', 'python', 'find' },
              { cwd = root, text = true }
            ):wait()
            if result.code == 0 and result.stdout then
              local python_path = result.stdout:gsub('%s+$', '')
              venv = python_path:match '^(.+)/bin/python'
                or python_path:match '^(.+)/Scripts/python'
            end
          end

          if venv then
            config.settings.python = config.settings.python or {}
            config.settings.python.pythonPath = venv .. '/bin/python'
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

    ruff = {
      install = true,
      config = {
        cmd = { 'ruff', 'server' },
        root_dir = function(fname)
          return require('lspconfig.util').root_pattern(
            'ruff.toml',
            '.ruff.toml',
            'pyproject.toml',
            'uv.lock',
            '.git'
          )(fname)
        end,
        on_attach = function(client, _)
          -- Disable ruff hover: it only shows lint rule docs,
          -- not symbol info. basedpyright covers hover.
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
    },
  },

  formatters = {
    {
      name = 'ruff_format',
      -- ruff LSP mason package covers this; no separate mason_package needed
      mason_package = false,
      config = {
        condition = function(_, ctx)
          return vim.fs.find(
            { 'pyproject.toml', 'ruff.toml', '.ruff.toml' },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },
    },
    {
      name = 'ruff_organize_imports',
      mason_package = false,
    },
  },
}
