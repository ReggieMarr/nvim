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
    local api = require 'nvim-tree.api'

    -- Get the directory of the current buffer
    local current_file = vim.fn.expand '%:p'
    local current_dir = vim.fn.expand '%:p:h'

    -- If current buffer is empty/new, use cwd
    if current_file == '' then
      current_dir = vim.fn.getcwd()
    end

    -- Close tree if already open to reset state
    if api.tree.is_visible() then
      api.tree.close()
    end

    -- Open nvim-tree with custom config for Vertico-like behavior
    api.tree.open()

    vim.schedule(function()
      -- Change root to current buffer's directory
      api.tree.change_root(current_dir)

      -- Focus the tree window
      api.tree.focus()

      -- If there's a current file, reveal and select it
      if current_file ~= '' and vim.fn.filereadable(current_file) == 1 then
        api.tree.find_file(current_file)
      end

      -- Start in filter mode for quick searching (like Vertico)
      vim.defer_fn(function()
        if api.tree.is_visible() then
          -- Enable live filter (search) mode
          vim.cmd 'normal! f' -- 'f' key starts filter in nvim-tree
        end
      end, 50)
    end)
  end

  -- vim.keymap.set('n', '<leader>ff', vertico_style_file_finder, { desc = 'Find file from buffer directory' })
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
