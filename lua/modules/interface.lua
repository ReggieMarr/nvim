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
          max_width = math.floor(vim.o.columns * 0.8),
          max_height = math.floor(vim.o.lines * 0.8),
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
          -- No preview by default — keep the picker minimal and
          -- non-distracting.  Preview can be toggled with <C-p>
          -- in any picker, and specific pickers that benefit from
          -- preview (grep, references, diagnostics) opt-in below.
          layout = { preset = 'select', cycle = true },
          preview = false,
          formatters = { file = { filename_first = true } },
          matcher = { frecency = true },
          win = {
            input = {
              keys = {
                ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
                -- Toggle preview on demand
                ['<C-p>'] = { 'toggle_preview', mode = { 'n', 'i' } },
              },
            },
          },
          -- Per-source preview opt-ins: pickers where context is
          -- genuinely useful get preview enabled by default.
          sources = {
            grep         = { preview = true, layout = { preset = 'vertical', cycle = true } },
            grep_word    = { preview = true, layout = { preset = 'vertical', cycle = true } },
            lsp_references      = { preview = true, layout = { preset = 'vertical', cycle = true } },
            lsp_definitions     = { preview = true, layout = { preset = 'vertical', cycle = true } },
            lsp_implementations = { preview = true, layout = { preset = 'vertical', cycle = true } },
            lsp_type_definitions = { preview = true, layout = { preset = 'vertical', cycle = true } },
            diagnostics  = { preview = true, layout = { preset = 'vertical', cycle = true } },
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
          -- Navigation & finding (aligns with Doom SPC f / SPC s)
          { '<leader>f', group = 'find' },
          { '<leader>b', group = 'buffers' },
          -- Git (aligns with Doom SPC g)
          { '<leader>g', group = 'git' },
          -- Language / LSP (aligns with Doom SPC l)
          { '<leader>l',  group = 'lsp' },
          { '<leader>lc', group = 'calls' },
          -- Tasks / build (aligns with Doom transient compile)
          { '<leader>t', group = 'tasks' },
          -- Project
          { '<leader>p', group = 'project' },
          -- Search (aligns with Doom SPC s)
          { '<leader>s', group = 'search' },
          -- Config / introspection
          { '<leader>c', group = 'config' },
          { '<leader>h', group = 'help/describe' },
          { '<leader>i', group = 'inspect' },
          -- UI toggles (aligns with Doom SPC t)
          { '<leader>u', group = 'ui' },
          -- Files / dired (oil, mini.files)
          { '<leader>x', group = 'files/dired' },
          -- Windows (aligns with Doom SPC w)
          { '<leader>w', group = 'windows' },
          -- Open / Org-mode (aligns with Doom SPC o)
          { '<leader>o', group = 'open/org' },
          -- Narrowing (aligns with Doom SPC n)
          { '<leader>n', group = 'narrow' },
          -- Tabs / workspaces (aligns with Doom SPC TAB)
          { '<leader><Tab>', group = 'tabs' },
          -- Quit (aligns with Doom SPC q)
          { '<leader>q', group = 'quit' },
          -- AI agents
          { '<leader>a', group = 'agents' },
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
    ['folke/zen-mode.nvim'] = {
      lazy = false, -- the plugin lazy-initialises itself
    },

    ['dmtrKovalenko/fff.nvim'] = {
      build = function()
        -- downloads a prebuilt binary or falls back to cargo build
        require('fff.download').download_or_build_binary()
      end,
      opts = {
        preview = {
          enabled = false,
        },
        git = {
          status_text_color = true,
        },
        layout = {
          height = 0.8,
          width = 0.8,
          prompt_position = 'top', -- or 'top'
          flex = { size = 130, wrap = 'top' },
          show_scrollbar = true,
          path_shorten_strategy = 'middle_number', -- 'middle_number' | 'middle' | 'end'
          anchor = 'center',
        },
      },
      lazy = false, -- the plugin lazy-initialises itself
    },
    ['https://codeberg.org/comfysage/artio.nvim'] = {
      lazy = false,
    },
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
      -- opts is a function so language specs are resolved lazily at setup time
      opts = function()
        local languages = require 'modules.text_editing.languages'
        return {
          -- Formatter list per filetype is driven entirely by language specs.
          -- Merge in the universal trim_whitespace fallback last.
          formatters_by_ft = vim.tbl_extend(
            'keep',
            languages.get_formatters_by_ft(),
            { ['_'] = { 'trim_whitespace' } }
          ),
          format_on_save = {
            timeout_ms = 500,
            lsp_format  = 'fallback', -- use LSP formatting when no conform formatter matches
          },
          -- Per-formatter config (condition fns, arg overrides, etc.) from language specs.
          formatters = languages.get_conform_formatter_configs(),
        }
      end,
    },
    -- Statusline: mirrors doom-modeline layout
    -- Left:  mode | branch | diff | filename
    -- Right: diagnostics | LSP clients | filetype | encoding (non-UTF8 only) | position
    ['nvim-lualine/lualine.nvim'] = {
      lazy = false,
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      opts = function()
        -- Show attached LSP server names (mirrors doom-modeline lsp segment)
        local function lsp_clients()
          local clients = vim.lsp.get_clients { bufnr = 0 }
          if #clients == 0 then return '' end
          local names = vim.tbl_map(function(c) return c.name end, clients)
          return '󰒋 ' .. table.concat(names, ' ')
        end

        -- Show encoding only when non-UTF-8 (mirrors buffer-encoding-simple segment)
        local function encoding()
          local enc = (vim.bo.fenc ~= '' and vim.bo.fenc) or vim.o.enc
          if enc == 'utf-8' then return '' end
          -- Also show line-ending type if not Unix
          local eol = vim.bo.fileformat
          local eol_flag = eol == 'dos' and ' CRLF' or (eol == 'mac' and ' CR' or '')
          return enc:upper() .. eol_flag
        end

        -- Show selection info when in visual mode
        local function selection()
          local mode = vim.fn.mode()
          if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then return '' end
          local start = vim.fn.getpos 'v'
          local stop  = vim.fn.getpos '.'
          local lines  = math.abs(stop[2] - start[2]) + 1
          local chars  = math.abs(stop[3] - start[3]) + 1
          return string.format('%dL %dC', lines, chars)
        end

        return {
          options = {
            theme                = 'tokyonight',
            globalstatus         = true,
            component_separators = { left = '', right = '' },
            section_separators   = { left = '', right = '' },
          },
          sections = {
            lualine_a = { 'mode' },
            lualine_b = {
              { 'branch',
                icon = '',
                on_click = function() vim.cmd 'Neogit' end,
              },
              { 'diff',
                symbols = { added = ' ', modified = '󰝤 ', removed = ' ' },
                source = function()
                  -- Read from env.state if available (avoids spawning git on every render)
                  local ok, env = pcall(require, 'env')
                  if ok then
                    local s = env.state.get 'vcs.status'
                    if s then return { added = s.staged, modified = s.unstaged, removed = 0 } end
                  end
                  return nil  -- fall back to lualine's built-in git diff
                end,
              },
            },
            lualine_c = {
              { 'filename',
                path    = 1,  -- relative path
                symbols = { modified = ' ●', readonly = ' ', unnamed = '[No Name]' },
              },
            },
            lualine_x = {
              { 'overseer',
                label   = '',
                colored = true,
                unique  = true,
              },
              { 'diagnostics',
                sources  = { 'nvim_lsp', 'nvim_diagnostic' },
                symbols  = { error = ' ', warn = ' ', info = ' ', hint = '󰌶 ' },
                on_click = function() vim.diagnostic.setloclist() end,
              },
              lsp_clients,
              selection,
            },
            lualine_y = {
              'filetype',
              encoding,
            },
            lualine_z = {
              { 'location' },
              { 'progress' },
            },
          },
          inactive_sections = {
            lualine_c = { { 'filename', path = 1 } },
            lualine_x = { 'location' },
          },
        }
      end,
    },

  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.
  setup = function()
    local snacks = require 'snacks'
    vim.fn.toggle_zoom = snacks.zen.zoom

    -- ── Apply colorscheme ───────────────────────────────────────────
    require('tokyonight').setup()
    vim.cmd.colorscheme 'tokyonight-storm'

    -- ── State providers ─────────────────────────────────────────────
    env.state.register_provider {
      id      = 'interface.notification_count',
      events  = { 'User' },
      pattern = 'SnacksNotifierUpdated',
      collect = function() return #snacks.notifier.get_history() end,
      desc    = 'Number of notifications in snacks history',
    }

    -- ── Capability registrations ────────────────────────────────────
    -- Core picker methods via snacks.picker.
    -- Domain modules extend this table further (filesystem, lsp, version_control).
    -- All vim.ui.picker.xxx call-sites work transparently via env.capabilities.
    env.capabilities.extend('picker', {
      files         = function(o) snacks.picker.files(o) end,
      grep          = function(o) snacks.picker.grep(o) end,
      grep_word     = function(o) snacks.picker.grep_word(o) end,
      buffers       = function(o) snacks.picker.buffers(o) end,
      help          = function(o) snacks.picker.help(o) end,
      keymaps       = function(o) snacks.picker.keymaps(o) end,
      commands      = function(o) snacks.picker.commands(o) end,
      colorschemes  = function(o) snacks.picker.colorschemes(o) end,
      diagnostics   = function(o) snacks.picker.diagnostics(o) end,
      notifications = function(o) snacks.picker.notifications(o) end,
      highlights    = function(o) snacks.picker.highlights(o) end,
      autocmds      = function(o) snacks.picker.autocmds(o) end,
      pickers       = function(o) snacks.picker.pickers(o) end,
      scripts       = function(o) snacks.picker.scripts(o) end,
      runtime_files = function(o) snacks.picker.runtime_files(o) end,
      -- LSP pickers registered by text_editing module in lsp.lua
      -- Git pickers registered by version_control module
    }, 'interface')

    -- ── Display registrations ────────────────────────────────────────
    env.display.register { id = 'interface.statusline',    kind = 'statusline',    module = 'interface',    desc = 'lualine — mode, branch, diff, filename, LSP, position' }
    env.display.register { id = 'interface.notifications', kind = 'notification',  module = 'interface',    desc = 'snacks.notifier — floating notification history' }
    env.display.register { id = 'interface.indent_scope',  kind = 'virtual_text',  module = 'interface',    desc = 'snacks.scope — indent scope highlight' }

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

    -- Toggles moved to SPC u (SPC t is now tasks/overseer)
    vim.keymap.set('n', '<leader>un', '<cmd>set number!<cr>', { silent = true, desc = 'ui.toggle_number' })
    vim.keymap.set('n', '<leader>ur', '<cmd>set relativenumber!<cr>', { silent = true, desc = 'ui.toggle_relnumber' })
    vim.keymap.set('n', '<leader>us', '<cmd>setlocal spell!<cr>', { silent = true, desc = 'ui.toggle_spell' })
    vim.keymap.set('n', '<leader>ux', '<cmd>set wrap!<cr>', { silent = true, desc = 'ui.toggle_wrap' })

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

    ----------------------------------------------------------------
    -- Narrowing (Doom: SPC n — narrow-to-region / widen)
    -- Neovim doesn't have built-in narrowing, so we use fold-based
    -- narrowing: fold everything except the selected region/function.
    ----------------------------------------------------------------

    --- Narrow to visual selection: fold everything outside the selection.
    local function narrow_to_region()
      local start_line = vim.fn.line "'<"
      local end_line   = vim.fn.line "'>"
      -- Save current fold settings
      vim.b.narrow_saved_foldmethod = vim.wo.foldmethod
      vim.b.narrow_saved_foldenable = vim.wo.foldenable
      vim.b.narrow_saved_foldlevel  = vim.wo.foldlevel
      -- Switch to manual folding
      vim.wo.foldmethod = 'manual'
      vim.wo.foldenable = true
      -- Remove existing folds
      vim.cmd 'normal! zE'
      -- Fold before selection
      if start_line > 1 then
        vim.cmd(string.format('1,%dfold', start_line - 1))
      end
      -- Fold after selection
      local total = vim.api.nvim_buf_line_count(0)
      if end_line < total then
        vim.cmd(string.format('%d,%dfold', end_line + 1, total))
      end
      vim.b.is_narrowed = true
    end

    --- Widen: remove all folds and restore fold settings.
    local function widen()
      vim.cmd 'normal! zE'
      if vim.b.narrow_saved_foldmethod then
        vim.wo.foldmethod = vim.b.narrow_saved_foldmethod
        vim.wo.foldenable = vim.b.narrow_saved_foldenable
        vim.wo.foldlevel  = vim.b.narrow_saved_foldlevel
      end
      vim.b.is_narrowed = false
    end

    --- Narrow to function: use treesitter to find the enclosing function.
    local function narrow_to_defun()
      local node = vim.treesitter.get_node()
      if not node then
        vim.notify('No treesitter node at cursor', vim.log.levels.WARN)
        return
      end
      -- Walk up to find function node
      while node do
        local t = node:type()
        if t:match 'function' or t:match 'method' then break end
        node = node:parent()
      end
      if not node then
        vim.notify('No enclosing function found', vim.log.levels.WARN)
        return
      end
      local sr, _, er, _ = node:range()
      -- Use the same fold-based narrowing
      vim.b.narrow_saved_foldmethod = vim.wo.foldmethod
      vim.b.narrow_saved_foldenable = vim.wo.foldenable
      vim.b.narrow_saved_foldlevel  = vim.wo.foldlevel
      vim.wo.foldmethod = 'manual'
      vim.wo.foldenable = true
      vim.cmd 'normal! zE'
      if sr > 0 then
        vim.cmd(string.format('1,%dfold', sr))
      end
      local total = vim.api.nvim_buf_line_count(0)
      if (er + 1) < total then
        vim.cmd(string.format('%d,%dfold', er + 2, total))
      end
      vim.b.is_narrowed = true
    end

    vim.keymap.set('v', '<leader>nr', narrow_to_region, { desc = 'narrow.region', silent = true })
    vim.keymap.set('n', '<leader>nd', narrow_to_defun,  { desc = 'narrow.defun', silent = true })
    vim.keymap.set('n', '<leader>nw', widen,            { desc = 'narrow.widen', silent = true })
  end,
}
