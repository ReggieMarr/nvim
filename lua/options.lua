require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!

-- -- Conceal Settings
-- -- in json files, conceal the quotes
-- -- In org-mode conceal the links
-- -- Markdown links can get concealed with this also.
-- -- NOTE: Moved to org-mode config
vim.opt.conceallevel = 2
vim.opt.concealcursor = "nc"

-- Folding Settings
-- These are used for the ufo plugin
-- + org-mode
-- vim.o.foldcolumn = "1" -- '0' is not bad
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- Snippet paths
vim.g.vscode_snippets_path = "~/.config/nvim/lua/custom/snippets/json"
vim.g.lua_snippets_path = "~/.config/nvim/lua/custom/snippets/lua"
vim.g.snipmate_snippets_path = "~/.config/nvim/lua/custom/snippets/snipmate"
vim.opt.timeoutlen = 1000 -- Increase this value if needed

-- editing style
-- Allow visual selection of blocks of text
-- that don't end on the same column number
vim.opt.virtualedit = "block"
-- Get command preview in a context buffer
vim.opt.inccommand = "split"
vim.opt.wrap = false
vim.opt.selection = "exclusive" -- More like traditional GUI editors

-- Enable automatic indentation
vim.opt.autoindent = true -- Copy indent from current line when starting a new line
vim.opt.smartindent = true -- Do smart autoindenting when starting a new line
vim.opt.cindent = true -- Stricter rules for C programs
-- vim.opt.preserveindent = true -- Preserve kind of whitespace when changing indent
-- vim.opt.copyindent = true  -- Copy the structure of the existing lines indent when autoindenting
-- Enable filetype-based indentation
-- vim.cmd('filetype plugin indent on')

-- for make files we need to ensure we're using spaces not tabs
vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
  end,
})
