local M = {}

local wk = require "which-key"

M.setup = function()
  wk.setup(M.opts)
  
  -- WhichKey prefixes:
  wk.register({
    ["<leader> "] = { name = " Quick" },
    ["<leader>a"] = { name = " AI" },
    ["<leader>b"] = { name = "󱂬 Buffer" },
    ["<leader>c"] = { name = "󱃖 Code" },
    ["<leader>cl"] = { name = "󰡱 LeetCode" },
    ["<leader>cm"] = { name = " Markdown" },
    ["<leader>cp"] = { name = " Cpp" },
    ["<leader>cs"] = { name = "󱝆 Surf" },
    ["<leader>cx"] = { name = "󱣘 Cargo.toml" },
    ["<leader>cz"] = { name = " Snippet" },
    ["<leader>d"] = { name = " Debug" },
    ["<leader>e"] = { name = " Edit" },
    ["<leader>f"] = { name = " Find" },
    ["<leader>fu"] = { name = "󰌷 URL" },
    ["<leader>g"] = { name = " Git" },
    ["<leader>gh"] = { name = " GitHub" },
    ["<leader>ghc"] = { name = " Card" },
    ["<leader>ghi"] = { name = " Issue" },
    ["<leader>ghj"] = { name = " Comment" },
    ["<leader>ghl"] = { name = "󰌕 Label" },
    ["<leader>ghn"] = { name = "󰓂 PR" },
    ["<leader>gho"] = { name = "󱓨 Assignee" },
    ["<leader>ghp"] = { name = " Repo" },
    ["<leader>ghr"] = { name = " Review" },
    ["<leader>ght"] = { name = "󱇫 Thread" },
    ["<leader>ghu"] = { name = " React" },
    ["<leader>h"] = { name = "󱕘 Harpoon" },
    ["<leader>i"] = { name = " Sniprun" },
    ["<leader>io"] = { name = " Open" },
    ["<leader>j"] = { name = " Join" },
    ["<leader>k"] = { name = " Color" },
    ["<leader>l"] = { name = "󱃕 Lists" },
    ["<leader>lt"] = { name = " TODO" },
    ["<leader>m"] = { name = " Modes" },
    ["<leader>mk"] = { name = "󰓫 Table" },
    ["<leader>ml"] = { name = "󰉦 Lush" },
    ["<leader>n"] = { name = " Compiler Explorer" },
    ["<leader>nt"] = { name = "󱘎 TreeSitter" },
    ["<leader>o"] = { name = " Open" },
    ["<leader>p"] = { name = " Profile" },
    ["<leader>pl"] = { name = "󱑤 Load" },
    ["<leader>q"] = { name = "󰗼 Quit" },
    ["<leader>r"] = { name = " Run" },
    ["<leader>rq"] = { name = " LeetCode" },
    ["<leader>s"] = { name = " LSP" },
    ["<leader>t"] = { name = "󰙨 Test" },
    ["<leader>u"] = { name = "󰚰 Update" },
    ["<leader>v"] = { name = " Games" },
    ["<leader>w"] = { name = " Workspace" },
    ["<leader>x"] = { name = " External" },
    ["<leader>y"] = { name = "󱘣 Neoclip" },
    ["<leader>z"] = { name = " Neorg" },
  })
end

M.opts = {
  icons = {
    group = "", -- disable + to make Nerf fonts usable
  },
}

return M
