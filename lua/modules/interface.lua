-- lua/modules/interface.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface

local env = require 'env'

return env.module.register {
  name = 'interface',
  domain = 'interface',
  depends_on = {},
  optional_deps = {},

  -- ── Plugin option contributions ──────────────────────────────────────
  -- Each key is a plugin string. Values are merged across all modules
  -- before being passed to lazy. No config functions here: setup() below
  -- handles all env surface registrations after plugins are loaded.

  plugins = {
    -- ['https://codeberg.org/comfysage/artio.nvim'] = {
    --   lazy = false,
    -- },
    ['t-troebst/perfanno.nvim'] = {
      lazy = false,
    },
    ['stevearc/oil.nvim'] = {
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      opts = {
        default_file_explorer = true,

        -- Columns shown in the oil buffer — mirrors what your picker shows
        columns = {
          'permissions',
          'size',
          'mtime',
          'icon',
        },

        -- Buffer-local options applied to the oil buffer
        buf_options = {
          buflisted = false,
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
      },
    },
    ['folke/snacks.nvim'] = {
      priority = 1000,
      lazy = false,
      opts = {
        profiler = {
          autocmd = true,
        },
        picker = {
          ui_select = true,
          layout = { preset = 'default', cycle = true },
          formatters = { file = { filename_first = true } },
          matcher = { frecency = true },
          win = {
            input = {
              keys = {
                ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
              },
            },
          },
        },
        notifier = {
          enabled = false,
          timeout = 3000,
          sort = { 'level', 'added' },
          level = vim.log.levels.TRACE,
          style = 'compact',
          top_down = false,
        },
        input = { enabled = true },
        indent = {
          enabled = false,
          animate = { enabled = false },
          scope = { enabled = true },
        },
        scope = { enabled = true },
        words = { enabled = true },
        bigfile = { enabled = true, size = 1.5 * 1024 * 1024 },
        scratch = { enabled = true },
        dashboard = { enabled = false },
        -- Explicitly disable snacks modules owned by other modules
        terminal = { enabled = false }, -- execution module
        zen = { enabled = false },
        animate = { enabled = false },
      },
    },

    -- Helps with mini.pick
    ['nvim-mini/mini.icons'] = {
      version = false,
    },

    ['nvim-mini/mini.sessions'] = {
      version = false,
    },
    ['s1n7ax/nvim-window-picker'] = {
      name = 'window-picker',
      event = 'VeryLazy',
      version = '2.*',
      config = function() require('window-picker').setup() end,
    },
    ['folke/tokyonight.nvim'] = {
      priority = 900,
      lazy = false,
      opts = {
        style = 'storm',
        transparent = true,
        styles = { sidebars = 'dark', floats = 'dark' },
        on_highlights = function(hl, c) hl.EnvDisplayVirtualText = { fg = c.comment, italic = true } end,
      },
    },

    ['folke/which-key.nvim'] = {
      event = 'VeryLazy',
      opts = {
        preset = 'modern',
        delay = 300,
        icons = { mappings = true },
        -- Top-level group labels: the keymap grammar skeleton.
        -- Domain modules add entries within these groups.
        spec = {
          { '<leader>f', group = 'find' },
          { '<leader>b', group = 'buffers' },
          { '<leader>g', group = 'git' },
          { '<leader>l', group = 'lsp' },
          { '<leader>t', group = 'tasks' },
          { '<leader>p', group = 'project' },
          { '<leader>c', group = 'config' },
          { '<leader>u', group = 'ui' },
          { '<leader>x', group = 'files' },
        },
      },
    },
    ['chrisgrieser/nvim-origami'] = {
      event = 'VeryLazy',
      pauseFoldsOnSearch = true,
      opts = {
        foldtext = {
          lineCount = {
            template = ' %d',
          },
        },
      },
      -- NOTE this was taken from "The Art of Code Folds (nvim origami)"
      -- youtube: https://www.youtube.com/watch?v=l6uz_VhP8BU
      -- gist: https://gist.github.com/AdamFrenzen/497ea55d4c49699d96c3ac0e8c4ea094
      init = function()
        -- This sets folds to be open by default
        -- TODO I'd like to leverage some tree-sitter based heuristics for setting the default fold level
        vim.opt.foldlevel = 99
        vim.opt.foldlevelstart = 99

        local fold_util = require 'utils.code_fold'
        -- Helper to determine if a buffer should have folding applied
        local function is_code_buffer(buf)
          local buftype = vim.bo[buf].buftype
          local filetype = vim.bo[buf].filetype

          -- Only apply to normal file buffers (not terminals, quickfix, etc.)
          if buftype ~= '' then return false end

          -- Blocklist of filetypes to exclude
          local excluded_filetypes = {
            ['NeogitStatus'] = true,
            ['NeogitCommitMessage'] = true,
            ['NeogitLogView'] = true,
            ['NeogitDiffView'] = true,
            ['gitcommit'] = true,
            ['help'] = true,
            ['man'] = true,
            ['oil'] = true,
            ['lazy'] = true,
            ['mason'] = true,
          }

          if excluded_filetypes[filetype] then return false end

          return true
        end
        vim.keymap.set('n', '<CR>', 'za', { noremap = true, silent = true })
        vim.keymap.set('n', '[[', fold_util.goto_previous_fold, { noremap = true, silent = true })
        vim.keymap.set('n', ']]', 'zj', { noremap = true, silent = true })

        vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'LspAttach' }, {
          callback = function(opts)
            if is_code_buffer(opts.buf) then fold_util.update_ranges(opts.buf) end
          end,
        })

        local last_row = nil
        vim.api.nvim_create_autocmd('CursorMoved', {
          callback = function(opts)
            if not is_code_buffer(opts.buf) then return end
            local row = vim.api.nvim_win_get_cursor(0)[1]
            if row ~= last_row then
              last_row = row
              fold_util.update_current_fold(row, opts.buf)
            end
          end,
        })

        vim.api.nvim_create_autocmd({ 'BufUnload', 'BufWipeout' }, {
          callback = function(opts) fold_util.clear(opts.buf) end,
        })

        vim.opt.statuscolumn = '%!v:lua.StatusCol()'
        function _G.StatusCol() return fold_util.statuscol() end
      end,
    },
    -- ['simifalaye/minibuffer.nvim'] = { lazy = false },

    ['nvim-mini/mini.pick'] = {
      version = false,
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.
  setup = function()
    local snacks = require 'snacks'

    -- ── Apply colorscheme ───────────────────────────────────────────
    require('tokyonight').setup(
      -- opts already applied by lazy via plugins["folke/tokyonight.nvim"].opts
      -- calling setup again here is a no-op but makes the apply explicit
    )
    vim.cmd.colorscheme 'tokyonight-storm'

    -- ── Picker capability ───────────────────────────────────────────
    -- -- Extend picker with interface-level finders
    env.capabilities.extend('picker', {
      help = function(o) snacks.picker.help(o) end,
      notifications = function(o) snacks.picker.notifications(o) end,
      recent = function(o) snacks.picker.recent(o) end,
      colorschemes = function(o) snacks.picker.colorschemes(o) end,
    }, 'interface')

    -- ── State providers ─────────────────────────────────────────────
    env.state.register_provider {
      id = 'interface.notification_count',
      events = { 'User' },
      pattern = 'SnacksNotifierUpdated',
      collect = function() return #snacks.notifier.get_history() end,
      desc = 'Number of notifications in snacks history',
    }

    -- Default mini.pick capabilities
    -- Centered on screen
    require('mini.icons').setup()
    local mfc = require 'utils.file_browsing.file_search_config'
    -- Load the autocmd/keymap module after setup so MiniFiles global exists.
    require 'utils.file_browsing.directory_editor'

    require('mini.pick').setup {
      mappings = {
        toggle_info = '<C-k>',
        move_up = '',
        toggle_preview = '<C-p>',
      },
    }

    -- Experimental UI2: floating cmdline and messages
    -- No more "hit enter after commands"
    vim.o.cmdheight = 1
    require('vim._core.ui2').enable {
      enable = true,
      msg = {
        targets = {
          [''] = 'msg',
          empty = 'cmd',
          bufwrite = 'msg',
          confirm = 'cmd',
          emsg = 'pager',
          echo = 'msg',
          echomsg = 'msg',
          echoerr = 'pager',
          completion = 'cmd',
          list_cmd = 'pager',
          lua_error = 'pager',
          lua_print = 'msg',
          progress = 'pager',
          rpc_error = 'pager',
          quickfix = 'msg',
          search_cmd = 'cmd',
          search_count = 'cmd',
          shell_cmd = 'pager',
          shell_err = 'pager',
          shell_out = 'pager',
          shell_ret = 'msg',
          undo = 'msg',
          verbose = 'pager',
          wildlist = 'cmd',
          wmsg = 'msg',
          typed_cmd = 'cmd',
        },
        cmd = {
          height = 0.5,
        },
        dialog = {
          height = 0.5,
        },
        msg = {
          height = 0.3,
          timeout = 5000,
          target = 'msg',
        },
        pager = {
          height = 0.5,
        },
      },
    }
    -- vim.ui.picker.env.capabilities.register('picker', {
    --   files = function(o) require('utils.file_browsing.mini_picker').find_file_at(o ~= nil and o or vim.fn.getcwd()) end,
    --   grep = function(o) snacks.picker.grep(o) end,
    --   buffers = function(o) snacks.picker.buffers(o) end,
    --   -- keymaps  = function(o) snacks.picker.keymaps(o)  end,
    --   -- commands = function(o) snacks.picker.commands(o) end,
    -- }, 'interface')
    --
    -- Customize the style of the notification window
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'msg',
      callback = function()
        local ui2 = require 'vim._core.ui2'
        local win = ui2.wins and ui2.wins.msg
        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_set_option_value('winhighlight', 'Normal:NormalFloat,FloatBorder:FloatBorder', { scope = 'local', win = win })
        end
      end,
    })

    local ui2 = require 'vim._core.ui2'
    local msgs = require 'vim._core.ui2.messages'
    local orig_set_pos = msgs.set_pos
    -- Set position to top right corner
    msgs.set_pos = function(tgt)
      orig_set_pos(tgt)
      if (tgt == 'msg' or tgt == nil) and vim.api.nvim_win_is_valid(ui2.wins.msg) then
        pcall(vim.api.nvim_win_set_config, ui2.wins.msg, {
          relative = 'editor',
          anchor = 'NE',
          row = 1,
          col = vim.o.columns - 1,
          border = 'rounded',
        })
      end
    end

    require('mini.sessions').setup()
    -- ── Interface keymaps ───────────────────────────────────────────

    -- restart (TODO: relocate later)
    vim.keymap.set('n', '<leader>R', function() MiniSessions.restart() end, { desc = 'interface.restart', silent = true })

    ----------------------------------------------------------------
    -- Buffer management
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>bb', function() env.use('picker').buffers() end, { desc = 'interface.find_buffers', silent = true })

    -- if env.state.get()['buffer.is_real'] then
    --   vim.keymap.set('n', '<leader>bd', function() snacks.bufdelete() end, { desc = 'interface.close_buffer', silent = true })
    -- end

    vim.keymap.set('n', '<leader>bo', function() snacks.bufdelete.other() end, { desc = 'interface.close_other_buffers', silent = true })

    vim.keymap.set('n', ']b', function() vim.cmd 'bnext' end, { desc = 'interface.next_buffer', silent = true })

    vim.keymap.set('n', '[b', function() vim.cmd 'bprevious' end, { desc = 'interface.prev_buffer', silent = true })

    vim.keymap.set('n', '<leader>bs', function() snacks.scratch() end, { desc = 'interface.scratch_buffer', silent = true })

    ----------------------------------------------------------------
    -- Basic introspection
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>fk', function() env.use('picker').keymaps() end, { desc = 'interface.find_keymaps', silent = true })

    vim.keymap.set('n', '<leader>fC', function() env.use('picker').commands() end, { desc = 'interface.find_commands', silent = true })

    vim.keymap.set('n', '<leader>fh', function() env.use('picker').help() end, { desc = 'interface.find_help', silent = true })

    vim.keymap.set('n', '<leader>fn', function() env.use('picker').notifications() end, { desc = 'interface.find_notifications', silent = true })

    ----------------------------------------------------------------
    -- UI toggles
    ----------------------------------------------------------------

    vim.keymap.set(
      'n',
      '<leader>ud',
      function() vim.diagnostic.enable(not vim.diagnostic.is_enabled()) end,
      { desc = 'interface.toggle_diagnostics', silent = true }
    )

    ---Toggle absolute + relative line numbers
    local function toggle_line_numbers()
      vim.opt.number = not vim.opt.number:get()
      vim.opt.relativenumber = not vim.opt.relativenumber:get()
    end

    vim.keymap.set('n', '<leader>ul', toggle_line_numbers, { desc = 'interface.toggle_line_numbers', silent = true })

    vim.keymap.set('n', '<leader>uw', function() snacks.words.toggle() end, { desc = 'interface.toggle_word_highlights', silent = true })

    vim.keymap.set('n', '<leader>ui', function() snacks.indent.toggle() end, { desc = 'interface.toggle_indent_guides', silent = true })

    vim.keymap.set('n', '<leader>uz', function() snacks.zen.zoom() end, { desc = 'interface.zoom_window', silent = true })

    ----------------------------------------------------------------
    -- Config inspection
    ----------------------------------------------------------------

    vim.keymap.set(
      'n',
      '<leader>cc',
      function()
        env.use('picker').files {
          cwd = vim.fn.stdpath 'config',
          title = 'Config files',
        }
      end,
      { desc = 'interface.find_in_config', silent = true }
    )

    vim.keymap.set(
      'n',
      '<leader>cg',
      function()
        env.use('picker').grep {
          cwd = vim.fn.stdpath 'config',
          title = 'Grep config',
        }
      end,
      { desc = 'interface.grep_config', silent = true }
    )

    vim.keymap.set('n', '<leader>cs', function() vim.cmd 'ConfigStatus' end, { desc = 'interface.config_status', silent = true })

    vim.keymap.set('n', '<leader>cS', function() vim.cmd 'ConfigStatus state' end, { desc = 'interface.config_status_state', silent = true })

    vim.keymap.set('n', '<leader>cl', function() require('lazy').home() end, { desc = 'interface.lazy', silent = true })
  end,
}
