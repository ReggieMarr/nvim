-- lua/modules/introspection.lua
-- Introspection module
--
-- Domain: introspection

local env = require 'env'

return env.module.register {
  name = 'introspection',
  domain = 'introspection',
  depends_on = {},
  optional_deps = {},

  -- ── Plugin option contributions ──────────────────────────────────────
  -- Each key is a plugin string. Values are merged across all modules
  -- before being passed to lazy. No config functions here: setup() below
  -- handles all env surface registrations after plugins are loaded.

  -- All pickers provided by snacks.picker via the capabilities system.
  -- The interface module registers core pickers in its setup() via env.capabilities.extend.
  -- The text_editing/lsp module extends with LSP pickers.
  -- No plugin declarations needed here — introspection keymaps wired in setup() below.
  plugins = {},

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.
  setup = function()
    -- ── State providers ─────────────────────────────────────────────
    -- env.state.register_provider {
    --   id = 'interface.notification_count',
    --   events = { 'User' },
    --   pattern = 'SnacksNotifierUpdated',
    --   collect = function() return #snacks.notifier.get_history() end,
    --   desc = 'Number of notifications in snacks history',
    -- }

    -- ── iIntrospection keymaps ───────────────────────────────────────────

    -- restart (TODO: relocate later)
    vim.keymap.set('n', '<leader>R', function() require('mini.sessions').restart() end, { desc = 'interface.restart', silent = true })

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- Basic introspection
    ----------------------------------------------------------------
    -- ── Introspection keymaps ────────────────────────────────────────
    -- <leader>h  — Help / describe
    -- <leader>f  — Find / search
    -- <leader>i  — Inspect

    -- Meta
    vim.keymap.set('n', '<leader>hp', function() vim.ui.picker.pickers() end, {
      desc = 'describe.pickers',
      silent = true,
    })

    -- Help
    vim.keymap.set('n', '<leader>hh', function() vim.ui.picker.help() end, {
      desc = 'describe.help_tags',
      silent = true,
    })
    vim.keymap.set('n', '<leader>hk', function() vim.ui.picker.keymaps() end, {
      desc = 'describe.keymaps',
      silent = true,
    })
    vim.keymap.set('n', '<leader>hc', function() vim.ui.picker.commands() end, {
      desc = 'describe.commands',
      silent = true,
    })
    vim.keymap.set('n', '<leader>ha', function() vim.ui.picker.autocmds() end, {
      desc = 'describe.autocommands',
      silent = true,
    })
    vim.keymap.set('n', '<leader>hs', function() vim.ui.picker.scripts() end, {
      desc = 'describe.sourced_scripts',
      silent = true,
    })
    vim.keymap.set('n', '<leader>hH', function() vim.ui.picker.highlights() end, {
      desc = 'describe.highlight_groups',
      silent = true,
    })
    vim.keymap.set('n', '<leader>hr', function() vim.ui.picker.runtime_files() end, {
      desc = 'describe.runtime_files',
      silent = true,
    })

    -- Find
    vim.keymap.set('n', '<leader>fn', function() vim.ui.picker.notifications() end, {
      desc = 'find.notifications',
      silent = true,
    })
    vim.keymap.set('n', '<leader>fC', function() vim.ui.picker.colorschemes() end, {
      desc = 'find.colorschemes',
      silent = true,
    })

    -- Inspect (these don't need pickers, they are point-in-time snapshots)
    vim.keymap.set('n', '<leader>ii', function() vim.show_pos() end, {
      desc = 'inspect.item_at_cursor',
      silent = true,
    })
    vim.keymap.set('n', '<leader>ih', function() vim.notify(vim.inspect(vim.lsp.get_clients { bufnr = 0 }), vim.log.levels.INFO) end, {
      desc = 'inspect.lsp_clients',
      silent = true,
    })
    vim.keymap.set('n', '<leader>io', function() vim.notify(vim.inspect(vim.bo), vim.log.levels.INFO) end, {
      desc = 'inspect.buffer_options',
      silent = true,
    })
    vim.keymap.set('n', '<leader>iO', function() vim.notify(vim.inspect(vim.wo), vim.log.levels.INFO) end, {
      desc = 'inspect.window_options',
      silent = true,
    })
  end,
}
