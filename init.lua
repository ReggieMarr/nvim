-- Load core info & configuration first
INFO = require 'base.info'
require 'core'

BASE_PLUGINS = require 'base.plugins'
BASE_PLUGINS.setup()

-- ============================================================================
-- FEATURE CONFIGURATION
-- ============================================================================

local features = {
  -- directory navigation, terminal interactions, package management ect
  system_management = true,
  -- project based directory tracking, jira integration, ect
  project_management = true,
  -- managing shell processes, compilation ect
  task_running = true,
  -- file contents (buffer) navigation, syntax highlighting, autocompletion, ect
  editing = true,
  -- git integration
  version_control = true,
}

-- Collect dependencies and modules
local dependencies = {
  -- { import = 'base.plugins' },
  {
    'nvim-orgmode/orgmode',
    event = 'VeryLazy',
    ft = { 'org' },
    config = function()
      -- Setup orgmode
      require('orgmode').setup {
        org_agenda_files = '~/orgfiles/**/*',
        org_default_notes_file = '~/orgfiles/refile.org',
      }

      -- Experimental LSP support
      vim.lsp.enable 'org'
    end,
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<leader>?',
        function() require('which-key').show { global = false } end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },

  {
    'folke/trouble.nvim',
    opts = {}, -- for default options, refer to the configuration section for custom setup.
    cmd = 'Trouble',
    keys = {
      {
        '<leader>xx',
        '<cmd>Trouble diagnostics toggle<cr>',
        desc = 'Diagnostics (Trouble)',
      },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
        desc = 'Buffer Diagnostics (Trouble)',
      },
      {
        '<leader>cs',
        '<cmd>Trouble symbols toggle focus=false<cr>',
        desc = 'Symbols (Trouble)',
      },
      {
        '<leader>cl',
        '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
        desc = 'LSP Definitions / references / ... (Trouble)',
      },
      {
        '<leader>xL',
        '<cmd>Trouble loclist toggle<cr>',
        desc = 'Location List (Trouble)',
      },
      {
        '<leader>xQ',
        '<cmd>Trouble qflist toggle<cr>',
        desc = 'Quickfix List (Trouble)',
      },
    },
  },
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    'nemanjamalesija/smart-paste.nvim',
    event = 'VeryLazy',
    config = true,
  },

  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    keys = {
      { '<leader>su', '<cmd>Noice pick<CR>', { desc = 'Search notifications' } },
      { '<leader>nl', '<cmd>Noice last<CR>', { desc = 'Show the last notification' } },
      { '<leader>nd', '<cmd>Noice dismiss<CR>', { desc = 'Dismiss noice' } },
    },
    config = function()
      require('noice').setup {
        routes = {
          {
            -- Filter out low-priority notifications
            filter = {
              event = 'notify',
              min_height = 1,
            },
            view = 'mini',
          },
          {
            -- Ignore LSP progress updates
            filter = {
              event = 'lsp',
              kind = 'progress',
            },
            opts = { skip = true },
          },
          {
            -- Skip written/yanked messages
            filter = {
              event = 'msg_show',
              kind = { 'echo', 'echomsg' },
              any = {
                { find = 'written' },
                { find = 'yanked' },
                { find = 'line' },
                { find = 'more lines' },
              },
            },
            opts = { skip = true },
          },
          {
            -- Route other messages to mini view
            filter = {
              event = 'msg_show',
            },
            view = 'mini',
          },
          {
            -- Skip all messages that aren't errors or warnings
            filter = {
              event = 'msg_show',
              ['not'] = {
                kind = { 'error', 'warning' },
              },
            },
            opts = { skip = true },
          },
        },
        messages = {
          -- NOTE: If you enable messages, then the cmdline is enabled automatically.
          -- This is a current Neovim limitation.
          enabled = true,
          view = 'mini', -- default view for messages
          view_error = 'notify', -- view for errors
          view_warn = 'notify', -- view for warnings
          view_history = 'messages', -- view for :messages
          view_search = false, -- view for search count messages. Set to `false` to disable
        },
        notify = {
          -- Reduce visual noise
          enabled = true,
          view = 'mini',
        },
      }
    end,
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      'MunifTanjim/nui.nvim',
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      'rcarriga/nvim-notify',
    },
  },
}


NAVIGATION = require 'base.navigation'

dependencies =
  vim.tbl_extend('keep', NAVIGATION.dependencies, dependencies)
local modules = {}

for name, enabled in pairs(features) do
  if enabled then
    local module = require('features.' .. name)
    if module.dependencies then vim.list_extend(dependencies, module.dependencies) end
    table.insert(modules, module)
  end
end

-- Load plugins
require('lazy').setup(dependencies, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
  defaults = {
    lazy = true,
  },
  checker = {
    enabled = true,
  },
  change_detection = {
    enabled = true,
    notify = true,
  },
  -- Manages lua plugins
  rocks = { hererocks = true },
})

-- Setup features after plugins load
for _, module in ipairs(modules) do
  if module.setup then module.setup() end
end
NAVIGATION.setup()

-- Set the default theme
vim.cmd [[colorscheme tokyonight]]

-- Add keymap handling
-- require('custom.keymaps.files').setup()
-- require('custom.keymaps.editor').setup()
-- require('custom.keymaps.windows').setup()
-- require('smart-paste').setup()
