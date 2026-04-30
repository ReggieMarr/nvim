-- lua/modules/filesystem.lua
-- Filesystem module: file tree, file operations, workspace context.
--
-- Provides capabilities:
--   filesystem — file tree and file operations
--
-- Extends capabilities:
--   picker     — file-specific finders
--
-- Domain: filesystem

local env = require 'env'

return env.module.register {
  name = 'filesystem',
  domain = 'filesystem',
  depends_on = { 'interface' },
  optional_deps = {},

  -- ── Plugin option contributions ──────────────────────────────────────
  plugins = {
    ['stevearc/oil.nvim'] = {
      -- plugins/oil.lua (or wherever your plugin specs live)
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      lazy = false, -- to ensure the setup gets called
      opts = {
        -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
        -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
        default_file_explorer = true,
        -- Columns mirror what your picker already shows: icon, permissions, size, mtime
        columns = {
          { 'icon', highlight = 'MiniPickNormal' },
          { 'permissions', highlight = 'Comment' },
          { 'size', highlight = 'Number' },
          { 'mtime', highlight = 'Special' },
        },
        lsp_file_methods = {
          -- Enable or disable LSP file operations
          enabled = true,
          -- Time to wait for LSP file operations to complete before skipping
          timeout_ms = 1000,
          -- Set to true to autosave buffers that are updated with LSP willRenameFiles
          -- Set to "unmodified" to only save unmodified buffers
          autosave_changes = false,
        },

        -- Oil will automatically delete hidden buffers after this delay
        -- You can set the delay to false to disable cleanup entirely
        -- Note that the cleanup process only starts when none of the oil buffers are currently displayed
        cleanup_delay_ms = 2000,
        -- Buffer-local options to use for oil buffers
        buf_options = {
          buflisted = false,
          bufhidden = 'hide',
        },

        view_options = {
          -- Show files and directories that start with "."
          show_hidden = true,
          -- This function defines what is considered a "hidden" file
          is_hidden_file = function(name, bufnr)
            local m = name:match '^%.'
            return m ~= nil
          end,
          -- Sort file names with numbers in a more intuitive order for humans.
          -- Can be "fast", true, or false. "fast" will turn it off for large directories.
          natural_order = 'fast',
          -- Sort file and directory names case insensitive
          case_insensitive = false,
          sort = {
            -- sort order can be "asc" or "desc"
            -- see :help oil-columns to see which columns are sortable
            { 'type', 'asc' },
            { 'name', 'asc' },
          },
          -- Customize the highlight group for the file name
          highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan) return nil end,
        },
        -- Window-local options to use for oil buffers
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

        -- Don't confirm before performing mutations; the buffer edit IS the intent.
        -- Mirrors dired's behaviour where saving the buffer applies changes.
        delete_to_trash = true,
        skip_confirm_for_simple_edits = true,
        prompt_save_on_select_new_entry = false,

        -- Constrain the cursor to the editable parts of the oil buffer
        -- Set to `false` to disable, or "name" to keep it on the file names
        constrain_cursor = 'editable',
        -- Set to true to watch the filesystem for changes and reload oil
        watch_for_changes = false,
        -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
        -- options with a `callback` (e.g. { callback = function() ... end, desc = "", mode = "n" })
        -- Additionally, if it is a string that matches "actions.<name>",
        -- it will use the mapping at require("oil.actions").<name>
        -- Set to `false` to remove a keymap
        -- See :help oil-actions for a list of all available actions
        -- Set to false to disable all of the above keymaps
        use_default_keymaps = true,
        -- Entering oil lands you in READ-ONLY / navigation mode (like dired).
        -- The buffer becomes editable only when the user explicitly requests it.
        -- This is handled via keymaps below rather than a built-in oil flag.

        keymaps = {
          -- ----------------------------------------------------------------
          -- Navigation (modal, dired-style: h/l move up/down the tree)
          -- ----------------------------------------------------------------
          ['l'] = { 'actions.select', mode = 'n' }, -- open / descend
          ['h'] = { 'actions.parent', mode = 'n' }, -- ascend
          ['<CR>'] = { 'actions.select', mode = 'n' },
          ['<BS>'] = { 'actions.parent', mode = 'n' },

          -- Preview without leaving oil (splits, consistent with picker preview)
          ['<C-p>'] = { 'actions.preview', mode = 'n' },

          -- ----------------------------------------------------------------
          -- Dired "enter edit mode" equivalent.
          -- In dired this is 'C-x C-q' or wdired-change-to-wdired-mode.
          -- We use 'I' (capital i) — mnemonic: Insert/edit.
          -- ----------------------------------------------------------------
          ['I'] = {
            desc = 'Enter editable (wdired) mode',
            mode = 'n',
            callback = function()
              -- Remove the nomodifiable lock that read-only mode sets
              vim.bo.modifiable = true
              vim.bo.readonly = false
              vim.notify('Oil: edit mode — save (:w) to apply, (:q!) to abort', vim.log.levels.INFO, { title = 'oil.nvim' })
            end,
          },

          -- Escape / abort: restore read-only and revert buffer
          ['<Esc>'] = {
            desc = 'Abort edits and return to navigation mode',
            mode = 'n',
            callback = function()
              if vim.bo.modifiable then
                -- Revert any pending mutations
                require('oil').discard_all_changes()
                vim.bo.modifiable = false
                vim.notify('Oil: changes discarded', vim.log.levels.WARN, { title = 'oil.nvim' })
              else
                -- No edits pending; just close like dired 'q'
                require('oil').close()
              end
            end,
          },

          -- Save = apply mutations (mirrors dired C-c C-c)
          ['<C-s>'] = {
            desc = 'Apply mutations and return to navigation mode',
            mode = 'n',
            callback = function()
              vim.cmd.write()
              vim.bo.modifiable = false
            end,
          },

          -- Toggle hidden files, mirrors your picker's <C-h>
          ['<C-h>'] = { 'actions.toggle_hidden', mode = 'n' },

          -- Refresh
          ['<C-r>'] = { 'actions.refresh', mode = 'n' },

          -- Open in system default application
          ['gx'] = { 'actions.open_external', mode = 'n' },

          -- Copy path to clipboard (useful companion to your picker)
          ['gy'] = { 'actions.copy_entry_path', mode = 'n' },

          -- Close oil and return to previous buffer
          ['q'] = { 'actions.close', mode = 'n' },

          -- Disable keymaps that conflict with navigation-mode intent
          ['<C-l>'] = false, -- would normally be 'refresh' but clashes with window nav
        },

        -- Start every oil buffer in non-editable navigation mode.
        -- The 'I' keymap above unlocks it on demand.
        keymaps_help = { border = 'rounded' },

        -- Restore navigation-mode (nomodifiable) every time an oil buffer is entered
        -- so that switching away and back doesn't leave you in edit mode accidentally.
      },

      config = function(_, opts)
        require('oil').setup(opts)

        -- Enforce navigation mode whenever we enter any oil buffer
        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'oil',
          callback = function()
            vim.bo.modifiable = false
            vim.bo.readonly = false -- readonly would block oil's internal writes
          end,
        })
      end,
    },
    ['nvim-mini/mini.files'] = {
      dependencies = { 'nvim-mini/mini.pick' },
      version = false,
      config = function()
        local mfc = require 'utils.file_browsing.file_search_config'
        -- Load the autocmd/keymap module after setup so MiniFiles global exists.
        -- TODO do this better
        require 'utils.file_browsing.directory_editor'

        require('mini.files').setup {
          content = {
            prefix = mfc.make_prefix,
            highlight = mfc.make_highlight,
          },
          options = {
            permanent_delete = false,
            use_as_default_explorer = false,
          },
          windows = {
            preview = true,
            width_focus = 50,
            width_nofocus = 20,
            width_preview = 60,
          },
        }
      end,
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────

  setup = function()
    -- ── State providers ─────────────────────────────────────────────
    env.state.register_provider {
      id = 'filesystem.tree_visible',
      events = { 'BufEnter', 'WinEnter', 'WinClosed' },
      collect = function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == 'neo-tree' then return true end
        end
        return false
      end,
      desc = 'Whether the neo-tree file tree is visible',
    }

    -- ── Filesystem keymaps ─────────────────────────────────────────

    ----------------------------------------------------------------
    -- Find / picker
    ----------------------------------------------------------------

    -- if state['workspace.cwd'] ~= nil then
    --   vim.keymap.set('n', '<leader>sd', function() env.use('picker').grep() end, { desc = 'filesystem.grep', silent = true })
    -- end

    local snacks = require 'snacks'
    vim.ui.picker.recent_files = function(o) snacks.picker.recent(o) end
    vim.keymap.set('n', '<leader>fr', function() vim.ui.picker.recent_files() end, { desc = 'filesystem.find_recent', silent = true })

    ----------------------------------------------------------------
    -- File finding
    ----------------------------------------------------------------

    vim.ui.picker.files_at = function(opts) require('utils.file_browsing.mini_picker').find_file_at(opts) end
    vim.keymap.set(
      'n',
      '<leader>ff',
      '',
      { desc = 'filesystem.find_files_at', callback = function() vim.ui.picker.files_at { cwd = vim.fn.getcwd() } end, silent = true }
    )

    -- if state['workspace.root'] ~= nil then
    --   vim.keymap.set(
    --     'n',
    --     '<leader>pf',
    --     function()
    --       env.use('picker').files {
    --         title = 'Files — ' .. (env.state.get 'workspace.project_name' or ''),
    --       }
    --     end,
    --     { desc = 'filesystem.find_project_files', silent = true }
    --   )
    -- end

    -- overrides vim.ui.picker to leverage mini-picker and make things update live
    vim.ui.picker.grep = function(o)
      require('mini.pick').builtin.grep_live(
        { globs = vim.fn.resolve(o.cwd or vim.fn.getcwd()) },
        vim.tbl_extend('force', {
          -- NOTE this is meant to make a centered window
          -- TODO pull this from the same source and utils.file_browsing.mini_picker
          window = {
            config = function()
              local height = math.floor(0.618 * vim.o.lines)
              local width = math.floor(0.618 * vim.o.columns)
              return {
                anchor = 'NW',
                height = height,
                width = width,
                row = math.floor(0.5 * (vim.o.lines - height)),
                col = math.floor(0.5 * (vim.o.columns - width)),
              }
            end,
          },
        }, o or {})
      )
    end
    vim.keymap.set('n', '<leader>sd', function() vim.ui.picker.grep { cwd = vim.fn.getcwd() } end, { desc = 'filesystem.search_cwd', silent = true })

    ----------------------------------------------------------------
    -- Copy path utilities
    ----------------------------------------------------------------

    -- if state['buffer.is_real'] then
    --   ---Copy relative path to clipboard
    --   local function copy_relative_path()
    --     local path = vim.fn.expand '%:.'
    --     vim.fn.setreg('+', path)
    --     vim.notify('Copied: ' .. path)
    --   end
    --
    --   vim.keymap.set('n', '<leader>fy', copy_relative_path, { desc = 'filesystem.copy_relative_path', silent = true })
    --
    --   ---Copy absolute path to clipboard
    --   local function copy_absolute_path()
    --     local path = vim.fn.expand '%:p'
    --     vim.fn.setreg('+', path)
    --     vim.notify('Copied: ' .. path)
    --   end
    --
    --   vim.keymap.set('n', '<leader>fY', copy_absolute_path, { desc = 'filesystem.copy_absolute_path', silent = true })
    -- end
  end,
}
