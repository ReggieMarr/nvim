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
local function format_time(ts)
  return os.date('%b %d %H:%M', ts)
end

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
  local devicons = require('nvim-web-devicons')
  if item.is_cwd then
    return '', 'MiniPickNormal'
  end
  if item.is_dir then
    return '', 'Directory' -- nerd font folder icon
  end
  local ext = item.path:match('%.([^.]+)$') or ''
  local icon, hl = devicons.get_icon(vim.fn.fnamemodify(item.path, ':t'), ext, { default = true })
  return icon or '', hl or 'MiniPickNormal'
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
  item.icon, item.icon_hl = get_icon(item)

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
local function format_item_line(item, name_col_start)
  local icon = item.icon or ''
  local perms = item.permissions or '---------'
  local size = item.size_str or '-'
  local time = item.time_str or '-'
  local name = item.text or ''

  -- Fixed width columns
  -- icon(2) + perms(9) + size(7) + time(12) + name
  local line = string.format(
    '%s %-9s %6s  %-12s  %s',
    icon,
    perms,
    size,
    time,
    name
  )
  return line
end

-- Calculate where the name column starts (constant, based on format)
-- icon(1+1space) + perms(9+1space) + size(6+2space) + time(12+2space) = 34
local NAME_COL = 2 + 1 + 9 + 1 + 6 + 2 + 12 + 2  -- = 35

local function custom_show(buf_id, items_to_show, query)
  local ns = vim.api.nvim_create_namespace('mini_pick_filebrowser')
  vim.api.nvim_buf_clear_namespace(buf_id, ns, 0, -1)

  local lines = {}
  for _, item in ipairs(items_to_show) do
    table.insert(lines, format_item_line(item))
  end

  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

  -- Now apply highlights per line
  for i, item in ipairs(items_to_show) do
    local row = i - 1

    -- Icon highlight
    if item.icon_hl then
      vim.api.nvim_buf_add_highlight(buf_id, ns, item.icon_hl, row, 0, 3)
    end

    -- Permissions highlight
    vim.api.nvim_buf_add_highlight(
      buf_id, ns, 'Comment', row, 3, 3 + 9
    )

    -- Size highlight
    vim.api.nvim_buf_add_highlight(
      buf_id, ns, 'Number', row, 13, 13 + 6
    )

    -- Time highlight
    vim.api.nvim_buf_add_highlight(
      buf_id, ns, 'Special', row, 21, 21 + 12
    )

    -- Name highlight: dirs blue, files normal
    local name_hl = item.is_dir and 'Directory' or 'MiniPickNormal'
    vim.api.nvim_buf_add_highlight(
      buf_id, ns, name_hl, row, NAME_COL, -1
    )

    -- Also highlight matching chars in the name portion only
    -- Re-run mini.pick's default match highlight but offset to name column
    local stritem = item.text or ''
    for _, query_char in ipairs(query) do
      local s, e = stritem:find(vim.pesc(query_char), 1, true)
      if s then
        vim.api.nvim_buf_add_highlight(
          buf_id, ns, 'MiniPickMatchCurrent',
          row,
          NAME_COL + s - 1,
          NAME_COL + e
        )
      end
    end
  end
end

-- Get directory entries, injecting './' as first item
local function get_entries(cwd, show_hidden)
  local items = {}

  table.insert(items, enrich_item({
    text = './',
    path = cwd,
    is_cwd = true,
    is_dir = true,
  }))

  local entries = vim.fn.readdir(cwd)
  local dirs = {}
  local files = {}

  for _, name in ipairs(entries) do
    if show_hidden or name:sub(1, 1) ~= '.' then
      local full_path = cwd .. '/' .. name
      local is_dir = vim.fn.isdirectory(full_path) == 1
      local item = enrich_item({
        text = is_dir and (name .. '/') or name,
        path = full_path,
        is_dir = is_dir,
        is_cwd = false,
      })
      if is_dir then
        table.insert(dirs, item)
      else
        table.insert(files, item)
      end
    end
  end

  local alpha = function(a, b)
    return a.text:lower() < b.text:lower()
  end
  table.sort(dirs, alpha)
  table.sort(files, alpha)

  for _, item in ipairs(dirs) do table.insert(items, item) end
  for _, item in ipairs(files) do table.insert(items, item) end

  return items
end


local function open_neotree(path)
  vim.schedule(function()
    vim.cmd(('Neotree dir=%s reveal position=current'):format(vim.fn.fnameescape(path)))
  end)
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
  local MiniPick = require('mini.pick')

  -- Restart picker at a new directory
  local function navigate_to(dir)
    MiniPick.stop()
    vim.schedule(function()
      find_file_at(dir, show_hidden)
    end)
  end

  local function navigate_up()
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent ~= cwd then
      navigate_to(parent)
    end
  end

  MiniPick.start({
    source = {
      name = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
      cwd = cwd,
      items = get_entries(cwd, show_hidden),
      show = custom_show,

      choose = function(item)
        if not item then return end

        -- Current dir item → open neotree
        if item.is_cwd then
          open_neotree(cwd)
          return
        end

        -- Directory → navigate into it
        if item.is_dir then
          navigate_to(item.path)
          return
        end

        -- File → open it in target window
        local target_win = MiniPick.get_picker_state().windows.target
        vim.api.nvim_win_call(target_win, function()
          vim.cmd.edit(item.path)
        end)
      end,

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

      move_down = '',
      -- Tab: navigate into selected dir (or open file)
      navigate_in = {
        char = '<Tab>',
        func = function()
          local item = MiniPick.get_picker_matches().current
          if not item then return end

          if item.is_cwd then
            MiniPick.stop()
            open_neotree(cwd)
            return true
          end

          if item.is_dir then
            navigate_to(item.path)
            return true
          end

          -- File: just choose it (same as <CR>)
          local target_win = MiniPick.get_picker_state().windows.target
          MiniPick.stop()
          vim.api.nvim_win_call(target_win, function()
            vim.cmd.edit(item.path)
          end)
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
            if query:match('%.[^./]+$') ~= nil then
              -- Has extension → create file and open
              if create_file(target) then
                vim.cmd.edit(target)
              end
            else
              -- No extension → create directory and navigate into it
              if create_directory(target) then
                find_file_at(target, show_hidden)
              end
            end
          end)
          return true
        end,
      },

      -- Disable built-in that typically uses C-t
      choose_in_tabpage = '',
      -- Open neotree at cwd
      open_neotree = {
        char = '<C-t>',
        func = function()
          MiniPick.stop()
          open_neotree(cwd)
          return true
        end,
      },
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
  })
end

local env = require("env")

return env.module.register({
  name          = "interface",
  domain        = "interface",
  depends_on    = {},
  optional_deps = {},

  -- ── Plugin option contributions ──────────────────────────────────────
  -- Each key is a plugin string. Values are merged across all modules
  -- before being passed to lazy. No config functions here: setup() below
  -- handles all env surface registrations after plugins are loaded.

  plugins = {
    ['nvim-neo-tree/neo-tree.nvim'] = {
        dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-tree/nvim-web-devicons',
        'MunifTanjim/nui.nvim',
        },
        cmd = 'Neotree',
    },

    ["folke/snacks.nvim"] = {
      priority = 1000,
      lazy     = false,
      opts = {
        picker = {
          ui_select  = true,
          layout     = { preset = "default", cycle = true },
          formatters = { file = { filename_first = true } },
          matcher    = { frecency = true },
          win = {
            input = {
              keys = {
                ["<Esc>"] = { "close", mode = { "n", "i" } },
              },
            },
          },
        },
        notifier = {
          enabled  = false,
          timeout  = 3000,
          sort     = { "level", "added" },
          level    = vim.log.levels.TRACE,
          style    = "compact",
          top_down = false,
        },
        input    = { enabled = true },
        indent   = {
          enabled = false,
          animate = { enabled = false },
          scope   = { enabled = true },
        },
        scope     = { enabled = true },
        words     = { enabled = true },
        bigfile   = { enabled = true, size = 1.5 * 1024 * 1024 },
        scratch   = { enabled = true },
        dashboard = { enabled  = false },
        -- Explicitly disable snacks modules owned by other modules
        terminal = { enabled = false }, -- execution module
        zen      = { enabled = false },
        animate  = { enabled = false },
      },
    },

    ["nvim-mini/mini.sessions"] = {
        version = false,
    },
    ['s1n7ax/nvim-window-picker'] = {
        name = 'window-picker',
        event = 'VeryLazy',
        version = '2.*',
        config = function()
            require'window-picker'.setup()
        end,
    },
    ["folke/tokyonight.nvim"] = {
      priority = 900,
      lazy     = false,
      opts = {
        style       = "night",
        transparent = false,
        styles      = { sidebars = "dark", floats = "dark" },
        on_highlights = function(hl, c)
          hl.EnvDisplayVirtualText = { fg = c.comment, italic = true }
        end,
      },
    },

    ["folke/which-key.nvim"] = {
      event = "VeryLazy",
      opts  = {
        preset = "modern",
        delay  = 300,
        icons  = { mappings = true },
        -- Top-level group labels: the keymap grammar skeleton.
        -- Domain modules add entries within these groups.
        spec = {
          { "<leader>f", group = "find"    },
          { "<leader>b", group = "buffers" },
          { "<leader>g", group = "git"     },
          { "<leader>l", group = "lsp"     },
          { "<leader>t", group = "tasks"   },
          { "<leader>p", group = "project" },
          { "<leader>c", group = "config"  },
          { "<leader>u", group = "ui"      },
          { "<leader>x", group = "files"   },
        },
      },
    },

  },

  -- ── Setup ─────────────────────────────────────────────────────────────
  -- Called by module_lib.run_setup() after lazy has loaded plugins.
  -- All plugin APIs are available. All env surface registrations live here.

  setup = function()
    local snacks = require("snacks")

    -- ── Apply colorscheme ───────────────────────────────────────────
    require("tokyonight").setup(
      -- opts already applied by lazy via plugins["folke/tokyonight.nvim"].opts
      -- calling setup again here is a no-op but makes the apply explicit
    )
    vim.cmd.colorscheme("tokyonight-night")

    -- ── Picker capability ───────────────────────────────────────────
    env.capabilities.register("picker", {
      files    = function(o)
        find_file_at(o ~= nil and o or vim.fn.getcwd())
      end,
      -- grep     = function(o) snacks.picker.grep(o)     end,
      buffers  = function(o) snacks.picker.buffers(o)  end,
      -- keymaps  = function(o) snacks.picker.keymaps(o)  end,
      -- commands = function(o) snacks.picker.commands(o) end,
    }, "interface")

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

    env.display.register({
      id       = "interface.indent_guides",
      module   = "interface",
      region   = "virtual_text",
      priority = 10,
      desc     = "Indent scope guides",
      when     = function(state)
        return state["buffer.is_real"] == true
      end,
    })

    env.display.register({
      id       = "interface.word_highlights",
      module   = "interface",
      region   = "highlight",
      priority = 50,
      desc     = "Current word occurrence highlights",
      when     = function(state)
        return state["buffer.is_real"] == true
          and state["editor.mode"] == "n"
      end,
    })

    -- Experimental UI2: floating cmdline and messages
    -- No more "hit enter after commands"
    vim.o.cmdheight = 1
    require("vim._core.ui2").enable({
        enable = true,
        msg = {
            targets = {
                [""] = "msg",
                empty = "cmd",
                bufwrite = "msg",
                confirm = "cmd",
                emsg = "pager",
                echo = "msg",
                echomsg = "msg",
                echoerr = "pager",
                completion = "cmd",
                list_cmd = "pager",
                lua_error = "pager",
                lua_print = "msg",
                progress = "pager",
                rpc_error = "pager",
                quickfix = "msg",
                search_cmd = "cmd",
                search_count = "cmd",
                shell_cmd = "pager",
                shell_err = "pager",
                shell_out = "pager",
                shell_ret = "msg",
                undo = "msg",
                verbose = "pager",
                wildlist = "cmd",
                wmsg = "msg",
                typed_cmd = "cmd",
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
    })

    -- Customize the style of the notification window
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "msg",
        callback = function()
            local ui2 = require("vim._core.ui2")
            local win = ui2.wins and ui2.wins.msg
            if win and vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_set_option_value(
                    "winhighlight",
                    "Normal:NormalFloat,FloatBorder:FloatBorder",
                    { scope = "local", win = win }
                )
            end
        end,
    })

    local ui2 = require("vim._core.ui2")
    local msgs = require("vim._core.ui2.messages")
    local orig_set_pos = msgs.set_pos
    -- Set position to top right corner
    msgs.set_pos = function(tgt)
        orig_set_pos(tgt)
        if (tgt == "msg" or tgt == nil) and vim.api.nvim_win_is_valid(ui2.wins.msg) then
            pcall(vim.api.nvim_win_set_config, ui2.wins.msg, {
                relative = "editor",
                anchor = "NE",
                row = 1,
                col = vim.o.columns - 1,
                border = "rounded",
            })
        end
    end

    require("mini.sessions").setup()
    -- ── Articulation ────────────────────────────────────────────────
    env.articulation.register_group("interface", {
      {
        id       = "restart", -- TODO this shouldn't go here
        handler  = function() MiniSessions.restart() end,
        desc     = "restart the current session",
        bindings = { { lhs = "<leader>R" } },
      },

      -- Buffer management
      {
        id       = "find_buffers",
        handler  = function() env.use("picker").buffers() end,
        desc     = "Find open buffers",
        bindings = { { lhs = "<leader>bb" } },
      },
      {
        id       = "close_buffer",
        handler  = function() snacks.bufdelete() end,
        desc     = "Close current buffer",
        bindings = { { lhs = "<leader>bd" } },
        when     = function(state) return state["buffer.is_real"] == true end,
      },
      {
        id       = "close_other_buffers",
        handler  = function() snacks.bufdelete.other() end,
        desc     = "Close all other buffers",
        bindings = { { lhs = "<leader>bo" } },
      },
      {
        id       = "next_buffer",
        handler  = function() vim.cmd("bnext") end,
        desc     = "Next buffer",
        bindings = { { lhs = "]b" } },
      },
      {
        id       = "prev_buffer",
        handler  = function() vim.cmd("bprevious") end,
        desc     = "Previous buffer",
        bindings = { { lhs = "[b" } },
      },
      {
        id       = "scratch_buffer",
        handler  = function() snacks.scratch() end,
        desc     = "Open scratch buffer",
        bindings = { { lhs = "<leader>bs" } },
      },

      -- Basic introspection
      {
        id       = "find_keymaps",
        handler  = function() env.use("picker").keymaps() end,
        desc     = "Find keymaps",
        bindings = { { lhs = "<leader>fk" } },
      },
      {
        id       = "find_commands",
        handler  = function() env.use("picker").commands() end,
        desc     = "Find commands",
        bindings = { { lhs = "<leader>fC" } },
      },
      {
        id       = "find_help",
        handler  = function() env.use("picker").help() end,
        desc     = "Find help tags",
        bindings = { { lhs = "<leader>fh" } },
      },
      {
        id       = "find_notifications",
        handler  = function() env.use("picker").notifications() end,
        desc     = "Find notification history",
        bindings = { { lhs = "<leader>fn" } },
      },

      -- UI toggles
      {
        id       = "toggle_diagnostics",
        handler  = function()
          vim.diagnostic.enable(not vim.diagnostic.is_enabled())
        end,
        desc     = "Toggle diagnostics",
        bindings = { { lhs = "<leader>ud" } },
      },
      {
        id       = "toggle_line_numbers",
        handler  = function()
          vim.opt.number         = not vim.opt.number:get()
          vim.opt.relativenumber = not vim.opt.relativenumber:get()
        end,
        desc     = "Toggle line numbers",
        bindings = { { lhs = "<leader>ul" } },
      },
      {
        id       = "toggle_word_highlights",
        handler  = function() snacks.words.toggle() end,
        desc     = "Toggle word highlights",
        bindings = { { lhs = "<leader>uw" } },
      },
      {
        id       = "toggle_indent_guides",
        handler  = function() snacks.indent.toggle() end,
        desc     = "Toggle indent guides",
        bindings = { { lhs = "<leader>ui" } },
      },
      {
        id       = "zoom_window",
        handler  = function() snacks.zen.zoom() end,
        desc     = "Zoom current window",
        bindings = { { lhs = "<leader>uz" } },
      },

      -- Config inspection
      {
        id       = "find_in_config",
        handler  = function()
          env.use("picker").files({
            cwd   = vim.fn.stdpath("config"),
            title = "Config files",
          })
        end,
        desc     = "Find in config",
        bindings = { { lhs = "<leader>cc" } },
      },
      {
        id       = "grep_config",
        handler  = function()
          env.use("picker").grep({
            cwd   = vim.fn.stdpath("config"),
            title = "Grep config",
          })
        end,
        desc     = "Grep config",
        bindings = { { lhs = "<leader>cg" } },
      },
      {
        id       = "config_status",
        handler  = function() vim.cmd("ConfigStatus") end,
        desc     = "Open config status",
        bindings = { { lhs = "<leader>cs" } },
      },
      {
        id       = "config_status_state",
        handler  = function() vim.cmd("ConfigStatus state") end,
        desc     = "Inspect environment state",
        bindings = { { lhs = "<leader>cS" } },
      },
      {
        id       = "lazy",
        handler  = function() require("lazy").home() end,
        desc     = "Open lazy plugin manager",
        bindings = { { lhs = "<leader>cl" } },
      },
    })
  end,
})
