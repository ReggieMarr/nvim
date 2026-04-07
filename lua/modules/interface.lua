-- lua/modules/interface.lua
-- Interface module: UI chrome, notification, picking, and core display primitives.
--
-- Provides capabilities:
--   notifier  — notification and progress reporting
--   picker    — unified fuzzy finding and list UI (via snacks.picker)
--
-- Registers display contributions:
--   statusline — composed from env.state, reads execution/lsp/vcs state
--   notifications — via snacks.notifier
--
-- Registers articulation:
--   buffer management actions
--   config inspection actions
--   UI toggle actions
--
-- No hard module dependencies: interface loads first and other modules
-- layer on top. The notifier capability is available immediately so
-- modules that load after can use it for their own notifications.

local env = require("env")
local IMG_PATH = vim.fn.expand '/home/reggiemarr/Pictures/Wallpapers/tent_in_nf.jpg'

env.module.register({
  name          = "interface",
  depends_on    = {},
  optional_deps = {},

  -- ── Providers ──────────────────────────────────────────────────────────
  -- Infrastructure plugins that serve both display and articulation.
  -- snacks is configured once here; other specs in display/articulation
  -- sections reference it by name and lazy deduplicates.

  providers = {
    -- snacks.nvim: the UI foundation
    -- https://github.com/folke/snacks.nvim
    {
      "folke/snacks.nvim",
      priority = 1000, -- load before everything else
      lazy     = false,
        init = function()
        -- require("etiennecollin.core.mappings.plugin").snacks()

        ---@type table<number, {token:lsp.ProgressToken, msg:string, done:boolean}[]>
        local progress = vim.defaulttable()
        vim.api.nvim_create_autocmd('LspProgress', {
            ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
            callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
            if not client or type(value) ~= 'table' then return end
            local p = progress[client.id]

            for i = 1, #p + 1 do
                if i == #p + 1 or p[i].token == ev.data.params.token then
                p[i] = {
                    token = ev.data.params.token,
                    msg = ('[%3d%%] %s%s'):format(
                    value.kind == 'end' and 100 or value.percentage or 100,
                    value.title or '',
                    value.message and (' **%s**'):format(value.message) or ''
                    ),
                    done = value.kind == 'end',
                }
                break
                end
            end

            local msg = {} ---@type string[]
            progress[client.id] = vim.tbl_filter(
                function(v) return table.insert(msg, v.msg) or not v.done end,
                p
            )

            local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
            vim.notify(table.concat(msg, '\n'), 'info', {
                id = 'lsp_progress',
                title = client.name,
                opts = function(notif)
                notif.icon = #progress[client.id] == 0 and ' '
                    or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
                end,
            })
            end,
        })
        end,
      ---@type snacks.Config
      opts = {
        -- Picker: unified list/fuzzy UI
        -- All picker capability methods delegate here
        picker = {
          enabled = true,
          ui_select = true, -- override vim.ui.select globally
          layout = {
            preset = "default",
            cycle  = true,
          },
          formatters = {
            file = { filename_first = true },
          },
          matcher = {
            frecency = true, -- weight recent/frequent files higher
            history_bonus = true,
          },
          previewers = {
              diff = {
              style = 'terminal',
              cmd = { 'delta' },
              },
          },
          win = {
            input = {
              keys = {
                -- Keep escape behavior consistent with the rest of the editor
                ["<Esc>"] = { "close", mode = { "n", "i" } },
              },
            },
          },

      sources = {
        -- git_log = git_actions,
        -- git_log_file = git_actions,
        -- git_log_line = git_actions,
        -- rga = rga_source,
        -- astgrep = astgrep_source,
        explorer = {
          auto_close = true,
          layout = { preset = 'ivy', preview = true },
          matcher = { fuzzy = true },
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
            explorer_dwim = function(picker_state)
              local item = picker_state:current()
              if item then
                if item.dir then
                  -- Navigate into directory
                  picker_state:cd(item.file)
                else
                  -- Open file
                  vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
                  picker_state:close()
                end
              end
            end,
          },
          win = {
            input = {
              keys = {
                ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
                ['<a-j>'] = { 'list_down', mode = { 'n' } },
                ['<a-k>'] = { 'list_up', mode = { 'n' } },
                ['<BS>'] = { 'explorer_up', mode = { 'n' } },
                ['h'] = { 'explorer_up', mode = { 'n' } },
                ['c-p'] = { 'toggle_preview', mode = { 'n', 'i' } },
                ['l'] = { 'explorer_focus', mode = { 'n' } },
                ['<ESC>'] = { 'focus_list', mode = { 'n', 'i' } },
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
        },
      },
        },

        -- Notifier: replaces vim.notify
        notifier = {
          enabled  = true,
          timeout  = 3000,
          sort     = { "level", "added" },
          level    = vim.log.levels.TRACE,
          style    = "compact",
          top_down = false,
        },

        -- Input: replaces vim.ui.input
        input = { enabled = true },
        animate = {
            enabled = true,
            fps = 120,
        },
        dim = {
            enabled = true,
        },
        explorer = {
            enabled = true,
            replace_netrw = true,
        },

        image = {
        enabled = true,
        doc = {
            inline = false,
            img_dirs = {
            'img',
            'images',
            'assets',
            'static',
            'public',
            'media',
            'attachments',
            'resources',
            },
        },
        math = {
            enabled = false,
        },
        },

        -- Indent guides
        indent = {
          enabled = true,
          animate = { enabled = false }, -- disable for performance
          scope   = { enabled = true },
        },

        quickfile = {
            enabled = true,
        },

        -- Scope: context-aware scope highlighting
        scope = { enabled = true },

        -- Words: highlight all occurrences of word under cursor
        words = { enabled = true },

        -- Bigfile: disable expensive features for large files
        -- State provider in lib/state.lua core providers uses this threshold
        bigfile = {
          enabled = true,
          size    = 1.5 * 1024 * 1024, -- 1.5MB
        },

        -- Scratch: quick scratch buffers
        scratch = { enabled = true },

        -- Dashboard: startup screen
        dashboard = {
          enabled = true,
            -- NOTE from etiennes config
            sections = {
                {
                enabled = function()
                    return (vim.fn.executable 'chafa' == 1) and (vim.fn.filereadable(IMG_PATH) == 1)
                end,
                {
                    section = 'terminal',
                    cmd = 'chafa '
                    .. IMG_PATH
                    .. ' --format symbols --symbols vhalf --size 60x17 --stretch',
                    height = 17,
                    padding = 1,
                },
                {
                    pane = 2,
                    { section = 'keys', gap = 1, padding = 1 },
                    { section = 'startup' },
                },
                },
                {
                enabled = function()
                    return not ((vim.fn.executable 'chafa' == 1) and (vim.fn.filereadable(IMG_PATH) == 1))
                end,
                { section = 'header' },
                { section = 'keys', gap = 1, padding = 1 },
                { section = 'startup' },
                },
            },
        },
        styles = {
            notification = {
                wo = { wrap = true }, -- Wrap notifications
            },
            snacks_image = {
                relative = 'editor',
                col = -1,
            },
        },
        zen      = { enabled = true }, -- not used

        -- Explicitly disable snacks modules owned by other modules
        -- so there's no ambiguity about who configured what
        -- TODO it'd be handy to check for conflicts on collect_plugin_specs
        terminal = { enabled = false }, -- owned by execution module
        animate  = { enabled = false }, -- prefer no animation globally
      },

      config = function(_, opts)
        local snacks = require("snacks")
        snacks.setup(opts)

        -- ── Register notifier capability ──────────────────────────────
        -- Override vim.notify immediately so all subsequent notifications
        -- go through snacks regardless of load order
        env.capabilities.register("notifier", {
          info = function(msg, o)
            snacks.notify.info(msg, o)
          end,
          warn = function(msg, o)
            snacks.notify.warn(msg, o)
          end,
          error = function(msg, o)
            snacks.notify.error(msg, o)
          end,
          progress = function(token, o)
            -- snacks handles LSP progress via its own handler
            -- this entry point is for explicit module progress reporting
            snacks.notify.info(token, vim.tbl_extend("force", {
              id      = token,
              timeout = false, -- progress notifications persist until dismissed
            }, o or {}))
          end,
        }, "interface")

        -- Replace vim.notify with the notifier capability so all
        -- existing vim.notify calls in plugins get routed through snacks
        vim.notify = function(msg, level, o)
          local notifier = env.capabilities.get("notifier")
          if not notifier then return end
          if level == vim.log.levels.ERROR then
            notifier.error(msg, o)
          elseif level == vim.log.levels.WARN then
            notifier.warn(msg, o)
          else
            notifier.info(msg, o)
          end
        end

        -- ── Register picker capability ────────────────────────────────
        -- Interface shape matches lib/capabilities.lua:M.interfaces.picker
        env.capabilities.register("picker", {
          files = function(o)
            snacks.picker.files(o)
          end,
          grep = function(o)
            snacks.picker.grep(o)
          end,
          buffers = function(o)
            snacks.picker.buffers(o)
          end,
          keymaps = function(o)
            snacks.picker.keymaps(o)
          end,
          commands = function(o)
            snacks.picker.commands(o)
          end,
        }, "interface")

        -- ── Register display contributions ────────────────────────────
        env.display.register({
          id       = "interface.notifications",
          module   = "interface",
          region   = "notification",
          priority = 100,
          desc     = "Snacks notification display",
          -- Always active: notifications are unconditional
        })

        env.display.register({
          id       = "interface.indent_guides",
          module   = "interface",
          region   = "virtual_text",
          priority = 10, -- low priority, decorative
          desc     = "Indent scope guides",
          when     = function(state)
            -- Disable in non-file buffers and very large files
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

        -- ── State providers specific to interface ─────────────────────
        -- Track notification history count for statusline
        env.state.register_provider({
          id      = "interface.notification_count",
          events  = { "User" },
          pattern = "SnacksNotifierUpdated",
          collect = function()
            local history = snacks.notifier.get_history()
            return #history
          end,
          desc = "Number of notifications in history",
        })
      end,
    },

    -- Colorscheme
    -- Loaded before other UI to prevent flash of unstyled content
    {
      "folke/tokyonight.nvim",
      priority = 900,
      lazy     = false,
      opts = {
        style       = "night",
        transparent = false,
        styles = {
          sidebars    = "dark",
          floats      = "dark",
        },
        on_highlights = function(hl, c)
          -- Ensure env.display namespace highlights don't conflict
          -- with the colorscheme. Reserved namespace for our virtual text.
          hl.EnvDisplayVirtualText = { fg = c.comment, italic = true }
        end,
      },
      config = function(_, opts)
        require("tokyonight").setup(opts)
        vim.cmd.colorscheme("tokyonight-night")
      end,
    },

    -- which-key: keybinding discovery and group labeling
    -- Loaded early so group labels registered by any module are visible
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {
        preset = "modern",
        delay  = 300,
        icons  = { mappings = true },
        spec   = {
          -- Top level group labels for the keymap grammar.
          -- Individual module articulation files add to these groups.
          -- Defined here so the structure exists even if modules are disabled.
          { "<leader>f", group = "find" },
          { "<leader>b", group = "buffers" },
          { "<leader>g", group = "git" },
          { "<leader>l", group = "lsp" },
          { "<leader>t", group = "tasks" },
          { "<leader>p", group = "project" },
          { "<leader>c", group = "config" },
          { "<leader>u", group = "ui" },
        },
      },
    },
  },

  -- ── Display ────────────────────────────────────────────────────────────
  -- Plugins whose primary concern is rendering information.

  display = {
    -- Statusline
    -- Reads from env.state rather than calling plugin APIs directly.
    -- This is the display layer contract: statusline is a state consumer.
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      event        = "VeryLazy",
      config = function()
        -- Helper: read from env.state with a fallback
        -- Used throughout lualine component definitions
        local function state(key, fallback)
          return function()
            local value = env.state.get(key)
            if value == nil then return fallback or "" end
            return value
          end
        end

        -- Component: LSP server names for current buffer
        -- Reads from state rather than calling vim.lsp.get_clients()
        local function lsp_clients()
          local servers = env.state.get("lsp.attached_servers")
          if not servers or #servers == 0 then return "" end
          return "  " .. table.concat(
            vim.tbl_map(function(s) return s.name end, servers),
            " "
          )
        end

        -- Component: active task count from overseer via state
        -- Only shown when execution module is enabled
        local function active_tasks()
          if not env.feature_enabled("execution") then return "" end
          local tasks = env.state.get("execution.active_tasks")
          if not tasks or #tasks == 0 then return "" end
          return string.format(" %d", #tasks)
        end

        -- Component: git branch from state
        -- Reads vcs.branch rather than calling vim.fn.system("git branch")
        local function git_branch()
          local branch = env.state.get("vcs.branch")
          if not branch or branch == "" then return "" end
          return "  " .. branch
        end

        -- Component: diagnostic counts from state
        local function diagnostics_from_state()
          local diags = env.state.get("lsp.diagnostics")
          if not diags then return "" end

          local counts = { error = 0, warn = 0, info = 0, hint = 0 }
          for _, d in ipairs(diags) do
            if d.severity == vim.diagnostic.severity.ERROR then
              counts.error = counts.error + 1
            elseif d.severity == vim.diagnostic.severity.WARN then
              counts.warn = counts.warn + 1
            elseif d.severity == vim.diagnostic.severity.INFO then
              counts.info = counts.info + 1
            elseif d.severity == vim.diagnostic.severity.HINT then
              counts.hint = counts.hint + 1
            end
          end

          local parts = {}
          if counts.error > 0 then
            table.insert(parts, string.format(" %d", counts.error))
          end
          if counts.warn > 0 then
            table.insert(parts, string.format(" %d", counts.warn))
          end
          return table.concat(parts, " ")
        end

        -- Component: last task result indicator
        local function last_task_result()
          local result = env.state.get("execution.last_result")
          if not result then return "" end
          local icon = result.status == "SUCCESS" and " " or " "
          return icon .. result.name
        end

        -- Register statusline display contribution
        -- Done here where we have access to the lualine config context
        env.display.register({
          id       = "interface.statusline",
          module   = "interface",
          region   = "statusline",
          priority = 100,
          desc     = "Lualine statusline reading from env.state",
        })

        require("lualine").setup({
          options = {
            theme                = "tokyonight",
            globalstatus         = true,
            section_separators   = { left = "", right = "" },
            component_separators = { left = "", right = "" },
            disabled_filetypes   = {
              statusline = { "dashboard", "alpha", "starter" },
            },
          },
          sections = {
            lualine_a = { "mode" },

            lualine_b = {
              {
                git_branch,
                color = { fg = "#7aa2f7" },
              },
            },

            lualine_c = {
              {
                "filename",
                path      = 1, -- relative path
                symbols   = { modified = " ●", readonly = " ", unnamed = "[No Name]" },
              },
            },

            lualine_x = {
              {
                diagnostics_from_state,
                color = { fg = "#f7768e" },
              },
              {
                lsp_clients,
                color = { fg = "#9ece6a" },
              },
              {
                active_tasks,
                color = { fg = "#e0af68" },
              },
            },

            lualine_y = { "filetype" },

            lualine_z = {
              { "location" },
              {
                -- Show notification count when there are unread notifications
                function()
                  local count = env.state.get("interface.notification_count")
                  if not count or count == 0 then return "" end
                  return string.format(" %d", count)
                end,
                color = { fg = "#bb9af7" },
              },
            },
          },

          inactive_sections = {
            lualine_c = { "filename" },
            lualine_x = { "location" },
          },

          -- Winbar: shows current context (treesitter breadcrumbs when language enabled)
          winbar = {
            lualine_c = {
              {
                function()
                  -- When language module is active, this slot is populated
                  -- by the language module extending the winbar component.
                  -- When inactive, shows the relative file path as fallback.
                  local context = env.state.get("lsp.current_symbol")
                  if context and context ~= "" then
                    return context
                  end
                  return state("buffer.path", "")()
                    :gsub(vim.fn.getcwd() .. "/", "")
                end,
                color = { fg = "#737aa2" },
              },
            },
          },

          inactive_winbar = {
            lualine_c = { { "filename", color = { fg = "#737aa2" } } },
          },
        })
      end,
    },

    -- Bufferline: tab-like buffer display
    {
      "akinsho/bufferline.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      event        = "VeryLazy",
      opts = {
        options = {
          mode              = "buffers",
          themable          = true,
          numbers           = "none",
          diagnostics       = "nvim_lsp",
          -- Show diagnostics indicator sourced through LSP,
          -- which ultimately comes from our lsp.diagnostics state.
          -- Bufferline reads this directly from nvim's diagnostic API
          -- rather than through env.state - acceptable here because
          -- bufferline has its own update mechanism and this is display-only.
          diagnostics_indicator = function(count, level)
            local icon = level:match("error") and " " or " "
            return icon .. count
          end,
          show_buffer_close_icons = false,
          show_close_icon         = false,
          separator_style         = "slant",
          always_show_bufferline  = false,
          offsets = {
            {
              -- Reserve space when filesystem module opens a file tree
              filetype   = "neo-tree",
              text       = "Files",
              highlight  = "Directory",
              separator  = true,
            },
          },
        },
      },
    },
  },

  -- ── Articulation ───────────────────────────────────────────────────────
  -- Keymaps and commands whose concern is UI interaction and buffer management.

  articulation = {
    {
      "folke/snacks.nvim",
      config = function()
        -- ── Buffer actions ──────────────────────────────────────────
        env.articulation.register_group_label("<leader>b", "buffers")

        env.articulation.register_group("interface", {
          {
            id      = "interface.find_buffers",
            handler = function()
              env.use("picker").buffers()
            end,
            desc     = "Find open buffers",
            bindings = { { lhs = "<leader>bb" } },
          },
          {
            id      = "interface.close_buffer",
            handler = function()
              -- Close buffer without closing the window
              -- snacks provides a safe version that handles splits
              require("snacks").bufdelete()
            end,
            desc     = "Close current buffer",
            bindings = { { lhs = "<leader>bd" } },
            when     = function(state)
              return state["buffer.is_real"] == true
            end,
          },
          {
            id      = "interface.close_other_buffers",
            handler = function()
              require("snacks").bufdelete.other()
            end,
            desc     = "Close all other buffers",
            bindings = { { lhs = "<leader>bo" } },
          },
          {
            id      = "interface.next_buffer",
            handler = function() vim.cmd("bnext") end,
            desc     = "Next buffer",
            bindings = { { lhs = "]b" } },
          },
          {
            id      = "interface.prev_buffer",
            handler = function() vim.cmd("bprevious") end,
            desc     = "Previous buffer",
            bindings = { { lhs = "[b" } },
          },

          -- ── Find / picker actions ─────────────────────────────────
          -- Generic search operations that are not domain-specific.
          -- Domain-specific finders (lsp refs, git commits) are registered
          -- by their owning modules as picker capability extensions.

          {
            id      = "interface.find_files",
            handler = function()
              env.use("picker").files()
            end,
            desc     = "Find files",
            bindings = { { lhs = "<leader>ff" } },
            when     = function(state)
              return state["workspace.cwd"] ~= nil
            end,
          },
          {
            id      = "interface.grep",
            handler = function()
              env.use("picker").grep()
            end,
            desc     = "Grep project",
            bindings = { { lhs = "<leader>fg" } },
            when     = function(state)
              return state["workspace.cwd"] ~= nil
            end,
          },
          {
            id      = "interface.find_recent",
            handler = function()
              require("snacks").picker.recent()
            end,
            desc     = "Recent files",
            bindings = { { lhs = "<leader>fr" } },
          },
          {
            id      = "interface.find_keymaps",
            handler = function()
              env.use("picker").keymaps()
            end,
            desc     = "Find keymaps",
            bindings = { { lhs = "<leader>fk" } },
          },
          {
            id      = "interface.find_commands",
            handler = function()
              env.use("picker").commands()
            end,
            desc     = "Find commands",
            bindings = { { lhs = "<leader>fC" } },
          },
          {
            id      = "interface.find_help",
            handler = function()
              require("snacks").picker.help()
            end,
            desc     = "Find help tags",
            bindings = { { lhs = "<leader>fh" } },
          },
          {
            id      = "interface.find_notifications",
            handler = function()
              require("snacks").picker.notifications()
            end,
            desc     = "Find notification history",
            bindings = { { lhs = "<leader>fn" } },
          },

          -- ── UI toggle actions ─────────────────────────────────────
          -- Toggle display features on and off.
          -- These affect the display layer directly.

          {
            id      = "interface.toggle_diagnostics",
            handler = function()
              -- Toggle diagnostic virtual text visibility
              local current = vim.diagnostic.is_enabled()
              vim.diagnostic.enable(not current)
            end,
            desc     = "Toggle diagnostics",
            bindings = { { lhs = "<leader>ud" } },
          },
          {
            id      = "interface.toggle_line_numbers",
            handler = function()
              vim.opt.number         = not vim.opt.number:get()
              vim.opt.relativenumber = not vim.opt.relativenumber:get()
            end,
            desc     = "Toggle line numbers",
            bindings = { { lhs = "<leader>ul" } },
          },
          {
            id      = "interface.toggle_word_highlights",
            handler = function()
              require("snacks").words.toggle()
            end,
            desc     = "Toggle word highlights",
            bindings = { { lhs = "<leader>uw" } },
          },
          {
            id      = "interface.toggle_indent_guides",
            handler = function()
              require("snacks").indent.toggle()
            end,
            desc     = "Toggle indent guides",
            bindings = { { lhs = "<leader>ui" } },
          },
          {
            id      = "interface.zoom_window",
            handler = function()
              require("snacks").zen.zoom()
            end,
            desc     = "Zoom current window",
            bindings = { { lhs = "<leader>uz" } },
          },

          -- ── Config inspection actions ─────────────────────────────
          -- These use the picker to navigate the config itself.
          -- Placed here because config inspection is a UI concern.

          {
            id      = "interface.find_in_config",
            handler = function()
              env.use("picker").files({
                cwd   = vim.fn.stdpath("config"),
                title = "Config files",
              })
            end,
            desc     = "Find in config",
            bindings = { { lhs = "<leader>cc" } },
          },
          {
            id      = "interface.grep_config",
            handler = function()
              env.use("picker").grep({
                cwd   = vim.fn.stdpath("config"),
                title = "Grep config",
              })
            end,
            desc     = "Grep config",
            bindings = { { lhs = "<leader>cg" } },
          },
          {
            id      = "interface.config_status",
            handler = function()
              -- Open the full ConfigStatus overview
              vim.cmd("ConfigStatus")
            end,
            desc     = "Open config status",
            bindings = { { lhs = "<leader>cs" } },
          },
          {
            id      = "interface.config_status_state",
            handler = function()
              vim.cmd("ConfigStatus state")
            end,
            desc     = "Inspect environment state",
            bindings = { { lhs = "<leader>cS" } },
          },
          {
            id      = "interface.lazy",
            handler = function()
              require("lazy").home()
            end,
            desc     = "Open lazy plugin manager",
            bindings = { { lhs = "<leader>cl" } },
          },

          -- ── Scratch buffer ────────────────────────────────────────
          {
            id      = "interface.scratch",
            handler = function()
              require("snacks").scratch()
            end,
            desc     = "Open scratch buffer",
            bindings = { { lhs = "<leader>bs" } },
          },
        })

        -- ── Extend picker with interface-level finders ────────────
        -- These finders are UI-layer concerns, not domain-specific.
        -- Domain modules (language, vcs) add their own picker extensions.
        env.capabilities.extend("picker", {
          help         = function(o) require("snacks").picker.help(o) end,
          notifications = function(o) require("snacks").picker.notifications(o) end,
          recent       = function(o) require("snacks").picker.recent(o) end,
          colorschemes = function(o) require("snacks").picker.colorschemes(o) end,
        }, "interface")
      end,
    },

    -- which-key articulation: register the top-level grammar
    -- Deferred to VeryLazy so all module group labels are registered first
    {
      "folke/which-key.nvim",
      config = function()
        -- which-key is configured in providers above.
        -- This spec exists to trigger any articulation-time setup
        -- that needs which-key to be loaded.
        -- Currently a no-op beyond what providers.opts handles.
      end,
    },
  },
})
