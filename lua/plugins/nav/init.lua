-- Import core functionality
local core = require "plugins.nav.core"

local function setup(opts)
  -- Your existing setup code
  local augroup = vim.api.nvim_create_augroup("ProjectFileBrowser", { clear = true })
  local browser_opened = false

  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = augroup,
    desc = "Open file browser when session is loaded",
    callback = function()
      if not browser_opened then
        browser_opened = true
        core.load_new_project()
        browser_opened = false
      end
    end,
  })

  -- Define all keybindings here
  local keymap = {
    { "<leader>fF", "<cmd>Telescope find_files cwd=%:p:h<CR>", { desc = "Find file under here" } },
    { "<leader>ff", core.file_browser, { desc = "Browse file under here" } },
    { "<leader>.", core.file_browser, { desc = "File Manager" } },
    { "<leader>sp", core.git_grep_files_from_project, { desc = "Search git files from project root" } },
    { "<leader>sd", core.git_grep_files_from_buffer, { desc = "Search git files from buffer directory" } },
    { "<leader>sD", core.live_grep_from_buffer, { desc = "Live grep from buffer directory" } },
    {
      "<leader>sf",
      function()
        require("telescope.builtin").git_files { cwd = vim.fn.expand "%:p:h" }
      end,
      { desc = "Search files from buffer directory (including hidden)" },
    },
    {
      "<leader>sF",
      function()
        require("telescope.builtin").find_files { cwd = vim.fn.expand "%:p:h", hidden = true }
      end,
      { desc = "Search files from buffer directory" },
    },
    { "<leader>pp", ":NeovimProjectDiscover<CR>", { desc = "Switch project" } },
    {
      "<leader><leader>",
      function()
        local root = core.find_project_root()
        require("telescope").extensions.file_browser.file_browser {
          path = root,
          select_buffer = true,
        }
      end,
      { desc = "Find files (project root)" },
    },
  }

  -- Apply keymaps
  for _, mapping in ipairs(keymap) do
    vim.keymap.set("n", mapping[1], mapping[2], mapping[3])
  end

  -- Browser setup
  core.browser_setup()
end

return {
  "nav",
  dir = vim.fn.stdpath "config" .. "/lua/plugins/nav",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "ibhagwan/fzf-lua",
    "Shatur/neovim-session-manager",
    "nvim-telescope/telescope-file-browser.nvim",
    "davvid/telescope-git-grep.nvim",
    {
      "coffebar/neovim-project",
      config = function()
        require("neovim-project").setup {
          projects = {
            "~/Projects/*",
            "~/.config/*",
          },
          picker = {
            type = "telescope",
          },
        }
      end,
    },
  },
  config = function()
    local augroup = vim.api.nvim_create_augroup("ProjectFileBrowser", { clear = true })
    local browser_opened = false
    setup()
  end,
  priority = 100,
  lazy = false,
}
