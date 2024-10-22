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
vim.opt.timeoutlen = 1000  -- Increase this value if needed

-- editing style
-- Allow visual selection of blocks of text 
-- that don't end on the same column number
vim.opt.virtualedit = "block"
-- Get command preview in a context buffer
vim.opt.inccommand = "split"
vim.opt.wrap = false
vim.opt.selection = "exclusive"  -- More like traditional GUI editors
vim.opt.smartindent = true
