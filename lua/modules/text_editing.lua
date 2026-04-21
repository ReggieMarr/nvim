-- lua/modules/text_editing.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface

local env = require 'env'

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

    ----------------------------------------------------------------
    -- Buffer search (Snacks picker)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>sb', '', {
      silent = true,
      desc = 'text_editing.search_in_buffer',
      callback = function()
        local current_buf = vim.api.nvim_get_current_buf()
        local current_win = vim.api.nvim_get_current_win()

        require('snacks').picker.lines {
          buf = current_buf,
          layout = {
            preset = 'dropdown',
            preview = false,
            layout = { height = 0.4 },
          },

          on_change = function(_, item)
            if item and vim.api.nvim_win_is_valid(current_win) then
              vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
              vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
            end
          end,

          confirm = function(picker, item)
            picker:close()

            if item and vim.api.nvim_win_is_valid(current_win) then
              vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
              vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
            end
          end,
        }
      end,
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
