-- ============================================================================
-- File Operations
-- ============================================================================
local M = {}

--   Error  06:58:36 PM notify.error [Neo-tree ERROR] debounce  filesystem_navigate  error:  ....local/share/nvim/lazy/nui.nvim/lua/nui/utils/keymap.lua:112: invalid key: mode
function M.setup()
  -- Helper functions for file operations
  local function copy_this_file()
    local src = vim.fn.expand '%:p'
    local dst = vim.fn.input('Copy to: ', src, 'file')
    if dst ~= '' and dst ~= src then
      vim.fn.system('cp ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dst))
      print('File copied to ' .. dst)
    end
  end

  local function delete_this_file()
    local file = vim.fn.expand '%:p'
    local choice = vim.fn.input('Delete ' .. file .. '? (y/n): ')
    if choice:lower() == 'y' then
      vim.cmd 'bdelete!'
      vim.fn.delete(file)
      print('File deleted: ' .. file)
    end
  end

  local function move_this_file()
    local src = vim.fn.expand '%:p'
    local dst = vim.fn.input('Move to: ', src, 'file')
    if dst ~= '' and dst ~= src then
      vim.fn.system('mv ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dst))
      vim.cmd('edit ' .. vim.fn.fnameescape(dst))
      print('File moved to ' .. dst)
    end
  end

  local function yank_buffer_path(relative)
    local path = vim.fn.expand '%:p'
    if relative then path = vim.fn.fnamemodify(path, ':.') end
    vim.fn.setreg('+', path)
    print('Yanked: ' .. path)
  end
  -- search for files in the same directory as the current buffer
  vim.keymap.set('n', '<leader>sd', function()
    local path = vim.fn.expand '%:p:h' -- current file's parent directory
    require('snacks').picker.files { cwd = path }
  end, { noremap = true })

  -- grep in the same directory as the current buffer
  vim.keymap.set('n', '<leader>sg', function()
    local path = vim.fn.expand '%:p:h'
    require('snacks').picker.grep { cwd = path }
  end, { noremap = true })
  vim.keymap.set('n', '<leader>fC', copy_this_file, { desc = 'Copy this file' })
  vim.keymap.set('n', '<leader>fD', delete_this_file, { desc = 'Delete this file' })
  vim.keymap.set('n', '<leader>fR', move_this_file, { desc = 'Rename/move this file' })
  vim.keymap.set('n', '<leader>fs', '<cmd>w<CR>', { desc = 'Save file' })
  vim.keymap.set(
    'n',
    '<leader>fy',
    function() yank_buffer_path(false) end,
    { desc = 'Yank file path' }
  )
  vim.keymap.set(
    'n',
    '<leader>fY',
    function() yank_buffer_path(true) end,
    { desc = 'Yank relative file path' }
  )
end

return M
