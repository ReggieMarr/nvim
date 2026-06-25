-- lua/modules/workspace.lua
-- Workspace module: project root detection, project name derivation.
--
-- Registers state:
--   workspace.root         — project root directory (LSP or marker-based)
--   workspace.project_name — basename of the root
--
-- Domain: workspace

local env = require 'env'

return env.module.register {
  name = 'workspace',
  domain = 'workspace',
  depends_on = {},
  optional_deps = {},

  -- ── Plugin option contributions ──────────────────────────────────────
  -- Each key is a plugin string. Values are merged across all modules
  -- before being passed to lazy. No config functions here: setup() below
  -- handles all env surface registrations after plugins are loaded.

  plugins = {},

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.
  setup = function()
    -- Project root detection.
    -- Uses LSP root when available, falls back to common marker files.
    -- Registers as workspace.root to complement workspace.cwd from core.
    env.state.register_provider {
      id = 'workspace.root',
      events = { 'BufEnter', 'LspAttach' },
      collect = function()
        -- Prefer LSP-reported root: most accurate for the current file
        local clients = vim.lsp.get_clients { bufnr = 0 }
        for _, client in ipairs(clients) do
          if client.config.root_dir then return client.config.root_dir end
        end

        -- Fall back to marker-based detection
        local markers = {
          '.git',
          '.hg',
          'Makefile',
          'package.json',
          'Cargo.toml',
          'pyproject.toml',
          'go.mod',
        }
        local path = vim.fn.expand '%:p:h'
        local root = vim.fs.root(path, markers)
        return root or vim.fn.getcwd()
      end,
      desc = 'Project root directory for the current buffer',
    }

    env.state.register_provider {
      id = 'workspace.project_name',
      events = { 'BufEnter', 'DirChanged' },
      collect = function()
        -- Derive project name from root, falling back to cwd basename
        local root = env.state.get 'workspace.root' or env.state.get 'workspace.cwd' or vim.fn.getcwd()
        return vim.fn.fnamemodify(root, ':t')
      end,
      desc = 'Name of the current project (basename of root)',
    }

    -- TODO evaluate if this is needed
    -- ── LspAttach integration ───────────────────────────────────────
    -- When LSP attaches to a buffer, update workspace.root immediately
    -- rather than waiting for the next BufEnter event.
    -- This ensures the state is current when LspAttach-triggered
    -- display conditions are evaluated.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('filesystem_lsp_root', { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.config.root_dir then
          env.state._update('workspace.root', client.config.root_dir)
          env.state._update('workspace.project_name', vim.fn.fnamemodify(client.config.root_dir, ':t'))
        end
      end,
    })
  end,
}
