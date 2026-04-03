-- lua/features/project-management.lua

local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  {
    'DrKJeff16/project.nvim',
    -- Loaded just after startup so that it's available from the dashboard
    event = 'VeryLazy',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'folke/snacks.nvim',
    },
  },
  {
    'folke/persistence.nvim',
    -- Since we want to be able to use persistence from the dashboard
    -- we need to have sessions accessible before entering a file
    event = 'VimEnter',
    lazy = false,
  },
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
function M.setup_projects()
  require('project').setup {
    snacks = {
      enabled = true, -- Will enable the `:ProjectSnacks` command
      opts = {
        sort = 'newest',
        hidden = false,
        title = 'Select Project',
        layout = 'select',
        -- icon = {},
        -- path_icons = {},
      },
    },
  }
  -- Link persistence support to project.nvim
  require('features.project_nvim_persistance_extension').init()
end

function M.setup_persistence()
  require('persistence').setup {
    dir = vim.fn.stdpath 'data' .. '/sessions/',
    need = 2, -- More than one file is a real indicator that we need to save something
    branch = true,
  }
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  local function browse_project_files()
    local root = require('project').get_project_root()

    require('snacks').picker.files {
      cwd = root,
      show_empty = true,
      supports_live = true,
      auto_close = true,
      dirs = { root },
      enter = true,
      layout = { preset = 'default', preview = false },
    }
  end
  local function search_in_project_files()
    local root = require('project').get_project_root()

    require('snacks').picker.grep {
      cwd = root,
      dirs = { root },
    }
  end

  vim.keymap.set('n', '<leader>pp', '<cmd>ProjectSnacks<cr>', { desc = 'Find Projects' })
  vim.keymap.set(
    'n',
    '<leader>pf',
    function() browse_project_files() end,
    { desc = 'Find files in current project' }
  )
  vim.keymap.set(
    'n',
    '<leader>sp',
    function() search_in_project_files() end,
    { desc = 'Search files in current project' }
  )

  vim.keymap.set('n', '<leader>qr', function()
    require('persistence').save()
    vim.cmd 'qa'
  end, { desc = 'Save session and quit (for restart)' })
  vim.keymap.set(
    'n',
    '<leader>qs',
    function() require('persistence').load() end,
    { desc = 'Restore session' }
  )
end

-- ============================================================================
-- MAIN SETUP FUNCTION
-- ============================================================================
function M.setup()
  M.setup_projects()
  M.setup_persistence()
  M.setup_keymaps()
end

return M
