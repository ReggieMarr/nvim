-- lua/base.lua
-- Options, global keymaps, and autocmds.
-- No plugin dependencies. Loaded before lazy.

local keys = require("lib.keys")

-- ─── Options ─────────────────────────────────────────────────────────────────

local options = {
  -- Editing
  expandtab     = true,
  shiftwidth    = 2,
  tabstop       = 2,
  smartindent   = true,
  wrap          = false,
  scrolloff     = 8,
  sidescrolloff = 8,

  -- Search
  ignorecase = true,
  smartcase  = true,
  hlsearch   = false,
  incsearch  = true,

  -- UI
  number         = true,
  relativenumber = true,
  signcolumn     = "yes",
  cursorline     = true,
  termguicolors  = true,
  showmode       = false,
  splitbelow     = true,
  splitright     = true,
  pumheight      = 10,

  -- Behavior
  undofile     = true,
  swapfile     = false,
  backup       = false,
  updatetime   = 250,
  timeoutlen   = 300,
  completeopt  = { "menuone", "noselect" },
  fileencoding = "utf-8",
  conceallevel = 0,
}

for k, v in pairs(options) do
  vim.opt[k] = v
end

-- ─── Diagnostic Config ────────────────────────────────────────────────────────

vim.diagnostic.config({
  update_in_insert = false,
  severity_sort    = true,
  float            = { border = "rounded", source = "if_many" },
  underline        = { severity = vim.diagnostic.severity.ERROR },
  virtual_text     = true,
  virtual_lines    = false,
  jump             = { float = true },
})

-- ─── Leader ───────────────────────────────────────────────────────────────────

-- Must be set before lazy / any plugin loads
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

-- ─── Which-key Groups ─────────────────────────────────────────────────────────

keys.register_group("<leader>b", "buffers", "n")
keys.register_group("<leader>c", "config",  "n")
keys.register_group("<leader>f", "find",    "n")
keys.register_group("<leader>g", "git",     "n")
keys.register_group("<leader>l", "lsp",     "n")
keys.register_group("<leader>p", "project", "n")
keys.register_group("<leader>q", "quit",    "n")
keys.register_group("<leader>t", "toggle",  "n")
keys.register_group("<leader>w", "write",   "n")

-- ─── Keymaps ─────────────────────────────────────────────────────────────────

local config_dir = vim.fn.stdpath("config")

keys.map_group("base", {

  -- ── Search ───────────────────────────────────────────────────────────
  {
    lhs  = "<Esc>",
    rhs  = "<cmd>nohlsearch<cr>",
    desc = "Clear search highlight",
  },

  -- ── Window navigation ─────────────────────────────────────────────────
  {
    lhs  = "<C-h>",
    rhs  = "<C-w>h",
    desc = "Move to left window",
  },
  {
    lhs  = "<C-j>",
    rhs  = "<C-w>j",
    desc = "Move to lower window",
  },
  {
    lhs  = "<C-k>",
    rhs  = "<C-w>k",
    desc = "Move to upper window",
  },
  {
    lhs  = "<C-l>",
    rhs  = "<C-w>l",
    desc = "Move to right window",
  },

  -- ── Buffer management ─────────────────────────────────────────────────
  {
    lhs  = "<S-l>",
    rhs  = "<cmd>bnext<cr>",
    desc = "Next buffer",
  },
  {
    lhs  = "<S-h>",
    rhs  = "<cmd>bprevious<cr>",
    desc = "Previous buffer",
  },
  {
    lhs  = "<leader>bd",
    rhs  = "<cmd>bdelete<cr>",
    desc = "Delete buffer",
  },

  -- ── Quit ─────────────────────────────────────────────────────────────
  {
    lhs  = "<leader>qq",
    rhs  = "<cmd>qa<cr>",
    desc = "Quit all",
  },
  {
    lhs  = "<leader>qQ",
    rhs  = "<cmd>qa!<cr>",
    desc = "Quit all (force)",
  },
  {
    lhs  = "<leader>wq",
    rhs  = "<cmd>wqa<cr>",
    desc = "Save and quit all",
  },

  -- ── Save ─────────────────────────────────────────────────────────────
  {
    lhs  = "<C-s>",
    rhs  = "<cmd>w<cr>",
    desc = "Save file",
  },

  -- ── Toggle ───────────────────────────────────────────────────────────
  {
    lhs  = "<leader>tn",
    rhs  = "<cmd>set number!<cr>",
    desc = "Toggle line numbers",
  },
  {
    lhs  = "<leader>tr",
    rhs  = "<cmd>set relativenumber!<cr>",
    desc = "Toggle relative numbers",
  },
  {
    lhs  = "<leader>ts",
    rhs  = "<cmd>setlocal spell!<cr>",
    desc = "Toggle spell check",
  },
  {
    lhs  = "<leader>tw",
    rhs  = "<cmd>set wrap!<cr>",
    desc = "Toggle word wrap",
  },

  -- ── Config ───────────────────────────────────────────────────────────
  {
    lhs = "<leader>cf",
    rhs = function()
      local files = vim.fn.globpath(config_dir, "**/*", false, true)
      files = vim.tbl_filter(
        function(f) return vim.fn.isdirectory(f) == 0 end,
        files
      )
      vim.ui.select(files, {
        prompt      = "Find config file:",
        format_item = function(item)
          return item:gsub(config_dir .. "/", "")
        end,
      }, function(choice)
        if choice then vim.cmd.edit(choice) end
      end)
    end,
    desc = "Find config file",
  },
  {
    lhs = "<leader>cg",
    rhs = function()
      local query = vim.fn.input("Grep config> ")
      if query == "" then return end
      vim.cmd("silent! vimgrep /" .. query .. "/gj " .. config_dir .. "/**/*")
      vim.cmd("copen")
    end,
    desc = "Grep config files",
  },
  {
    lhs  = "<leader>cm",
    rhs  = "<cmd>ConfigStatus modules<cr>",
    desc = "Config module status",
  },
  {
    lhs  = "<leader>ck",
    rhs  = "<cmd>ConfigStatus keys<cr>",
    desc = "Config keymap registry",
  },
  {
    lhs  = "<leader>cc",
    rhs  = "<cmd>ConfigStatus capabilities<cr>",
    desc = "Config capability registry",
  },

}, { silent = true })

-- ── Multi-mode mappings ───────────────────────────────────────────────────────
-- Registered separately as they don't share the default normal mode

keys.map_group("base", {
  {
    lhs  = "<C-s>",
    rhs  = "<cmd>w<cr><Esc>",
    desc = "Save file",
    mode = { "i", "v" },
  },
  {
    lhs  = "<C-x><C-c>",
    rhs  = "<cmd>wqa!<cr>",
    desc = "Save and quit (force)",
    mode = { "n", "i", "v" },
  },
})

-- ── Insert mode ───────────────────────────────────────────────────────────────

keys.map_group("base", {
  {
    lhs  = "<C-a>",
    rhs  = "<Esc>^i",
    desc = "Go to beginning of line",
  },
  {
    lhs  = "<C-e>",
    rhs  = "<End>",
    desc = "Go to end of line",
  },
}, { mode = "i", silent = true })

-- ── Normal mode line navigation ───────────────────────────────────────────────

keys.map_group("base", {
  {
    lhs  = "<C-a>",
    rhs  = "^",
    desc = "Go to beginning of line",
  },
  {
    lhs  = "<C-e>",
    rhs  = "$",
    desc = "Go to end of line",
  },
}, { mode = "n", silent = true })

-- ── Visual mode ───────────────────────────────────────────────────────────────

keys.map_group("base", {
  {
    lhs  = "<",
    rhs  = "<gv",
    desc = "Indent left (keep selection)",
  },
  {
    lhs  = ">",
    rhs  = ">gv",
    desc = "Indent right (keep selection)",
  },
  {
    lhs  = "p",
    rhs  = "pgv",
    desc = "Paste (keep selection)",
  },
}, { mode = "v", silent = true })

-- ── Terminal mode ─────────────────────────────────────────────────────────────

keys.map_group("base", {
  {
    lhs  = "<Esc><Esc>",
    rhs  = "<C-\\><C-n>",
    desc = "Exit terminal mode",
  },
  {
    lhs  = "<C-x>",
    rhs  = "<C-\\><C-n>",
    desc = "Exit terminal mode (alternate)",
  },
}, { mode = "t", silent = true })

-- ─── Autocmds ────────────────────────────────────────────────────────────────

local function augroup(name)
  return vim.api.nvim_create_augroup("base_" .. name, { clear = true })
end

vim.api.nvim_create_autocmd("TextYankPost", {
  group    = augroup("yank_highlight"),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
  desc = "Highlight yanked text",
})

vim.api.nvim_create_autocmd("BufReadPost", {
  group    = augroup("restore_cursor"),
  callback = function()
    local mark       = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
  desc = "Restore cursor position",
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group    = augroup("trim_whitespace"),
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end,
  desc = "Trim trailing whitespace on save",
})

vim.api.nvim_create_autocmd("FileType", {
  group   = augroup("quick_close"),
  pattern = {
    "help", "lspinfo", "man",
    "notify", "qf", "checkhealth",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    keys.map({
      lhs    = "q",
      rhs    = "<cmd>close<cr>",
      desc   = "Close window",
      module = "base",
      buffer = event.buf,
    })
  end,
  desc = "Close utility windows with q",
})

vim.api.nvim_create_autocmd("VimResized", {
  group    = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
  desc = "Equalize splits on resize",
})
