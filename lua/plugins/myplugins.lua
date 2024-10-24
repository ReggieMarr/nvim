-- TODO: Remove telescope as a dependency and lazy load plugins later for squeezed performance.conf
local telescope_actions = require "telescope.actions"
local telescope_layout = require "telescope.actions.layout"

-- Loaded plugins etc.
local status = require("utils").status
local tools = require "configs.tools"

-- Helper function to flatten tables
local function flatten(t)
  local flat = {}
  for _, category in pairs(t) do
    if type(category) == "table" then
      for _, item in pairs(category) do
        if type(item) == "table" then
          for _, subitem in pairs(item) do
            table.insert(flat, subitem)
          end
        else
          table.insert(flat, item)
        end
      end
    else
      table.insert(flat, category)
    end
  end
  return flat
end

---@type NvPluginSpec[]
local plugins = {
  { -- Built-in cheats
    -- AWESOME
    "sudormrfbin/cheatsheet.nvim",
    lazy = false,

    cmd = { "Cheatsheet" },

    keys = {
      {
        "<leader>fi",
        "<cmd>Cheatsheet<cr>",
        mode = "n",
        desc = "Find Cheat",
      },
    },

    dependencies = {
      { "nvim-telescope/telescope.nvim" },
      { "nvim-lua/popup.nvim" },
      { "nvim-lua/plenary.nvim" },
    },
  },

  {
    "folke/which-key.nvim",
    lazy = false,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "whichkey")
      -- TODO update these configs to match my nmenonics and uncomment this
      -- local wk_config = require("configs.which-key")
      -- opts = vim.tbl_deep_extend("force", opts, wk_config.opts)
      -- wk_config.setup()
    end,
  },

  --Override plugin definition options
  -- FIXME: TODO: remove telescope override and write it as a dependency
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release",
      },
      -- NOTE this is an awesome ui package but I need to spend some time to properly configure it
      -- its also worth noting this is considered experimental
      {
        "folke/noice.nvim",
        event = "VeryLazy",
        keys = {
          { "<leader>su", "<cmd>Noice pick<CR>", { desc = "Search notifications" } },
          { "<leader>nl", "<cmd>Noice last<CR>", { desc = "Show the last notification" } },
          { "<leader>nd", "<cmd>Noice dismiss<CR>", { desc = "Dismiss noice" } },
        },
        config = function()
          require("noice").setup {
            routes = {
              {
                -- Filter out low-priority notifications
                filter = {
                  event = "notify",
                  min_height = 1,
                },
                view = "mini",
              },
              {
                -- Ignore LSP progress updates
                filter = {
                  event = "lsp",
                  kind = "progress",
                },
                opts = { skip = true },
              },
              {
                -- Skip written/yanked messages
                filter = {
                  event = "msg_show",
                  kind = { "echo", "echomsg" },
                  any = {
                    { find = "written" },
                    { find = "yanked" },
                    { find = "line" },
                    { find = "more lines" },
                  },
                },
                opts = { skip = true },
              },
              {
                -- Route other messages to mini view
                filter = {
                  event = "msg_show",
                },
                view = "mini",
              },
              {
                -- Skip all messages that aren't errors or warnings
                filter = {
                  event = "msg_show",
                  ["not"] = {
                    kind = { "error", "warning" },
                  },
                },
                opts = { skip = true },
              },
            },
            messages = {
              -- NOTE: If you enable messages, then the cmdline is enabled automatically.
              -- This is a current Neovim limitation.
              enabled = true,
              view = "mini", -- default view for messages
              view_error = "notify", -- view for errors
              view_warn = "notify", -- view for warnings
              view_history = "messages", -- view for :messages
              view_search = false, -- view for search count messages. Set to `false` to disable
            },
            notify = {
              -- Reduce visual noise
              enabled = true,
              view = "mini",
            },
          }
        end,
        dependencies = {
          -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
          "MunifTanjim/nui.nvim",
          -- OPTIONAL:
          --   `nvim-notify` is only needed, if you want to use the notification view.
          --   If not available, we use `mini` as the fallback
          "rcarriga/nvim-notify",
        },
      },
    },
    keys = {
      { "<leader>sn", "<cmd>Telescope notify<CR>", { desc = "Search notifications" } },
      { "<leader>sN", "<cmd>Notification<CR>", { desc = "Get logs" } },
    },
    config = function()
      -- load extensions
      local telescope = require "telescope"
      telescope.load_extension "fzf"
      telescope.load_extension "notify"
      telescope.load_extension "git_grep"
      telescope.load_extension "file_browser"
      telescope.load_extension "noice"

      local actions = require "telescope.actions"
      telescope.setup {
        defaults = {
          select_buffer = true,
          grouped = true,
          sorting_strategy = "ascending",
          path_display = { "filename_first" },
          layout_config = {
            prompt_position = "top",
          },
          mappings = {
            i = {
              ["<C-n>"] = actions.toggle_selection + actions.move_selection_worse,
              ["<C-p>"] = actions.toggle_selection + actions.move_selection_better,
              ["<TAB>"] = actions.select_default,
            },
            n = {
              ["<TAB>"] = actions.select_default,
            },
          },
        },
        pickers = {
          lsp_references = {
            show_line = false,
          },
          find_files = {
            hidden = true,
          },
          live_grep = {
            additional_args = { "--hidden" },
          },
          file_browser = {
            select_buffer = true,
            grouped = true,
            hidden = true,
          },
        },
      }
    end,
  },

  {
    "davvid/telescope-git-grep.nvim",
  },

  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "joechrisellis/lsp-format-modifications.nvim",
      {
        "ray-x/lsp_signature.nvim",
        event = "InsertEnter",
        config = function(_, opts)
          require("lsp_signature").setup {
            bind = true,
            handler_opts = {
              border = "rounded",
            },
          }
        end,
      },
      { -- Lsp lens Show References, Definitions etc. as virtual text
        -- Not working smoothly in every language
        "VidocqH/lsp-lens.nvim",

        keys = {
          {
            "<leader>ll",
            "<cmd> LspLensToggle<CR>",
            mode = "n",
            desc = "Enable Lsp Lens",
          },
        },

        config = function(_, opts)
          local SymbolKind = vim.lsp.protocol.SymbolKind
          require("lsp-lens").setup {
            enable = false,
            include_declaration = false, -- Reference include declaration

            sections = { -- Enable / Disable specific request
              definition = false,
              references = true,
              implements = true,
            },
            -- Target Symbol Kinds to show lens information
            target_symbol_kinds = { SymbolKind.Function, SymbolKind.Method, SymbolKind.Interface },
            -- Symbol Kinds that may have target symbol kinds as children
            wrapper_symbol_kinds = { SymbolKind.Class, SymbolKind.Struct },
            ignore_filetype = {
              "prisma",
            },
          }
        end,
      },

      -- format & linting
      {
        dependencies = {
          "ckolkey/ts-node-action",
        },
        "nvimtools/none-ls.nvim",
        config = function()
          require "configs.null-ls"
        end,
      },
    },
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      install_root_dir = os.getenv "HOME" .. "/.local/share/nvim/mason/",
      ensure_installed = tools.lsp,
    },
  },

  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
    },
    opts = {
      install_root_dir = os.getenv "HOME" .. "/.local/share/nvim/mason/",
    },
  },

  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    keys = {
      {
        "<leader>lF",
        function()
          require("conform").format { async = true, lsp_fallback = true }
        end,
        mode = "",
        desc = "Format entire buffer",
      },
      {
        "<leader>lf",
        function()
          -- Format git changes in current buffer
          require("configs.conform").format_on_save_handler(0)
        end,
        mode = "",
        desc = "Format changed lines",
      },
    },
    opts = {
      formatters_by_ft = tools.formatters,
      -- Extract format_on_save logic to a separate function for reusability
      format_on_save = function(bufnr)
        -- Add special handling for Makefiles
        local ft = vim.bo[bufnr].filetype
        if ft == "make" or ft == "makefile" then
          -- Ensure tabs are preserved
          vim.bo[bufnr].expandtab = false
          vim.bo[bufnr].tabstop = 8
          vim.bo[bufnr].shiftwidth = 8
        end
        return require("configs.conform").format_on_save_handler(bufnr)
      end,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },

  -- TODO this was thought to be needed but apparently conform already does this
  -- {
  --   "joechrisellis/lsp-format-modifications.nvim",
  --   dependencies = {
  --     "neovim/nvim-lspconfig",
  --     "stevearc/conform.nvim",
  --   },
  --   keys = {
  --     {
  --       "<leader>cf",
  --       "<cmd>FormatModifications<cr>",
  --       desc = "Format modified lines",
  --     },
  --   },
  -- },

  {
    "jay-babu/mason-null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "nvimtools/none-ls.nvim",
    },
    opts = {
      install_root_dir = os.getenv "HOME" .. "/.local/share/nvim/mason/",
      ensure_installed = flatten(tools.linters),
      automatic_installation = true,
      handlers = {},
    },
  },

  -- NOTE this is interesting but doesn't seem to work well with lazy
  -- https://github.com/code-biscuits/nvim-biscuits/issues/47
  --{ -- Show context on delimiter. (eg:..
  --  --   fn some(a, b ,c) {             |
  --  --   some_action();                 |
  --  --   } // fn some(a, b ,c) <--------'
  --  -- )

  --  "code-biscuits/nvim-biscuits",
  --  lazy = false,
  --  keys = {
  --    {
  --      "<leader>lt",
  --      function()
  --        require("nvim-biscuits").BufferAttach()
  --        require("nvim-biscuits").toggle_biscuits()
  --      end,
  --      mode = "n",
  --      desc = "Enable Biscuits",
  --    },
  --  },
  --  config = function(_, opts)
  --    require("nvim-biscuits").setup {
  --      cursor_line_only = true,
  --      show_on_start = false,
  --      on_events = "CursorHoldI",
  --      trim_by_words = true,
  --    }
  --  end,
  --},

  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    -- not strictly a plugin but related
    config = function()
      require("nvim-treesitter.configs").setup {
        -- todo these should go in configs.tools
        ensure_installed = {
          -- defaults
          "vim",
          "lua",
          -- web dev
          "html",
          "css",
          "javascript",
          "typescript",
          "tsx",
          "json",
          -- "vue", "svelte",
          -- Systems programming
          "c",
          "cpp",
          "cmake",
          "make",
          "rust",
          -- Note
          "org",
          "markdown",
          "markdown_inline",
          -- Script
          "bash",
          "python",
        },
        auto_install = true,
        indent = {
          enable = true,
          -- These aren't working at the moment
          disable = {
            "c",
            "cpp",
            "make",
          },
        },
        highlight = {
          enable = true,
          use_languagetree = true,
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<leader>vs",
            node_incremental = "<leader>vi",
            scope_incremental = "<leader>vc",
            node_decremental = "<leader>vd",
          },
        },
        textobjects = {
          select = {
            enable = true,
            -- Automatically jump forward to textobj, similar to targets.vim
            lookahead = true,
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              -- these can be inspected with :InspectTree or :Ts* commands
              ["ia"] = { query = "@definition", query_group = "locals", desc = "Select language scope" },
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
              ["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" },
            },
            selection_modes = {
              ["@parameter.outer"] = "v", -- charwise
              ["@function.outer"] = "V", -- linewise
              ["@class.outer"] = "<c-v>", -- blockwise
            },
            include_surrounding_whitespace = true,
          },
        },
      }
    end,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      git = {
        enable = true,
      },

      renderer = {
        highlight_git = true,
        icons = {
          show = {
            git = true,
          },
        },
      },
    },
  },

  -- {
  --   "max397574/better-escape.nvim",
  --   event = "InsertEnter",
  --   config = function()
  --     require("better_escape").setup()
  --   end,
  -- },

  -- C++ development
  -- Nice but limited cpp codegen features which I'll (probably) not use (if you want create keymapps)
  -- {
  --   "Badhi/nvim-treesitter-cpp-tools",
  --
  --   dependencies = { "nvim-treesitter/nvim-treesitter" },
  --   keys = require("configs.cpp").treesitter.keys,
  --   opts = require("configs.cpp").treesitter.opts,
  --
  --   config = function(_, opts)
  --     require("nt-cpp-tools").setup(opts)
  --   end,
  -- },

  {
    "hrsh7th/nvim-cmp",
    dependencies = require("configs.cmp").dependencies,
    opts = require("configs.cmp").opts,
  },

  {
    "stevearc/overseer.nvim",
    lazy = false,
    keys = {
      {
        "<leader>cc",
        function()
          local overseer = require "overseer"
          local tasks = overseer.list_tasks()
          local running_tasks = {}

          for _, task in ipairs(tasks) do
            if task.status == "RUNNING" then
              table.insert(running_tasks, task)
            end
          end

          local most_recent_task = tasks[#tasks]

          if #running_tasks > 0 then
            vim.notify("Stopping running tasks", vim.log.levels.INFO)
            for _, task in ipairs(running_tasks) do
              overseer.run_action(task, "dispose")
            end
            vim.cmd "OverseerToggle"
          elseif most_recent_task then
            vim.notify("Redoing last task", vim.log.levels.INFO)
            overseer.run_action(most_recent_task, "restart")
          else
            vim.notify("Opening task menu", vim.log.levels.INFO)
            overseer.run_template()
          end
        end,
        mode = "n",
        desc = "Tasks DWIM",
      },
      {
        "<leader>cd",
        function()
          local overseer = require "overseer"
          overseer.run_template()
        end,
        mode = "n",
        desc = "Stop running tasks",
      },
      {
        "<leader>cs",
        function()
          local overseer = require "overseer"
          local tasks = overseer.list_tasks()
          for _, task in ipairs(tasks) do
            if task.status == "RUNNING" then
              overseer.run_action(task, "dispose")
            end
          end
        end,
        mode = "n",
        desc = "Stop running tasks",
      },
      {
        "<leader>cr",
        function()
          local overseer = require "overseer"
          local tasks = overseer.list_tasks()
          if #tasks > 0 then
            overseer.run_action(tasks[#tasks], "restart")
          else
            vim.notify("No tasks to restart", vim.log.levels.WARN)
          end
        end,
        mode = "n",
        desc = "Restart last task",
      },
      {
        "<leader>cd",
        ":OverseerToggle<CR>",
        mode = "n",
        desc = "Toggle Task List",
      },
    },

    config = function(_, opts)
      vim.api.nvim_create_user_command("WatchRun", function()
        local overseer = require("overseer")
        overseer.run_template({ name = "run script" }, function(task)
          if task then
            task:add_component({ "restart_on_save", paths = {vim.fn.expand("%:p")} })
            local main_win = vim.api.nvim_get_current_win()
            overseer.run_action(task, "open vsplit")
            vim.api.nvim_set_current_win(main_win)
          else
            vim.notify("WatchRun not supported for filetype " .. vim.bo.filetype, vim.log.levels.ERROR)
          end
        end)
      end, {})

      require("overseer").setup {
      }
    end,

    dependencies = {
      "nvim-neotest/nvim-nio",
      "akinsho/toggleterm.nvim", -- Make sure to add toggleterm as a dependency
      {
        "stevearc/dressing.nvim",
        config = function(_, opts)
          require("dressing").setup(opts)
        end,
        opts = {
          default_prompt = "❯ ",
        },
      },
    },
  },

  { -- Integrated Tests -- CONFIG
    "nvim-neotest/neotest",

    keys = {
      {
        "<leader>to",
        ":Neotest summary<CR>",
        mode = "n",
        desc = "Open interactive test session",
      },
      {
        "<leader>te",
        ":Neotest run<CR>",
        mode = "n",
        desc = "Run tests for the session",
      },
      {
        "<leader>tf",
        function()
          require("neotest").output_panel.toggle()
        end,
        mode = "n",
        desc = "Toggle test panel",
      },
      {
        "<leader>tq",
        function()
          require("neotest").output.open { enter = true }
        end,
        mode = "n",
        desc = "Open test results",
      },
    },

    dependencies = {
      -- Required
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",

      -- Dev
      "rouge8/neotest-rust", -- Rust development
    },

    config = function(_, opts)
      require("neotest").setup {
        adapters = {
          require "neotest-rust",
          -- require "neotest-vim-test" {
          --   ignore_file_types = { "python", "vim", "lua" },
          -- },
        },
      }
    end,
  },

  {
    "NeogitOrg/neogit",

    keys = {
      {
        "<leader>gg",
        "<cmd> Neogit<CR>",
        mode = "n",
        desc = "Open Neogit",
      },
    },

    dependencies = {
      "nvim-lua/plenary.nvim", -- required
      "nvim-telescope/telescope.nvim", -- optional
      "sindrets/diffview.nvim", -- optional
    },

    config = function(_, opts)
      require("neogit").setup(opts)
      status.git = true
    end,

    opts = {},
  },

  {
    "debugloop/telescope-undo.nvim",

    keys = {
      { "<leader>tu", ":Telescope undo<CR>", mode = "n", desc = "Open Undo History" },
    },

    dependencies = {
      {
        "nvim-telescope/telescope.nvim",
        opts = {
          extensions = {
            undo = {
              side_by_side = true,
              layout_strategy = "vertical",
              layout_config = {
                preview_height = 0.8,
              },
            },
          },
        },
      },
    },

    config = function(_, opts)
      require("telescope").load_extension "undo"
    end,
  },

  -- { -- C/C++ cpp <-> hpp file pairing TODO: replace with other.nvim || harpoon
  --   "Everduin94/nvim-quick-switcher", -- TODO: use other.nvim
  --
  --   keys = {
  --     {
  --       "<leader>sw",
  --       ":lua require('nvim-quick-switcher').toggle('cpp', 'hpp')<CR>",
  --       mode = "n",
  --       desc = "Switch To Pair File",
  --     },
  --   },
  --
  --   config = function() end,
  -- },

  {
    "ThePrimeagen/refactoring.nvim",

    config = function()
      require("refactoring").setup()
      -- require("telescope").load_extension "refactoring" -- Unnede When dressing.nvim is a thing
    end,

    keys = require("configs.refactoring").keys,
  },

  -- NOTE this is another AI tool, will have to eval this integeration seperately
  -- {
  --   "sourcegraph/sg.nvim",
  --
  --   dependencies = { "nvim-lua/plenary.nvim" },
  --
  --   config = function(_, opts)
  --     require("sg").setup(opts)
  --     status.cody = true
  --   end,
  --
  --   opts = require("configs.sg").opts,
  --   keys = require("configs.sg").keys,
  --
  --   -- If you have a recent version of lazy.nvim, you don't need to add this!
  --   -- build = "nvim -l build/init.lua",
  -- },

  -- TODO replace this with our own quartz powered previewer
  -- { -- TODO: Fix
  --   "iamcco/markdown-preview.nvim",
  --
  --   ft = {
  --     "markdown",
  --   },
  --   build = ":call mkdp#util#install()",
  --
  --   keys = {
  --     {
  --       "<leader>mp",
  --       "<cmd>MarkdownPreviewToggle<cr>",
  --       mode = "n",
  --       desc = "Markdown Preview",
  --     },
  --   },
  --
  --   config = function()
  --     vim.g.mkdp_filetypes = { "markdown" }
  --   end,
  -- },

  { -- Allows to use vim command "w" inside CamelCase snake_case etc
    "chaoren/vim-wordmotion",
    lazy = false,
  },

  { -- nvim-dap UI
    "rcarriga/nvim-dap-ui",
    keys = {
      {
        "<leader>dq",
        function()
          require("dapui").eval()
        end,
        mode = { "n", "v" },
        desc = "Hover",
      },
      {
        "<leader>df",
        function()
          require("dapui").float_element()
        end,
        mode = "n",
        desc = "Lookup Options",
      },
    },

    config = function(_, opts)
      require("dapui").setup(opts)
      status.debug = true
    end,
  },

  { -- nvim-dap virtual text
    "theHamsta/nvim-dap-virtual-text",
    config = function(_, opts)
      require("nvim-dap-virtual-text").setup(opts)
    end,
    opts = {},
  },

  { -- DAP REPL Autocompletion
    "rcarriga/cmp-dap",
    config = function(_, opts)
      require("cmp").setup {
        enabled = function()
          return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt" or require("cmp_dap").is_dap_buffer()
        end,
      }
      require("cmp").setup.filetype({
        "dap-repl",
        "dapui_watches",
        "dapui_hover",
      }, {
        sources = {
          { name = "dap" },
        },
      })
    end,
  },

  {
    "LiadOz/nvim-dap-repl-highlights",
    dependencies = "nvim-treesitter/nvim-treesitter",

    keys = {
      {
        "<leader>dp",
        function()
          require("nvim-dap-repl-highlights").setup_highlights()
        end,
        mode = "n",
        desc = "Set REPL Highlight",
      },
    },

    config = function()
      require("nvim-dap-repl-highlights").setup()
      require("nvim-treesitter.configs").setup {
        highlight = {
          enable = true,
        },
        ensure_installed = {
          "dap_repl",
        },
      }
    end,
  },

  { -- Debug Adapter Protocol
    "mfussenegger/nvim-dap",

    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "rcarriga/cmp-dap",
      "LiadOz/nvim-dap-repl-highlights",
    },
    -- TODO: Move these to configs/nvim-dap.lua
    config = function()
      require("utils").load_breakpoints()
      local dap = require "dap"
      -- dap.set_log_level "TRACE"

      ----------------------------------------------------
      --                    ADAPTERS                    --
      ----------------------------------------------------
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          -- CHANGE THIS to your path!
          command = "codelldb",
          args = { "--port", "${port}" },

          -- On windows you may have to uncomment this:
          -- detached = false,
        },
      }

      dap.adapters.debugpy = {
        -- Requires:
        --  python -m pip install debugpy # --break-system-packages # <- if the first command doesn't work
        type = "executable",
        command = "python",
        -- function()
        --    local venv = os.getenv "VIRTUAL_ENV"
        --    if venv then
        --      return venv .. "/bin/python"
        --    else
        --      return "python" -- From $PATH
        --    end
        -- end,
        args = {
          "-m",
          "debugpy.adapter",
        },
      }

      -------------------------------------------------------
      --                    DAP CONFIGS                    --
      -------------------------------------------------------

      dap.configurations.python = {
        {
          -- The first three options are required by nvim-dap
          type = "debugpy", -- the type here established the link to the adapter definition: `dap.adapters.debugpy`
          request = "launch",
          name = "Launch file",
          cwd = "${workspaceFolder}",

          program = "${file}", -- This configuration will launch the current file if used.
          pythonPath = function()
            -- debugpy supports launching an application with a different interpreter then the one used to launch debugpy itself.
            -- The code below looks for a `venv` or `.venv` folder in the current directly and uses the python within.
            -- You could adapt this - to for example use the `VIRTUAL_ENV` environment variable.
            local cwd = vim.fn.getcwd()
            if vim.fn.executable(cwd .. "/venv/bin/python") == 1 then
              return cwd .. "/venv/bin/python"
            elseif vim.fn.executable(cwd .. "/.venv/bin/python") == 1 then
              return cwd .. "/.venv/bin/python"
            else
              return "/usr/bin/python"
            end
          end,
        },
      }

      dap.configurations.cpp = {
        {
          name = "Launch file",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = function()
            -- First split it by spaces
            local raw = vim.fn.input "Args: "
            local home = os.getenv "HOME"
            local args_filtered = raw.gsub(raw, "~", home)
            local args = vim.split(args_filtered, " ")

            print "HERE:"
            vim.print(args)
            for i, arg in ipairs(args) do
              -- Replace ~ with $HOME
              print(arg)
            end
            vim.print(args)

            return args
          end,
        },
      }

      -- Reuse configurations for other languages
      dap.configurations.c = dap.configurations.cpp
      dap.configurations.rust = {
        {
          name = "Launch file",
          type = "codelldb",
          request = "launch",
          program = function()
            print "Building Project..."
            vim.cmd "!cargo build"
            print "Done!"

            -- local release_dir = vim.fn.finddir("target/release", vim.fn.getcwd() .. ";")
            local debug_dir = vim.fn.finddir("target/debug", vim.fn.getcwd() .. ";")

            -- If both are nil then run cargo build
            -- WARNING:
            -- if release_dir == "" and debug_dir == "" then
            --   print "Building Project..."
            --   vim.cmd "silent !cargo build"
            --   print "Built With Cargo"
            -- end

            -- Select binary by the (only) file that has no extension
            -- Get the directory path where your files are located
            --[[ release_dir or ]]
            local directory = debug_dir

            -- Get a list of files in the directory
            local files = vim.fn.readdir(directory)

            -- Iterate through the files
            for _, file in ipairs(files) do
              local filepath = directory .. "/" .. file

              -- Check if the file is executable
              local is_executable = vim.fn.executable(filepath) == 1

              if is_executable then
                print("Found Executable on: ", filepath)
                return filepath
                -- You can perform further actions on the executable here
              end
            end

            -- If none of the above don't work
            -- then ask the user to input the path to the executable
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,

          args = function()
            -- First split it by spaces
            local raw = vim.fn.input "Args: "
            local home = os.getenv "HOME"
            local args_filtered = raw.gsub(raw, "~", home)
            local args = vim.split(args_filtered, " ")

            print "HERE:"
            vim.print(args)
            for i, arg in ipairs(args) do
              -- Replace ~ with $HOME
              print(arg)
            end
            vim.print(args)

            return args
          end,
        },
      }

      -------------------------------------------------
      --                    SIGNS                    --
      -------------------------------------------------
      vim.fn.sign_define("DapBreakpoint", {
        text = " ",
        texthl = "DapBreakpoint",
        linehl = "DapBreakpointLine",
        numhl = "DapBreakpointNum",
      })

      vim.fn.sign_define("DapLogPoint", {
        text = " ",
        texthl = "DapLogPoint",
        linehl = "DapLogPointLine",
        numhl = "DapLogPointNum",
      })

      vim.fn.sign_define("DapStopped", {
        text = " ",
        texthl = "DapStopped",
        linehl = "DapStoppedLine",
        numhl = "DapStoppedNum",
      })

      vim.fn.sign_define("DapBreakpointCondition", {
        text = " ",
        texthl = "DapBreakpointCondition",
        linehl = "DapBreakpointConditionLine",
        numhl = "DapBreakpointConditionNum",
      })

      vim.fn.sign_define("DapBreakpointRejected", {
        text = " ",
        texthl = "DapBreakpointRejected",
        linehl = "DapBreakpointRejectedLine",
        numhl = "DapBreakpointRejectedNum",
      })
    end,

    keys = require("configs.nvim-dap").keys,
  },

  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function(_, opts)
      require("neogen").setup(opts)
    end,

    opts = {
      snippet_engine = "luasnip",
    },

    keys = {
      {
        "<leader>rd",
        "<cmd>lua require('neogen').generate()<CR>",
        mode = "n",
        desc = "Generate Base Documentation",
      },
    },
  },

  {
    -- NOTE requires we install ripgrep like so:
    -- cargo install ripgrep --features pcre2
    -- this should be done with mason
    "chrisgrieser/nvim-rip-substitute",
    cmd = "RipSubstitute",
    keys = {
      {
        "<leader>rr",
        function()
          require("rip-substitute").sub()
        end,
        mode = { "n", "x" },
        desc = " Regex replace",
      },
    },
  },
  -- { -- Regexplainer
  --   "tomiis4/Hypersonic.nvim",
  --   config = function(_, opts)
  --     require("hypersonic").setup(opts)
  --   end,
  --
  --   opts = {},
  --
  --   keys = {
  --     { "<leader>re", "<cmd>Hypersonic<cr>", mode = { "n", "v" }, desc = "RegExplain" },
  --   },
  -- },
  --
  {
    "jay-babu/mason-nvim-dap.nvim",

    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },

    cmd = { "DapInstall", "DapUninstall" },
    opts = {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        "codelldb", -- Rust, C/C++
        "python",
        -- Update this to ensure that you have the debuggers for the langs you want
      },
    },
  },

  -- TODO if we're going to use this it should play nice with conform
  -- {
  --   "Wansmer/treesj",
  --
  --   dependencies = {
  --     "nvim-treesitter/nvim-treesitter",
  --   },
  --
  --   keys = {
  --     {
  --       "<leader>jj",
  --       function()
  --         require("treesj").toggle()
  --       end,
  --       mode = "n",
  --       desc = "Toggle Treesitter Unjoin",
  --     },
  --
  --     {
  --       "<leader>js",
  --       function()
  --         require("treesj").split()
  --       end,
  --       mode = "n",
  --       desc = "Treesitter Split",
  --     },
  --
  --     {
  --       "<leader>jl",
  --       function()
  --         require("treesj").join()
  --       end,
  --       mode = "n",
  --       desc = "Treesitter Join Line",
  --     },
  --   },
  --
  --   config = function(_, opts)
  --     require("treesj").setup(opts)
  --   end,
  --
  --   opts = {
  --     use_default_keymaps = false,
  --     max_join_length = 220, -- 120 is not sufficient
  --   },
  -- },

  -- NOTE lets get regular objects working well then take a look at this
  {
    --          DEFINITELY TAKE A LOOK
    --             IT's AWESOME!!!
    -- -> https://github.com/CKolkey/ts-node-action <-
    --
    -- !!! INTEGRATED WITH BUILT-IN CODE ACTIONS !!!
    "ckolkey/ts-node-action",
    dependencies = { "nvim-treesitter" },

    keys = {
      {
        "<leader>ca",
        function()
          require("ts-node-action").node_action()
        end,
        mode = "n",
        desc = "Treesitter Code Action", -- Actually Node but...
      },
    },

    config = function(_, opts)
      -- Repo says it is not required if not using custom actions
      require("ts-node-action").setup(opts)
    end,
    opts = require("configs.ts").opts,
  },

  -- NOTE provideds highlighting for args when lsp isn't present, review if we really need this
  -- { -- Highlight Args in functions etc. -- TODO: Add highlight-mode for this
  --   -- I think this is a bloat for now
  --   "m-demare/hlargs.nvim",
  --   opts = {},
  --   config = function(_, opts)
  --     require("hlargs").setup(opts) -- Automatically enables the plugin
  --     -- require("hlargs").disable() -- So disable it
  --   end,
  --
  --   keys = {
  --     {
  --       "<leader>mh",
  --       function()
  --         require("hlargs").toggle()
  --       end,
  --       mode = "n",
  --       desc = "Toggle Highlight Args",
  --     },
  --   },
  -- },

  { -- https://github.com/t-troebst/perfanno.nvim
    "t-troebst/perfanno.nvim",

    dependencies = {
      "nvim-telescope/telescope.nvim",
    },

    config = function(_, opts)
      require("perfanno").setup(opts)

      require("perfanno").setup {
        -- Creates a 10-step RGB color gradient between bgcolor and "#CC3300"
        line_highlights = require("perfanno.util").make_bg_highlights(
          vim.fn.synIDattr(vim.fn.hlID "Normal", "bg", "gui"),
          "#CC3300",
          10
        ),
        vt_highlight = require("perfanno.util").make_fg_highlight "#CC3300",
      }
    end,

    keys = require("configs.perfanno").keys,
    opts = require("configs.perfanno").opts,
  },

  { -- Folding. The fancy way
    "kevinhwang91/nvim-ufo",

    -- event = "VeryLazy",
    keys = require("configs.ufo").keys,
    dependencies = require("configs.ufo").dependencies,
    opts = require("configs.ufo").opts,

    config = function(_, opts)
      require("ufo").setup(opts)

      -- Better UI elements
      -- vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
      -- vim.o.foldcolumn = "3" -- "1" is better
    end,
  },

  { -- Rust Cargo.toml integration
    -- https://github.com/Saecki/crates.nvim#functions
    "Saecki/crates.nvim",

    keys = require("configs.rust").keys,

    tag = "v0.3.0", -- Adventurous but Featureful
    event = "BufEnter Cargo.toml",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = require("configs.rust").opts,

    config = function(_, opts)
      require("crates").setup(opts)
    end,
  },

  { -- Better quickfix window including telescope integration, code view etc.
    -- TODO: improve this
    "kevinhwang91/nvim-bqf",
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
      },

      { -- OPTIONAL for fuzzy searching TODO: Replace MAYBE
        "junegunn/fzf",
        build = function()
          vim.fn["fzf#install"]()
        end,
      },

      {
        "yorickpeterse/nvim-pqf",
      },
    },

    keys = require("configs.nvim-bqf").keys,
    opts = require("configs.nvim-bqf").opts,

    config = function(_, opts) -- TODO: add hlgroups
      require("bqf").setup(opts)
      -- Better UI in quickfix window:
      -- https://github.com/kevinhwang91/nvim-bqf/tree/c920a55c6153766bd909e474b7feffa9739f07e8#format-new-quickfix
      -- https://github.com/kevinhwang91/nvim-bqf/tree/c920a55c6153766bd909e474b7feffa9739f07e8#rebuild-syntax-for-quickfix
    end,
  },

  { -- Jump Jump Jump
    "folke/flash.nvim",
    -- event = "VeryLazy",
    ---@type Flash.Config
    opts = require("configs.flash").opts,
    keys = require("configs.flash").keys,
  },

  {
    "jubnzv/mdeval.nvim",

    cmd = "MdEval",
    keys = require("configs.mdeval").keys,
  },

  -- { -- TODO: migrate to file
  --   "krady21/compiler-explorer.nvim",
  --
  --   config = function(_, opts)
  --     require("compiler-explorer").setup(opts)
  --   end,
  --
  --   opts = {
  --     url = "https://godbolt.org",
  --     infer_lang = true, -- Try to infer possible language based on file extension.
  --     line_match = {
  --       -- FIXME: defaults are false and they don't work
  --       -- highlight = true, -- highlight the matching line(s) in the other buffer.
  --       -- jump = true, -- move the cursor in the other buffer to the first matching line.
  --     },
  --     open_qflist = true, --  Open qflist after compilation if there are diagnostics.
  --     split = "split", -- How to split the window after the second compile (split/vsplit).
  --     compiler_flags = "", -- Default flags passed to the compiler.
  --     job_timeout_ms = 25000, -- Timeout for libuv job in milliseconds.
  --     languages = { -- Language specific default compiler/flags
  --       --c = {
  --       --  compiler = "g121",
  --       --  compiler_flags = "-O2 -Wall",
  --       --},
  --     },
  --   },
  --
  --   -- cmd = { -- TODO
  --   --   ":CECompile",
  --   --   ":CECompileLive",
  --   --   ":CEFormat",
  --   --   ":CEAddLibrary",
  --   --   ":CELoadExample",
  --   --   ":CEOpenWebsite",
  --   --   ":CEDeleteCache",
  --   --   ":CEShowTooltip",
  --   --
  --   --   ":CEGotoLabel",
  --   -- },
  --   keys = { --- IDK whether they work under v mode
  --     -- stylua: ignore start
  --     { "<leader>nc", ":CECompile<CR>",     mode = "n", desc = "Compile"      },
  --     { "<leader>nl", ":CECompileLive<CR>", mode = "n", desc = "Compile Live" },
  --     { "<leader>nf", ":CEFormat<CR>",      mode = "n", desc = "Format"       },
  --     { "<leader>na", ":CEAddLibrary<CR>",  mode = "n", desc = "Add Library"  },
  --     { "<leader>ne", ":CELoadExample<CR>", mode = "n", desc = "Load Example" },
  --     { "<leader>nw", ":CEOpenWebsite<CR>", mode = "n", desc = "Open Website" },
  --     { "<leader>nd", ":CEDeleteCache<CR>", mode = "n", desc = "Delete Cache" },
  --     { "<leader>ns", ":CEShowTooltip<CR>", mode = "n", desc = "Show Tooltip" },
  --     { "<leader>ng", ":CEGotoLabel<CR>",   mode = "n", desc = "Goto Label"   },
  --     -- stylua: ignore end
  --   },
  -- },

  -- TODO bring this up
  -- { -- TODO add hlgroups according to repo
  --   "ThePrimeagen/harpoon",
  --
  --   config = function(_, opts)
  --     require("harpoon").setup(opts)
  --     require("telescope").load_extension "harpoon"
  --   end,
  --
  --   opts = {
  --     global_settings = {
  --       -- sets the marks upon calling `toggle` on the ui, instead of require `:w`.
  --       save_on_toggle = false,
  --
  --       -- saves the harpoon file upon every change. disabling is unrecommended.
  --       save_on_change = true,
  --
  --       -- sets harpoon to run the command immediately as it's passed to the terminal when calling `sendCommand`.
  --       enter_on_sendcmd = false,
  --
  --       -- closes any tmux windows harpoon that harpoon creates when you close Neovim.
  --       tmux_autoclose_windows = false,
  --
  --       -- filetypes that you want to prevent from adding to the harpoon list menu.
  --       excluded_filetypes = { "harpoon" },
  --
  --       -- set marks specific to each git branch inside git repository
  --       mark_branch = false,
  --
  --       -- enable tabline with harpoon marks
  --       tabline = false,
  --       tabline_prefix = "   ",
  --       tabline_suffix = "   ",
  --     },
  --   },
  --
  --   keys = {
  --     {
  --       "<leader>hm",
  --       "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>",
  --       mode = "n",
  --       desc = "Toggle Harpoon Menu",
  --     },
  --
  --     {
  --       "<leader>ha",
  --       "<cmd>lua require('harpoon.mark').add_file()<cr>",
  --       mode = "n",
  --       desc = "Add File",
  --     },
  --
  --     {
  --       "<leader>hn",
  --       "<cmd>lua require('harpoon.ui').nav_next()<cr>",
  --       mode = "n",
  --       desc = "Jump to next file",
  --     },
  --
  --     {
  --       "<leader>hp",
  --       "<cmd>lua require('harpoon.ui').nav_prev()<cr>",
  --       mode = "n",
  --       desc = "Jump to previous file",
  --     },
  --
  --     { -- FIXME: doesn't work (after loading with :Telescope harpoon)
  --       "<leader>hs",
  --       "<cmd> Telescope harpoon marks<cr>", -- TODO: Lazy load them on this specific keystroke
  --       mode = "n",
  --       desc = "Telescope Harpoon",
  --     },
  --   },
  -- },

  {
    "AckslD/nvim-neoclip.lua",
    dependencies = {
      -- Restore from last session
      { "kkharji/sqlite.lua", module = "sqlite" }, -- packer style
      { "nvim-telescope/telescope.nvim" },
    },

    config = function(_, opts)
      require("neoclip").setup(opts)
      require("telescope").load_extension "neoclip"
    end,

    keys = {
      { "<leader>sy", "<cmd>Telescope neoclip<cr>", mode = "n", desc = "Telescope Yanks" },

      { -- NOTE: Macros are recorded after this plugin is loaded
        "<leader>sY",
        function()
          require("telescope").extensions.macroscope.default()
        end,
        mode = "n",
        desc = "Telescope Macros",
      },
    },
  },

  { -- Smooth scrolling
    "karb94/neoscroll.nvim",

    config = function(_, opts)
      require("neoscroll").setup(opts)
    end,

    keys = {
      {
        "<leader>ms",
        "",
        mode = "n",
        desc = "Enable Smooth Scrolling",
      },
    },

    opts = {
      -- All these keys will be mapped to their corresponding default scrolling animation
      mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
      hide_cursor = true, -- Hide cursor while scrolling
      stop_eof = true, -- Stop at <EOF> when scrolling downwards
      respect_scrolloff = false, -- Stop scrolling when the cursor reaches the scrolloff margin of the file
      cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
      easing_function = "sine", -- Default easing function == nil
      pre_hook = nil, -- Function to run before the scrolling animation starts
      post_hook = nil, -- Function to run after the scrolling animation ends
      performance_mode = false, -- Disable "Performance Mode" on all buffers.
    },

    -- You can create your own scrolling mappings using the following lua functions:
    --
    --     scroll(lines, move_cursor, time[, easing])
    --     zt(half_win_time[, easing])
    --     zz(half_win_time[, easing])
    --     zb(half_win_time[, easing])
  },

  {
    "michaelb/sniprun",
    lazy = false,
    build = "sh ./install.sh",
    keys = require("configs.sniprun").keys,
    opts = require("configs.sniprun").opts,
    -- config = function(_, opts)
    --   require("sniprun").setup(opts)
    -- end,
  },

  ------- GAMES -------
  -- {
  --   "jim-fx/sudoku.nvim",
  --   cmd = "Sudoku",
  --
  --   config = function(_, opts)
  --     require("sudoku").setup(opts)
  --     status.games = true
  --   end,
  --
  --   opts = require("configs.sudoku").opts,
  --   keys = require("configs.sudoku").keys,
  -- },
  --
  -- {
  --   "ThePrimeagen/vim-be-good",
  --   cmd = "VimBeGood",
  --
  --   config = function(_, opts)
  --     status.games = true
  --   end,
  --   keys = {
  --     { "<leader>vg", "<cmd> VimBeGood<CR>", mode = "n", desc = "Play VimBeGood" },
  --   },
  -- },
  --
  -- {
  --   "alec-gibson/nvim-tetris",
  --
  --   cmd = "Tetris",
  --
  --   config = function(_, opts)
  --     status.games = true
  --   end,
  --
  --   keys = {
  --     { "<leader>vt", "<cmd> Tetris<CR>", mode = "n", desc = "Play Tetris" },
  --   },
  -- },
  --
  -- { -- One of the nices things ever!
  --   "seandewar/killersheep.nvim",
  --
  --   config = function(_, opts)
  --     require("killersheep").setup(opts)
  --     status.games = true
  --   end,
  --
  --   opts = {
  --     gore = true, -- Enables/disables blood and gore.
  --     keymaps = {
  --       move_left = "h", -- Keymap to move cannon to the left.
  --       move_right = "l", -- Keymap to move cannon to the right.
  --       shoot = "<Space>", -- Keymap to shoot the cannon.
  --     },
  --   },
  --
  --   cmd = "KillKillKill",
  --
  --   keys = {
  --     { "<leader>vk", "<cmd> KillKillKill<CR>", mode = "n", desc = "Play Killer Sheep" },
  --   },
  -- },
  --
  -- { -- Nice actions using your buffers text
  --   "Eandrju/cellular-automaton.nvim",
  --
  --   cmd = "CellularAutomaton",
  --
  --   keys = {
  --     { "<leader>vr", "<cmd> CellularAutomaton make_it_rain<CR>", mode = "n", desc = "Rain" },
  --     { "<leader>vl", "<cmd> CellularAutomaton game_of_life<CR>", mode = "n", desc = "Game of Life" },
  --     { "<leader>vx", "<cmd> CellularAutomaton scramble<CR>", mode = "n", desc = "Scrable" },
  --   },
  -- },
  --
  -- {
  --   "seandewar/nvimesweeper",
  --
  --   cmd = "Nvimesweeper",
  --
  --   config = function(_, opts)
  --     status.games = true
  --   end,
  --
  --   keys = {
  --     { "<leader>vw", "<cmd> Nvimesweeper<CR>", mode = "n", desc = "Play MineSweeper" },
  --   },
  -- },
  --
  {
    "madskjeldgaard/cppman.nvim",

    dependencies = {
      {
        "MunifTanjim/nui.nvim",
      },
    },

    cmd = {
      "CPPMan",
    },

    keys = {
      {
        "<leader>fd",
        function()
          require("cppman").open_cppman_for(vim.fn.expand "<cword>")
        end,
        mode = "n",
        desc = "Open Cpp Manual",
      },

      {
        "<leader>fx",
        function()
          require("cppman").input()
        end,
        mode = "n",
        desc = "Search Cpp Manual",
      },
    },

    config = function()
      require("cppman").setup()
    end,
  },

  {
    "kylechui/nvim-surround",
    lazy = false,
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    config = function(_, opts)
      --use defaults
      require("nvim-surround").setup {}
    end,
  },

  {
    "sindrets/winshift.nvim",
    lazy = false,

    keys = {
      {
        "<M-w>",
        "<cmd> WinShift<CR>",
        mode = "n",
        desc = "Window Shift Mode",
      },
    },

    config = function(_, opts)
      require("winshift").setup(opts)
    end,

    opts = {
      highlight_moving_win = true, -- Highlight the window being moved
      -- focused_hl_group = "Visual", -- The highlight group used for the moving window

      moving_win_options = {
        -- These are local options applied to the moving window while it's
        -- being moved. They are unset when you leave Win-Move mode.
        wrap = false,
        cursorline = false,
        cursorcolumn = false,
        colorcolumn = "",
      },

      keymaps = {
        disable_defaults = false, -- Disable the default keymaps
        win_move_mode = {
          ["h"] = "left",
          ["j"] = "down",
          ["k"] = "up",
          ["l"] = "right",
          ["H"] = "far_left",
          ["J"] = "far_down",
          ["K"] = "far_up",
          ["L"] = "far_right",
          ["<left>"] = "left",
          ["<down>"] = "down",
          ["<up>"] = "up",
          ["<right>"] = "right",
          ["<S-left>"] = "far_left",
          ["<S-down>"] = "far_down",
          ["<S-up>"] = "far_up",
          ["<S-right>"] = "far_right",
        },
      },
      ---A function that should prompt the user to select a window.
      ---
      ---The window picker is used to select a window while swapping windows with
      ---`:WinShift swap`.
      ---@return integer? winid # Either the selected window ID, or `nil` to
      ---   indicate that the user cancelled / gave an invalid selection.
      window_picker = function()
        return require("winshift.lib").pick_window {
          -- A string of chars used as identifiers by the window picker.
          picker_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
          filter_rules = {
            -- This table allows you to indicate to the window picker that a window
            -- should be ignored if its buffer matches any of the following criteria.
            cur_win = true, -- Filter out the current window
            floats = true, -- Filter out floating windows
            filetype = {}, -- List of ignored file types
            buftype = {}, -- List of ignored buftypes
            bufname = {}, -- List of vim regex patterns matching ignored buffer names
          },
          ---A function used to filter the list of selectable windows.
          ---@param winids integer[] # The list of selectable window IDs.
          ---@return integer[] filtered # The filtered list of window IDs.
          filter_func = nil,
        }
      end,
    },
  },

  -- {
  --   "nvim-neorg/neorg",
  --
  --   build = ":Neorg sync-parsers",
  --   dependencies = { "nvim-lua/plenary.nvim" },
  --
  --   cmd = "Neorg",
  --   event = "BufEnter *.norg",
  --
  --   keys = {
  --     {
  --       "<leader>zc",
  --       "<cmd> Neorg keybind all core.looking-glass.magnify-code-block<CR>",
  --       mode = "n",
  --       desc = "Neorg Code Buffer",
  --     },
  --     {
  --       "<leader>zm",
  --       "<cmd> Neorg toggle-concealer<CR>",
  --       mode = "n",
  --       desc = "Toggle Markdown",
  --     },
  --     {
  --       "<leader>zn",
  --       "<cmd> Neorg keybind all core.integrationg.treesitter.next.heading<CR>",
  --       mode = "n",
  --       desc = "Next Heading",
  --     },
  --     {
  --       "<leader>zp",
  --       "<cmd> Neorg keybind all core.integrationg.treesitter.previous.heading<CR>",
  --       mode = "n",
  --       desc = "Previous Heading",
  --     },
  --     {
  --       "<leader>zl",
  --       "<cmd> Neorg keybind all core.integrationg.treesitter.next.link<CR>",
  --       mode = "n",
  --       desc = "Next Link",
  --     },
  --     {
  --       "<leader>zn",
  --       "<cmd> Neorg keybind all core.integrationg.treesitter.previous.link<CR>",
  --       mode = "n",
  --       desc = "Previous Link",
  --     },
  --
  --     -- {
  --     --   "<leader>z",
  --     --   "<cmd> Neorg <CR>",
  --     --   mode = "n",
  --     --   desc = "Neorg ",
  --     -- },
  --   },
  --
  --   config = function(_, opts)
  --     require("neorg").setup(opts)
  --   end,
  --
  --   opts = {
  --     load = {
  --       ["core.defaults"] = {}, -- Loads default behaviour
  --       ["core.integrations.nvim-cmp"] = {},
  --
  --       -- ["core.integrations.treesitter "] = {}, -- FIXME
  --
  --       ["core.completion"] = {
  --         config = {
  --           engine = "nvim-cmp",
  --         },
  --       },
  --       ["core.ui.calendar"] = {},
  --       ["core.presenter"] = {
  --         config = {
  --           zen_mode = "zen-mode",
  --         },
  --       },
  --       ["core.summary"] = {},
  --       ["core.export.markdown"] = {},
  --       ["core.export"] = {},
  --       ["core.qol.toc"] = {
  --         config = {
  --           close_after_use = true,
  --         },
  --       },
  --       -- [""] = {},
  --       -- [""] = {},
  --       -- [""] = {},
  --       -- [""] = {},
  --       ["core.concealer"] = {}, -- Adds pretty icons to your documents
  --       ["core.dirman"] = { -- Manages Neorg workspaces
  --         config = {
  --           workspaces = {
  --             -- NOTE: for multiple workspaces check out the README
  --             notes = "~/Notes",
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },

  {
    "axieax/urlview.nvim",
    cmd = "UrlView",

    config = function(_, opts)
      require("urlview").setup(opts)
    end,

    opts = {
      -- custom configuration options --
    },

    keys = {
      { "<leader>fuu", "<Cmd>UrlView<CR>", mode = "n", desc = "View buffer URLs" },
      { "<leader>ful", "<Cmd>UrlView lazy<CR>", mode = "n", desc = "View Lazy URLs" },
      { "<leader>fup", "<Cmd>UrlView packer<CR>", mode = "n", desc = "View Packer plugin URLs" },
      { "<leader>fuv", "<Cmd>UrlView vimplug<CR>", mode = "n", desc = "View Packer plugin URLs" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = false,
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
    dependencies = "nvim-treesitter/nvim-treesitter",
  },

  {
    "mbbill/undotree",
    keys = {
      { "<leader>fg", "<cmd> UndotreeToggle<CR>", mode = "n", desc = "View Undo Tree" },
    },
  },

  -- {
  --   "XXiaoA/ns-textobject.nvim",
  --
  --   config = function(_, opts)
  --     require("ns-textobject").setup(opts)
  --   end,
  --
  --   opts = {
  --     -- auto_mapping = {
  --     --   -- automatically mapping for nvim-surround's aliases
  --     --   aliases = true,
  --     --   -- for nvim-surround's surrounds
  --     --   surrounds = true,
  --     -- },
  --     -- disable_builtin_mapping = {
  --     --   enabled = true,
  --     --   -- list of char which shouldn't mapping by auto_mapping
  --     --   chars = { "b", "B", "t", "`", "'", '"', "{", "}", "(", ")", "[", "]", "<", ">" },
  --     -- },
  --   },
  -- },

  {
    "lalitmee/browse.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function(_, opts)
      require("browse").setup(opts)
    end,

    keys = {
      {
        "<leader>op",
        function()
          require("browse").browse()
        end,
        mode = "n",
        desc = "Browse Anything",
      },
    },
    opts = {
      -- search provider you want to use
      provider = "google", -- duckduckgo, bing

      -- either pass it here or just pass the table to the functions
      -- see below for more
      bookmarks = {
        ["github"] = {
          ["name"] = "search github from neovim",
          ["code_search"] = "https://github.com/search?q=%s&type=code",
          ["repo_search"] = "https://github.com/search?q=%s&type=repositories",
          ["issues_search"] = "https://github.com/search?q=%s&type=issues",
          ["pulls_search"] = "https://github.com/search?q=%s&type=pullrequests",
        },
      },
    },
  },

  {
    "AckslD/nvim-FeMaco.lua",

    keys = {
      {
        "<leader>cme",
        "<cmd> FeMaco<CR>",
        mode = "n",
        desc = "Edit Code Block",
      },
    },

    config = function(_, opts)
      require("femaco").setup(opts)
    end,

    opts = {
      -- -- should prepare a new buffer and return the winid
      -- -- by default opens a floating window
      -- -- provide a different callback to change this behaviour
      -- -- @param opts: the return value from float_opts
      -- prepare_buffer = function(opts)
      --   local buf = vim.api.nvim_create_buf(false, false)
      --   return vim.api.nvim_open_win(buf, true, opts)
      -- end,
      -- -- should return options passed to nvim_open_win
      -- -- @param code_block: data about the code-block with the keys
      -- --   * range
      -- --   * lines
      -- --   * lang
      -- float_opts = function(code_block)
      --   return {
      --     relative = "cursor",
      --     width = clip_val(5, 120, vim.api.nvim_win_get_width(0) - 10), -- TODO how to offset sign column etc?
      --     height = clip_val(5, #code_block.lines, vim.api.nvim_win_get_height(0) - 6),
      --     anchor = "NW",
      --     row = 0,
      --     col = 0,
      --     style = "minimal",
      --     border = "rounded",
      --     zindex = 1,
      --   }
      -- end,
      -- -- return filetype to use for a given lang
      -- -- lang can be nil
      -- ft_from_lang = function(lang)
      --   return lang
      -- end,
      -- -- what to do after opening the float
      -- post_open_float = function(winnr)
      --   vim.wo.signcolumn = "no"
      -- end,
      -- -- create the path to a temporary file
      -- create_tmp_filepath = function(filetype)
      --   return os.tmpname()
      -- end,
      -- -- if a newline should always be used, useful for multiline injections
      -- -- which separators needs to be on separate lines such as markdown, neorg etc
      -- -- @param base_filetype: The filetype which FeMaco is called from, not the
      -- -- filetype of the injected language (this is the current buffer so you can
      -- -- get it from vim.bo.filetyp).
      -- ensure_newline = function(base_filetype)
      --   return false
      -- end,
    },
  },

  {
    "nfrid/markdown-togglecheck",

    keys = {
      {
        "<leader>cml",
        function()
          require("markdown-togglecheck").toggle()
        end,
        mode = "n",
        desc = "Toggle Markdown Checkbox",
      },
    },

    dependencies = {
      "nfrid/treesitter-utils",
    },

    ft = {
      "markdown",
    },
  },

  {
    "potamides/pantran.nvim",

    keys = {
      { "<leader><leader>t", "<cmd> Pantran<CR>", mode = { "n", "v" }, desc = "Translate" },
      -- { "<leader>t", "<cmd> Pantran<CR>", mode = "v", desc = "Translate" },
    },

    config = function(_, opts)
      local default_source = "auto"
      local default_target = "tr" -- MUST: Refactor as your default target language.

      require("pantran").setup {
        -- Default engine to use for translation. To list valid engine names run
        -- `:lua =vim.tbl_keys(require("pantran.engines"))`.
        default_engine = "argos",
        -- Configuration for individual engines goes here.
        engines = {
          argos = {
            -- Default languages can be defined on a per engine basis. In this case
            -- `:lua require("pantran.async").run(function()
            -- vim.pretty_print(require("pantran.engines").yandex:languages()) end)`
            -- can be used to list available language identifiers.
            default_source = default_source,
            default_target = default_target, -- MUST: Refactor as your default target language.
          },
          apertium = {
            -- Default languages can be defined on a per engine basis. In this case
            -- `:lua require("pantran.async").run(function()
            -- vim.pretty_print(require("pantran.engines").yandex:languages()) end)`
            -- can be used to list available language identifiers.
            default_source = default_source,
            default_target = default_target, -- MUST: Refactor as your default target language.
          },
          yandex = {
            -- Default languages can be defined on a per engine basis. In this case
            -- `:lua require("pantran.async").run(function()
            -- vim.pretty_print(require("pantran.engines").yandex:languages()) end)`
            -- can be used to list available language identifiers.
            default_source = default_source,
            default_target = default_target, -- MUST: Refactor as your default target language.
          },
          google = {
            -- Default languages can be defined on a per engine basis. In this case
            -- `:lua require("pantran.async").run(function() vim.pretty_print(require("pantran.engines").yandex:languages()) end)`
            -- can be used to list available language identifiers.
            default_source = default_source,
            default_target = default_target, -- MUST: Refactor as your default target language.
          },
        },
        -- controls = {
        --   mappings = {
        --     edit = {
        --       n = {
        --         -- Use this table to add additional mappings for the normal mode in
        --         -- the translation window. Either strings or function references are
        --         -- supported.
        --         ["j"] = "gj",
        --         ["k"] = "gk",
        --       },
        --       i = {
        --         -- Similar table but for insert mode. Using 'false' disables
        --         -- existing keybindings.
        --         ["<C-y>"] = false,
        --         ["<C-a>"] = require("pantran.ui.actions").yank_close_translation,
        --       },
        --     },
        --     -- Keybindings here are used in the selection window.
        --     select = {
        --       n = {
        --         -- ...
        --       },
        --     },
        --   },
        -- },
      }
    end,
  },

  { -- markdown-mode
    "jakewvincent/mkdnflow.nvim",

    keys = {
      {
        "<leader>cmm",
        "<cmd> Mkdnflow<CR>",
        mode = "n",
        desc = "Markdown Mode",
      },
    },

    ft = {
      "markdown",
    },

    config = function(_, opts)
      require("mkdnflow").setup(opts)
    end,

    opts = {

      modules = {
        bib = true,
        buffers = true,
        conceal = true,
        cursor = true,
        folds = true,
        links = true,
        lists = true,
        maps = true,
        paths = true,
        tables = true,
        yaml = false,
      },
      filetypes = { md = true, rmd = true, markdown = true },
      create_dirs = true,
      perspective = {
        priority = "first",
        fallback = "current",
        root_tell = false,
        nvim_wd_heel = false,
        update = false,
      },
      wrap = false,
      bib = {
        default_path = nil,
        find_in_root = true,
      },
      silent = false,
      links = {
        style = "markdown",
        name_is_source = false,
        conceal = false,
        context = 0,
        implicit_extension = nil,
        transform_implicit = false,
        transform_explicit = function(text)
          text = text:gsub(" ", "-")
          text = text:lower()
          text = os.date "%Y-%m-%d_" .. text
          return text
        end,
      },
      new_file_template = {
        use_template = false,
        placeholders = {
          before = {
            title = "link_title",
            date = "os_date",
          },
          after = {},
        },
        template = "# {{ title }}",
      },
      to_do = {
        symbols = { " ", "-", "X" },
        update_parents = true,
        not_started = " ",
        in_progress = "-",
        complete = "X",
      },
      tables = {
        trim_whitespace = true,
        format_on_move = true,
        auto_extend_rows = false,
        auto_extend_cols = false,
      },
      yaml = {
        bib = { override = false },
      },
      mappings = {
        MkdnEnter = { { "n", "v" }, "<CR>" },
        MkdnTab = false,
        MkdnSTab = false,
        MkdnNextLink = { "n", "<Tab>" },
        MkdnPrevLink = { "n", "<S-Tab>" },
        MkdnNextHeading = { "n", "]]" },
        MkdnPrevHeading = { "n", "[[" },
        MkdnGoBack = { "n", "<BS>" },
        MkdnGoForward = { "n", "<Del>" },
        MkdnCreateLink = false, -- see MkdnEnter
        MkdnCreateLinkFromClipboard = { { "n", "v" }, "<leader>p" }, -- see MkdnEnter
        MkdnFollowLink = false, -- see MkdnEnter
        MkdnDestroyLink = { "n", "<M-CR>" },
        MkdnTagSpan = { "v", "<M-CR>" },
        MkdnMoveSource = { "n", "<F2>" },
        MkdnYankAnchorLink = { "n", "yaa" },
        MkdnYankFileAnchorLink = { "n", "yfa" },
        MkdnIncreaseHeading = { "n", "+" },
        MkdnDecreaseHeading = { "n", "-" },
        MkdnToggleToDo = { { "n", "v" }, "<C-Space>" },
        MkdnNewListItem = { "i", "<CR>" },
        MkdnNewListItemBelowInsert = { "n", "o" },
        MkdnNewListItemAboveInsert = { "n", "O" },
        MkdnExtendList = false,
        MkdnUpdateNumbering = { "n", "<leader>nn" },
        MkdnTableNextCell = { "i", "<Tab>" },
        MkdnTablePrevCell = { "i", "<S-Tab>" },
        MkdnTableNextRow = false,
        MkdnTablePrevRow = { "i", "<M-CR>" },
        MkdnTableNewRowBelow = { "n", "<leader>ir" },
        MkdnTableNewRowAbove = { "n", "<leader>iR" },
        MkdnTableNewColAfter = { "n", "<leader>ic" },
        MkdnTableNewColBefore = { "n", "<leader>iC" },
        MkdnFoldSection = { "n", "<leader>f" },
        MkdnUnfoldSection = { "n", "<leader>F" },
      },
    },
  },

  {
    -- NOTE: cmp sources are listed in configs/cmp.lua
    "nvim-orgmode/orgmode",

    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter",
        lazy = true, -- I doubt this is necessary
        opts = {
          highlight = {
            enable = true,
            additional_vim_regex_highlighting = {
              "org",
            },
          },
          -- NOTE: ensure_installed is in nvim-treesitter's config
        },
      },
      {
        "akinsho/org-bullets.nvim",
        config = function(_, opts)
          require("org-bullets").setup(opts)
        end,

        -- opts = {
        --   concealcursor = false, -- If false then when the cursor is on a line underlying characters are visible
        --   symbols = {
        --     -- list symbol
        --     list = "•",
        --     -- headlines can be a list
        --     headlines = { "◉", "○", "✸", "✿" },
        --     -- or a function that receives the defaults and returns a list
        --     headlines = function(default_list)
        --       table.insert(default_list, "♥")
        --       return default_list
        --     end,
        --     checkboxes = {
        --       half = { "", "OrgTSCheckboxHalfChecked" },
        --       done = { "✓", "OrgDone" },
        --       todo = { "˟", "OrgTODO" },
        --     },
        --   },
        -- },
      },

      {
        "lukas-reineke/headlines.nvim",
        dependencies = "nvim-treesitter",
        config = true,
      },

      {
        "dhruvasagar/vim-table-mode",
      },

      {
        "NFrid/due.nvim",
      },
      {
        "danilshvalov/org-modern.nvim",
      },
    },

    event = "BufEnter *.org",

    config = function()
      -- Custom Menu
      local Menu = require "org-modern.menu"
      -- Setup orgmode
      require("orgmode").setup {
        org_startup_folded = "inherit",
        org_agenda_files = "~/org/**/*.org",
        org_default_notes_file = "~/org/daily/routine.org",
        ui = {
          menu = {
            handler = function(data)
              Menu:new({
                window = {
                  margin = { 1, 0, 1, 0 },
                  padding = { 0, 1, 0, 1 },
                  title_pos = "center",
                  border = "single",
                  zindex = 1000,
                },
                icons = {
                  separator = "➜",
                },
              }):open(data)
            end,
          },
        },
      }

      -- Conceal links, bolds etc.
      vim.opt.conceallevel = 2
      vim.opt.concealcursor = "nc"

      vim.cmd [[TableModeEnable]] -- Align tables with ||
      require("due_nvim").draw(0) -- Draw Due Dates
    end,
  },

  {
    "dhruvasagar/vim-table-mode",

    keys = {
      { "<leader>mkk", "<cmd> TableModeToggle<CR>", mode = "n", desc = "Toggle Table Mode" },
      { "<leader>mka", "<cmd> TableAddFormula<CR>", mode = "n", desc = "Add Formula" },
      { "<leader>make", "<cmd> TableEvalFormulaLine<CR>", mode = "n", desc = "Eval Formula" },
      { "<leader>mkr", "<cmd> TableModeRealign<CR>", mode = "n", desc = "Realign Table" },
      { "<leader>mkl", "<cmd> Tableize<CR>", mode = "n", desc = "Tableize" },
      { "<leader>mks", "<cmd> TableSort<CR>", mode = "n", desc = "Sort Table" },
    },

    config = function()
      -- WARNING: Mapping these keys would probably cause something (NOT) funny
      vim.keymap.del("n", "<leader>tm")
      vim.keymap.del("n", "<leader>tt")
    end,
  },

  {
    "NFrid/due.nvim",

    keys = {
      -- require("due_nvim").draw(0)   -- Draws it for a buffer (0 to current)
      -- require("due_nvim").clean(0)  -- Cleans the array from it
      -- require("due_nvim").redraw(0) -- Cleans, then draws
      -- require("due_nvim").async_update(0) -- Runs the async update function (needs update_rate > 0)
      {
        "<leader>mc",
        function()
          require("due_nvim").draw(0)
        end,
        mode = "n",
        desc = "Due Mode",
      },
      -- {
      --   "<leader>md",
      --   function () require("due_nvim").clean(0) end,
      --   mode = "n",
      --   desc = "Due Clean",
      -- },
      -- {
      --   "<leader>mr",
      --   function () require("due_nvim").redraw(0) end,
      --   mode = "n",
      --   desc = "Due Redraw",
      -- },
      -- {
      --   "<leader>mu",
      --   function () require("due_nvim").async_update(0) end,
      --   mode = "n",
      --   desc = "Due Async Update",
      -- },
    },

    config = function(_, opts)
      local date_pattern = [[(%d%d)%-(%d%d)]]
      local datetime_pattern = date_pattern .. " (%d+):(%d%d)" -- m, d, h, min
      local fulldatetime_pattern = "(%d%d%d%d)%-" .. datetime_pattern -- y, m, d, h, min
      vim.o.foldlevel = 99

      require("due_nvim").setup {
        prescript = "due: ", -- prescript to due data
        prescript_hi = "Comment", -- highlight group of it
        due_hi = "String", -- highlight group of the data itself
        ft = "*.md", -- filename template to apply aucmds :)
        today = "TODAY", -- text for today's due
        today_hi = "Character", -- highlight group of today's due
        overdue = "OVERDUE", -- text for overdued
        overdue_hi = "Error", -- highlight group of overdued
        date_hi = "Conceal", -- highlight group of date string

        -- NOTE: needed for more complex patterns (e.g orgmode dates)
        pattern_start = "", -- start for a date string pattern
        pattern_end = "", -- end for a date string pattern
        -- pattern_start = "<", -- start for a date string pattern
        -- pattern_end = ">", -- end for a date string pattern

        -- lua patterns: in brackets are 'groups of data', their order is described
        -- accordingly. More about lua patterns: https://www.lua.org/pil/20.2.html
        date_pattern = date_pattern, -- m, d
        datetime_pattern = datetime_pattern, -- m, d, h, min
        datetime12_pattern = datetime_pattern .. " (%a%a)", -- m, d, h, min, am/pm
        fulldate_pattern = "(%d%d%d%d)%-" .. date_pattern, -- y, m, d
        fulldatetime_pattern = fulldatetime_pattern, -- y, m, d, h, min
        fulldatetime12_pattern = fulldatetime_pattern .. " (%a%a)", -- y, m, d, h, min, am/pm
        -- idk how to allow to define the order by config yet,
        -- but you can help me figure it out...

        -- regex_hi = "\\d*-*\\d\\+-\\d\\+\\( \\d*:\\d*\\( \\a\\a\\)\\?\\)\\?",
        regex_hi = [[\d*-*\d\+-\d\+\( \d*:\d*\( \a\a\)\?\)\?]],

        -- vim regex for highlighting, notice double
        -- backslashes cuz lua strings escaping

        -- update_rate = use_clock_time and (use_seconds and 1000 or 60000) or 0,
        -- selects the rate due clocks will update in
        -- milliseconds. 0 or less disables it

        use_clock_time = false, -- display also hours and minutes
        use_clock_today = false, -- do it instead of TODAY
        use_seconds = false, -- if use_clock_time == true, display seconds
        -- as well
        default_due_time = "midnight", -- if use_clock_time == true, calculate time
        -- until option on specified date. Accepts
        -- "midnight", for 23:59:59, or noon, for
        -- 12:00:00
      }
    end,
  },

  { -- Same with nvim-biscuits
    -- TODO: migrate to this
    "andersevenrud/nvim_context_vt",
    dependencies = "nvim-treesitter",
    config = function(_, opts)
      require("nvim_context_vt").setup(opts)
      vim.cmd [[NvimContextVtToggle]]
    end,

    keys = {
      {
        "<leader>me",
        "<cmd> NvimContextVtToggle<CR>",
        mode = "n",
        desc = "Toggle Context Visualizer",
      },
    },

    -- opts = function()
    --   return {
    --     -- Enable by default. You can disable and use :NvimContextVtToggle to manually enable.
    --     -- Default: true
    --     enabled = true,
    --
    --     -- Override default virtual text prefix
    --     -- Default: '-->'
    --     prefix = "",
    --
    --     -- Override the internal highlight group name
    --     -- Default: 'ContextVt'
    --     highlight = "CustomContextVt",
    --
    --     -- Disable virtual text for given filetypes
    --     -- Default: { 'markdown' }
    --     disable_ft = { "markdown" },
    --
    --     -- Disable display of virtual text below blocks for indentation based languages like Python
    --     -- Default: false
    --     disable_virtual_lines = false,
    --
    --     -- Same as above but only for specific filetypes
    --     -- Default: {}
    --     disable_virtual_lines_ft = { "yaml" },
    --
    --     -- How many lines required after starting position to show virtual text
    --     -- Default: 1 (equals two lines total)
    --     min_rows = 1,
    --
    --     -- Same as above but only for specific filetypes
    --     -- Default: {}
    --     min_rows_ft = {},
    --
    --     -- Custom virtual text node parser callback
    --     -- Default: nil
    --     custom_parser = function(node, ft, opts)
    --       local utils = require "nvim_context_vt.utils"
    --
    --       -- If you return `nil`, no virtual text will be displayed.
    --       if node:type() == "function" then
    --         return nil
    --       end
    --
    --       -- This is the standard text
    --       return opts.prefix .. " " .. utils.get_node_text(node)[1]
    --     end,
    --
    --     -- Custom node validator callback
    --     -- Default: nil
    --     custom_validator = function(node, ft, opts)
    --       -- Internally a node is matched against min_rows and configured targets
    --       local default_validator = require("nvim_context_vt.utils").default_validator
    --       if default_validator(node, ft) then
    --         -- Custom behaviour after using the internal validator
    --         if node:type() == "function" then
    --           return false
    --         end
    --       end
    --
    --       return true
    --     end,
    --
    --     -- Custom node virtual text resolver callback
    --     -- Default: nil
    --     custom_resolver = function(nodes, ft, opts)
    --       -- By default the last node is used
    --       return nodes[#nodes]
    --     end,
    --   }
    -- end,
  },

  {
    "LudoPinelli/comment-box.nvim",
    config = function(_, opts)
      require("comment-box").setup(opts)
    end,

    keys = {
      {
        "<leader>bb",
        function()
          require("comment-box").ccbox()
        end,
        mode = { "n", "v" },
        desc = "Comment Box",
      },

      {
        "<leader>be",
        function()
          -- take an input:
          local input = vim.fn.input "Catalog: "
          require("comment-box").ccbox(input)
        end,
        mode = { "n", "v" },
        desc = "Left Comment Box",
      },

      {
        "<leader>bc",
        function()
          require("comment-box").lbox()
        end,
        mode = { "n", "v" },
        desc = "Left Comment Box",
      },

      {
        "<leader>bx",
        function()
          require("comment-box").catalog()
        end,
        mode = { "n", "v" },
        desc = "Comment Catalog",
      },
    },

    opts = {
      doc_width = 80, -- width of the document
      box_width = 60, -- width of the boxes
      borders = { -- symbols used to draw a box
        top = "─",
        bottom = "─",
        left = "│",
        right = "│",
        top_left = "╭",
        top_right = "╮",
        bottom_left = "╰",
        bottom_right = "╯",
      },
      line_width = 70, -- width of the lines
      line = { -- symbols used to draw a line
        line = "─",
        line_start = "─",
        line_end = "─",
      },
      outer_blank_lines = false, -- insert a blank line above and below the box
      inner_blank_lines = false, -- insert a blank line above and below the text
      line_blank_line_above = false, -- insert a blank line above the line
      line_blank_line_below = false, -- insert a blank line below the line
    },
  },

  --  [markdown markmap]
  --  https://github.com/Zeioth/markmap.nvim
  {
    "Zeioth/markmap.nvim",
    build = "yarn global add markmap-cli", -- WARNING: yarn bin need to be in $PATH

    keys = {
      -- {"<leader>mm", "<cmd> MarkmapOpen<CR>", mode = "n", desc = "Open Markmap"},
      -- {"<leader>mq", "<cmd> MarkmapWatchStop<CR>", mode = "n", desc = "Stop Markmap"},
      { "<leader>cmk", "<cmd> MarkmapWatch<CR>", mode = "n", desc = "Watch Markmap" },
      { "<leader>cms", "<cmd> MarkmapSave<CR>", mode = "n", desc = "Save Markmap" },
    },

    cmd = {
      "MarkmapOpen",
      "MarkmapSave",
      "MarkmapWatch",
      "MarkmapWatchStop",
    },

    opts = {
      html_output = "/tmp/markmap.html", -- (default) Setting a empty string "" here means: [Current buffer path].html
      hide_toolbar = false, -- (default)
      grace_period = 3600000, -- (default) Stops markmap watch after 60 minutes. Set it to 0 to disable the grace_period.
    },
    config = function(_, opts)
      require("markmap").setup(opts)
    end,
  },

  {
    "tommcdo/vim-exchange",

    keys = {
      { "cx", mode = "n" },
      { "X", mode = "v" },
    },
  },

  { -- Session Manager
    "folke/persistence.nvim",

    -- event = "BufReadPre", -- this will only start session saving when an actual file was opened

    -- restore the session for the current directory
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        mode = "n",
        desc = "Save Session",
      },
      -- restore the last session
      {
        "<leader>ql",
        function()
          require("persistence").load { last = true }
        end,
        mode = "n",
        desc = "Restore Session",
      },
      -- stop Persistence => session won't be saved function()on exit
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Stop Session Save",
        mode = "n",
      },
    },

    opts = {
      -- add any custom options here
    },
  },

  { -- Glyph Picker
    "2kabhishek/nerdy.nvim",
    lazy = false, -- TODO find someone to depend on this

    keys = {
      {
        "<leader>se",
        "<cmd> Nerdy<CR>",
        mode = "n",
        desc = "Glyph Picker",
      }, -- Gigantic Search Base
    },

    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Nerdy",
  },

  { -- Note this plugin is written as dependency of quickfix plugins
    -- Prettier quickfix window
    "yorickpeterse/nvim-pqf",

    dependencies = {
      "kevinhwang91/nvim-bqf",
    },

    config = function(_, opts)
      require("pqf").setup(opts)
    end,

    opts = {
      signs = {
        error = "E",
        warning = "W",
        info = "I",
        hint = "H",
      },

      -- By default, only the first line of a multi line message will be shown.
      -- When this is true, multiple lines will be shown for an entry, separated by a space
      show_multiple_lines = false,

      -- How long filenames in the quickfix are allowed to be. 0 means no limit.
      -- Filenames above this limit will be truncated from the beginning with [...]
      max_filename_length = 0,
    },
  },

  {
    "chentoast/marks.nvim",

    keys = {
      {
        "<leader>bm",
        "<cmd> MarksToggleSigns<CR>",
        mode = "n",
        desc = "Marks",
      },
    },

    config = function(_, opts)
      require("marks").setup(opts)
      -- This plugin enables by default
      -- So we toggle it to reanable it (because we only have a toggling function)
      vim.cmd [[MarksToggleSigns]]
    end,

    opts = {
      -- whether to map keybinds or not. default true
      default_mappings = true,
      -- which builtin marks to show. default {}
      builtin_marks = { ".", "<", ">", "^" },
      -- whether movements cycle back to the beginning/end of buffer. default true
      cyclic = true,
      -- whether the shada file is updated after modifying uppercase marks. default false
      force_write_shada = false,
      -- how often (in ms) to redraw signs/recompute mark positions.
      -- higher values will have better performance but may cause visual lag,
      -- while lower values may cause performance penalties. default 150.
      refresh_interval = 250,
      -- sign priorities for each type of mark - builtin marks, uppercase marks, lowercase
      -- marks, and bookmarks.
      -- can be either a table with all/none of the keys, or a single number, in which case
      -- the priority applies to all marks.
      -- default 10.
      sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
      -- disables mark tracking for specific filetypes. default {}
      excluded_filetypes = {},
      -- marks.nvim allows you to configure up to 10 bookmark groups, each with its own
      -- sign/virttext. Bookmarks can be used to group together positions and quickly move
      -- across multiple buffers. default sign is '!@#$%^&*()' (from 0 to 9), and
      -- default virt_text is "".
      bookmark_0 = {
        sign = "⚑",
        virt_text = "hello world",
        -- explicitly prompt for a virtual line annotation when setting a bookmark from this group.
        -- defaults to false.
        annotate = false,
      },
      mappings = {},
    },
  },

  {
    "mg979/vim-visual-multi",
    branch = "master",
    keys = {
      {
        "<C-n>",
        function()
          vim.cmd [[call vm#insert#insert()]]
        end,
        mode = "i",
        desc = "Insert Mode",
      },
      {
        "<C-n>",
        function()
          vim.cmd [[call vm#visual_multi#start()]]
        end,
        mode = "n",
        desc = "Normal Mode",
      },
    },
  },
}

return plugins
