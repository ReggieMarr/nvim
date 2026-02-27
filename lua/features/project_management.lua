-- lua/features/project-management.lua

local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  {
  'DrKJeff16/project.nvim',
    cmd = { -- Lazy-load by commands
      'Project',
      'ProjectAdd',
      'ProjectConfig',
      'ProjectDelete',
      'ProjectExport',
      'ProjectImport',
      'ProjectHealth',
      'ProjectHistory',
      'ProjectRecents',
      'ProjectRoot',
      'ProjectSession',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'folke/snacks.nvim',
    },
  },

  {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    cmd = 'Neotree',
  },

  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
  },
}

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
function M.setup_projects()
require('project').setup({
  snacks = {
    enabled = true, -- Will enable the `:ProjectSnacks` command
    opts = {
      sort = 'newest',
      hidden = false,
      title = 'Select Project',
      layout = 'select',
      -- icon = {},
      -- path_icons = {},
    },
  },
})
end

function M.setup_neotree()
	-- TODO this comes from custom.files. Make this commonly accessible for both
	local function make_finder(cwd)
	    ---@param opts snacks.picker.files.Config
	    ---@param ctx snacks.picker.Context
	    return function(opts, ctx)
		opts = Snacks.picker.util.shallow_copy(opts)

		-- constrain to single directory, include dirs in results
		opts.cmd     = "fd"
		opts.cwd     = cwd
		opts.dirs    = { cwd }
		opts.notify  = false
		opts.args    = {
		    "--max-depth", "1",       -- ← the key difference from M.search
		    "--type",      "d",       -- dirs (files are default in files.lua)
		    "--path-separator", "/",
		}

		local fd_stream = require("snacks.picker.source.files").files(opts, ctx)

		return function(cb)
		fd_stream(function(item)
		    -- fd marks dirs with trailing slash
		    local is_dir = item.file:sub(-1) == "/"
		    if is_dir then
		    item.file = item.file:sub(1, -2)
		    item.dir  = true
		    end

		    -- strip cwd prefix → basename only for display + matching
		    local basename = item.file:match("[^/]+$") or item.file
		    item.text   = is_dir and (basename .. "/") or basename
		    item.hidden = basename:sub(1, 1) == "."

		    -- simple sort: dirs before files, then alpha
		    item.sort = is_dir and ("!" .. basename) or ("#" .. basename)

		    cb(item)
		end)
		end
	    end
	end

    local function has_extension(name)
        return name:match("%.[^./]+$") ~= nil
    end

    local function create_file(path)
        local dir = vim.fn.fnamemodify(path, ":h")
        vim.fn.mkdir(dir, "p")
        local ok, err = pcall(vim.fn.writefile, {}, path)
        if not ok then
    	vim.notify("Failed to create file: " .. err, vim.log.levels.ERROR)
    	return false
        end
        return true
    end

    local function create_directory(path)
        local ok = vim.fn.mkdir(path, "p")
        if ok == 0 then
    	vim.notify("Failed to create directory: " .. path, vim.log.levels.ERROR)
    	return false
        end
        return true
    end
    local function find_file_at(cwd)
        cwd = vim.fn.resolve(vim.fn.expand(cwd))
        -- navigate into dir, re-using the picker instance
        local function navigate_to(picker, dir)
            cwd = vim.fn.resolve(dir)
            picker.opts.title  = "Find: " .. vim.fn.fnamemodify(cwd, ":~")
            picker.opts.finder = make_finder(cwd)
            picker.opts.cwd    = cwd
            picker.input:set("")
            picker:find()
        end

        -- navigate to parent of current cwd
        local function navigate_up(picker)
            local parent = vim.fn.fnamemodify(cwd, ":h")
            if parent ~= cwd then   -- guard against filesystem root
            navigate_to(picker, parent)
            end
        end
        -- open neo-tree at cwd
        local function open_neotree(picker)
            picker:close()
            vim.schedule(function()
              vim.cmd(("Neotree dir=%s reveal position=current"):format(vim.fn.fnameescape(cwd)))
            end)
        end
        -- TODO make this it's own picker module
        Snacks.picker.pick({
            title  = "Find: " .. vim.fn.fnamemodify(cwd, ":~"),
            finder = make_finder(cwd),

            -- text is now basename only → fuzzy match is scoped to current level
            -- this is exactly the vertico find-file behaviour
            format = "file",
            formatters = { file = { filename_only = true } },
            actions = {
                yank_relative_cwd = function(_, item)
                    local path = vim.fn.fnamemodify(item.file, ":.")
                    vim.fn.setreg("+", path)
                    vim.fn.setreg('"', path)
                    vim.notify("Yanked: " .. path)
                end,
                yank_relative_home = function(_, item)
                    local path = vim.fn.fnamemodify(item.file, ":~")
                    vim.fn.setreg("+", path)
                    vim.fn.setreg('"', path)
                    vim.notify("Yanked: " .. path)
                end,
                -- DWIM backspace: no input → navigate up, else delete char
                dwim_backspace = function(picker)
                    local search = picker.input:get() or ""
                    print("backspace with " .. search)
                    if search == "" then
                        local cwd = vim.fn.resolve(vim.fn.expand(cwd))
                        print("find file at " .. cwd .. " parent " .. vim.fs.dirname(cwd))
                        find_file_at(vim.fs.dirname(cwd))
                    else
                        -- delegate to the built-in backspace behaviour
                        vim.api.nvim_feedkeys(
                            vim.api.nvim_replace_termcodes("<BS>", true, false, true),
                            "n",
                            false
                        )
                    end
                end,
            },

		confirm = function(picker, item)
			local search = picker.input:get() or ""

			-- no input at all → open neotree
			if search == "" and not item then
				open_neotree(picker)
				return
			end

			-- item exists and is a directory → navigate into it
			if item and item.dir and search ~= vim.fn.fnamemodify(item.file, ":t") then
				cwd = item.file
				find_file_at(cwd)
				return
			end

			-- item exists and is a file → open it
			if item and not item.dir then
				picker:close()
				vim.schedule(function()
					vim.cmd.edit(item.file)
				end)
				return
			end

			-- no matching item but there is input → vertico-style create
			-- treat the search string as the name to create
			if search ~= "" and not item then
				local target = cwd .. "/" .. search
				picker:close()
				vim.schedule(function()
					if has_extension(search) then
					-- has extension → create as file and open it
					if create_file(target) then
						vim.cmd.edit(target)
					end
					else
					-- no extension → create as directory, navigate into it
					if create_directory(target) then
						find_file_at(target)
					end
					end
				end)
				return
			end
		end,
            win = {
                input = {
                    keys = {
                        ["<Tab>"] = {"confirm", mode = {"n", "i"}},
                        ["<a-j>"] = {"list_down", mode = {"n"}},
                        ["<a-k>"] = {"list_up", mode = {"n"}},
                        ["<BS>"] = {"dwim_backspace", mode = {"n", "i"}},
                        ["h"] = {"dwim_backspace", mode = {"n"}},
                        ["<c-p>"] = {"toggle_preview", mode = {"n", "i"}},
                        ["<c-h>"] = {"toggle_hidden", mode = {"n", "i"}},
                        ["l"] = {"confirm", mode = {"n"}},
                        ["<c-ESC>"] = {"focus_list", mode = {"n", "i"}},
                        ["<ESC>"] = {"close", mode = {"n"}},
                    },
                },
                list = {
                keys = {
                    ["."] = "explorer_focus",
                    ["<BS>"] = "explorer_up",
                    ["<space>"] = "select_and_next",
                    ["<Tab>"] = {"confirm", mode = {"n", "i"}},
                    ["<a-j>"] = {"list_down", mode = {"n"}},
                    ["<a-k>"] = {"list_up", mode = {"n"}},
                    ["a"] = "explorer_add",
                    ["<c-h>"] = {"toggle_hidden", mode = {"n", "i"}},
                    ["c"] = "explorer_copy",
                    ["d"] = "explorer_del",
                    ["l"] = "explorer_focus",
                    ["h"] = {"explorer_up", mode = {"n"}},
                    ["i"] = {"focus_input", mode = {"n"}},
                    ["m"] = "explorer_move",
                    ["r"] = "explorer_rename",
                    ["<c-o>"] = "explorer_yank",
                    ["y"] = "yank_relative_cwd",
                    ["Y"] = "yank_relative_home",
                },
                },
            },

            layout = { preset = "default", preview = false },
            focus = "input",
    })
    end

  require('neo-tree').setup({
    -- don't use a sidebar — open in whatever window called it
    window = {
      position = "current",
    },

    filesystem = {
      -- follow the current buffer automatically
      follow_current_file = {
        enabled    = false,
        leave_dirs_open = false,
      },
      close_if_last_window = true,
      use_libuv_file_watcher = true,
      group_empty_dirs = true, -- when true, empty folders will be grouped together
      hijack_netrw_behavior = "open_default", -- netrw disabled, opening a directory opens neo-tree
      -- dired shows all files
      filtered_items = {
        visible        = true,   -- show hidden/filtered items, dimmed
        hide_dotfiles  = false,
        hide_gitignored = false,
      },
      -- true creates a 2-way binding between vim's cwd and neo-tree's root
      bind_to_cwd = true,
	  commands = {
		open_or_set_root = function(state)
		  local node = state.tree:get_node()
		  
		  if node.type == "directory" then
		    require("neo-tree.sources.filesystem.commands").set_root(state)
		  else
		    require("neo-tree.sources.filesystem.commands").open(state)
		  end
		end,
		create_dwim = function(state)
			local node = state.tree:get_node()

			-- get the directory to create in
			local dir
			if node.type == "directory" then
				dir = node:get_id()
			else
				dir = vim.fn.fnamemodify(node:get_id(), ":h")
			end

			vim.ui.input({
				prompt = "Create in " .. vim.fn.fnamemodify(dir, ":~") .. ": ",
				completion = "file",
			}, function(input)
				if not input or input == "" then return end

				local target = dir .. "/" .. input

				if input:match("%.[^./]+$") then
					-- has extension → create file
					vim.fn.mkdir(vim.fn.fnamemodify(target, ":h"), "p")
					local ok, err = pcall(vim.fn.writefile, {}, target)
					if not ok then
						vim.notify("Failed to create file: " .. err, vim.log.levels.ERROR)
						return
					end
					vim.notify("Created file: " .. input)
					-- open the new file
					vim.schedule(function()
						vim.cmd.edit(target)
					end)
				else
					-- no extension → create directory
					local ok = vim.fn.mkdir(target, "p")
					if ok == 0 then
						vim.notify("Failed to create directory: " .. target, vim.log.levels.ERROR)
						return
					end
					vim.notify("Created directory: " .. input)
				end

				-- refresh neo-tree so the new item appears
				require("neo-tree.sources.manager").refresh("filesystem")
			end)
		end,
	  },

      -- when opening a file, use the window neo-tree displaced
      -- rather than splitting — pure buffer-swap like dired
      window = {
        mappings = {
          -- dired-style navigation
          ["<CR>"]  = "open",           -- open file OR enter dir
          ["<Tab>"]  = "open",
          ["<SPC>sb"]  = "fuzzy_finder",
          ["l"]     = "open_or_set_root",           -- also on l (ranger-style)
          ["h"]     = "navigate_up",    -- go to parent dir
          ["-"]     = "navigate_up",    -- emacs dired uses - for this
          ["q"]     = "close_window",
          ["<c-h>"] = "toggle_hidden",
          ["R"]     = "refresh",
          ["?"]    = "show_help",
		  ["+"] = "create_dwim",

          -- dired file operations
          ["c"]     = "copy",
          -- ["m"]     = "move",
          ["d"]     = "delete",
          ["r"]     = "rename",
          ["a"]     = "add",            -- create file
          ["A"]     = "add_directory",  -- create dir
          ["yy"]     = "copy_to_clipboard",
          ["p"]     = "paste_from_clipboard",

          -- open without leaving neo-tree (dired's o)
          ["o"]     = { "open", config = { stay_in_tree = true } },
        },
        fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
          ["<down>"] = "move_cursor_down",
          ["<up>"] = "move_cursor_up",
          ["<esc>"] = "close",
          ["<S-CR>"] = "close_keep_filter",
          ["<C-CR>"] = "close_clear_filter",
          ["<C-w>"] = { "<C-S-w>", raw = true },
          {
            -- normal mode mappings
            n = {
              ["j"] = "move_cursor_down",
              ["k"] = "move_cursor_up",
              ["<S-CR>"] = "close_keep_filter",
              ["<C-CR>"] = "close_clear_filter",
              ["<esc>"] = "close",
            }
          },
        },
      },
    },
    -- Since neo-tree's mapping config doesn't support key sequences like this
    -- we have to add it manually 
 vim.api.nvim_create_autocmd("FileType", {
	  pattern = "neo-tree",
	  callback = function(ev)

	    vim.keymap.set("n", "<leader>sf", function()
            find_file_at(path)
	    end, { buffer = ev.buf, noremap = true })

	    vim.keymap.set("n", "<leader>sg", function()
	      local state = require("neo-tree.sources.manager").get_state_for_window()
	      local node = state.tree:get_node()
	      local path = node:get_id()

		  -- if node is a file, search from its parent directory
		  if node.type == "file" then
		    path = vim.fn.fnamemodify(path, ":h")
		  end
	      require("snacks").picker.grep({ cwd = path })
	    end, { buffer = ev.buf, noremap = true })

   end,
})
  })
end

function M.setup_persistence()
	require('persistence').setup({
		dir = vim.fn.stdpath('data') .. '/sessions/',
	})
	vim.keymap.set('n', '<leader>qr', function()
	  require("persistence").save()
	  vim.cmd("qa")
	end, { desc = 'Save session and quit (for restart)' })
	vim.keymap.set('n', '<leader>qs', function()
	  require("persistence").load()
	end, { desc = 'Restore session' })
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup('ProjectManagement', { clear = true })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      if vim.fn.winnr('$') == 1 and vim.bo.filetype == 'neo-tree' then
        vim.cmd('quit')
      end
    end,
  })
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  local map = vim.keymap.set
  local function browse_project_files()
	  local root = require("project").get_project_root()

	  require('snacks').picker.files({
	    cwd = root,
	    show_empty = true,
	    supports_live = true,
	    auto_close = true,
	    dirs = { root },
	    enter = true,
        layout = { preset = "default", preview = false },
	  })
  end
  local function search_in_project_files()
	  local root = require("project").get_project_root()

	  require('snacks').picker.grep({
	    cwd = root,
	    dirs = { root },
	  })
  end

  map('n', '<leader>pp', '<cmd>ProjectSnacks<cr>', { desc = 'Find Projects' })
  map('n', '<leader>pf', function() browse_project_files() end, { desc = 'Find files in current project' })
  map('n', '<leader>sp', function() search_in_project_files() end, { desc = 'Search files in current project' })
  map('n', '<leader>e', '<cmd>Neotree toggle<cr>', { desc = 'Toggle Explorer' })
  map('n', '<leader>qs', function() require('persistence').load() end, { desc = 'Restore Session' })
end

-- ============================================================================
-- MAIN SETUP FUNCTION
-- ============================================================================
function M.setup()
  M.setup_projects()
  M.setup_neotree()
  M.setup_persistence()
  M.setup_autocmds()
  M.setup_keymaps()
end

return M
