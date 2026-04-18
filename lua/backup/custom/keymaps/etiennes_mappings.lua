-- These functions set mappings used by plugins.
-- They should be called in the respective plugin config function.
local M = {}

function M.slime()
  local function toggle_slime_tmux_nvim()
    pcall(function()
      vim.b.slime_config = nil
      vim.g.slime_default_config = nil
    end)
    if vim.g.slime_target == "tmux" then
      -- Use neovim terminal for slime
      vim.g.slime_target = "neovim"
      vim.g.slime_bracketed_paste = true
      vim.g.slime_python_ipython = false
      print("Using neovim terminal for slime")
    elseif vim.g.slime_target == "neovim" then
      -- Use tmux for slime
      vim.g.slime_target = "tmux"
      vim.g.slime_bracketed_paste = true
      vim.g.slime_python_ipython = false
      vim.g.slime_default_config = { socket_name = "default", target_pane = ".2" }
      print("Using tmux for slime")
    end
  end

  vim.keymap.set("n", "<leader>tsc", "<cmd>SlimeConfig<cr>", { desc = "Configure slime" })
  vim.keymap.set("n", "<leader>tso", toggle_slime_tmux_nvim, { desc = "Toggle tmux/nvim terminal for slime" })
  vim.keymap.set("n", "<leader><cr>", "<plug>SlimeSendCell", { desc = "Slime send cell" })
  vim.keymap.set("v", "<leader><cr>", "<plug>SlimeRegionSend", { desc = "Slime send visual" })
end

function M.cloak()
  vim.keymap.set("n", "<leader>`", "<cmd>CloakPreviewLine<cr>", { desc = "Cloak preview line" })
end

function M.img_clip()
  vim.keymap.set("n", "<leader>i", "<cmd>PasteImage<cr>", { desc = "Paste image" })
  vim.keymap.set("n", "<leader>I", function()
    Snacks.picker.files({
      ft = { "jpg", "jpeg", "png", "webp" },
      confirm = function(self, item, _)
        self:close()
        require("img-clip").paste_image({}, "./" .. item.file) -- ./ is necessary for img-clip to recognize it as path
      end,
    })
  end, { desc = "Pick image" })
end

function M.cellular_automaton()
  vim.keymap.set("n", "<leader>XA", "<cmd>CellularAutomaton make_it_rain<cr>", { desc = "Cellular automaton" })
end

function M.undotree()
  vim.keymap.set("n", "<leader>u", "<cmd>UndotreeToggle<cr>", { desc = "Undotree" })
end

function M.silicon()
  vim.keymap.set("v", "<leader>XS", ":Silicon<cr>", { desc = "Silicon" })
end

function M.boole()
  vim.keymap.set({ "n", "v" }, "<leader>=", "<cmd>Boole increment<cr>", { desc = "Boole increment" })
  vim.keymap.set({ "n", "v" }, "<leader>-", "<cmd>Boole decrement<cr>", { desc = "Boole decrement" })
end

function M.language_specific()
  local is_file_type = function(x)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    return filetype == x
  end

  local local_map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = 0, silent = true, desc = desc })
  end

  -- Add keymaps for typst, and markdown
  if is_file_type("typst") then
    local_map("<leader>m", "", "Typst")
    local_map("<leader>mc", "<cmd>! typst compile --root ~ " .. vim.fn.expand("%:p") .. "<cr>", "Compile PDF")
    local_map("<leader>mm", "<cmd>TypstPreviewToggle<cr>", "Toggle preview")
  elseif is_file_type("markdown") then
    local_map("<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", "Toggle markdown preview")
  elseif is_file_type("rust") then
    local_map("<leader>m", "", "Rust")
    local_map("<leader>mc", "<cmd>RustLsp codeAction<cr>", "Code Actions")
    local_map("<leader>me", "<cmd>RustLsp explainError<cr>", "Explain Error")
    local_map("<leader>mx", "<cmd>RustLsp renderDiagnostic<cr>", "Render Diagnostics")
    local_map("<leader>mo", "<cmd>RustLsp openDocs<cr>", "Open Documentation")
    local_map("<leader>mr", "<cmd>RustLsp runnables<cr>", "Run")
    local_map("<leader>md", "<cmd>RustLsp debuggables<cr>", "Debug")
    local_map("<leader>mt", "<cmd>RustLsp testables<cr>", "Test")
  elseif is_file_type("python") then
    local function run_current_buffer()
      local tmpfile = "/tmp/nvim_exec_temp.py"
      vim.cmd("w! " .. tmpfile)
      vim.cmd("belowright split")
      vim.cmd("resize 15")
      vim.cmd("terminal python3 " .. tmpfile)
    end
    local_map("<leader>m", run_current_buffer, "Run python buffer")
  end
end

function M.gitsigns(buffer)
  local gs = require("gitsigns")

  local function map(mode, l, r, desc)
    vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
  end

  map("n", "]h", function()
    if vim.wo.diff then
      vim.cmd.normal({ "]c", bang = true })
    else
      gs.nav_hunk("next")
    end
  end, "Next Hunk")
  map("n", "[h", function()
    if vim.wo.diff then
      vim.cmd.normal({ "[c", bang = true })
    else
      gs.nav_hunk("prev")
    end
  end, "Prev Hunk")

  -- stylua: ignore start
  map("n", "]H", function() gs.nav_hunk("last") end, "Last Hunk")
  map("n", "[H", function() gs.nav_hunk("first") end, "First Hunk")

  -- These two mappings use a "command" form to allow ranges in visual mode
  map({ "n", "v" }, "<leader>gr", ":Gitsigns reset_hunk<cr>", "Reset Hunk")
  map({ "n", "v" }, "<leader>gs", ":Gitsigns stage_hunk<cr>", "Stage Hunk")

  map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame Hunk")
  map("n", "<leader>gB", function() gs.blame() end, "Blame Buffer")
  map("n", "<leader>gd", gs.diffthis, "Diff This")
  map("n", "<leader>gD", function() gs.diffthis("~") end, "Diff This ~")
  map("n", "<leader>gp", gs.preview_hunk_inline, "Preview Hunk Inline")
  map("n", "<leader>gR", gs.reset_buffer, "Reset Buffer")
  map("n", "<leader>gS", gs.stage_buffer, "Stage Buffer")
  map({ "o", "x" }, "ih", ":<c-U>Gitsigns select_hunk<cr>", "GitSigns Select Hunk")
  -- stylua: ignore end
end

function M.grug_far()
  vim.keymap.set("n", "<leader>S", "<cmd>GrugFar<cr>", { desc = "GrugFar" })
  vim.keymap.set("x", "<leader>S", ":GrugFarWithin<cr>", { desc = "GrugFarWithin" })
end

function M.dropbar()
  local dropbar_api = require("dropbar.api")
  vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
  vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
  vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
end

function M.flash()
  local flash = require("flash")
  vim.keymap.set({ "n", "x" }, "<cr>", flash.jump, { desc = "Flash" })
  vim.keymap.set({ "n", "x", "o" }, "<s-cr>", flash.treesitter, { desc = "Flash Treesitter" })
end

function M.dapui()
  local dapui = require("dapui")
  local virtual_text = require("nvim-dap-virtual-text")
  vim.keymap.set("n", "<leader>ku", function()
    dapui.toggle()
    virtual_text.refresh()
  end, { desc = "Dap UI Toggle" })
  vim.keymap.set({ "n", "x" }, "<leader>ke", dapui.eval, { desc = "Dap UI Eval" })
end

-- stylua: ignore start
function M.snacks()
  -- Snacks other
  vim.keymap.set("n", "<leader>zh", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
  vim.keymap.set("n", "<leader>rf", function() Snacks.rename.rename_file() end, { desc = "Rename File" })
  vim.keymap.set({ "n", "t" }, "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Next Reference" })
  vim.keymap.set({ "n", "t" }, "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Prev Reference" })
  vim.keymap.set("n", "<leader>XZ", function() Snacks.zen() end, { desc = "Toggle zen mode" })
  vim.keymap.set("n", "<leader>zs", function() Snacks.scratch() end, { desc = "Scratch buffer" })

  -- Snacks terminal
  vim.keymap.set({ "n", "i", "v", "t" }, "<F3>", function() Snacks.terminal.toggle(nil, { auto_insert = false }) end, { desc = "Toggle terminal", })
  vim.keymap.set("n", "<leader>ttp", function() Snacks.terminal.toggle("python", { auto_insert = false }) end, { desc = "Python" })

  -- Snacks git
  vim.keymap.set({ "n", "i", "v", "t" }, "<F2>", function() Snacks.lazygit() end, { desc = "Lazygit" })
  vim.keymap.set("n", "<leader>gf", function() Snacks.picker.git_log_file() end, { desc = "Log file" })
  vim.keymap.set("n", "<leader>gl", function() Snacks.picker.git_log() end, { desc = "Logs" })
  vim.keymap.set("n", "<leader>gL", function() Snacks.picker.git_log_line() end, { desc = "Log line" })
  vim.keymap.set("n", "<leader>go", function() Snacks.gitbrowse() end, { desc = "Git Browse" })
  vim.keymap.set("n", "<leader>gx", function() Snacks.picker.git_status() end, { desc = "Git Status" })

  -- Snacks explorer
  vim.keymap.set({ "n" }, "<leader>e", function() Snacks.picker.explorer() end, { desc = "Toggle Explorer" })

  -- Snacks picker
  vim.keymap.set({ "n" }, "<leader><leader>", function() Snacks.picker.buffers({ sort_lastused = false }) end, { desc = "Buffers" })
  vim.keymap.set({ "n" }, '<leader>s"', function() Snacks.picker.registers() end, { desc = "Registers" })
  vim.keymap.set({ "n" }, "<leader>s:", function() Snacks.picker.commands() end, { desc = "Commands" })
  vim.keymap.set({ "n" }, "<leader>s;", function() Snacks.picker.command_history() end, { desc = "Command History" })
  vim.keymap.set({ "n" }, "<leader>sa", function() Snacks.picker.rga() end, { desc = "Ripgrep-All" })
  vim.keymap.set({ "n" }, "<leader>sA", function() Snacks.picker.autocmds() end, { desc = "Autocmds" })
  vim.keymap.set({ "n" }, "<leader>sB", function() Snacks.picker.grep_buffers() end, { desc = "Grep Open Buffers" })
  vim.keymap.set({ "n" }, "<leader>sb", function() Snacks.picker.lines() end, { desc = "Buffer Lines" })
  vim.keymap.set({ "n" }, "<leader>sc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, { desc = "Find Config File" })
  vim.keymap.set({ "n" }, "<leader>sC", function() Snacks.picker.colorschemes() end, { desc = "Colorschemes" })
  vim.keymap.set({ "n" }, "<leader>sd", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })
  vim.keymap.set({ "n" }, "<leader>sf", function() Snacks.picker.files() end, { desc = "Files" })
  vim.keymap.set({ "n" }, "<leader>sg", function() Snacks.picker.grep() end, { desc = "Grep" })
  vim.keymap.set({ "n" }, "<leader>sG", function() Snacks.picker.git_files() end, { desc = "Git Files" })
  vim.keymap.set({ "n" }, "<leader>sh", function() Snacks.picker.help() end, { desc = "Help Pages" })
  vim.keymap.set({ "n" }, "<leader>sH", function() Snacks.picker.highlights() end, { desc = "Highlights" })
  vim.keymap.set({ "n" }, "<leader>sj", function() Snacks.picker.jumps() end, { desc = "Jumps" })
  vim.keymap.set({ "n" }, "<leader>sk", function() Snacks.picker.keymaps() end, { desc = "Keymaps" })
  vim.keymap.set({ "n" }, "<leader>sl", function() Snacks.picker.loclist() end, { desc = "Location List" })
  vim.keymap.set({ "n" }, "<leader>sm", function() Snacks.picker.marks() end, { desc = "Marks" })
  vim.keymap.set({ "n" }, "<leader>sM", function() Snacks.picker.man() end, { desc = "Man Pages" })
  vim.keymap.set({ "n" }, "<leader>sof", function() require("obsidian.picker").find_notes() end, { desc = "Find Note" })
  vim.keymap.set({ "n" }, "<leader>sog", function() require("obsidian.picker").grep_notes() end, { desc = "Grep Notes" })
  vim.keymap.set({ "n" }, "<leader>sow", "<cmd>Obsidian workspace<cr>", { desc = "Obsidian Workspace" })
  vim.keymap.set({ "n" }, "<leader>sp", function() Snacks.picker() end, { desc = "Picker" })
  vim.keymap.set({ "n" }, "<leader>sP", function() Snacks.picker.projects() end, { desc = "Projects" })
  vim.keymap.set({ "n" }, "<leader>sq", function() Snacks.picker.qflist() end, { desc = "Quickfix List" })
  vim.keymap.set({ "n" }, "<leader>sr", function() Snacks.picker.recent() end, { desc = "Recent" })
  vim.keymap.set({ "n" }, "<leader>sR", function() Snacks.picker.resume({ exclude = {"explorer"} }) end, { desc = "Resume" })
  vim.keymap.set({ "n" }, "<leader>ss", function() Snacks.picker.lsp_symbols() end, { desc = "LSP Symbols" })
  vim.keymap.set({ "n" }, "<leader>sS", function() Snacks.picker.astgrep() end, { desc = "ast-grep" })
  vim.keymap.set({ "n" }, "<leader>st", function() Snacks.picker.treesitter() end, { desc = "Treesitter" })
  vim.keymap.set({ "n" }, "<leader>sT", function() Snacks.picker.todo_comments() end, { desc = "Todo/Fix/Fixme" })
  vim.keymap.set({ "n", "x" }, "<leader>sw", function() Snacks.picker.grep_word() end, { desc = "Visual selection or word" })

  -- Snacks LSP
  vim.keymap.set({ "n" }, "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Goto Definition" })
  vim.keymap.set({ "n" }, "gI", function() Snacks.picker.lsp_implementations() end, { desc = "Goto Implementation" })
  vim.keymap.set({ "n" }, "gr", function() Snacks.picker.lsp_references() end, { nowait = true, desc = "References" })
  vim.keymap.set({ "n" }, "gy", function() Snacks.picker.lsp_type_definitions() end, { desc = "Goto T[y]pe Definition" })
end

function M.lsp(_, bufnr)
  local map = function(mode, keys, func, desc)
    vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
  end

  map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
  map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
  map("n", "H", function() vim.diagnostic.open_float(nil, { focusable = true, scope = "cursor", source = "if_many" }) end, "Hover Diagnostics")
  map("n", "K", vim.lsp.buf.hover, "Hover Documentation")
  map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
  map("n", "<leader>rs", ":LspRestart<cr>", "Restart")
  map({ "n", "i" }, "<c-s>", vim.lsp.buf.signature_help, "Signature help")

  -- TODO: I should find a better place for these mappings as they are not necessarily LSP specific
  vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Goto previous diagnostic" })
  vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Goto next diagnostic" })
  vim.keymap.set("n", "lh", function() vim.diagnostic.hide() end, { desc = "Hide diagnostics" })
  vim.keymap.set("n", "ls", function() vim.diagnostic.show() end, { desc = "Show diagnostics" })
end

function M.dap()
  local map = function(keys, func, desc)
    vim.keymap.set({ "n", "v" }, keys, func, { desc = desc })
  end

  -- From lazyvim
  -- https://github.com/lazyvim/lazyvim/blob/main/lua/lazyvim/plugins/extras/dap/core.lua
  ---@param config {args?:string[]|fun():string[]?}
  local function get_args(config)
    local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
    config = vim.deepcopy(config)
    ---@cast args string[]
    config.args = function()
      local new_args = vim.fn.input("Run with args: ", table.concat(args, " ")) --[[@as string]]
      return vim.split(vim.fn.expand(new_args) --[[@as string]], " ")
    end
    return config
  end

  local dap = require("dap")
  local widgets = require("dap.ui.widgets")

  map("<leader>kB", function() dap.set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, "breakpoint condition")
  map("<leader>kC", dap.run_to_cursor, "Run to cursor")
  map("<leader>kO", dap.step_out, "Step out")
  map("<leader>ka", function() dap.continue({ before = get_args }) end, "Run with args")
  map("<leader>kb", dap.toggle_breakpoint, "Toggle breakpoint")
  map("<leader>kc", dap.continue, "Run/Continue")
  map("<leader>kf", function() widgets.centered_float(widgets.frames) end , "Frames")
  map("<leader>kg", dap.goto_, "Go to line (no execute)")
  map("<leader>kh", widgets.hover, "Hover")
  map("<leader>ki", dap.step_into, "Step into")
  map("<leader>kj", dap.down, "Down")
  map("<leader>kk", dap.up, "Up")
  map("<leader>kl", dap.run_last, "Run last")
  map("<leader>ko", dap.step_over, "Step over")
  map("<leader>kp", dap.pause, "Pause")
  map("<leader>kr", dap.repl.toggle, "Toggle repl")
  map("<leader>kR", dap.restart, "Restart")
  map("<leader>ks", dap.session, "Session")
  map("<leader>kT", dap.terminate, "Terminate")
  map("<leader>kt", function() widgets.centered_float(widgets.threads) end, "Threads")
end
-- stylua: ignore end

return M
