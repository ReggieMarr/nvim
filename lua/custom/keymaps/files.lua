-- ============================================================================
-- File Operations
-- ============================================================================
local M = {}

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
    if relative then
      path = vim.fn.fnamemodify(path, ':.')
    end
    vim.fn.setreg('+', path)
    print('Yanked: ' .. path)
  end

  local function vertico_style_file_finder()
    local picker = require 'snacks.picker'
    picker.explorer({
      layout = { preset = "default", preview = false },
      focus = "input",
      follow_file = true,
      -- Make it non-recursive (only current directory)
      hidden = true,
      dirs = {picker:cwd()},
      live = true,
      max_depth = 1,
      matcher = {
        fuzzy = true, -- use fuzzy matching
        smartcase = true, -- use smartcase
        cwd_bonus = true, -- give bonus for matching files in the cwd
        frecency = true,
        history_bonus = true, -- give more weight to chronological order
      },
    })
  end


  vim.keymap.set('n', '<leader>ff', vertico_style_file_finder, { desc = 'Find file from buffer directory' })
  vim.keymap.set('n', '<leader>fC', copy_this_file, { desc = 'Copy this file' })
  vim.keymap.set('n', '<leader>fD', delete_this_file, { desc = 'Delete this file' })
  vim.keymap.set('n', '<leader>fR', move_this_file, { desc = 'Rename/move this file' })
  vim.keymap.set('n', '<leader>fr', '<cmd>Telescope oldfiles<CR>', { desc = 'Recent files' })
  vim.keymap.set('n', '<leader>fs', '<cmd>w<CR>', { desc = 'Save file' })
  vim.keymap.set('n', '<leader>fy', function()
    yank_buffer_path(false)
  end, { desc = 'Yank file path' })
  vim.keymap.set('n', '<leader>fY', function()
    yank_buffer_path(true)
  end, { desc = 'Yank relative file path' })
end

return M
