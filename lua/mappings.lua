require "nvchad.mappings"
---@type MappingsTable
local extern = require("utils").extern
local status = require("utils").status

-- Helper function to set keymaps
local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    vim.keymap.set(mode, lhs, rhs, opts)
end

-- General mappings
for _, mapping in ipairs({
    { "<leader>ww", "<cmd>w<cr>", desc = "Save Changes", opts = { nowait = true } },
    { "<leader>qq", "<cmd>qa<cr>", desc = "Quit Editor", opts = { nowait = true } },
    { "<leader>fq", "<cmd>qa!<cr>", desc = "Force Quit Editor", opts = { nowait = true } },
    { "<leader>wq", "<cmd>wq<cr>", desc = "Write Quit Editor", opts = { nowait = true } },
    { "<leader>ip", "<cmd>Inspect<cr>", desc = "HL Group Under Cursor" },
    { "<leader><leader>", "<cmd>Telescope find_files<CR>", desc = "Find file in project" },
    { "<leader>.", "<cmd>Telescope file_browser<CR>", desc = "Browse files" },
    { "<leader>/", "<cmd>Telescope live_grep<CR>", desc = "Search in project" },
    { "<leader>:", "<cmd>Telescope commands<CR>", desc = "Execute command" },
    { "<leader>bb", "<cmd>Telescope buffers<CR>", desc = "Switch buffer" },
    { "<leader>`", "<c-^>", desc = "Switch to last buffer" },
}) do
    map("n", mapping[1], mapping[2], { desc = mapping.desc, nowait = mapping.opts and mapping.opts.nowait })
end

-- Toggles
for _, mapping in ipairs({
    { "<leader>tf", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal" },
    { "<leader>tn", "<cmd>set number!<CR>", desc = "Toggle line numbers" },
    { "<leader>tr", "<cmd>set relativenumber!<CR>", desc = "Toggle relative line numbers" },
    { "<leader>ts", "<cmd>setlocal spell!<CR>", desc = "Toggle spell check" },
    { "<leader>tw", "<cmd>set wrap!<CR>", desc = "Toggle word wrap" },
}) do
    map("n", mapping[1], mapping[2], { desc = mapping.desc })
end

for _, mapping in ipairs({
  { "<leader>bb", "<cmd>Telescope buffers<CR>", desc = "Switch buffer" },
  { "<leader>bd", "<cmd>bdelete<CR>", desc = "Delete buffer" },
  { "<leader>bn", "<cmd>bnext<CR>", desc = "Next buffer" },
  { "<leader>bp", "<cmd>bprevious<CR>", desc = "Previous buffer" },
  { "<leader>bR", "<cmd>lua vim.lsp.buf.rename()<CR>", desc = "Rename buffer" },
  { "<leader>ht", "<cmd> Telescope themes <CR>", desc = "Nvchad themes" },
  { "<leader>ft", "<cmd> Telescope terms <CR>", desc = "Pick hidden term" },
  { "<leader>nts", "<cmd> Inspect<CR>", desc = "HL groups Under Cursor" },
  { "<leader>ntt", "<cmd> InspectTree<CR>", desc = "Parsed Syntax Tree" },
  { "<leader>ntq", "<cmd> PreviewQuery<CR>", desc = "Query Editor" },
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
  { "<leader>bk", function()
    require("nvchad.tabufline").close_buffer()
  end, desc = "Close buffer (Terminals are hidden)" },
  { "<leader>hh", function()
    require("nvterm.terminal").new("horizontal")
  end, desc = "New horizontal term" },
  { "<leader>vv", function()
    require("nvterm.terminal").new("vertical")
  end, desc = "New vertical term" },
  { "<C-M-a>", "gg0vG$", mode = "n", desc = "Select Whole Buffer" },
  { "<leader>ee", "<cmd> NvimTreeFocus<CR>", desc = "Toggle NvimTree" },
  { "<leader>et", ":NvimTreeToggle<CR>", desc = "Toggle NvimTree" },
  { "<leader>er", ":NvimTreeRefresh<CR>", desc = "Refresh NvimTree" },
  { "<leader>ef", ":NvimTreeFindFile<CR>", desc = "Find File in NvimTree" },
  { "<leader>bi", "<cmd> Nvdash<CR>", desc = "Open Dashboard" },

}) do
    map("n", mapping[1], mapping[2], { desc = mapping.desc })
end
