-- ============================================================================
-- Window Management
-- ============================================================================
local M = {}

-- Window zoom toggle (simplified)
local function toggle_zoom()
  local function is_zoomed()
    return vim.t.zoomed or false
  end

  local function zoom_session_file()
    if not vim.t.zoom_session_file then
      vim.t.zoom_session_file = vim.fn.tempname() .. '_' .. vim.api.nvim_tabpage_get_number(0)
      vim.api.nvim_create_autocmd('TabClosed', {
        callback = function()
          if vim.t.zoom_session_file then
            os.remove(vim.t.zoom_session_file)
          end
        end,
      })
    end
    return vim.t.zoom_session_file
  end

  if is_zoomed() then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd('silent! source ' .. zoom_session_file())
    vim.t.zoomed = false
    vim.api.nvim_win_set_cursor(0, cursor_pos)
  else
    if #vim.api.nvim_tabpage_list_wins(0) == 1 then
      return
    end
    local old_sessionoptions = vim.o.sessionoptions
    vim.o.sessionoptions = 'blank,buffers,curdir,terminal,help'
    vim.cmd('mksession! ' .. zoom_session_file())
    vim.cmd 'only'
    vim.t.zoomed = true
    vim.o.sessionoptions = old_sessionoptions
  end
end

-- Helper functions for window operations
local function move_window(direction)
  local curwin = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. direction)
  local newwin = vim.api.nvim_get_current_win()
  if curwin == newwin then
    local opposite = { h = 'l', l = 'h', j = 'k', k = 'j' }
    vim.cmd('wincmd ' .. opposite[direction])
  end
  vim.cmd 'wincmd x'
end


function M.setup()
  -- Window navigation
  vim.keymap.set('n', '<leader>wf', toggle_zoom, { desc = 'Toggle Zoom' })
  vim.keymap.set('n', '<leader>ww', '<C-w>w', { desc = 'Next window' })
  vim.keymap.set('n', '<leader>wh', '<C-w>h', { desc = 'Window left' })
  vim.keymap.set('n', '<leader>wj', '<C-w>j', { desc = 'Window down' })
  vim.keymap.set('n', '<leader>wk', '<C-w>k', { desc = 'Window up' })
  vim.keymap.set('n', '<leader>wl', '<C-w>l', { desc = 'Window right' })

  -- Window splits
  vim.keymap.set('n', '<leader>ws', '<cmd>split<CR>', { desc = 'Split horizontal' })
  vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<CR>', { desc = 'Split vertical' })

  -- Window moving
  vim.keymap.set('n', '<leader>wH', function()
    move_window 'h'
  end, { desc = 'Move window left' })
  vim.keymap.set('n', '<leader>wJ', function()
    move_window 'j'
  end, { desc = 'Move window down' })
  vim.keymap.set('n', '<leader>wK', function()
    move_window 'k'
  end, { desc = 'Move window up' })
  vim.keymap.set('n', '<leader>wL', function()
    move_window 'l'
  end, { desc = 'Move window right' })

  -- Window operations
  vim.keymap.set('n', '<leader>wd', '<C-w>c', { desc = 'Delete window' })
  vim.keymap.set('n', '<leader>wo', '<C-w>o', { desc = 'Delete other windows' })
  vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = 'Balance windows' })
end

return M
