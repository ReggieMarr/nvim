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
  { "<leader><leader>", "<cmd>Telescope find_files<CR>", desc = "Find file in project" },
  { "<leader>.", "<cmd>Telescope file_browser<CR>", desc = "Browse files" },
  { "<leader>/", "<cmd>Telescope live_grep<CR>", desc = "Search in project" },
  { "<leader>:", "<cmd>Telescope commands<CR>", desc = "Execute command" },
  { "<leader>bb", "<cmd>Telescope buffers<CR>", desc = "Switch buffer" },
  { "<leader>`", "<c-^>", desc = "Switch to last buffer" },
}

M.lsp = {
  { "<leader>lD", vim.lsp.buf.declaration, desc = "Go to declaration" },
  { "<leader>ld", vim.lsp.buf.definition, desc = "Go to definition" },
  { "<leader>lI", vim.lsp.buf.implementation, desc = "Go to implementation" },
  { "<leader>lr", vim.lsp.buf.references, desc = "Find references" },
  { "<leader>lt", vim.lsp.buf.type_definition, desc = "Go to type definition" },
  { "<leader>lk", vim.lsp.buf.hover, desc = "Show hover information" },
  { "<leader>la", vim.lsp.buf.code_action, desc = "Code actions" },
  { "<leader>lf", vim.lsp.buf.formatting, desc = "Format code" },
  { "<leader>lr", vim.lsp.buf.rename, desc = "Rename symbol" },
}

M.toggles = {
  { "<leader>tf", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
  { "<leader>tn", "<cmd>set number!<CR>", desc = "Toggle line numbers" },
  { "<leader>tr", "<cmd>set relativenumber!<CR>", desc = "Toggle relative line numbers" },
  { "<leader>ts", "<cmd>setlocal spell!<CR>", desc = "Toggle spell check" },
  { "<leader>tw", "<cmd>set wrap!<CR>", desc = "Toggle word wrap" },
}

M.search = {
  { "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },
  { "<leader>sf", "<cmd>Telescope find_files<CR>", desc = "Search files" },
  { "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "Search by grep" },
  { "<leader>sm", "<cmd>Telescope marks<CR>", desc = "Search marks" },
  { "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Search symbols in file" },
}

M.project = {
  { "<leader>pp", "<cmd>Telescope projects<CR>", desc = "Switch project" },
  { "<leader>pf", "<cmd>Telescope find_files<CR>", desc = "Find file in project" },
  { "<leader>pb", "<cmd>Telescope buffers<CR>", desc = "Switch to project buffer" },
}

M.files = {
  { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find file" },
  { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
}

M.buffers = {
  { "<leader>bb", "<cmd>Telescope buffers<CR>", desc = "Switch buffer" },
  { "<leader>bd", "<cmd>bdelete<CR>", desc = "Delete buffer" },
  { "<leader>bn", "<cmd>bnext<CR>", desc = "Next buffer" },
  { "<leader>bp", "<cmd>bprevious<CR>", desc = "Previous buffer" },
  { "<leader>bR", "<cmd>lua vim.lsp.buf.rename()<CR>", desc = "Rename buffer" },
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
