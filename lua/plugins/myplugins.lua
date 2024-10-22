-- TODO: Remove telescope as a dependency and lazy load plugins later for squeezed performance.conf
local telescope_actions = require "telescope.actions"
local telescope_layout = require("telescope.actions.layout")
local overrides = require "configs.overrides"

-- Loaded plugins etc.
local status = require("utils").status

---@type NvPluginSpec[]
local plugins = {

  {
    "nvim-treesitter/nvim-treesitter",
  },

  {
    "folke/which-key.nvim",
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "whichkey")
      local wk_config = require("configs.which-key")
      opts = vim.tbl_deep_extend("force", opts, wk_config.opts)
      wk_config.setup()
    end,
  },

  -- -- pulled from https://github.com/igorlfs/dotfiles/blob/main/nvim/.config/nvim/lua/plugins/nvim-dap.lua
  -- {
  --     "mfussenegger/nvim-dap",
  --     dependencies = {
  --         -- Runs preLaunchTask / postDebugTask if present
  --         { "stevearc/overseer.nvim", config = true },
  --         "rcarriga/nvim-dap-ui",
  --     },
  --     keys = {
  --         {
  --             "<leader>db",
  --             function() require("dap").list_breakpoints() end,
  --             desc = "DAP Breakpoints",
  --         },
  --         {
  --             "<leader>ds",
  --             function()
  --                 local widgets = require("dap.ui.widgets")
  --                 widgets.centered_float(widgets.scopes, { border = "rounded" })
  --             end,
  --             desc = "DAP Scopes",
  --         },
  --         { "<F1>", function() require("dap.ui.widgets").hover(nil, { border = "rounded" }) end },
  --         { "<F4>", "<CMD>DapDisconnect<CR>", desc = "DAP Disconnect" },
  --         { "<F16>", "<CMD>DapTerminate<CR>", desc = "DAP Terminate" },
  --         { "<F5>", "<CMD>DapContinue<CR>", desc = "DAP Continue" },
  --         { "<F17>", function() require("dap").run_last() end, desc = "Run Last" },
  --         { "<F6>", function() require("dap").run_to_cursor() end, desc = "Run to Cursor" },
  --         { "<F9>", "<CMD>DapToggleBreakpoint<CR>", desc = "Toggle Breakpoint" },
  --         {
  --             "<F21>",
  --             function()
  --                 vim.ui.input(
  --                     { prompt = "Breakpoint condition: " },
  --                     function(input) require("dap").set_breakpoint(input) end
  --                 )
  --             end,
  --             desc = "Conditional Breakpoint",
  --         },
  --         { "<F10>", "<CMD>DapStepOver<CR>", desc = "Step Over" },
  --         { "<F11>", "<CMD>DapStepInto<CR>", desc = "Step Into" },
  --         { "<F12>", "<CMD>DapStepOut<CR>", desc = "Step Out" },
  --     },
  --     config = function()
  --         -- Signs
  --         for _, group in pairs({
  --             "DapBreakpoint",
  --             "DapBreakpointCondition",
  --             "DapBreakpointRejected",
  --             "DapLogPoint",
  --         }) do
  --             vim.fn.sign_define(group, { text = "●", texthl = group })
  --         end
  --
  --         -- Setup
  --
  --         -- Decides when and how to jump when stopping at a breakpoint
  --         -- The order matters!
  --         --
  --         -- (1) If the line with the breakpoint is visible, don't jump at all
  --         -- (2) If the buffer is opened in a tab, jump to it instead
  --         -- (3) Else, create a new tab with the buffer
  --         --
  --         -- This avoid unnecessary jumps
  --         require("dap").defaults.fallback.switchbuf = "usevisible,usetab,newtab"
  --
  --         -- Adapters
  --         -- C, C++, Rust
  --         require("plugins.dap.codelldb")
  --         -- Python
  --         require("plugins.dap.debugpy")
  --         -- JS, TS
  --         require("plugins.dap.js-debug-adapter")
  --     end,
  -- },
  {
    "nvim-telescope/telescope.nvim",
    -- opts = {
    --   defaults = {
    --     vimgrep_arguments = {
    --       "rg",
    --       "--color=never",
    --       "--no-heading",
    --       "--with-filename",
    --       "--line-number",
    --       "--column",
    --       "--smart-case",
    --     },
    --     select_buffer = true,
    --     grouped = true,
    --     collapse_dirs = true,
    --     scroll_strategy = "limit",
    --     layout_strategy = "horizontal",
    --     -- layout_strategy = "bottom_pane",
    --     cycle_layout_list = { "horizontal", "vertical" },
    --     layout_config = {
    --       horizontal = {
    --         -- width = 0.9,
    --         -- height = 0.9,
    --         preview_width = 0.5,
    --         -- preview_cutoff = 120,
    --         preview_cutoff = 0,
    --         prompt_position = "top",
    --       },
    --       height = math.floor(vim.o.lines / 2),
    --       width = vim.o.columns,
    --     },
    --     sorting_strategy = "ascending",
    --     --selection_strategy = "closest",
    --     selection_strategy = "reset",
    --       file_sorter = require("telescope.sorters").get_fuzzy_file,
    --       file_ignore_patterns = {},
    --       generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
    --       path_display = { "absolute" },
    --       winblend = 0,
    --       border = {},
    --       borderchars = { " ", " ", " ", " ", " ", " ", " ", " " },
    --       color_devicons = true,
    --       use_less = true,
    --       set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
    --       file_previewer = require("telescope.previewers").vim_buffer_cat.new,
    --       grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
    --       qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    --       -- Developer configurations: Not meant for general override
    --       buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
    --     results_title = false,
    --     prompt_prefix = "   ",
    --     prompt_title = false,
    --     mappings = {
    --       i = {
    --         ["<C-j>"] = require("telescope.actions").move_selection_next,
    --         ["<C-k>"] = require("telescope.actions").move_selection_previous,
    --         ["<C-u>"] = false,
    --         ["<C-d>"] = false,
    --         ["<TAB>"] = require("telescope.actions").select_default,
    --       },
    --       n = {
    --         ["<TAB>"] = require("telescope.actions").select_default,
    --       },
    --     },
    --   },
    --   pickers = {
    --     buffers = {
    --       theme = "dropdown",
    --       previewer = false,
    --       layout_config = {
    --         width = 0.5,
    --         height = 0.4,
    --       },
    --       mappings = {
    --         i = {
    --           ["<C-d>"] = require("telescope.actions").delete_buffer,
    --         },
    --         n = {
    --           ["dd"] = require("telescope.actions").delete_buffer,
    --         },
    --       },
    --     },
    --     current_buffer_fuzzy_find = {
    --       theme = "dropdown",
    --       previewer = false,
    --       layout_config = {
    --         width = 0.5,
    --         height = 0.4,
    --       },
    --     },
    --   },
    -- },
    dependencies = {
          { 'nvim-telescope/telescope-fzf-native.nvim',
            build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release' 
          },
          "folke/noice.nvim",
    },

    config = function()
        local telescope = require("telescope")
        telescope.load_extension("noice")

        local actions = require("telescope.actions")
        telescope.setup({
            defaults = {
                sorting_strategy = "ascending",
                path_display = { "filename_first" },
                layout_config = {
                    prompt_position = "top",
                    anchor = "N",
                },
                mappings = {
                    i = {
                        ["<Tab>"] = actions.move_selection_next,
                        ["<S-Tab>"] = actions.move_selection_previous,
                        ["<C-n>"] = actions.toggle_selection + actions.move_selection_worse,
                        ["<C-p>"] = actions.toggle_selection + actions.move_selection_better,
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
            },
        })
        telescope.load_extension("fzf")
    end,
  },

  {
      'davvid/telescope-git-grep.nvim'
  },

  {
    "nvim-telescope/telescope-file-browser.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "configs.nav".browser_setup()
    end,
  },
  {
    "coffebar/neovim-project",
    opts = {
      projects = { -- define project roots
        "~/Projects/*",
        "~/.config/*",
      },
      picker = {
        type = "telescope", -- or "fzf-lua"
      }
    },
    init = function()
      -- enable saving the state of plugins in the session
      vim.opt.sessionoptions:append("globals") -- save global variables that start with an uppercase letter and contain at least one lowercase letter.
    end,
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope.nvim", tag = "0.1.4" },
      { "ibhagwan/fzf-lua" },
      { "Shatur/neovim-session-manager" },
      { "nvim-telescope/telescope-file-browser.nvim" },
      { "davvid/telescope-git-grep.nvim" },
    },
    lazy = false,
    priority = 100,
    keys = {
      { '<leader>fF', '<cmd>Telescope find_files cwd=%:p:h<CR>', {desc = "Find file under here"}},
      { '<leader>ff', function() require("configs.nav").file_browser() end, {desc = "Browse file under here"}},
      { "<leader>.", function() require("configs.nav").file_browser() end, desc = "File Manager" },
      { "<leader>sp", function() require("configs.nav").git_grep_files_from_project() end, desc = "Search git files from project root" },
      { "<leader>sd", function() require("configs.nav").git_grep_files_from_buffer() end, desc = "Search git files from buffer directory" },
      { "<leader>sD", function() require("configs.nav").live_grep_from_buffer() end, desc = "Live grep from buffer directory" },
      { "<leader>sf", function() require("telescope.builtin").git_files({ cwd = vim.fn.expand("%:p:h") }) end, desc = "Search files from buffer directory (including hidden)" },
      { "<leader>sF", function() require("telescope.builtin").find_files({ cwd = vim.fn.expand("%:p:h"), hidden=true }) end, desc = "Search files from buffer directory" },
      { "<leader>pp", ":NeovimProjectDiscover<CR>", { desc = "Switch project" }},
    },
  },


  {
    "neovim/nvim-lspconfig",
    dependencies = {
      -- format & linting
      {
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

  -- override plugin configs
  {
      "jay-babu/mason-null-ls.nvim",
      event = { "BufReadPre", "BufNewFile" },
      dependencies = {
        "williamboman/mason.nvim",
        "nvimtools/none-ls.nvim",
      },
      config = function()
        require "configs.null-ls"
      end,
  },

  {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    opts = overrides.mason,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = overrides.treesitter,
  },

  {
    "nvim-tree/nvim-tree.lua",
    opts = overrides.nvimtree,
  },

  {
    "hrsh7th/nvim-cmp",
    dependencies = require("configs.cmp").dependencies,
    opts = require("configs.cmp").opts,
  },

  { -- Code runner
    "Zeioth/compiler.nvim",
    keys = {
      {
        "<leader>rr",
        ":CompilerOpen<CR>",
        mode = "n",
        desc = "Run Project",
      },
      {
        "<leader>rt",
        ":CompilerToggleResults<CR>",
        mode = "n",
        desc = "Toggle Results",
      },
    },

    cmd = {
      "CompilerOpen",
      "CompilerToggleResults",
      "CompilerRedo",
    },

    dependencies = {
      "stevearc/overseer.nvim",
    },

    opts = {},
  },

  { -- The task runner for compiler.nvim + daily tasks
    "stevearc/overseer.nvim",
    -- commit = "19aac0426710c8fc0510e54b7a6466a03a1a7377",

    dependencies = {
      "nvim-neotest/nvim-nio",
    },
    keys = {
      {
        "<leader>ra",
        function()
          vim.cmd [[OverseerRun]]
          vim.cmd [[OverseerOpen]]
        end,
        mode = "n",
        desc = "Run Task",
      },
    },

    cmd = {
      "CompilerOpen",
      "CompilerToggleResults",
      "CompilerRedo",
    },

    opts = {
      task_list = {
        direction = "bottom",
        min_height = 25,
        max_height = 25,
        default_detail = 1,
        bindings = {
          ["q"] = function()
            vim.cmd "OverseerClose"
          end,
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
    "ThePrimeagen/refactoring.nvim",

    config = function()
      require("refactoring").setup()
      -- require("telescope").load_extension "refactoring" -- Unnede When dressing.nvim is a thing
    end,

    keys = require("configs.refactoring").keys,
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

  { -- nvim-dap installer MAYBE
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

  { -- TODO add hlgroups according to repo
    "ThePrimeagen/harpoon",

    config = function(_, opts)
      require("harpoon").setup(opts)
      require("telescope").load_extension "harpoon"
    end,

    opts = {
      global_settings = {
        -- sets the marks upon calling `toggle` on the ui, instead of require `:w`.
        save_on_toggle = false,

        -- saves the harpoon file upon every change. disabling is unrecommended.
        save_on_change = true,

        -- sets harpoon to run the command immediately as it's passed to the terminal when calling `sendCommand`.
        enter_on_sendcmd = false,

        -- closes any tmux windows harpoon that harpoon creates when you close Neovim.
        tmux_autoclose_windows = false,

        -- filetypes that you want to prevent from adding to the harpoon list menu.
        excluded_filetypes = { "harpoon" },

        -- set marks specific to each git branch inside git repository
        mark_branch = false,

        -- enable tabline with harpoon marks
        tabline = false,
        tabline_prefix = "   ",
        tabline_suffix = "   ",
      },
    },

    keys = {
      {
        "<leader>hm",
        "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>",
        mode = "n",
        desc = "Toggle Harpoon Menu",
      },

      {
        "<leader>ha",
        "<cmd>lua require('harpoon.mark').add_file()<cr>",
        mode = "n",
        desc = "Add File",
      },

      {
        "<leader>hn",
        "<cmd>lua require('harpoon.ui').nav_next()<cr>",
        mode = "n",
        desc = "Jump to next file",
      },

      {
        "<leader>hp",
        "<cmd>lua require('harpoon.ui').nav_prev()<cr>",
        mode = "n",
        desc = "Jump to previous file",
      },

      { -- FIXME: doesn't work (after loading with :Telescope harpoon)
        "<leader>hs",
        "<cmd> Telescope harpoon marks<cr>", -- TODO: Lazy load them on this specific keystroke
        mode = "n",
        desc = "Telescope Harpoon",
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
    build = "sh ./install.sh",
    keys = require("configs.sniprun").keys,
    opts = require("configs.sniprun").opts,
    -- config = function(_, opts)
    --   require("sniprun").setup(opts)
    -- end,
  },

  {
    "gsuuon/llm.nvim",

    cmd = "Llm", -- Others cmds are ignored for now

    keys = {
      {
        "<leader>al",
        "<cmd> Llm<CR>",
        mode = { "n", "v" },
        desc = "LLM Generate",
      },
    },

    config = function(_, opts)
      require("llm").setup(opts)
    end,

    opts = function()
      return {
        default_prompt = {
          provider = require("llm.prompts.starters").palm,
          builder = function(input, context)
            return {
              model = "text-bison-001",
              prompt = {
                text = input,
              },
              temperature = 0.2,
            }
          end,
        },
        hl_group = "",
        -- prompts = {},
      }
    end,
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


}

return plugins

