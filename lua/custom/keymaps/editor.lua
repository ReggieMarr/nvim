-- ============================================================================
-- Core, Editor focused Navigation Mappings
-- ============================================================================

local M = {}

function M.setup()
  -- Emacs-style line navigation (keep these if you want them)
  vim.keymap.set('i', '<C-a>', '<ESC>^i', { desc = 'Beginning of line' })
  vim.keymap.set('n', '<C-a>', '^', { desc = 'Beginning of line' })
  vim.keymap.set('i', '<C-e>', '<End>', { desc = 'End of line' })
  vim.keymap.set('n', '<C-e>', '$', { desc = 'End of line' })

  -- Format
  vim.keymap.set('n', '<leader>fm', function()
    require('conform').format { lsp_fallback = true }
  end, { desc = 'Format file' })

  -- Comments
  vim.keymap.set('n', '<A-;>', 'gcc', { desc = 'toggle comment', remap = true })
  vim.keymap.set('v', '<A-;>', 'gc', { desc = 'toggle comment', remap = true })

  -- Visual mode improvements
  vim.keymap.set('v', '<', '<gv', { desc = 'Indent left (keep selection)' })
  vim.keymap.set('v', '>', '>gv', { desc = 'Indent right (keep selection)' })
  vim.keymap.set('v', 'p', 'pgv', { desc = 'Paste (keep selection)' })

  -- Clear search highlighting
  vim.keymap.set('n', '<Esc>', '<cmd>noh<CR>', { desc = 'Clear highlights' })

  -- Toggles
  vim.keymap.set('n', '<leader>tn', '<cmd>set number!<CR>', { desc = 'Toggle line numbers' })
  vim.keymap.set('n', '<leader>tr', '<cmd>set relativenumber!<CR>', { desc = 'Toggle relative numbers' })
  vim.keymap.set('n', '<leader>ts', '<cmd>setlocal spell!<CR>', { desc = 'Toggle spell check' })
  vim.keymap.set('n', '<leader>tw', '<cmd>set wrap!<CR>', { desc = 'Toggle word wrap' })

  -- Terminal
  vim.keymap.set('t', '<C-x>', '<C-\\><C-N>', { desc = 'Exit terminal mode' })

  -- Quit commands
  vim.keymap.set('n', '<leader>qq', '<cmd>qa<CR>', { desc = 'Quit all' })
  vim.keymap.set('n', '<leader>qQ', '<cmd>qa!<CR>', { desc = 'Force quit all' })
  vim.keymap.set('n', '<C-x><C-c>', '<cmd>xa<CR>', { desc = 'Save all and quit (Emacs-style)' })

  -- Inspect
  vim.keymap.set('n', '<leader>ip', '<cmd>Inspect<CR>', { desc = 'Inspect highlight group' })

  -- ============================================================================
  -- Buffer Operations
  -- ============================================================================
  vim.keymap.set('n', '<leader>bb', '<cmd>Telescope buffers<CR>', { desc = 'Switch buffer' })
  vim.keymap.set('n', '<leader>`', '<c-^>', { desc = 'Switch to last buffer' })
  vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'Delete buffer' })
  vim.keymap.set('n', '<leader>bn', '<cmd>bnext<CR>', { desc = 'Next buffer' })
  vim.keymap.set('n', '<leader>bp', '<cmd>bprevious<CR>', { desc = 'Previous buffer' })

  -- ============================================================================
  -- Search Operations
  -- ============================================================================
  vim.keymap.set('n', '<leader>/', '<cmd>Telescope live_grep<CR>', { desc = 'Search in project' })
  vim.keymap.set('n', '<leader>sb', function()
    local builtin = require 'telescope.builtin'
    local themes = require 'telescope.themes'
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    builtin.current_buffer_fuzzy_find(themes.get_dropdown {
      winblend = 10,
      previewer = false,
      layout_config = {
        height = 0.4,
      },
      attach_mappings = function(prompt_bufnr, map)
        -- Jump to line on selection change (as you type)
        local function jump_to_line()
          local selection = action_state.get_selected_entry()
          if selection then
            -- Get the original buffer and window
            local picker = action_state.get_current_picker(prompt_bufnr)
            local original_win = picker.original_win_id

            -- Jump to the line in the original window without closing telescope
            if original_win and vim.api.nvim_win_is_valid(original_win) then
              vim.api.nvim_win_set_cursor(original_win, { selection.lnum, 0 })
              -- Center the line in the window
              vim.api.nvim_win_call(original_win, function()
                vim.cmd 'normal! zz'
              end)
            end
          end
        end

        -- Override cursor movement to update preview
        map('i', '<Down>', function()
          actions.move_selection_next(prompt_bufnr)
          jump_to_line()
        end)

        map('i', '<Up>', function()
          actions.move_selection_previous(prompt_bufnr)
          jump_to_line()
        end)

        -- Also jump on any input change
        vim.api.nvim_create_autocmd('TextChangedI', {
          buffer = prompt_bufnr,
          callback = function()
            vim.schedule(jump_to_line)
          end,
        })

        -- Keep default enter behavior
        map('i', '<CR>', function()
          actions.select_default(prompt_bufnr)
        end)

        -- Exit with escape
        map('i', '<Esc>', function()
          actions.close(prompt_bufnr)
        end)

        return true
      end,
    })
  end, { desc = 'Search in buffer' })
  vim.keymap.set('n', '<leader>sg', '<cmd>Telescope live_grep<CR>', { desc = 'Search by grep' })
  vim.keymap.set('n', '<leader>sm', '<cmd>Telescope marks<CR>', { desc = 'Search marks' })
  vim.keymap.set('n', '<leader>si', '<cmd>Telescope treesitter<CR>', { desc = 'Search with treesitter' })

  -- Search symbol at point in project
  local function search_project_for_symbol_at_point()
    local word = vim.fn.expand '<cword>'
    require('telescope.builtin').grep_string {
      search = word,
      prompt_title = 'Search for "' .. word .. '" in project',
    }
  end
  vim.keymap.set('n', '<leader>*', search_project_for_symbol_at_point, { desc = 'Search symbol at point' })
  vim.keymap.set('n', '<leader>ds', vim.diagnostic.setloclist, { desc = 'Diagnostic loclist' })

  -- ============================================================================
  -- LSP
  -- ============================================================================
  -- Fuzzy find all the symbols in your current document.
  --  Symbols are things like variables, functions, types, etc.
  vim.keymap.set('n', '<leader>ls', require('telescope.builtin').lsp_document_symbols, { desc = '[Lsp] find [S]ymbols' })
  vim.keymap.set('n', '<leader>lS', require('telescope.builtin').lsp_dynamic_workspace_symbols, { desc = '[Lsp] find workplace [S]ymbols' })
  --  Most Language Servers support renaming across files, etc.
  vim.keymap.set('n', '<leader>lR', vim.lsp.buf.rename, { desc = '[L]sp [R]ename' })
  vim.keymap.set('n', '<leader>lr', require('telescope.builtin').lsp_references, { desc = '[L]sp [R]eferenaces' })
  -- Execute a code action, usually your cursor needs to be on top of an error
  -- or a suggestion from your LSP for this to activate.
  vim.keymap.set('n', '<leader>la', vim.lsp.buf.code_action, { desc = '[L]sp [A]ction' })
  vim.keymap.set('x', '<leader>la', vim.lsp.buf.code_action, { desc = '[L]sp [A]ction' })
  -- Jump to the implementation of the word under your cursor.
  --  Useful when your language has ways of declaring types without an actual implementation.
  vim.keymap.set('n', '<leader>li', require('telescope.builtin').lsp_implementations, { desc = '[G]oto [I]mplementation' })
  -- Jump to the definition of the word under your cursor.
  --  This is where a variable was first declared, or where a function is defined, etc.
  --  To jump back, press <C-t>.
  vim.keymap.set('n', '<leader>ld', require('telescope.builtin').lsp_definitions, { desc = '[G]oto [D]efinition' })
  -- WARN: This is not Goto Definition, this is Goto Declaration.
  --  For example, in C this would take you to the header.
  vim.keymap.set('n', '<leader>lD', vim.lsp.buf.declaration, { desc = '[G]oto [D]eclaration' })
  -- The following code creates a keymap to toggle inlay hints in your
  -- code, if the language server you are using supports them
  --
  -- This may be unwanted, since they displace some of your code
  if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
    vim.keymap.set('n', '<leader>lh', function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
    end, '[T]oggle Inlay [H]ints')
  end

  -- Jump to the type of the word under your cursor.
  --  Useful when you're not sure what type a variable is and you want to see
  --  the definition of its *type*, not where it was *defined*.
  vim.keymap.set('n', '<leader>lt', require('telescope.builtin').lsp_type_definitions, { desc = '[G]oto [T]ype [D]eclaration' })

  -- ============================================================================
  -- Quit Operations
  -- ============================================================================
  vim.keymap.set('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit all' })
  vim.keymap.set('n', '<leader>qQ', '<cmd>qa!<cr>', { desc = 'Quit all (force)' })
  vim.keymap.set('n', '<leader>wq', '<cmd>wqa<cr>', { desc = 'Save and quit all' })
  vim.keymap.set('n', '<C-x><C-c>', '<cmd>wqa!<cr>', { desc = 'Save and quit (force)' })

  -- ============================================================================
  -- Help & Discovery
  -- ============================================================================
  vim.keymap.set('n', '<M-x>', '<cmd>Telescope keymaps<CR>', { desc = '[H]elp [K]eymaps' })
  vim.keymap.set('n', '<leader>ht', '<cmd>Telescope help_tags<CR>', { desc = '[H]elp [T]ags' })
  vim.keymap.set('n', '<leader>ho', '<cmd>Telescope vim_options<CR>', { desc = '[H]elp vim [O]ptions' })
end

return M
