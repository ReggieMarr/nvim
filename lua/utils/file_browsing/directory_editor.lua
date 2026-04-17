-- lua/file_browser/directory_editor.lua
-- dired-style file browser

local M = {}

local oil_opts = {
  -- Columns shown in the oil buffer — mirrors what your picker shows
  columns = {
    { 'permissions', highlight = 'Comment' },
    { 'size', highlight = 'Number' },
    { 'mtime', highlight = 'Special' },
    'icon',
  },

  -- Buffer-local options applied to the oil buffer
  buf_options = {
    buflisted = true,
    bufhidden = 'hide',
  },

  -- Window options for the oil buffer (non-float)
  win_options = {
    wrap = false,
    signcolumn = 'no',
    cursorcolumn = false,
    foldcolumn = '0',
    spell = false,
    list = false,
    conceallevel = 3,
    concealcursor = 'nvic',
  },
  constrain_cursor = true,

  -- Restore window options when leaving oil
  restore_win_options = true,

  -- Don't confirm before performing mutations
  skip_confirm_for_simple_edits = true,

  -- Prompt before performing ANY destructive action even with above set
  -- (deletes are still confirmed)
  prompt_save_on_select_new_entry = true,

  -- Watching the filesystem for changes
  watch_for_changes = true,

  -- Keymaps: hjkl navigation + keep search feeling native
  keymaps = {
    ['?'] = 'actions.show_help',
    ['<CR>'] = 'actions.select',

    -- Open in splits / tabs
    ['<C-s>'] = { 'actions.select', opts = { vertical = true } },
    ['<C-x>'] = { 'actions.select', opts = { horizontal = true } },
    ['<C-t>'] = { 'actions.select', opts = { tab = true } },

    -- Preview without navigating
    ['<C-p>'] = 'actions.preview',

    -- Close float or go back
    ['q'] = 'actions.close',
    ['<BS>'] = 'actions.parent', -- backspace goes up, mirrors your picker

    -- Open a new oil window at the cwd
    ['_'] = 'actions.open_cwd',

    -- cd to the directory shown in oil
    ['`'] = 'actions.cd',
    ['~'] = { 'actions.cd', opts = { scope = 'tab' } },

    -- Toggle hidden files — mirrors your picker's <C-h>
    ['<C-h>'] = 'actions.toggle_hidden',
    ['<leader>ot'] = 'actions.open_terminal',

    ['o'] = 'actions.change_sort',
    ['<C-o>'] = 'actions.open_external',
  },
  -- Disable ALL default keymaps so nothing conflicts with hjkl or search
  use_default_keymaps = false,

  -- Float configuration mirrors your picker's window sizing
  float = {
    padding = 2,
    max_width = math.floor(vim.o.columns * 0.618),
    max_height = math.floor(vim.o.lines * 0.618),
    border = 'rounded',
    win_options = {
      winblend = 0,
    },
  },

  -- Preview window configuration
  preview = {
    max_width = 0.45,
    min_width = { 40, 0.4 },
    width = nil,
    max_height = 0.9,
    min_height = { 5, 0.1 },
    height = nil,
    border = 'rounded',
    win_options = {
      winblend = 0,
    },
  },
}

M.NAV_MODE = true

function M.setup()
  require('oil').setup(oil_opts)

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'oil',
    callback = function(ev)
      local buf = ev.buf

      -- ----------------------------------------------------------------
      -- State: each oil buffer independently tracks whether it is in
      -- navigation mode or edit mode.
      -- ----------------------------------------------------------------

      local function set_nav_mode()
        M.NAV_MODE = true
        vim.bo[buf].modifiable = false
        vim.bo[buf].readonly = false -- oil needs this false internally
        vim.notify('Navigation mode', vim.log.levels.INFO, { title = 'oil.nvim' })
      end

      local function set_edit_mode()
        M.NAV_MODE = false
        vim.bo[buf].modifiable = true
        vim.notify('Edit mode  —  <C-x><C-s> to apply  |  <Esc> to discard', vim.log.levels.INFO, { title = 'oil.nvim' })
      end

      -- Start in navigation mode
      set_nav_mode()

      -- ----------------------------------------------------------------
      -- Helper: define a buffer-local normal-mode map that is easy to
      -- remove when we toggle modes.
      -- ----------------------------------------------------------------
      local nav_maps = {} -- { lhs, rhs_or_callback } pairs
      local edit_maps = {}

      local function nmap(lhs, rhs, desc, tbl)
        vim.keymap.set('n', lhs, rhs, { buffer = buf, desc = desc, nowait = true })
        table.insert(tbl, lhs)
      end

      local function clear_maps(tbl)
        for _, lhs in ipairs(tbl) do
          pcall(vim.keymap.del, 'n', lhs, { buffer = buf })
        end
        -- Clear the list so we don't try to delete them twice
        for k in pairs(tbl) do
          tbl[k] = nil
        end
      end

      -- ----------------------------------------------------------------
      -- Navigation mode maps
      -- ----------------------------------------------------------------
      local function apply_nav_maps()
        local oil = require 'oil'
        oil.setup(oil_opts)

        -- Directory traversal on h / l (dired style)
        nmap('l', function()
          local entry = oil.get_cursor_entry()
          if entry and entry.type == 'directory' then
            oil.select()
          else
            -- On a file: preview without leaving oil, mirrors dired 'v'
            oil.select { preview = true }
          end
        end, 'Oil: enter / descend', nav_maps)
        local actions = require 'oil.actions'

        nmap('h', actions.parent.callback, 'Oil: ascend to parent', nav_maps)

        -- <CR> opens the entry (file → edit buffer, dir → descend)
        nmap('<CR>', oil.select, 'Oil: open entry', nav_maps)
        -- -- Backspace also ascends, mirrors your picker's <BS> behaviour
        nmap('<BS>', actions.parent.callback, 'Oil: ascend (BS)', nav_maps)
        -- q closes oil and returns to the previous buffer
        nmap('q', oil.close, 'Oil: close', nav_maps)
        -- -- Toggle hidden files, same chord as your picker
        nmap('<C-h>', oil.toggle_hidden, 'Oil: toggle hidden', nav_maps)

        nmap('<C-r>', actions.refresh.callback, 'Oil: refresh', nav_maps)

        -- Open in splits / tab without leaving oil
        nmap('<C-v>', function() oil.select { vertical = true } end, 'Oil: open vsplit', nav_maps)
        nmap('<C-x>', function() oil.select { horizontal = true } end, 'Oil: open split', nav_maps)
        nmap('<C-t>', function() oil.select { tab = true } end, 'Oil: open tab', nav_maps)

        -- Preview pane
        nmap('<C-p>', oil.open_preview, 'Oil: preview', nav_maps)

        -- Copy path to clipboard
        nmap('gy', actions.copy_to_system_clipboard.callback, 'Oil: copy path', nav_maps)

        -- Switch to edit mode
        nmap('i', function()
          clear_maps(nav_maps)
          set_edit_mode()
          apply_edit_maps()
        end, 'Oil: enter edit mode', nav_maps)
      end

      -- ----------------------------------------------------------------
      -- Edit mode maps  (wdired equivalent)
      -- ----------------------------------------------------------------
      local function apply_edit_maps()
        local oil = require 'oil'

        -- <C-x><C-s>: apply mutations and return to navigation mode
        -- Closest faithful Emacs equivalent achievable in Neovim
        nmap('<C-x><C-s>', function() -- note: registered as a single lhs string
          vim.cmd.write()
          clear_maps(edit_maps)
          set_nav_mode()
          apply_nav_maps()
        end, 'Oil: apply changes (wdired save)', edit_maps)

        -- ZZ: same semantic — save and return
        nmap('ZZ', function()
          vim.cmd.write()
          clear_maps(edit_maps)
          set_nav_mode()
          apply_nav_maps()
        end, 'Oil: apply changes (ZZ)', edit_maps)

        -- <Esc>: discard and return to navigation mode
        nmap('<Esc>', function()
          oil.discard_all_changes()
          clear_maps(edit_maps)
          set_nav_mode()
          apply_nav_maps()
        end, 'Oil: discard changes', edit_maps)

        -- In edit mode h/l should revert to their normal vim motion meaning
        -- (character navigation) — do NOT add them to edit_maps so that
        -- the default vim behaviour falls through naturally.
      end

      -- ----------------------------------------------------------------
      -- Bootstrap
      -- ----------------------------------------------------------------
      apply_nav_maps()

      -- Prevent accidentally entering insert mode via the default 'i' key
      -- while in navigation mode (apply_nav_maps already remaps 'i' but
      -- this is a safety net for other insert-mode entry keys).
      vim.keymap.set('n', 'I', '<Nop>', { buffer = buf, desc = 'Oil: blocked in nav mode' })
      vim.keymap.set('n', 'a', '<Nop>', { buffer = buf, desc = 'Oil: blocked in nav mode' })
      vim.keymap.set('n', 'A', '<Nop>', { buffer = buf, desc = 'Oil: blocked in nav mode' })
      vim.keymap.set('n', 'o', '<Nop>', { buffer = buf, desc = 'Oil: blocked in nav mode' })
      vim.keymap.set('n', 'O', '<Nop>', { buffer = buf, desc = 'Oil: blocked in nav mode' })

      -- When edit mode is active those <Nop> maps should be lifted so the
      -- user can actually type. Wire that into the mode transition:
      local _orig_set_edit = set_edit_mode
      set_edit_mode = function()
        _orig_set_edit()
        for _, key in ipairs { 'I', 'a', 'A', 'o', 'O' } do
          pcall(vim.keymap.del, 'n', key, { buffer = buf })
        end
      end

      local _orig_set_nav = set_nav_mode
      set_nav_mode = function()
        _orig_set_nav()
        -- Re-block insert-mode entry keys when returning to navigation mode
        for _, key in ipairs { 'I', 'a', 'A', 'o', 'O' } do
          vim.keymap.set('n', key, '<Nop>', { buffer = buf })
        end
      end
    end,
  })
end

return M
