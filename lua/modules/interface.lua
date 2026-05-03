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
      lazy = false,
    },

    ['nvim-mini/mini.sessions'] = {
      version = false,
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
    -- ['chrisgrieser/nvim-origami'] = {
    --   event = 'VeryLazy',
    --   pauseFoldsOnSearch = true,
    --   opts = {
    --     foldtext = {
    --       lineCount = {
    --         template = ' %d',
    --       },
    --     },
    --   },
    --   -- NOTE this was taken from "The Art of Code Folds (nvim origami)"
    --   -- youtube: https://www.youtube.com/watch?v=l6uz_VhP8BU
    --   -- gist: https://gist.github.com/AdamFrenzen/497ea55d4c49699d96c3ac0e8c4ea094
    --   init = function()
    --     -- This sets folds to be open by default
    --     -- TODO I'd like to leverage some tree-sitter based heuristics for setting the default fold level
    --     vim.opt.foldlevel = 99
    --     vim.opt.foldlevelstart = 99
    --
    --     local fold_util = require 'utils.code_fold'
    --     -- Helper to determine if a buffer should have folding applied
    --     local function is_code_buffer(buf)
    --       local buftype = vim.bo[buf].buftype
    --       local filetype = vim.bo[buf].filetype
    --
    --       -- Only apply to normal file buffers (not terminals, quickfix, etc.)
    --       if buftype ~= '' then return false end
    --
    --       -- Blocklist of filetypes to exclude
    --       local excluded_filetypes = {
    --         ['NeogitStatus'] = true,
    --         ['NeogitCommitMessage'] = true,
    --         ['NeogitLogView'] = true,
    --         ['NeogitDiffView'] = true,
    --         ['gitcommit'] = true,
    --         ['help'] = true,
    --         ['man'] = true,
    --         ['oil'] = true,
    --         ['lazy'] = true,
    --         ['mason'] = true,
    --       }
    --
    --       if excluded_filetypes[filetype] then return false end
    --
    --       return true
    --     end
    --     vim.keymap.set('n', '<CR>', 'za', { noremap = true, silent = true })
    --     vim.keymap.set('n', '[[', fold_util.goto_previous_fold, { noremap = true, silent = true })
    --     vim.keymap.set('n', ']]', 'zj', { noremap = true, silent = true })
    --
    --     -- vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'LspAttach' }, {
    --     --   callback = function(opts)
    --     --     if is_code_buffer(opts.buf) then fold_util.update_ranges(opts.buf) end
    --     --   end,
    --     -- })
    --     --
    --     -- local last_row = nil
    --     -- vim.api.nvim_create_autocmd('CursorMoved', {
    --     --   callback = function(opts)
    --     --     if not is_code_buffer(opts.buf) then return end
    --     --     local row = vim.api.nvim_win_get_cursor(0)[1]
    --     --     if row ~= last_row then
    --     --       last_row = row
    --     --       fold_util.update_current_fold(row, opts.buf)
    --     --     end
    --     --   end,
    --     -- })
    --     --
    --     -- vim.api.nvim_create_autocmd({ 'BufUnload', 'BufWipeout' }, {
    --     --   callback = function(opts) fold_util.clear(opts.buf) end,
    --     -- })
    --     --
    --     -- vim.opt.statuscolumn = '%!v:lua.StatusCol()'
    --     -- function _G.StatusCol() return fold_util.statuscol() end
    --   end,
    -- },
    -- ['simifalaye/minibuffer.nvim'] = {
    --   lazy = false,
    --   init = function()
    --     local minibuffer = require 'minibuffer'
    --
    --     vim.ui.select = require 'minibuffer.builtin.ui_select'
    --     vim.ui.input = require 'minibuffer.builtin.ui_input'
    --
    --     vim.keymap.set('n', '<M-;>', require 'minibuffer.builtin.cmdline')
    --     vim.keymap.set('n', '<M-.>', function() minibuffer.resume(true) end)
    --   end,
    -- },
    -- ['dmtrKovalenko/fff.nvim'] = {
    --   build = function()
    --     -- downloads a prebuilt binary or falls back to cargo build
    --     require('fff.download').download_or_build_binary()
    --   end,
    --   -- for nixos:
    --   -- build = "nix run .#release",
    --   opts = {
    --     debug = {
    --       enabled = true,
    --       show_scores = true,
    --     },
    --   },
    --   lazy = false, -- the plugin lazy-initialises itself
    --   -- keys = {
    --   --   { 'ff', function() require('fff').find_files() end, desc = 'FFFind files' },
    --   --   { 'fg', function() require('fff').live_grep() end, desc = 'LiFFFe grep' },
    --   --   { 'fz', function() require('fff').live_grep { grep = { modes = { 'fuzzy', 'plain' } } } end, desc = 'Live fffuzy grep' },
    --   --   { 'fc', function() require('fff').live_grep { query = vim.fn.expand '<cword>' } end, desc = 'Search current word' },
    --   -- },
    -- },
    -- ['https://codeberg.org/comfysage/artio.nvim'] = {
    --   lazy = false,
    -- },
    ['t-troebst/perfanno.nvim'] = {
      lazy = false,
    },
    ['rachartier/tiny-cmdline.nvim'] = {
      init = function() vim.o.cmdheight = 0 end,
      lazy = false,
    },
    ['stevearc/conform.nvim'] = {
      event = { 'BufWritePre' },
      cmd = { 'ConformInfo' },
      opts = {
        formatters_by_ft = {
          lua = { 'stylua' },
          python = {
            'ruff_format', -- fast, uv-aware
            'ruff_organize_imports',
          },
          -- Fallback for any filetype with an LSP that can format
          ['_'] = { 'trim_whitespace' },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_format = 'fallback', -- use LSP if no conform formatter
        },
        formatters = {
          stylua = {
            -- stylua reads StyLua.toml from the project root
            -- no extra config needed; uv projects have pyproject.toml
            -- stylua has its own config discovery
          },
          ruff_format = {
            -- ruff respects pyproject.toml [tool.ruff] automatically
            condition = function(_, ctx)
              -- only run ruff in python projects
              return vim.fs.find({ 'pyproject.toml', 'ruff.toml', '.ruff.toml' }, { path = ctx.filename, upward = true })[1] ~= nil
            end,
          },
        },
      },
    },
    ['nvim-mini/mini.pick'] = {
      version = false,
      -- NOTE this will automatically override vim.ui.select
      lazy = false,
      opts = {
        mappings = {
          toggle_info = '<C-k>',
          move_up = '',
          toggle_preview = '<C-p>',
        },
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
      },
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.
  setup = function()
    local snacks = require 'snacks'
    vim.fn.toggle_zoom = snacks.zen.zoom

    -- ── Apply colorscheme ───────────────────────────────────────────
    require('tokyonight').setup(
      -- opts already applied by lazy via plugins["folke/tokyonight.nvim"].opts
      -- calling setup again here is a no-op but makes the apply explicit
    )
    vim.cmd.colorscheme 'tokyonight-storm'

    -- ── State providers ─────────────────────────────────────────────
    env.state.register_provider {
      id = 'interface.notification_count',
      events = { 'User' },
      pattern = 'SnacksNotifierUpdated',
      collect = function() return #snacks.notifier.get_history() end,
      desc = 'Number of notifications in snacks history',
    }

    -- NOTE: after loading plugin
    -- local picker_ui = require 'fff.picker_ui'
    -- picker_ui.open = require 'minibuffer.integrations.fff'

    -- vim.ui.picker.env.capabilities.register('picker', {
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

    -- ── Interface keymaps ───────────────────────────────────────────

    -- Window zoom toggle (simplified)
    local function toggle_zoom()
      local function is_zoomed() return vim.t.zoomed or false end

      local function zoom_session_file()
        if not vim.t.zoom_session_file then
          vim.t.zoom_session_file = vim.fn.tempname() .. '_' .. vim.api.nvim_tabpage_get_number(0)
          vim.api.nvim_create_autocmd('TabClosed', {
            callback = function()
              if vim.t.zoom_session_file then os.remove(vim.t.zoom_session_file) end
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
        if #vim.api.nvim_tabpage_list_wins(0) == 1 then return end
        local old_sessionoptions = vim.o.sessionoptions
        vim.o.sessionoptions = 'blank,buffers,curdir,terminal,help'
        vim.cmd('mksession! ' .. zoom_session_file())
        vim.cmd 'only'
        vim.t.zoomed = true
        vim.o.sessionoptions = old_sessionoptions
      end
    end
    vim.fn.toggle_zoom = toggle_zoom

    ----------------------------------------------------------------
    -- Window navigation
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>wf', '', {
      silent = true,
      callback = function() vim.fn.toggle_zoom() end,
      desc = 'base.window_zoom',
    })

    vim.keymap.set('n', '<leader>wh', '<C-w>h', { silent = true, desc = 'base.window_left' })
    vim.keymap.set('n', '<leader>wj', '<C-w>j', { silent = true, desc = 'base.window_down' })
    vim.keymap.set('n', '<leader>wk', '<C-w>k', { silent = true, desc = 'base.window_up' })
    vim.keymap.set('n', '<leader>wl', '<C-w>l', { silent = true, desc = 'base.window_right' })

    vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<cr>', { silent = true, desc = 'base.window_vsplit' })
    vim.keymap.set('n', '<leader>ws', '<cmd>split<cr>', { silent = true, desc = 'base.window_split' })

    ----------------------------------------------------------------
    -- Window repositioning
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>H', '<C-w>H', { silent = true, desc = 'base.window_move_left' })
    vim.keymap.set('n', '<leader>J', '<C-w>J', { silent = true, desc = 'base.window_move_down' })
    vim.keymap.set('n', '<leader>K', '<C-w>K', { silent = true, desc = 'base.window_move_up' })
    vim.keymap.set('n', '<leader>L', '<C-w>L', { silent = true, desc = 'base.window_move_right' })

    vim.keymap.set('n', '<leader>wd', '<C-w>c', { silent = true, desc = 'base.window_delete' })
    vim.keymap.set('n', '<leader>wo', '<C-w>o', { silent = true, desc = 'base.window_delete_others' })

    ----------------------------------------------------------------
    -- Buffer management
    ----------------------------------------------------------------

    -- vim.ui.picker.buffers = function(o) snacks.picker.buffers(o) end
    vim.keymap.set('n', '<leader>bb', function() vim.ui.picker.buffers() end, { desc = 'interface.find_buffers', silent = true })

    vim.keymap.set('n', '<leader>bo', function() snacks.bufdelete.other() end, { desc = 'interface.close_other_buffers', silent = true })

    vim.keymap.set('n', '<leader>bs', function() snacks.scratch() end, { desc = 'interface.scratch_buffer', silent = true })

    vim.keymap.set('n', '<S-l>', '<cmd>bnext<cr>', { silent = true, desc = 'base.buffer_next' })
    vim.keymap.set('n', '<S-h>', '<cmd>bprevious<cr>', { silent = true, desc = 'base.buffer_prev' })
    vim.keymap.set('n', '<leader>bd', '<cmd>bdelete<cr>', { silent = true, desc = 'base.buffer_delete' })

    ----------------------------------------------------------------
    -- Quit
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>qq', '<cmd>qa<cr>', { silent = true, desc = 'base.quit_all' })
    vim.keymap.set('n', '<leader>wq', '<cmd>wqa<cr>', { silent = true, desc = 'base.write_quit_all' })

    ----------------------------------------------------------------
    -- Toggles
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>tn', '<cmd>set number!<cr>', { silent = true, desc = 'base.toggle_number' })
    vim.keymap.set('n', '<leader>tr', '<cmd>set relativenumber!<cr>', { silent = true, desc = 'base.toggle_relnumber' })
    vim.keymap.set('n', '<leader>ts', '<cmd>setlocal spell!<cr>', { silent = true, desc = 'base.toggle_spell' })
    vim.keymap.set('n', '<leader>tw', '<cmd>set wrap!<cr>', { silent = true, desc = 'base.toggle_wrap' })

    local function toggle_line_numbers()
      vim.opt.number = not vim.opt.number:get()
      vim.opt.relativenumber = not vim.opt.relativenumber:get()
    end

    vim.keymap.set('n', '<leader>ul', toggle_line_numbers, { desc = 'interface.toggle_line_numbers', silent = true })

    vim.keymap.set('n', '<leader>uw', function() snacks.words.toggle() end, { desc = 'interface.toggle_word_highlights', silent = true })

    vim.keymap.set('n', '<leader>ui', function() snacks.indent.toggle() end, { desc = 'interface.toggle_indent_guides', silent = true })

    vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>', {
      silent = true,
      desc = 'base.clear_search_highlight',
    })
  end,
}
