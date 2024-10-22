-- Helper function to set keymaps
local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    vim.keymap.set(mode, lhs, rhs, opts)
end
-- require "nvchad.mappings"
-- TODO this is just manually placing these for now
vim.keymap.set("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "move end of line" })
vim.keymap.set("i", "<C-h>", "<Left>", { desc = "move left" })
vim.keymap.set("i", "<C-l>", "<Right>", { desc = "move right" })
vim.keymap.set("i", "<C-j>", "<Down>", { desc = "move down" })
vim.keymap.set("i", "<C-k>", "<Up>", { desc = "move up" })

vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "switch window left" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "switch window right" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "switch window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "switch window up" })

vim.keymap.set("n", "<Esc>", "<cmd>noh<CR>", { desc = "general clear highlights" })

-- vim.keymap.set("n", "<C-s>", "<cmd>w<CR>", { desc = "general save file" })
-- vim.keymap.set("n", "<C-c>", "<cmd>%y+<CR>", { desc = "general copy whole file" })

vim.keymap.set("n", "<leader>n", "<cmd>set nu!<CR>", { desc = "toggle line number" })
vim.keymap.set("n", "<leader>rn", "<cmd>set rnu!<CR>", { desc = "toggle relative number" })
vim.keymap.set("n", "<leader>ch", "<cmd>NvCheatsheet<CR>", { desc = "toggle nvcheatsheet" })

vim.keymap.set("n", "<leader>fm", function()
  require("conform").format { lsp_fallback = true }
end, { desc = "general format file" })

-- global lsp mappings
vim.keymap.set("n", "<leader>ds", vim.diagnostic.setloclist, { desc = "LSP diagnostic loclist" })

-- tabufline
vim.keymap.set("n", "<leader>b", "<cmd>enew<CR>", { desc = "buffer new" })

vim.keymap.set("n", "<tab>", function()
  require("nvchad.tabufline").next()
end, { desc = "buffer goto next" })

vim.keymap.set("n", "<S-tab>", function()
  require("nvchad.tabufline").prev()
end, { desc = "buffer goto prev" })

vim.keymap.set("n", "<leader>x", function()
  require("nvchad.tabufline").close_buffer()
end, { desc = "buffer close" })


-- nvimtree
vim.keymap.set("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeFocus<CR>", { desc = "nvimtree focus window" })

-- telescope
vim.keymap.set("n", "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "telescope live grep" })
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "telescope find buffers" })
vim.keymap.set("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })
vim.keymap.set("n", "<leader>ma", "<cmd>Telescope marks<CR>", { desc = "telescope find marks" })
vim.keymap.set("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "telescope find oldfiles" })
vim.keymap.set("n", "<leader>gt", "<cmd>Telescope git_status<CR>", { desc = "telescope git status" })
vim.keymap.set("n", "<leader>pt", "<cmd>Telescope terms<CR>", { desc = "telescope pick hidden term" })

vim.keymap.set("n", "<leader>th", function()
  require("nvchad.themes").open()
end, { desc = "telescope nvchad themes" })

vim.keymap.set(
  "n",
  "<leader>fa",
  "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>",
  { desc = "telescope find all files" }
)

-- terminal
vim.keymap.set("t", "<C-x>", "<C-\\><C-N>", { desc = "terminal escape terminal mode" })

-- new terminals
vim.keymap.set("n", "<leader>h", function()
  require("nvchad.term").new { pos = "sp" }
end, { desc = "terminal new horizontal term" })

vim.keymap.set("n", "<leader>v", function()
  require("nvchad.term").new { pos = "vsp" }
end, { desc = "terminal new vertical term" })

-- toggleable
vim.keymap.set({ "n", "t" }, "<A-v>", function()
  require("nvchad.term").toggle { pos = "vsp", id = "vtoggleTerm" }
end, { desc = "terminal toggleable vertical term" })

vim.keymap.set({ "n", "t" }, "<A-h>", function()
  require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "terminal toggleable horizontal term" })

vim.keymap.set({ "n", "t" }, "<A-i>", function()
  require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })

-- whichkey
vim.keymap.set("n", "<leader>wK", "<cmd>WhichKey <CR>", { desc = "whichkey all keymaps" })
vim.keymap.set("n", "<leader>wk", function()
  vim.cmd("WhichKey " .. vim.fn.input "WhichKey: ")
end, { desc = "whichkey query lookup" })

---@type MappingsTable (Start of custom maps)

-- Comment
vim.keymap.set("n", "<A-;>", "gcc", { desc = "toggle comment", remap = true })
vim.keymap.set("v", "<A-;>", "gc", { desc = "toggle comment", remap = true })
-- General mappings
map("n", "<C-a>", "0", { desc = "move beginning of line" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit Editor", nowait = true })
map("n", "<leader>fq", "<cmd>qa!<cr>", { desc = "Force Quit Editor", nowait = true })
map("n", "<leader>wq", "<cmd>wq<cr>", { desc = "Write Quit Editor", nowait = true })
map("n", "<leader>ip", "<cmd>Inspect<cr>", { desc = "HL Group Under Cursor" })
map("n", "<leader><leader>", "<cmd>Telescope find_files<CR>", { desc = "Find file in project" })
-- already defined in myplugins.lua
-- map("n", "<leader>.", "<cmd>Telescope file_browser<CR>", { desc = "Browse files" })
map("n", "<leader>/", "<cmd>Telescope live_grep<CR>", { desc = "Search in project" })

-- bringing M-x to neovim
-- TODO create something that combines keymaps, commands, and functions
map("n", "<M-x>", "<cmd>Telescope keymaps<CR>", { desc = "Execute command" })
map("n", "<leader>bb", "<cmd>Telescope buffers<CR>", { desc = "Switch buffer" })
map("n", "<leader>`", "<c-^>", { desc = "Switch to last buffer" })

-- Toggles
-- TODO figure out what the equivalent neovim command would be too this
-- map("n", "<leader>tf", "<cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
map("n", "<leader>tn", "<cmd>set number!<CR>", { desc = "Toggle line numbers" })
map("n", "<leader>tr", "<cmd>set relativenumber!<CR>", { desc = "Toggle relative line numbers" })
map("n", "<leader>ts", "<cmd>setlocal spell!<CR>", { desc = "Toggle spell check" })
map("n", "<leader>tw", "<cmd>set wrap!<CR>", { desc = "Toggle word wrap" })

-- Search
map("n", "<leader>sg", "<cmd>Telescope live_grep<CR>", { desc = "Search by grep" })
map("n", "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Search in buffer" })
map("n", "<leader>sm", "<cmd>Telescope marks<CR>", { desc = "Search marks" })
map("n", "<leader>ss", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Search symbols in file" })
map("n", "<leader>sv", "<cmd>Telescope vim_options<CR>", { desc = "Search vim_options" })
map("n", "<leader>st", "<cmd>Telescope treesitter<CR>", { desc = "Search vim_options" })

-- Project
map("n", "<leader>pf", "<cmd>Telescope git_files<CR>", { desc = "Find file in project" })
map("n", "<leader>pF", function() require('telescope.builtin').find_files() end, { desc = "Find file in project" })
map("n", "<leader>pp", ":NeovimProjectDiscover<CR>", { desc = "Switch project" })

map("n", "<leader>pb", function() require('telescope.builtin').buffers() end, { desc = "Switch to project buffer" })

-- Buffers
map("n", "<leader>bb", "<cmd>Telescope buffers<CR>", { desc = "Switch buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bR", "<cmd>lua vim.lsp.buf.rename()<CR>", { desc = "Rename buffer" })
-- Toggling Conceal
local function search_project_for_symbol_at_point()
  local word = vim.fn.expand("<cword>")
  local search_dirs = {}
  
  if vim.fn.exists("*ProjectRootGet") == 1 then
    -- If you're using projectroot plugin
    search_dirs = {vim.fn.ProjectRootGet()}
  elseif vim.fn.exists("*FugitiveWorkTree") == 1 then
    -- If you're using vim-fugitive
    search_dirs = {vim.fn.FugitiveWorkTree()}
  else
    -- Fallback to current working directory
    search_dirs = {vim.fn.getcwd()}
  end

  require('telescope.builtin').grep_string({
    search = word,
    search_dirs = search_dirs,
    prompt_title = 'Search for "' .. word .. '" in project',
    use_regex = false,
    word_match = "-w",
    only_sort_text = true,
    sorter = require('telescope.sorters').get_fzy_sorter(),
  })
end

local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    vim.keymap.set(mode, lhs, rhs, opts)
end

map('n', '<leader>*', search_project_for_symbol_at_point, {desc = "Search project for symbol at point"})
local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    vim.keymap.set(mode, lhs, rhs, opts)
end

-- Helper functions
local function copy_this_file()
    local src = vim.fn.expand('%:p')
    local dst = vim.fn.input('Copy to: ', src, 'file')
    vim.fn.system('cp ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dst))
    print('File copied to ' .. dst)
end

local function delete_this_file()
    local file = vim.fn.expand('%:p')
    local choice = vim.fn.input('Delete ' .. file .. '? (y/n): ')
    if choice:lower() == 'y' then
        vim.cmd('bdelete!')
        vim.fn.delete(file)
        print('File deleted: ' .. file)
    end
end

local function move_this_file()
    local src = vim.fn.expand('%:p')
    local dst = vim.fn.input('Move to: ', src, 'file')
    vim.fn.system('mv ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dst))
    vim.cmd('edit ' .. vim.fn.fnameescape(dst))
    print('File moved to ' .. dst)
end

local function sudo_edit()
    local file = vim.fn.expand('%')
    vim.cmd('w !sudo tee > /dev/null %')
end

local function yank_buffer_path(relative)
    local path = vim.fn.expand('%:p')
    if relative then
        path = vim.fn.fnamemodify(path, ':.')
    end
    vim.fn.setreg('+', path)
    print('Yanked: ' .. path)
end

-- Keybindings
map('n', '<leader>fC', copy_this_file, {desc = "Copy this file"})
map('n', '<leader>fD', delete_this_file, {desc = "Delete this file"})
map('n', '<leader>fE', '<cmd>Telescope file_browser cwd=~/.config/nvim<CR>', {desc = "Browse in neovim config"})
map('n', '<leader>fP', '<cmd>Telescope find_files cwd=~/.config/nvim<CR>', {desc = "Open private config"})
map('n', '<leader>fR', move_this_file, {desc = "Move this file"})
map('n', '<leader>fS', '<cmd>saveas<CR>', {desc = "Save as"})
map('n', '<leader>fU', sudo_edit, {desc = "Sudo edit this file"})
map('n', '<leader>fY', function() yank_buffer_path(true) end, {desc = "Yank buffer path (relative)"})
map('n', '<leader>fc', '<cmd>e .editorconfig<CR>', {desc = "Find EditorConfig file"})
map('n', '<leader>fd', '<cmd>Telescope file_browser<CR>', {desc = "File browser"})
map('n', '<leader>fe', '<cmd>Telescope find_files cwd=~/.config/nvim<CR>', {desc = "Find file in neovim config"})
-- TODO replace this with a locate like grepper
-- map('n', '<leader>fl', '<cmd>Telescope live_grep<CR>', {desc = "Live grep (like locate)"})
map('n', '<leader>fp', '<cmd>Telescope find_files cwd=~/.config/nvim<CR>', {desc = "Find file in private config"})
map('n', '<leader>fr', '<cmd>Telescope oldfiles<CR>', {desc = "Recent files"})
map('n', '<leader>fs', '<cmd>w<CR>', {desc = "Save buffer"})
map('n', '<leader>fu', '<cmd>e sudo:%%<CR>', {desc = "Sudo find file"})
map('n', '<leader>fy', function() yank_buffer_path(false) end, {desc = "Yank buffer path"})

-- Function to save all and quit
local function save_all_and_quit()
    vim.cmd('wa')
    vim.cmd('qa!')
end

-- Set up the mapping
-- Option 1: Emacs-like keybinding
map('n', '<C-x><C-c>', save_all_and_quit, {desc = "Save all and quit (like Emacs C-x C-c)"})

-- Option 2: Leader-based mapping
map('n', '<leader>qq', save_all_and_quit, {desc = "Save all and quit (like Emacs C-x C-c)"})

local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    vim.keymap.set(mode, lhs, rhs, opts)
end

-- Neogit keybindings
map('n', '<leader>gG', function()
    require('neogit').open({ cwd = vim.fn.expand('%:p:h') })
end, {desc = "Neogit status here"})

map('n', '<leader>gL', function()
    require('neogit').open({ 'log', '--', vim.fn.expand('%:p') })
end, {desc = "Neogit log current file"})

map('n', '<leader>gB', function()
    vim.cmd('Neogit blame')
end, {desc = "Neogit blame"})

map('n', '<leader>gC', function()
    local url = vim.fn.input('Enter repository URL: ')
    if url ~= '' then
        require('neogit').clone(url)
    end
end, {desc = "Neogit clone"})

-- Improved toggle_maximize_buffer function
local maximized = false
local saved_win_view
local saved_win_config

-- Place this at the top of your file
-- Some plagirizing from dhruvasagar/vim-zoom + llm mods to make it better for nvim 10 on nvchad
local api = vim.api
local fn = vim.fn

-- The main toggle_zoom function
local function toggle_zoom()
  local function is_zoomed()
    return vim.t.zoomed or false
  end

  local function is_only_window()
    return #api.nvim_tabpage_list_wins(0) == 1
  end

  local function set_zoomed(value)
    vim.t.zoomed = value or false
  end

  local function zoom_session_file()
    if not vim.t.zoom_session_file then
      vim.t.zoom_session_file = fn.tempname() .. '_' .. api.nvim_tabpage_get_number(0)
      
      api.nvim_create_autocmd("TabClosed", {
        group = api.nvim_create_augroup("ZoomCleanup", { clear = true }),
        callback = function()
          if vim.t.zoom_session_file then
            os.remove(vim.t.zoom_session_file)
          end
        end,
      })
    end
    return vim.t.zoom_session_file
  end

  if is_zoomed() then
    api.nvim_exec_autocmds("User", { pattern = "ZoomPre" })
    
    local cursor_pos = api.nvim_win_get_cursor(0)
    local current_buffer = api.nvim_get_current_buf()
    
    vim.cmd('silent! source ' .. zoom_session_file())
    
    fn.setqflist(vim.t.qflist or {})
    
    api.nvim_set_current_buf(current_buffer)
    set_zoomed(false)
    api.nvim_win_set_cursor(0, cursor_pos)
    api.nvim_exec_autocmds("User", { pattern = "ZoomPost" })
  else
    if is_only_window() then return end
    
    local old_sessionoptions = vim.o.sessionoptions
    local old_session = vim.v.this_session
    
    vim.o.sessionoptions = 'blank,buffers,curdir,terminal,help'
    
    vim.t.qflist = fn.getqflist()
    vim.cmd('mksession! ' .. zoom_session_file())
    vim.cmd('only')
    set_zoomed(true)
    
    vim.v.this_session = old_session
    vim.o.sessionoptions = old_sessionoptions
  end
end

-- You can now use this function directly in your keymapping
vim.keymap.set('n', '<leader>wf', toggle_zoom, {desc = "Toggle zoom"})

local function get_all_buffers()
    local buffers = {}
    local log_buffers = {}
    for buffer = 1, vim.fn.bufnr('$') do
        local bufname = vim.fn.bufname(buffer)
        local buftype = vim.fn.getbufvar(buffer, '&buftype')
        local filetype = vim.fn.getbufvar(buffer, '&filetype')

        -- Check if it's a log buffer
        if buftype == 'log' or filetype == 'log' or string.match(bufname, '%.log$') then
            table.insert(log_buffers, {
                buffer = buffer,
                filename = bufname ~= '' and bufname or '[Log]',
                filetype = 'log'
            })
        elseif vim.fn.buflisted(buffer) == 1 or buftype ~= '' then
            table.insert(buffers, {
                buffer = buffer,
                filename = bufname ~= '' and bufname or '[No Name]',
                filetype = filetype ~= '' and filetype or buftype
            })
        end
    end

    -- Add Neovim's message buffer
    table.insert(log_buffers, {
        buffer = -1,  -- Special identifier for messages
        filename = '[Messages]',
        filetype = 'messages'
    })

    -- Add LSP log if it exists
    local lsp_log_path = vim.lsp.get_log_path()
    if vim.fn.filereadable(lsp_log_path) == 1 then
        table.insert(log_buffers, {
            buffer = -2,  -- Special identifier for LSP log
            filename = '[LSP Log]',
            filetype = 'lsp_log'
        })
    end

    -- Combine regular buffers and log buffers
    for _, log_buffer in ipairs(log_buffers) do
        table.insert(buffers, 1, log_buffer)  -- Insert at the beginning
    end

    return buffers
end

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local function all_buffers()
    local buffers = get_all_buffers()

    pickers.new({}, {
        prompt_title = "All Buffers and Logs",
        finder = finders.new_table {
            results = buffers,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = string.format("[%s] %s", entry.filetype, entry.filename),
                    ordinal = entry.filename,
                }
            end
        },
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection.value.buffer == -1 then
                    -- Show messages
                    vim.cmd('messages')
                elseif selection.value.buffer == -2 then
                    -- Open LSP log
                    vim.cmd('edit ' .. vim.lsp.get_log_path())
                else
                    vim.api.nvim_set_current_buf(selection.value.buffer)
                end
            end)
            return true
        end,
    }):find()
end

map('n', '<leader><', all_buffers, { noremap = true, silent = true, desc = "Show all buffers and logs" })

vim.api.nvim_create_user_command("NvChadFiles", function()
  require("telescope.builtin").find_files({
    prompt_title = "NvChad Files",
    cwd = vim.fn.stdpath("data"),
  })
end, {})

vim.api.nvim_set_keymap("n", "<leader>fn", ":NvChadFiles<CR>", {noremap = true, silent = true})

local lookup_key = function()
  local ok, which_key = pcall(require, "which-key")
  if not ok then
    vim.notify("which-key is not installed", vim.log.levels.ERROR)
    return
  end

  local function get_key_mapping(key)
    local mode = vim.api.nvim_get_mode().mode
    local mapping = vim.fn.maparg(key, mode, false, true)
    if vim.tbl_isempty(mapping) then
      return nil
    end
    return mapping
  end

  local function display_mapping_info(mapping)
    if mapping.callback then
      vim.notify("This key is mapped to a Lua function", vim.log.levels.INFO)
    elseif mapping.rhs then
      vim.notify("This key is mapped to: " .. mapping.rhs, vim.log.levels.INFO)
    end
    vim.notify("Defined in: " .. (mapping.script_file or "N/A"), vim.log.levels.INFO)
    vim.notify("Mode: " .. (mapping.mode or "N/A"), vim.log.levels.INFO)
  end

  which_key.show_command_center({
    {
      key = "",
      label = "Press a key to lookup its mapping",
      action = function()
        vim.ui.input({prompt = "Enter key: "}, function(input)
          if input then
            local mapping = get_key_mapping(input)
            if mapping then
              display_mapping_info(mapping)
            else
              vim.notify("No mapping found for " .. input, vim.log.levels.WARN)
            end
          end
        end)
      end,
    },
  })
end

map("n", "<leader>hk", function() lookup_key() end, { desc = "Look up key source" })

-- Helper function to move windows
local function move_window(direction)
  local curwin = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. direction)
  local newwin = vim.api.nvim_get_current_win()
  if curwin == newwin then
    if direction == "h" then
      vim.cmd("wincmd l")
    elseif direction == "l" then
      vim.cmd("wincmd h")
    elseif direction == "j" then
      vim.cmd("wincmd k")
    elseif direction == "k" then
      vim.cmd("wincmd j")
    end
  end
  vim.cmd("wincmd x")
end

-- Window split and follow
local function split_and_follow(cmd)
  local curwin = vim.api.nvim_get_current_win()
  vim.cmd(cmd)
  local newwin = vim.api.nvim_get_current_win()
  if curwin == newwin then
    vim.cmd("wincmd w")
  end
end

-- Toggle line wrapping
map('n', '<leader>tw', ':set wrap!<CR>', {desc = "Delete window"})

-- Window navigation
map('n', '<leader>wd', '<C-w>c', {desc = "Delete window"})
map('n', '<leader>ww', '<C-w>w', {desc = "Switch windows"})
map('n', '<leader>wh', '<C-w>h', {desc = "Window left"})
map('n', '<leader>wj', '<C-w>j', {desc = "Window down"})
map('n', '<leader>wk', '<C-w>k', {desc = "Window up"})
map('n', '<leader>wl', '<C-w>l', {desc = "Window right"})
map("n", "<C-w>w", "<C-w>w", { desc = "Other window" })

-- Window splitting
map("n", "<leader>ws", function() split_and_follow("split") end, { desc = "Split window horizontally and follow" })
map("n", "<leader>wv", function() split_and_follow("vsplit") end, { desc = "Split window vertically and follow" })

-- Window moving
map("n", "<leader>wH", function() move_window("h") end, { desc = "Move window left" })
map("n", "<leader>wJ", function() move_window("j") end, { desc = "Move window down" })
map("n", "<leader>wK", function() move_window("k") end, { desc = "Move window up" })
map("n", "<leader>wL", function() move_window("l") end, { desc = "Move window right" })

-- Additional window commands
map("n", "<leader>wc", "<C-w>c", { desc = "Close window" })
map("n", "<leader>wo", "<C-w>o", { desc = "Close other windows" })
map("n", "<leader>w=", "<C-w>=", { desc = "Balance windows" })
map("n", "<leader>wt", "<C-w>T", { desc = "Move window to new tab" })

local function neogit_find_file()
  local neogit = require("neogit")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  -- Get the list of branches
  local branches = vim.fn.systemlist("git branch --all | sed 's/^[ *]*//'")

  pickers.new({}, {
    prompt_title = "Select Branch/Revision",
    finder = finders.new_table {
      results = branches
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local branch = selection[1]

        -- Now use Telescope to pick a file from the selected branch
        require("telescope.builtin").git_files({
          prompt_title = "Find File in " .. branch,
          cwd = vim.fn.getcwd(),
          git_command = { "git", "ls-tree", "-r", "--name-only", branch },
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              local file = selection[1]
              
              -- Open the file in a new buffer
              vim.cmd("enew")
              vim.cmd("silent !git show " .. branch .. ":" .. file .. " > " .. vim.fn.tempname())
              vim.cmd("edit " .. vim.fn.tempname())
              vim.cmd("set buftype=nofile")
              vim.cmd("set readonly")
              vim.cmd("file " .. branch .. ":" .. file)
            end)
            return true
          end,
        })
      end)
      return true
    end,
  }):find()
end
map("n", "<leader>gf", neogit_find_file, { desc = "Neogit find file in branch" })

local function toggle_ignore_submodules()
  local function read_file(path)
    local file = io.open(path, "r")
    if not file then return {} end
    local content = file:read("*all")
    file:close()
    return vim.split(content, "\n")
  end

  local function write_file(path, lines)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(table.concat(lines, "\n"))
    file:close()
    return true
  end

  local project_root = vim.fn.getcwd()
  local gitmodules_file = project_root .. "/.gitmodules"
  local ignore_file = project_root .. "/.ignore"

  local submodules = {}
  for line in io.lines(gitmodules_file) do
    if line:match("^%s*path%s*=%s*(.+)") then
      table.insert(submodules, line:match("^%s*path%s*=%s*(.+)"))
    end
  end

  local current_ignored = read_file(ignore_file)

  local function prompt_for_submodules()
    local choices = vim.fn.inputlist(vim.list_extend({"Select submodules to ignore:"}, submodules))
    local selected = {}
    for _, choice in ipairs(choices) do
      if choice > 0 and choice <= #submodules then
        table.insert(selected, submodules[choice])
      end
    end
    return selected
  end

  vim.fn.timer_start(1000, function()
    if vim.fn.getchar(1) ~= 0 then
      local to_ignore = prompt_for_submodules()
      write_file(ignore_file, to_ignore)
    else
      if #current_ignored > 0 then
        write_file(ignore_file, {})
      else
        write_file(ignore_file, submodules)
      end
    end
    print("Submodule ignoring has been toggled.")
    -- Here you might want to add code to invalidate any relevant caches
  end)
end

-- Set up the keybinding
vim.api.nvim_set_keymap('n', '<C-*>', ':lua toggle_ignore_submodules()<CR>', {noremap = true, silent = true})

-- Sticky visual mode
vim.keymap.set("v", "<", "<gv", { noremap = true, silent = true })
vim.keymap.set("v", ">", ">gv", { noremap = true, silent = true })
vim.keymap.set("v", "p", "pgv", { noremap = true, silent = true })
local function prevent_visual_exit()
    local mode = vim.api.nvim_get_mode().mode
    if mode:sub(1,1) == 'v' then  -- if in any visual mode
        local key = vim.fn.getchar()
        if key == 27 then  -- ESC key
            return '<Esc>'
        elseif string.char(key) == 'y' then  -- yank
            return 'y'
        elseif string.char(key) == 'd' then  -- delete
            return 'd'
        else
            return ''
        end
    end
    return ''
end

vim.keymap.set('v', '<expr>', prevent_visual_exit)
