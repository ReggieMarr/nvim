require "nvchad.mappings"
---@type MappingsTable
local M = {}
local extern = require("utils").extern
local status = require("utils").status

-- Convert to the new which-key spec format
M.general = {
  { "<leader>ww", "<cmd> w<cr>", desc = "Save Changes", opts = { nowait = true } },
  { "<leader>qq", "<cmd> qa<cr>", desc = "Quit Editor", opts = { nowait = true } },
  { "<leader>fq", "<cmd> qa!<cr>", desc = "Force Quit Editor", opts = { nowait = true } },
  { "<leader>wq", "<cmd> wq<cr>", desc = "Write Quit Editor", opts = { nowait = true } },
  { "<leader>ip", "<cmd> Inspect<cr>", desc = "HL Group Under Cursor" },
}

-- Disabled mappings can be left as is or removed if not needed

M.themes = {
  { "<leader>ht", "<cmd> Telescope themes <CR>", desc = "Nvchad themes" },
}

M.terms = {
  { "<leader>ft", "<cmd> Telescope terms <CR>", desc = "Pick hidden term" },
}

M.treesitter = {
  { "<leader>nts", "<cmd> Inspect<CR>", desc = "HL groups Under Cursor" },
  { "<leader>ntt", "<cmd> InspectTree<CR>", desc = "Parsed Syntax Tree" },
  { "<leader>ntq", "<cmd> PreviewQuery<CR>", desc = "Query Editor" },
}

-- Toggling Conceal
local toggled = false
M.buffer = {
  { "<leader>bf", function()
    vim.opt.concealcursor = "nc"
    if toggled then
      vim.opt.conceallevel = 0
      toggled = false
    else
      vim.opt.conceallevel = 2
      toggled = true
    end
  end, desc = "Toggle Conceal" },
  { "<leader>bn", "<cmd> enew <CR>", desc = "New buffer" },
  { "<leader>bd", "<cmd> q<CR>", desc = "Close buffer" },
  { "<leader>bk", function()
    require("nvchad.tabufline").close_buffer()
  end, desc = "Close buffer (Terminals are hidden)" },
}

M.sort = {
  { "<leader>sq", ":sort<CR>", mode = "v", desc = "Sort Selection" },
}

M.nvterm = {
  { "<leader>hh", function()
    require("nvterm.terminal").new("horizontal")
  end, desc = "New horizontal term" },
  { "<leader>vv", function()
    require("nvterm.terminal").new("vertical")
  end, desc = "New vertical term" },
}

M.selection = {
  { "<C-M-a>", "gg0vG$", mode = "n", desc = "Select Whole Buffer" },
}

M.nvimtree = {
  { "<leader>ee", "<cmd> NvimTreeFocus<CR>", desc = "Toggle NvimTree" },
  { "<leader>et", ":NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
  { "<leader>er", ":NvimTreeRefresh<CR>", desc = "Refresh NvimTree" },
  { "<leader>ef", ":NvimTreeFindFile<CR>", desc = "Find File in NvimTree" },
}

M.snippets = {
  { "<leader>es", ":lua require('luasnip.loaders').edit_snippet_files()<CR>", desc = "Edit Snippets" },
}

M.config = {
  { "<leader>oc", ":next ~/.config/nvim/lua/custom/*.lua<CR>", desc = "Open Editor Configuration" },
}

M.telescope = {
  { "<leader>fc", ":Telescope builtin<CR>", desc = "Find Editor Command" },
  { "<leader>fr", "<cmd> Telescope oldfiles<CR>", desc = "Recent Files" },
}

M.update = {
  { "<leader>uu", ":NvChadUpdate<CR>", desc = "Update NvChad UI" },
}

M.lazy = {
  { "<leader>ll", ":Lazy<CR>", desc = "Open Plugin Manager" },
}

M.mason = {
  { "<leader>om", ":Mason<CR>", desc = "Open LSP Installer" },
}

M.git = {
  { "<leader>gc", "<cmd> Telescope git_commits <CR>", desc = "Git commits" },
}

M.code = {
  { "<leader>cz", ":Telescope lsp_range_code_actions", mode = "v", desc = "Code actions for refactoring" },
  { "<leader>ca", function() vim.lsp.buf.code_action() end, mode = "v", desc = "LSP Code Action" },
  { "<leader>sr", function() vim.lsp.buf.signature_help() end, desc = "LSP Signature Help" },
  { "<leader>sa", function() require("nvchad.renamer").open() end, desc = "LSP rename" },
  { "<leader>ss", function() vim.diagnostic.open_float({ border = "rounded" }) end, desc = "Floating diagnostic" },
}

M.other = {
  { "<leader>bl", "<cmd> set nu!<cr>", desc = "Toggle line number", opts = { nowait = true } },
  { "<leader>br", "<cmd> set rnu! <CR>", desc = "Toggle relative number" },
}

M.dashboard = {
  { "<leader>bi", "<cmd> Nvdash<CR>", desc = "Open Dashboard" },
}

M.irc = {
  { "<leader>xi", function()
    extern("weechat", "vertical")
    status.irc = true
  end, desc = "IRC Client" },
}

M.hn = {
  { "<leader>xh", function()
    extern("hackernews_tui", "vertical")
    status.hn = true
  end, desc = "Hacker News" },
}

M.discord = {
  { "<leader>xd", function()
    extern("discordo", "vertical")
    status.discord = true
  end, desc = "Discord" },
}

M.map = {
  { "<leader>xm", function()
    extern("mapscii", "vertical")
    status.worldmap = true
  end, desc = "Open World Map" },
}

M.browser = {
  { "<leader>xb", function()
    extern("browsh", "vertical")
    status.browser = true
  end, desc = "Open Browsher" },
  { "<leader>xl", function()
    extern("lynx", "vertical")
  end, desc = "Open Lynx" },
}

M.reddit = {
  { "<leader>xr", function()
    extern("tuir", "vertical")
    status.reddit = true
  end, desc = "Reddit Client" },
}

M.stackoverflow = {
  { "<leader>xs", function()
    local q = vim.fn.input("Query: ")
    extern("so " .. q, "vertical")
    status.stackoverflow = true
  end, desc = "Query StackOverflow" },
}

M.mail = {
  { "<leader>xq", function()
    extern("mutt", "vertical")
    status.mail = true
  end, desc = "Email Client" },
}

M.ncmpcpp = {
  { "<leader>xa", function()
    extern("ncmpcpp", "vertical")
  end, desc = "Music Player" },
}

M.whatsapp = {
  { "<leader>xw", function()
    extern("nchat", "vertical")
    status.whatsapp = true
  end, desc = "WhatsApp Client" },
}

-- M. = {
--   n = {
--  [""] = { "", "" },
--   },
-- }

-----------------------------------------------------------
-- Github Copilot Bindings
-----------------------------------------------------------
-- M.copilot = {
--   mode_opts = { expr = true },
--   i = {
--     ["<C-h>"] = { 'copilot#Accept("<Left>")', "   copilot accept" },
--   },
-- }
-- more keybinds!

return M
