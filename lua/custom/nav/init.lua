-- lua/custom/nav/init.lua

local M = {}
local core = require('custom.nav.core')

function M.setup(opts)
  opts = opts or {}

  -- Setup autocmd
  local augroup = vim.api.nvim_create_augroup('ProjectFileBrowser', { clear = true })
  local browser_opened = false

  vim.api.nvim_create_autocmd('SessionLoadPost', {
    group = augroup,
    desc = 'Open file browser when session is loaded',
    callback = function()
      if not browser_opened then
        browser_opened = true
        core.load_new_project()
        browser_opened = false
      end
    end,
  })

  -- Define keybindings
  local keymaps = {
    { '<leader>fF', '<cmd>Telescope find_files cwd=%:p:h<CR>', { desc = 'Find file under here' } },
    { '<leader>ff', core.file_browser, { desc = 'Browse file under here' } },
    { '<leader>.', core.file_browser, { desc = 'File Manager' } },
    { '<leader>sp', core.git_grep_files_from_project, { desc = 'Search git files from project root' } },
    { '<leader>sd', core.git_grep_files_from_buffer, { desc = 'Search git files from buffer directory' } },
    { '<leader>sD', core.live_grep_from_buffer, { desc = 'Live grep from buffer directory' } },
    {
      '<leader>sf',
      function()
        require('telescope.builtin').git_files { cwd = vim.fn.expand('%:p:h') }
      end,
      { desc = 'Search git files from buffer directory' },
    },
    {
      '<leader>sF',
      function()
        require('telescope.builtin').find_files { cwd = vim.fn.expand('%:p:h'), hidden = true }
      end,
      { desc = 'Search files from buffer directory (including hidden)' },
    },
    { '<leader>pp', ':NeovimProjectDiscover<CR>', { desc = 'Switch project' } },
    {
      '<leader><leader>',
      function()
        local root = core.find_project_root()
        require('telescope').extensions.file_browser.file_browser {
          path = root,
          select_buffer = true,
        }
      end,
      { desc = 'Find files (project root)' },
    },
  }

  -- Apply keymaps
  for _, mapping in ipairs(keymaps) do
    vim.keymap.set('n', mapping[1], mapping[2], mapping[3])
  end

  -- Browser setup
  core.browser_setup()
end

-- Export core functions for direct access if needed
M.file_browser = core.file_browser
M.find_project_root = core.find_project_root
M.git_grep_files_from_project = core.git_grep_files_from_project
M.git_grep_files_from_buffer = core.git_grep_files_from_buffer
M.live_grep_from_buffer = core.live_grep_from_buffer

return M
