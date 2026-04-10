-- lua/modules/interface.lua
-- Interface module: UI chrome, notification, and picking primitives.
--
-- Provides capabilities:
--   notifier  — routes vim.notify through snacks
--   picker    — unified fuzzy finding via snacks.picker
--
-- Domain: interface

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
          enabled  = true,
          timeout  = 3000,
          sort     = { "level", "added" },
          level    = vim.log.levels.TRACE,
          style    = "compact",
          top_down = false,
        },
        input    = { enabled = true },
        indent   = {
          enabled = true,
          animate = { enabled = false },
          scope   = { enabled = true },
        },
        scope     = { enabled = true },
        words     = { enabled = true },
        bigfile   = { enabled = true, size = 1.5 * 1024 * 1024 },
        scratch   = { enabled = true },
        dashboard = {
          enabled  = true,
          sections = {
            { section = "header" },
            { section = "keys",         gap = 1, padding = 1 },
            { section = "recent_files", gap = 1, padding = 1 },
            { section = "startup" },
          },
        },
        -- Explicitly disable snacks modules owned by other modules
        terminal = { enabled = false }, -- execution module
        zen      = { enabled = false },
        animate  = { enabled = false },
      },
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
      files    = function(o) snacks.picker.files(o)    end,
      grep     = function(o) snacks.picker.grep(o)     end,
      buffers  = function(o) snacks.picker.buffers(o)  end,
      keymaps  = function(o) snacks.picker.keymaps(o)  end,
      commands = function(o) snacks.picker.commands(o) end,
    }, "interface")

    -- Extend picker with interface-level finders
    env.capabilities.extend("picker", {
      help          = function(o) snacks.picker.help(o)          end,
      notifications = function(o) snacks.picker.notifications(o) end,
      recent        = function(o) snacks.picker.recent(o)        end,
      colorschemes  = function(o) snacks.picker.colorschemes(o)  end,
    }, "interface")

    -- ── State providers ─────────────────────────────────────────────
    env.state.register_provider({
      id      = "interface.notification_count",
      events  = { "User" },
      pattern = "SnacksNotifierUpdated",
      collect = function()
        return #snacks.notifier.get_history()
      end,
      desc = "Number of notifications in snacks history",
    })

    -- ── Display contributions ───────────────────────────────────────
    env.display.register({
      id       = "interface.notifications",
      module   = "interface",
      region   = "notification",
      priority = 100,
      desc     = "Snacks notification overlay",
    })

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

    -- No more "hit enter after commands"
    require("vim._core.ui2").enable {
        enable = true,
        msg = { -- Options related to the message module.
            ---@type 'cmd'|'msg' Default message target, either in the
            ---cmdline or in a separate ephemeral message window.
            ---@type string|table<string, 'cmd'|'msg'|'pager'> Default message target
            ---or table mapping |ui-messages| kinds and triggers to a target.
            targets = "cmd",
            cmd = { -- Options related to messages in the cmdline window.
                height = 0.5, -- Maximum height while expanded for messages beyond 'cmdheight'.
            },
            dialog = { -- Options related to dialog window.
                height = 0.5, -- Maximum height.
            },
            msg = { -- Options related to msg window.
                height = 0.5, -- Maximum height.
                timeout = 4000, -- Time a message is visible in the message window.
            },
            pager = { -- Options related to message window.
                height = 0.5, -- Maximum height.
            },
        },
    }

    -- ── Articulation ────────────────────────────────────────────────
    env.articulation.register_group("interface", {

      -- Buffer management
      {
        id       = "interface.find_buffers",
        handler  = function() env.use("picker").buffers() end,
        desc     = "Find open buffers",
        bindings = { { lhs = "<leader>bb" } },
      },
      {
        id       = "interface.close_buffer",
        handler  = function() snacks.bufdelete() end,
        desc     = "Close current buffer",
        bindings = { { lhs = "<leader>bd" } },
        when     = function(state) return state["buffer.is_real"] == true end,
      },
      {
        id       = "interface.close_other_buffers",
        handler  = function() snacks.bufdelete.other() end,
        desc     = "Close all other buffers",
        bindings = { { lhs = "<leader>bo" } },
      },
      {
        id       = "interface.next_buffer",
        handler  = function() vim.cmd("bnext") end,
        desc     = "Next buffer",
        bindings = { { lhs = "]b" } },
      },
      {
        id       = "interface.prev_buffer",
        handler  = function() vim.cmd("bprevious") end,
        desc     = "Previous buffer",
        bindings = { { lhs = "[b" } },
      },
      {
        id       = "interface.scratch_buffer",
        handler  = function() snacks.scratch() end,
        desc     = "Open scratch buffer",
        bindings = { { lhs = "<leader>bs" } },
      },

      -- Find / picker
      {
        id       = "interface.find_files",
        handler  = function() env.use("picker").files() end,
        desc     = "Find files",
        bindings = { { lhs = "<leader>ff" } },
        when     = function(state) return state["workspace.cwd"] ~= nil end,
      },
      {
        id       = "interface.grep",
        handler  = function() env.use("picker").grep() end,
        desc     = "Grep project",
        bindings = { { lhs = "<leader>fg" } },
        when     = function(state) return state["workspace.cwd"] ~= nil end,
      },
      {
        id       = "interface.find_recent",
        handler  = function() env.use("picker").recent() end,
        desc     = "Recent files",
        bindings = { { lhs = "<leader>fr" } },
      },
      {
        id       = "interface.find_keymaps",
        handler  = function() env.use("picker").keymaps() end,
        desc     = "Find keymaps",
        bindings = { { lhs = "<leader>fk" } },
      },
      {
        id       = "interface.find_commands",
        handler  = function() env.use("picker").commands() end,
        desc     = "Find commands",
        bindings = { { lhs = "<leader>fC" } },
      },
      {
        id       = "interface.find_help",
        handler  = function() env.use("picker").help() end,
        desc     = "Find help tags",
        bindings = { { lhs = "<leader>fh" } },
      },
      {
        id       = "interface.find_notifications",
        handler  = function() env.use("picker").notifications() end,
        desc     = "Find notification history",
        bindings = { { lhs = "<leader>fn" } },
      },

      -- UI toggles
      {
        id       = "interface.toggle_diagnostics",
        handler  = function()
          vim.diagnostic.enable(not vim.diagnostic.is_enabled())
        end,
        desc     = "Toggle diagnostics",
        bindings = { { lhs = "<leader>ud" } },
      },
      {
        id       = "interface.toggle_line_numbers",
        handler  = function()
          vim.opt.number         = not vim.opt.number:get()
          vim.opt.relativenumber = not vim.opt.relativenumber:get()
        end,
        desc     = "Toggle line numbers",
        bindings = { { lhs = "<leader>ul" } },
      },
      {
        id       = "interface.toggle_word_highlights",
        handler  = function() snacks.words.toggle() end,
        desc     = "Toggle word highlights",
        bindings = { { lhs = "<leader>uw" } },
      },
      {
        id       = "interface.toggle_indent_guides",
        handler  = function() snacks.indent.toggle() end,
        desc     = "Toggle indent guides",
        bindings = { { lhs = "<leader>ui" } },
      },
      {
        id       = "interface.zoom_window",
        handler  = function() snacks.zen.zoom() end,
        desc     = "Zoom current window",
        bindings = { { lhs = "<leader>uz" } },
      },

      -- Config inspection
      {
        id       = "interface.find_in_config",
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
        id       = "interface.grep_config",
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
        id       = "interface.config_status",
        handler  = function() vim.cmd("ConfigStatus") end,
        desc     = "Open config status",
        bindings = { { lhs = "<leader>cs" } },
      },
      {
        id       = "interface.config_status_state",
        handler  = function() vim.cmd("ConfigStatus state") end,
        desc     = "Inspect environment state",
        bindings = { { lhs = "<leader>cS" } },
      },
      {
        id       = "interface.lazy",
        handler  = function() require("lazy").home() end,
        desc     = "Open lazy plugin manager",
        bindings = { { lhs = "<leader>cl" } },
      },
    })
  end,
})
