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
    ['nvim-mini/mini.pick'] = {
      version = false,
    },

    ['nvim-neo-tree/neo-tree.nvim'] = {
      dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons',
        'MunifTanjim/nui.nvim',
      },
      cmd = 'Neotree',
      opts = {
        close_if_last_window = true,
        enable_git_status = true,
        enable_diagnostics = true,
        open_files_do_not_replace_types = { 'terminal', 'trouble', 'qf' },
        default_component_configs = {
          indent = {
            indent_size = 2,
            with_markers = true,
            with_expanders = true,
          },
          icon = {
            folder_closed = '',
            folder_open = '',
            folder_empty = '',
          },
          modified = { symbol = '●' },
          git_status = {
            symbols = {
              added = '',
              modified = '',
              deleted = '✖',
              renamed = '󰁕',
              untracked = '',
              ignored = '',
              unstaged = '󰄱',
              staged = '',
              conflict = '',
            },
          },
        },
        window = {
          position = 'left',
          width = 35,
          mappings = {
            -- Keep window mappings minimal: heavy operations go
            -- through env.articulation so they appear in the registry
            ['<space>'] = 'none', -- avoid conflict with leader
            ['P'] = { 'toggle_preview', config = { use_float = true } },
          },
        },
        filesystem = {
          filtered_items = {
            visible = false,
            hide_dotfiles = false,
            hide_gitignored = true,
          },
          follow_current_file = { enabled = true },
          group_empty_dirs = true,
          use_libuv_file_watcher = true,
        },
        buffers = {
          follow_current_file = { enabled = true },
        },
        git_status = {
          window = { position = 'float' },
        },
      },
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────

  setup = function()
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

    -- Centered on screen
    require('mini.pick').setup {
      mappings = {
        toggle_info = '<C-k>',
        move_up = '',
        toggle_preview = '<C-p>',
      },
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
      {
        id = 'find_files',
        handler = function() env.use('picker').files() end,
        desc = 'Find files',
        bindings = { { lhs = '<leader>ff' } },
        when = function(state) return state['workspace.cwd'] ~= nil end,
      },
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
