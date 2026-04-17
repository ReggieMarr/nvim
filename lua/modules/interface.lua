-- lua/modules/interface.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface

-- Format bytes into human readable string
local function format_size(bytes)
  if bytes < 1024 then return string.format('%dB', bytes) end
  if bytes < 1024 * 1024 then return string.format('%.1fK', bytes / 1024) end
  if bytes < 1024 * 1024 * 1024 then return string.format('%.1fM', bytes / (1024 * 1024)) end
  return string.format('%.1fG', bytes / (1024 * 1024 * 1024))
end

-- Format unix timestamp → "MMM DD HH:MM" like ls -l
local function format_time(ts) return os.date('%b %d %H:%M', ts) end

-- Format permissions bits like rwxr-xr-x
local function format_permissions(mode)
  -- mode is the st_mode from uv.fs_stat, extract lower 12 bits
  local m = mode % 4096
  local chars = {}
  local bits = { 256, 128, 64, 32, 16, 8, 4, 2, 1 }
  local labels = { 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' }
  for i, bit in ipairs(bits) do
    table.insert(chars, (m % (bit * 2) >= bit) and labels[i] or '-')
  end
  return table.concat(chars)
end

-- Get icon + highlight group for an item
local function get_icon(item)
  local icons = require 'mini.icons'
  if item.is_cwd then return icons.get('default', 'default') end
  if item.is_dir then return icons.get('default', 'directory') end
  return icons.get('file', vim.fn.fnamemodify(item.path, ':t'))
end

-- Enrich an item with stat metadata
local function enrich_item(item)
  if item.is_cwd then
    item.icon, item.icon_hl = '', 'MiniPickNormal'
    item.permissions = '---------'
    item.size_str = '-'
    item.time_str = '-'
    return item
  end

  local stat = vim.uv.fs_stat(item.path)
  item.icon, item.icon_hl, _ = get_icon(item)

  if stat then
    item.permissions = format_permissions(stat.mode)
    item.size_str = item.is_dir and '-' or format_size(stat.size)
    item.time_str = format_time(stat.mtime.sec)
  else
    item.permissions = '---------'
    item.size_str = '?'
    item.time_str = '?'
  end

  return item
end

-- Build the display columns, returning line string + highlight regions
-- Format: <icon> <perms> <size> <time>  <name>
-- Describes one rendered column segment: its highlight group and the
-- string value that was written into that column (used to measure width).
---@class ColumnSpec
---@field hl      string   highlight group name
---@field value   string   the exact substring written to the buffer
---@field gap     integer  number of space chars appended AFTER this segment

-- Returns both the formatted line and an ordered list of ColumnSpecs so
-- that highlight ranges can be derived purely from segment lengths, with
-- no hardcoded magic offsets.
local function format_item_line(item)
  local icon = item.icon or ''
  local perms = item.permissions or '---------'
  local size = item.size_str or '-'
  local time = item.time_str or '-'
  local name = item.display or item.text or ''

  -- Each segment is formatted to a fixed visual width via format directives,
  -- then stored verbatim so we can measure its byte length below.
  local icon_col = string.format('%-2s', icon) -- 2 cols: glyph + space
  local perms_col = string.format('%-9s', perms) -- 9 cols
  local size_col = string.format('%6s', size) -- 6 cols, right-aligned
  local time_col = string.format('%-12s', time) -- 12 cols

  local line = perms_col .. ' ' .. size_col .. '  ' .. time_col .. ' ' .. icon_col .. '  ' .. name

  ---@type ColumnSpec[]
  local cols = {
    { hl = 'Comment', value = perms_col, gap = 1 },
    { hl = 'Number', value = size_col, gap = 2 },
    { hl = 'Special', value = time_col, gap = 2 },
    { hl = item.icon_hl or 'MiniPickNormal', value = icon_col, gap = 1 },
    -- name segment has no gap (goes to end of line); hl resolved at call site
    { hl = item.is_dir and 'Directory' or 'MiniPickNormal', value = name, gap = 0 },
  }

  return line, cols
end

local function custom_show(buf_id, items_to_show, query)
  local ns = vim.api.nvim_create_namespace 'mini_pick_filebrowser'
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  -- First pass: build lines
  local lines = {}
  local all_cols = {} -- parallel array of ColumnSpec[] per item

  for _, item in ipairs(items_to_show) do
    local line, cols = format_item_line(item)
    table.insert(lines, line)
    table.insert(all_cols, cols)
  end

  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  -- Second pass: highlights derived entirely from segment byte lengths
  for i, item in ipairs(items_to_show) do
    local row = i - 1
    local cursor = 0 -- byte offset into the line, advances as we consume segments

    for col_idx, seg in ipairs(all_cols[i]) do
      local seg_len = #seg.value -- byte length of this segment's content
      local seg_end = cursor + seg_len

      vim.hl.range(buf_id, ns, seg.hl, { row, cursor }, { row, seg_end })

      -- The last column is the name; apply match highlights within it
      local is_name_col = col_idx == #all_cols[i]
      if is_name_col then
        local name_start = cursor
        local display = item.display or item.text or ''

        for _, query_char in ipairs(query) do
          local s, e = display:find(vim.pesc(query_char), 1, true)
          if s then vim.hl.range(buf_id, ns, 'MiniPickMatchCurrent', { row, name_start + s - 1 }, { row, name_start + e }) end
        end
      end

      -- Advance past the segment content AND its trailing gap spaces
      cursor = seg_end + seg.gap
    end
  end
end

-- Get directory entries, injecting './' as first item
local function get_entries(cwd, show_hidden)
  local items = {}

  table.insert(
    items,
    enrich_item {
      text = './',
      path = cwd,
      is_cwd = true,
      is_dir = true,
    }
  )

  local entries = vim.fn.readdir(cwd)
  local dirs = {}
  local files = {}

  for _, name in ipairs(entries) do
    if show_hidden or name:sub(1, 1) ~= '.' then
      local full_path = cwd .. '/' .. name
      local is_dir = vim.fn.isdirectory(full_path) == 1
      local item = enrich_item {
        text = is_dir and (name .. '/') or name,
        path = full_path,
        is_dir = is_dir,
        is_cwd = false,
      }
      if is_dir then
        table.insert(dirs, item)
      else
        table.insert(files, item)
      end
    end
  end

  local alpha = function(a, b) return a.text:lower() < b.text:lower() end
  table.sort(dirs, alpha)
  table.sort(files, alpha)

  for _, item in ipairs(dirs) do
    table.insert(items, item)
  end
  for _, item in ipairs(files) do
    table.insert(items, item)
  end

  return items
end

local function create_file(path)
  local dir = vim.fn.fnamemodify(path, ':h')
  vim.fn.mkdir(dir, 'p')
  local ok, err = pcall(vim.fn.writefile, {}, path)
  if not ok then
    vim.notify('Failed to create file: ' .. err, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function create_directory(path)
  local ok = vim.fn.mkdir(path, 'p')
  if ok == 0 then
    vim.notify('Failed to create directory: ' .. path, vim.log.levels.ERROR)
    return false
  end
  return true
end

local function find_file_at(cwd, show_hidden)
  cwd = vim.fn.resolve(vim.fn.expand(cwd or vim.fn.getcwd()))
  show_hidden = show_hidden or false
  local MiniPick = require 'mini.pick'

  -- Restart picker at a new directory
  local function navigate_to(dir)
    MiniPick.stop()
    vim.schedule(function() find_file_at(dir, show_hidden) end)
  end

  local function navigate_up()
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent ~= cwd then navigate_to(parent) end
  end

  local function choose_custom(item)
    if not item then return end

    -- Current dir item → open in oil float at this directory
    if item.is_cwd then
      MiniPick.stop()
      vim.schedule(function() require('oil').open(item.path) end)
      return
    end

    -- Directory → navigate into it
    if item.is_dir then
      navigate_to(item.path)
      return
    end

    -- File → open it in target window
    local target_win = MiniPick.get_picker_state().windows.target
    vim.api.nvim_win_call(target_win, function() vim.cmd.edit(item.path) end)
    MiniPick.stop()
  end

  MiniPick.start {
    source = {
      name = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
      cwd = cwd,
      items = get_entries(cwd, show_hidden),
      show = custom_show,
      choose = choose_custom,

      preview = function(buf_id, item)
        if not item then return end
        if item.is_dir then
          -- Show directory listing as preview
          local entries = vim.fn.readdir(item.path)
          local lines = {}
          for _, name in ipairs(entries) do
            local full = item.path .. '/' .. name
            local suffix = vim.fn.isdirectory(full) == 1 and '/' or ''
            table.insert(lines, name .. suffix)
          end
          table.sort(lines)
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        else
          -- Default file preview
          MiniPick.default_preview(buf_id, item)
        end
      end,
    },

    mappings = {
      -- NOTE we need to disable the built-in first otherwise we'll get a warning
      delete_char = '',
      -- Backspace: go up if query empty, else delete char
      dwim_backspace = {
        char = '<BS>',
        func = function()
          local query = MiniPick.get_picker_query()
          if #query == 0 then
            navigate_up()
          else
            -- Remove last character from query
            local new_query = vim.list_slice(query, 1, #query - 1)
            MiniPick.set_picker_query(new_query)
          end
        end,
      },
      choose = '',

      dwim_choose = {
        char = '<CR>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          local item = matches and matches.current

          if item then
            -- Delegate to your normal choose logic (extracted to a function)
            return choose_custom(item)
          end

          -- No item matched → create from query
          local query_str = table.concat(MiniPick.get_picker_query())
          print(query_str)
          local name = query_str
          if name == '' then return end

          MiniPick.stop()
          vim.schedule(function()
            if query_str:match '%.[^./]+$' then
              if create_file(query_str) then vim.cmd.edit(query_str) end
            else
              if create_directory(query_str) then find_file_at(query_str, show_hidden) end
            end
          end)
          return true
        end,
      },
      move_down = '',
      -- Tab: navigate into selected dir (or open file)
      navigate_in = {
        char = '<Tab>',
        func = function()
          local item = MiniPick.get_picker_matches().current
          choose_custom(item)
          return true
        end,
      },

      -- Toggle hidden files
      scroll_left = '',
      toggle_hidden = {
        char = '<C-h>',
        func = function()
          show_hidden = not show_hidden
          MiniPick.set_picker_items(get_entries(cwd, show_hidden))
        end,
      },

      -- Create file/directory from current query (vertico-style)
      create = {
        char = '<C-n>',
        func = function()
          local query = table.concat(MiniPick.get_picker_query())
          if query == '' then return end

          local target = cwd .. '/' .. query
          MiniPick.stop()
          vim.schedule(function()
            if query:match '%.[^./]+$' ~= nil then
              -- Has extension → create file and open
              if create_file(target) then vim.cmd.edit(target) end
            else
              -- No extension → create directory and navigate into it
              if create_directory(target) then find_file_at(target, show_hidden) end
            end
          end)
          return true
        end,
      },

      -- Disable built-in that typically uses C-t
      choose_in_tabpage = '',
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
  }
end
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
        style = 'night',
        transparent = false,
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

        vim.keymap.set('n', '<CR>', 'za', { noremap = true, silent = true })
        vim.keymap.set('n', '[[', fold_util.goto_previous_fold, { noremap = true, silent = true })
        vim.keymap.set('n', ']]', 'zj', { noremap = true, silent = true })

        vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'LspAttach' }, {
          callback = function(opts) fold_util.update_ranges(opts.buf) end,
        })

        local last_row = nil
        vim.api.nvim_create_autocmd('CursorMoved', {
          callback = function(opts)
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
    vim.cmd.colorscheme 'tokyonight-night'

    -- ── Picker capability ───────────────────────────────────────────
    env.capabilities.register('picker', {
      files = function(o) find_file_at(o ~= nil and o or vim.fn.getcwd()) end,
      grep = function(o) snacks.picker.grep(o) end,
      buffers = function(o) snacks.picker.buffers(o) end,
      -- keymaps  = function(o) snacks.picker.keymaps(o)  end,
      -- commands = function(o) snacks.picker.commands(o) end,
    }, 'interface')

    -- -- Extend picker with interface-level finders
    -- env.capabilities.extend("picker", {
    --   help          = function(o) snacks.picker.help(o)          end,
    --   notifications = function(o) snacks.picker.notifications(o) end,
    --   recent        = function(o) snacks.picker.recent(o)        end,
    --   colorschemes  = function(o) snacks.picker.colorschemes(o)  end,
    -- }, "interface")

    -- ── State providers ─────────────────────────────────────────────
    -- env.state.register_provider({
    --   id      = "interface.notification_count",
    --   events  = { "User" },
    --   pattern = "SnacksNotifierUpdated",
    --   collect = function()
    --     return #snacks.notifier.get_history()
    --   end,
    --   desc = "Number of notifications in snacks history",
    -- })

    -- -- ── Display contributions ───────────────────────────────────────
    -- env.display.register({
    --   id       = "interface.notifications",
    --   module   = "interface",
    --   region   = "notification",
    --   priority = 100,
    --   desc     = "Snacks notification overlay",
    -- })
    -- Default mini.pick capabilities
    -- Centered on screen
    require('mini.icons').setup()
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
    require('oil').setup(oil_opts)

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'oil',
      callback = function(ev)
        local buf = ev.buf

        -- ----------------------------------------------------------------
        -- State: each oil buffer independently tracks whether it is in
        -- navigation mode or edit mode.
        -- ----------------------------------------------------------------
        local nav_mode = true

        local function set_nav_mode()
          nav_mode = true
          vim.bo[buf].modifiable = false
          vim.bo[buf].readonly = false -- oil needs this false internally
          vim.notify('Navigation mode', vim.log.levels.INFO, { title = 'oil.nvim' })
        end

        local function set_edit_mode()
          nav_mode = false
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

    require('mini.pick').setup {
      mappings = {
        toggle_info = '<C-k>',
        move_up = '',
        toggle_preview = '<C-p>',
      },
    }

    env.display.register {
      id = 'interface.indent_guides',
      module = 'interface',
      region = 'virtual_text',
      priority = 10,
      desc = 'Indent scope guides',
      when = function(state) return state['buffer.is_real'] == true end,
    }

    env.display.register {
      id = 'interface.word_highlights',
      module = 'interface',
      region = 'highlight',
      priority = 50,
      desc = 'Current word occurrence highlights',
      when = function(state) return state['buffer.is_real'] == true and state['editor.mode'] == 'n' end,
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
        },
        pager = {
          height = 0.5,
        },
      },
    }

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
    -- ── Articulation ────────────────────────────────────────────────
    env.articulation.register_group('interface', {
      {
        id = 'restart', -- TODO this shouldn't go here
        handler = function() MiniSessions.restart() end,
        desc = 'restart the current session',
        bindings = { { lhs = '<leader>R' } },
      },

      -- Buffer management
      {
        id = 'find_buffers',
        handler = function() env.use('picker').buffers() end,
        desc = 'Find open buffers',
        bindings = { { lhs = '<leader>bb' } },
      },
      {
        id = 'close_buffer',
        handler = function() snacks.bufdelete() end,
        desc = 'Close current buffer',
        bindings = { { lhs = '<leader>bd' } },
        when = function(state) return state['buffer.is_real'] == true end,
      },
      {
        id = 'close_other_buffers',
        handler = function() snacks.bufdelete.other() end,
        desc = 'Close all other buffers',
        bindings = { { lhs = '<leader>bo' } },
      },
      {
        id = 'next_buffer',
        handler = function() vim.cmd 'bnext' end,
        desc = 'Next buffer',
        bindings = { { lhs = ']b' } },
      },
      {
        id = 'prev_buffer',
        handler = function() vim.cmd 'bprevious' end,
        desc = 'Previous buffer',
        bindings = { { lhs = '[b' } },
      },
      {
        id = 'scratch_buffer',
        handler = function() snacks.scratch() end,
        desc = 'Open scratch buffer',
        bindings = { { lhs = '<leader>bs' } },
      },

      -- Basic introspection
      {
        id = 'find_keymaps',
        handler = function() env.use('picker').keymaps() end,
        desc = 'Find keymaps',
        bindings = { { lhs = '<leader>fk' } },
      },
      {
        id = 'find_commands',
        handler = function() env.use('picker').commands() end,
        desc = 'Find commands',
        bindings = { { lhs = '<leader>fC' } },
      },
      {
        id = 'find_help',
        handler = function() env.use('picker').help() end,
        desc = 'Find help tags',
        bindings = { { lhs = '<leader>fh' } },
      },
      {
        id = 'find_notifications',
        handler = function() env.use('picker').notifications() end,
        desc = 'Find notification history',
        bindings = { { lhs = '<leader>fn' } },
      },

      -- UI toggles
      {
        id = 'toggle_diagnostics',
        handler = function() vim.diagnostic.enable(not vim.diagnostic.is_enabled()) end,
        desc = 'Toggle diagnostics',
        bindings = { { lhs = '<leader>ud' } },
      },
      {
        id = 'toggle_line_numbers',
        handler = function()
          vim.opt.number = not vim.opt.number:get()
          vim.opt.relativenumber = not vim.opt.relativenumber:get()
        end,
        desc = 'Toggle line numbers',
        bindings = { { lhs = '<leader>ul' } },
      },
      {
        id = 'toggle_word_highlights',
        handler = function() snacks.words.toggle() end,
        desc = 'Toggle word highlights',
        bindings = { { lhs = '<leader>uw' } },
      },
      {
        id = 'toggle_indent_guides',
        handler = function() snacks.indent.toggle() end,
        desc = 'Toggle indent guides',
        bindings = { { lhs = '<leader>ui' } },
      },
      {
        id = 'zoom_window',
        handler = function() snacks.zen.zoom() end,
        desc = 'Zoom current window',
        bindings = { { lhs = '<leader>uz' } },
      },

      -- Config inspection
      {
        id = 'find_in_config',
        handler = function()
          env.use('picker').files {
            cwd = vim.fn.stdpath 'config',
            title = 'Config files',
          }
        end,
        desc = 'Find in config',
        bindings = { { lhs = '<leader>cc' } },
      },
      {
        id = 'grep_config',
        handler = function()
          env.use('picker').grep {
            cwd = vim.fn.stdpath 'config',
            title = 'Grep config',
          }
        end,
        desc = 'Grep config',
        bindings = { { lhs = '<leader>cg' } },
      },
      {
        id = 'config_status',
        handler = function() vim.cmd 'ConfigStatus' end,
        desc = 'Open config status',
        bindings = { { lhs = '<leader>cs' } },
      },
      {
        id = 'config_status_state',
        handler = function() vim.cmd 'ConfigStatus state' end,
        desc = 'Inspect environment state',
        bindings = { { lhs = '<leader>cS' } },
      },
      {
        id = 'lazy',
        handler = function() require('lazy').home() end,
        desc = 'Open lazy plugin manager',
        bindings = { { lhs = '<leader>cl' } },
      },
    })
  end,
}
