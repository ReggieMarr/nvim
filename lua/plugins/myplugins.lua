-- TODO: Remove telescope as a dependency and lazy load plugins later for squeezed performance.conf
local telescope_actions = require "telescope.actions"
local telescope_layout = require("telescope.actions.layout")
local overrides = require "configs.overrides"

-- Loaded plugins etc.
local status = require("utils").status

---@type NvPluginSpec[]
local plugins = {

  {
    "folke/which-key.nvim",
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "whichkey")
      local wk_config = require("configs.which-key")
      opts = vim.tbl_deep_extend("force", opts, wk_config.opts)
      wk_config.setup()
    end,
  },

-- {
--   "nvim-telescope/telescope.nvim",
--   opts = {
--     defaults = {
--       layout_strategy = "horizontal",
--       layout_config = {
--         horizontal = {
--           height = 0.8,
--           width = 0.6,
--           prompt_position = "top",
--           preview_width = 0, -- Disable preview
--         },
--       },
--       -- Disable preview completely
--       previewer = false,
--       -- Results customization
--       results_win_options = {
--         winblend = 0,
--         winhighlight = "Normal:Normal",
--       },
--       -- Scrolling behavior
--       scroll_strategy = "limit",
--       scroll_speed = 1,
--       -- Results behavior
--       sorting_strategy = "descending",
--       selection_strategy = "closest",
--       results_title = false,
--       -- Entry display
--       entry_prefix = "  ",
--       selection_caret = "▶ ",
--       -- Custom results mappings
--       mappings = {
--         i = {
--           ["<C-u>"] = require("telescope.actions").results_scrolling_up,
--           ["<C-d>"] = require("telescope.actions").results_scrolling_down,
--           ["<C-j>"] = require("telescope.actions").move_selection_next,
--           ["<C-k>"] = require("telescope.actions").move_selection_previous,
--         },
--       },
--     },
--   },
--   config = function(_, opts)
--     local telescope = require("telescope")
--     -- Apply the configuration
--     telescope.setup(vim.tbl_deep_extend("force", opts, {
--       defaults = {
--         entry_maker = function(entry)
--           return {
--             value = entry,
--             display = function(entry)
--               return entry.value
--             end,
--             ordinal = entry,
--           }
--         end,
--       },
--     }))
--   end,
-- },
{
  "nvim-telescope/telescope.nvim",
  branch = "master",  -- Force latest master branch
  version = false,    -- Disable version tags
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      layout_config = {
        horizontal = {
          height = 0.8,
          width = 0.6,
          prompt_position = "top",
        },
      },
      sorting_strategy = "ascending",
      scroll_strategy = "cycle",
      
      -- Force results positioning
      attach_mappings = function(prompt_bufnr)
        require("telescope.actions.set").register_hook("results_accumulated", function(results)
          if #results > 0 then
            local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
            picker:set_selection(0)
          end
        end)
        return true
      end,

      -- Custom sorter to work better with ascending sort
      generic_sorter = function(opts)
        local Sorter = require("telescope.sorters").Sorter
        return Sorter:new({
          scoring_function = function(_, prompt, line)
            return -require("telescope.algos.fzy").score(prompt, line)
          end,
          highlighter = require("telescope.highlighters").fuzzy_highlighter,
        })
      end,
    },
  },
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

  { -- TODO FIXME:
    "AckslD/nvim-neoclip.lua",
    dependencies = {
      -- -- Restore from last session
      -- { "kkharji/sqlite.lua", module = "sqlite" }, -- packer style

      -- you'll need at least one of these
      { "nvim-telescope/telescope.nvim" },
      -- {'ibhagwan/fzf-lua'},
    },

    config = function(_, opts)
      require("neoclip").setup(opts)
      require("telescope").load_extension "neoclip"
    end,

    keys = {
      { "<leader>yp", "<cmd>Telescope neoclip<cr>", mode = "n", desc = "Telescope Yanks" },

      { -- NOTE: Macros are recorded after this plugin is loaded
        "<leader>ym",
        function()
          require("telescope").extensions.macroscope.default()
        end,
        mode = "n",
        desc = "Telescope Macros",
      },
    },

    opts = {
      history = 1000,
      enable_persistent_history = false,
      length_limit = 1048576,
      continuous_sync = false,
      db_path = vim.fn.stdpath "data" .. "/databases/neoclip.sqlite3",
      filter = nil,
      preview = true,
      prompt = nil,
      default_register = '"',
      default_register_macros = "q",
      enable_macro_history = true,
      content_spec_column = true,
      disable_keycodes_parsing = false,
      on_select = {
        move_to_front = false,
        close_telescope = true,
      },
      on_paste = {
        set_reg = false,
        move_to_front = false,
        close_telescope = true,
      },
      on_replay = {
        set_reg = false,
        move_to_front = false,
        close_telescope = true,
      },
      on_custom_action = {
        close_telescope = true,
      },
      keys = {
        telescope = {
          i = {
            select = "<cr>",
            paste = "<c-p>",
            paste_behind = "<c-k>",
            replay = "<c-q>", -- replay a macro
            delete = "<c-d>", -- delete an entry
            edit = "<c-e>", -- edit an entry
            custom = {},
          },
          n = {
            select = "<cr>",
            paste = "p",
            --- It is possible to map to more than one key.
            -- paste = { 'p', '<c-p>' },
            paste_behind = "P",
            replay = "q",
            delete = "d",
            edit = "e",
            custom = {},
          },
        },
        fzf = {
          select = "default",
          paste = "ctrl-p",
          paste_behind = "ctrl-k",
          custom = {},
        },
      },
    },
  },
}

return plugins

