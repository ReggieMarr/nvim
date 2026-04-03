-- ============================================================================
-- Core, Editor focused Navigation Mappings
-- ============================================================================

local M = {}

function M.setup()
  -- Format
  vim.keymap.set(
    'n',
    '<leader>fm',
    function() require('conform').format { lsp_fallback = true } end,
    { desc = 'Format file' }
  )

  -- Inspect
  vim.keymap.set('n', '<leader>ip', '<cmd>Inspect<CR>', { desc = 'Inspect highlight group' })

  -- ============================================================================
  -- Buffer Operations
  -- ============================================================================

  vim.keymap.set('n', '<leader>ds', vim.diagnostic.setloclist, { desc = 'Diagnostic loclist' })
  vim.keymap.set(
    'n',
    '<leader>*',
    function() Snacks.picker.grep_word() end,
    { desc = 'Search symbol at point' }
  )

  -- ============================================================================
  -- Help & Discovery
  -- ============================================================================
  vim.keymap.set(
    'n',
    '<leader>hk',
    function() require('snacks').picker.keymaps() end,
    { desc = '[H]elp [K]eymaps' }
  )
  vim.keymap.set(
    'n',
    '<leader>hh',
    function() require('snacks').picker.help() end,
    { desc = '[H]elp [P]rojects' }
  )
  vim.keymap.set(
    'n',
    '<leader>hm',
    function() require('snacks').picker.man() end,
    { desc = '[H]elp [M]anpages' }
  )
  vim.keymap.set(
    'n',
    '<leader>hl',
    function() Snacks.picker.lsp_config() end,
    { desc = '[H]elp [M]anpages' }
  )
end

return M
