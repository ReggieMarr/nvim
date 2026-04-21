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

-- Declare a global function to retrieve the current directory
function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir = require('oil').get_current_dir(bufnr)
  if dir then
    return vim.fn.fnamemodify(dir, ':~')
  else
    -- If there is no current directory (e.g. over ssh), just show the buffer name
    return vim.api.nvim_buf_get_name(0)
  end
end

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
      lazy = true, -- we only open it programmatically from the picker
      opts = {
        -- Use the current window, consistent with your picker's non-disruptive philosophy
        default_file_explorer = false, -- don't hijack netrw, your picker handles that

        -- Columns mirror what your picker already shows: icon, permissions, size, mtime
        columns = {
          { 'icon', highlight = 'MiniPickNormal' },
          { 'permissions', highlight = 'Comment' },
          { 'size', highlight = 'Number' },
          { 'mtime', highlight = 'Special' },
        },

        buf_options = {
          buflisted = false,
          bufhidden = 'hide',
        },

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

        view_options = {
          show_hidden = false, -- toggled per-session via <C-h>
          -- Natural sort: directories before files, mirrors your picker's get_entries
          sort = {
            { 'type', 'asc' },
            { 'name', 'asc' },
          },
        },

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
  },

  -- ── Setup ─────────────────────────────────────────────────────────────

  setup = function()
    require('oil').setup {
      -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
      -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
      default_file_explorer = true,
      -- Id is automatically added at the beginning, and name at the end
      -- See :help oil-columns
      columns = {
        'icon',
        'permissions',
        'size',
        'mtime',
      },
      -- Buffer-local options to use for oil buffers
      buf_options = {
        buflisted = false,
        bufhidden = 'hide',
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
      -- Send deleted files to the trash instead of permanently deleting them (:help oil-trash)
      delete_to_trash = false,
      -- Skip the confirmation popup for simple operations (:help oil.skip_confirm_for_simple_edits)
      skip_confirm_for_simple_edits = false,
      -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
      -- (:help prompt_save_on_select_new_entry)
      prompt_save_on_select_new_entry = true,
      -- Oil will automatically delete hidden buffers after this delay
      -- You can set the delay to false to disable cleanup entirely
      -- Note that the cleanup process only starts when none of the oil buffers are currently displayed
      cleanup_delay_ms = 2000,
      lsp_file_methods = {
        -- Enable or disable LSP file operations
        enabled = true,
        -- Time to wait for LSP file operations to complete before skipping
        timeout_ms = 1000,
        -- Set to true to autosave buffers that are updated with LSP willRenameFiles
        -- Set to "unmodified" to only save unmodified buffers
        autosave_changes = false,
      },
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
      view_options = {
        -- Show files and directories that start with "."
        show_hidden = false,
        -- This function defines what is considered a "hidden" file
        is_hidden_file = function(name, bufnr)
          local m = name:match '^%.'
          return m ~= nil
        end,
        -- This function defines what will never be shown, even when `show_hidden` is set
        is_always_hidden = function(name, bufnr) return false end,
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
      -- Configuration for the floating action confirmation window
      confirmation = {
        -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
        -- min_width and max_width can be a single value or a list of mixed integer/float types.
        -- max_width = {100, 0.8} means "the lesser of 100 columns or 80% of total"
        max_width = 0.9,
        -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
        min_width = { 40, 0.4 },
        -- optionally define an integer/float for the exact width of the preview window
        width = nil,
        -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
        -- min_height and max_height can be a single value or a list of mixed integer/float types.
        -- max_height = {80, 0.9} means "the lesser of 80 columns or 90% of total"
        max_height = 0.9,
        -- min_height = {5, 0.1} means "the greater of 5 columns or 10% of total"
        min_height = { 5, 0.1 },
        -- optionally define an integer/float for the exact height of the preview window
        height = nil,
        border = nil,
        win_options = {
          winblend = 0,
        },
      },
      -- Configuration for the floating progress window
      progress = {
        max_width = 0.9,
        min_width = { 40, 0.4 },
        width = nil,
        max_height = { 10, 0.9 },
        min_height = { 5, 0.1 },
        height = nil,
        border = nil,
        minimized_border = 'none',
        win_options = {
          winblend = 0,
        },
      },
    }
    -- ── Filesystem capability ───────────────────────────────────────
    env.capabilities.register('filesystem', {
      open_tree = function(path)
        require('neo-tree.command').execute {
          action = 'show',
          source = 'filesystem',
          position = 'left',
          dir = path or vim.fn.getcwd(),
          toggle = true,
        }
      end,

      reveal_file = function(filepath)
        require('neo-tree.command').execute {
          action = 'focus',
          source = 'filesystem',
          position = 'left',
          reveal_file = filepath or vim.api.nvim_buf_get_name(0),
        }
      end,

      close_tree = function() require('neo-tree.command').execute { action = 'close' } end,
    }, 'filesystem')

    -- ── Picker extensions ───────────────────────────────────────────
    -- File-specific finders registered as picker extensions.
    -- Other modules (language, vcs) similarly extend picker with their
    -- domain-specific finders in their own setup() calls.
    env.capabilities.extend('picker', {
      -- Find files scoped to cwd (generic files already in interface,
      -- this adds config-aware variants)
      directories = function(o)
        require('snacks').picker.pick(vim.tbl_extend('force', {
          source = 'directories',
          finder = 'files',
          filter = { cwd = true, dirs_only = true },
          title = 'Directories',
        }, o or {}))
      end,
    }, 'filesystem')

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

    -- Project root detection.
    -- Uses LSP root when available, falls back to common marker files.
    -- Registers as workspace.root to complement workspace.cwd from core.
    env.state.register_provider {
      id = 'workspace.root',
      events = { 'BufEnter', 'LspAttach' },
      collect = function()
        -- Prefer LSP-reported root: most accurate for the current file
        local clients = vim.lsp.get_clients { bufnr = 0 }
        for _, client in ipairs(clients) do
          if client.config.root_dir then return client.config.root_dir end
        end

        -- Fall back to marker-based detection
        local markers = {
          '.git',
          '.hg',
          'Makefile',
          'package.json',
          'Cargo.toml',
          'pyproject.toml',
          'go.mod',
        }
        local path = vim.fn.expand '%:p:h'
        local root = vim.fs.root(path, markers)
        return root or vim.fn.getcwd()
      end,
      desc = 'Project root directory for the current buffer',
    }

    env.state.register_provider {
      id = 'workspace.project_name',
      events = { 'BufEnter', 'DirChanged' },
      collect = function()
        -- Derive project name from root, falling back to cwd basename
        local root = env.state.get 'workspace.root' or env.state.get 'workspace.cwd' or vim.fn.getcwd()
        return vim.fn.fnamemodify(root, ':t')
      end,
      desc = 'Name of the current project (basename of root)',
    }

    -- ── Display contributions ───────────────────────────────────────
    env.display.register {
      id = 'filesystem.file_tree',
      module = 'filesystem',
      region = 'signs',
      priority = 90,
      desc = 'Neo-tree file explorer panel',
      -- No when condition: visibility is controlled by the toggle action
    }

    -- ── Articulation ────────────────────────────────────────────────
    env.articulation.register_group('filesystem', {
      -- Find / picker
      {
        id = 'grep',
        handler = function() env.use('picker').grep() end,
        desc = 'Grep current dir',
        bindings = { { lhs = '<leader>sd' } },
        when = function(state) return state['workspace.cwd'] ~= nil end,
      },
      {
        id = 'find_recent',
        handler = function() env.use('picker').recent() end,
        desc = 'Recent files',
        bindings = { { lhs = '<leader>fr' } },
      },

      -- File finding: extend the find group with filesystem-specific pickers
      -- {
      --   id = 'find_files',
      --   handler = function() env.use('picker').files() end,
      --   desc = 'Find files',
      --   bindings = { { lhs = '<leader>ff' } },
      --   when = function(state) return state['workspace.cwd'] ~= nil end,
      -- },
      {
        id = 'find_project_files',
        handler = function()
          env.use('picker').files {
            title = 'Files — ' .. (env.state.get 'workspace.project_name' or ''),
          }
        end,
        desc = 'Find project files',
        bindings = { { lhs = '<leader>pf' } },
        when = function(state) return state['workspace.root'] ~= nil end,
      },
      {
        id = 'find_directories',
        handler = function() env.use('picker').directories() end,
        desc = 'Find directories',
        bindings = { { lhs = '<leader>fd' } },
      },

      -- Copy path utilities
      {
        id = 'copy_relative_path',
        handler = function()
          local path = vim.fn.expand '%:.'
          vim.fn.setreg('+', path)
          vim.notify('Copied: ' .. path)
        end,
        desc = 'Copy relative path to clipboard',
        bindings = { { lhs = '<leader>fy' } },
        when = function(state) return state['buffer.is_real'] == true end,
      },
      {
        id = 'copy_absolute_path',
        handler = function()
          local path = vim.fn.expand '%:p'
          vim.fn.setreg('+', path)
          vim.notify('Copied: ' .. path)
        end,
        desc = 'Copy absolute path to clipboard',
        bindings = { { lhs = '<leader>fY' } },
        when = function(state) return state['buffer.is_real'] == true end,
      },
    })

    -- ── LspAttach integration ───────────────────────────────────────
    -- When LSP attaches to a buffer, update workspace.root immediately
    -- rather than waiting for the next BufEnter event.
    -- This ensures the state is current when LspAttach-triggered
    -- display conditions are evaluated.
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('filesystem_lsp_root', { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.config.root_dir then
          env.state._update('workspace.root', client.config.root_dir)
          env.state._update('workspace.project_name', vim.fn.fnamemodify(client.config.root_dir, ':t'))
        end
      end,
    })
  end,
}
