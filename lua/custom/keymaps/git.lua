-- Git-related keymaps
local M = {}

function M.setup()
  -- Neogit/Git status
  vim.keymap.set('n', '<leader>gg', '<cmd>Neogit<CR>', { desc = 'Neogit status' })
  vim.keymap.set('n', '<leader>gG', function()
    require('neogit').open { cwd = vim.fn.expand '%:p:h' }
  end, { desc = 'Neogit status (current dir)' })
  vim.keymap.set('n', '<leader>gc', '<cmd>Neogit commit<CR>', { desc = 'Git commit' })
  vim.keymap.set('n', '<leader>gp', '<cmd>Neogit push<CR>', { desc = 'Git push' })
  vim.keymap.set('n', '<leader>gP', '<cmd>Neogit pull<CR>', { desc = 'Git pull' })

  -- Telescope git
  vim.keymap.set('n', '<leader>gt', '<cmd>Telescope git_status<CR>', { desc = 'Git status (Telescope)' })
  vim.keymap.set('n', '<leader>gb', '<cmd>Telescope git_branches<CR>', { desc = 'Git branches' })
  vim.keymap.set('n', '<leader>gB', '<cmd>Neogit blame<CR>', { desc = 'Git blame' })
  vim.keymap.set('n', '<leader>gf', '<cmd>Telescope git_files<CR>', { desc = 'Git files' })
end

return M
