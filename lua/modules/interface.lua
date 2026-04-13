-- lua/modules/interface.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface
local function make_finder(cwd)
  ---@param opts snacks.picker.files.Config
  ---@param ctx snacks.picker.Context
  return function(opts, ctx)
    opts = Snacks.picker.util.shallow_copy(opts)
    opts.cmd = 'fd'
    opts.cwd = cwd
    opts.dirs = { cwd }
    opts.notify = false
    opts.hidden = true
    opts.args = {
      '--max-depth',
      '1',
      '--type',
      'd',
      '--path-separator',
      '/',
    }
    local fd_stream = require('snacks.picker.source.files').files(opts, ctx)
    return function(cb)
      -- inject the current directory as the first item
      cb {
        file = cwd,
        text = './',
        dir = true,
        is_cwd = true, -- flag so confirm can identify it
        sort = ' ', -- space sorts before '!' so it appears first
      }
      fd_stream(function(item)
        local is_dir = item.file:sub(-1) == '/'
        if is_dir then
          item.file = item.file:sub(1, -2)
          item.dir = true
        end
        local basename = item.file:match '[^/]+$' or item.file
        item.text = is_dir and (basename .. '/') or basename
        item.hidden = basename:sub(1, 1) == '.'
        item.sort = is_dir and ('!' .. basename) or ('#' .. basename)
        cb(item)
      end)
    end
  end
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

local function find_file_at(cwd)
  -- navigate into dir, re-using the picker instance
  local function navigate_to(picker, dir)
    cwd = vim.fn.resolve(dir)
    picker.opts.title = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~')
    picker.opts.finder = make_finder(cwd)
    picker.opts.cwd = cwd
    picker.input:set ''
    picker:find()
  end

  -- navigate to parent of current cwd
  local function navigate_up(picker)
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent ~= cwd then -- guard against filesystem root
      navigate_to(picker, parent)
    end
  end
  -- open neo-tree at cwd
  local function open_neotree(picker)
    picker:close()
    vim.schedule(
      function() vim.cmd(('Neotree dir=%s reveal position=current'):format(vim.fn.fnameescape(cwd))) end
    )
  end

  -- TODO make this it's own picker module
  Snacks.picker.pick {
    title = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
    finder = make_finder(cwd),

    -- text is now basename only → fuzzy match is scoped to current level
    -- this is exactly the vertico find-file behaviour
    format = 'file',
    formatters = { file = { filename_only = true } },
    actions = {
      yank_relative_cwd = function(_, item)
        local path = vim.fn.fnamemodify(item.file, ':.')
        vim.fn.setreg('+', path)
        vim.fn.setreg('"', path)
        vim.notify('Yanked: ' .. path)
      end,
      yank_relative_home = function(_, item)
        local path = vim.fn.fnamemodify(item.file, ':~')
        vim.fn.setreg('+', path)
        vim.fn.setreg('"', path)
        vim.notify('Yanked: ' .. path)
      end,
      -- DWIM backspace: no input → navigate up, else delete char
      dwim_backspace = function(picker)
        local search = picker.input:get() or ''
        print('backspace with ' .. search)
        if search == '' then
          local cwd = vim.fn.resolve(vim.fn.expand(cwd))
          print('find file at ' .. cwd .. ' parent ' .. vim.fs.dirname(cwd))
          find_file_at(vim.fs.dirname(cwd))
        else
          -- delegate to the built-in backspace behaviour
          vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes('<BS>', true, false, true),
            'n',
            false
          )
        end
      end,
    },

    confirm = function(picker, item)
        local search = picker.input:get() or ''

        print(vim.inspect(item))
        -- no input at all → open neotree
        if search == '' and not item then
            open_neotree(picker)
            return
        end

        -- ↓ new: selected the "./" current directory item → open neotree
        if item and item.is_cwd then
            open_neotree(picker)
            return
        end

        -- item exists and is a directory → navigate into it
        if item and item.dir then
            cwd = item.file
            find_file_at(cwd)
            return
        end

        -- item exists and is a file → open it
        if item and not item.dir then
            picker:close()
            vim.schedule(function() vim.cmd.edit(item.file) end)
            return
        end

        -- no matching item but there is input → vertico-style create
        if search ~= '' and not item then
            local target = cwd .. '/' .. search
            picker:close()
            vim.schedule(function()
            if search:match '%.[^./]+$' ~= nil then
                if create_file(target) then vim.cmd.edit(target) end
            else
                if create_directory(target) then find_file_at(target) end
            end
            end)
            return
        end
    end,
    win = {
      input = {
        keys = {
          ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
          ['<a-j>'] = { 'list_down', mode = { 'n' } },
          ['<a-k>'] = { 'list_up', mode = { 'n' } },
          ['<BS>'] = { 'dwim_backspace', mode = { 'n', 'i' } },
          ['h'] = { 'dwim_backspace', mode = { 'n' } },
          ['<c-p>'] = { 'toggle_preview', mode = { 'n', 'i' } },
          ['<c-h>'] = { 'toggle_hidden', mode = { 'n', 'i' } },
          ['l'] = { 'confirm', mode = { 'n' } },
          ['<c-ESC>'] = { 'focus_list', mode = { 'n', 'i' } },
          ['<ESC>'] = { 'close', mode = { 'n' } },
        },
      },
      list = {
        keys = {
          ['.'] = 'explorer_focus',
          ['<BS>'] = 'explorer_up',
          ['<space>'] = 'select_and_next',
          ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
          ['<a-j>'] = { 'list_down', mode = { 'n' } },
          ['<a-k>'] = { 'list_up', mode = { 'n' } },
          ['a'] = 'explorer_add',
          ['<c-h>'] = { 'toggle_hidden', mode = { 'n', 'i' } },
          ['c'] = 'explorer_copy',
          ['d'] = 'explorer_del',
          ['l'] = 'explorer_focus',
          ['h'] = { 'explorer_up', mode = { 'n' } },
          ['i'] = { 'focus_input', mode = { 'n' } },
          ['m'] = 'explorer_move',
          ['r'] = 'explorer_rename',
          ['<c-o>'] = 'explorer_yank',
          ['y'] = 'yank_relative_cwd',
          ['Y'] = 'yank_relative_home',
        },
      },
    },

    layout = { preset = 'default', preview = false },
    focus = 'input',
  }
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
