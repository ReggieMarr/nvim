local M = {}

local function get_git_root(path)
  local git_cmd = vim.fn.system(string.format("cd %s && git rev-parse --show-toplevel", path))
  local git_root = string.gsub(git_cmd, "\n", "")
  return git_root ~= "" and git_root or nil
end

local builtin = require "telescope.builtin"
function M.browser_setup()
  local telescope = require "telescope"
  local fb_actions = require("telescope").extensions.file_browser.actions
  local Path = require "plenary.path"

  local git_files_from_browser = function(prompt_bufnr)
    local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
    local path
    if current_picker.finder.files then
      path = current_picker.finder.path
    else
      local selection = require("telescope.actions.state").get_selected_entry()
      path = selection and selection.Path:absolute() or current_picker.finder.path
    end

    -- Get the git root
    local git_root = get_git_root(path)
    if not git_root then
      print "Not a git repository"
      return
    end

    -- Calculate the relative path from git root to the selected path
    local relative_path = Path:new(path):make_relative(git_root)

    require("telescope.actions").close(prompt_bufnr)

    builtin.git_files {
      git_command = {
        "git",
        "ls-files",
        "--exclude-standard",
        "--cached",
        "--",
        relative_path,
      },
    }
  end

  local find_file_from_browser = function(prompt_bufnr)
    local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
    local path
    if current_picker.finder.files then
      path = current_picker.finder.path
    else
      local selection = require("telescope.actions.state").get_selected_entry()
      path = selection and selection.Path:absolute() or current_picker.finder.path
    end
    require("telescope.actions").close(prompt_bufnr)
    require("telescope.builtin").find_files { cwd = path }
  end

  local search_files_from_browser = function(prompt_bufnr)
    local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
    local path
    if current_picker.finder.files then
      path = current_picker.finder.path
    else
      local selection = require("telescope.actions.state").get_selected_entry()
      path = selection and selection.Path:absolute() or current_picker.finder.path
    end
    require("telescope.actions").close(prompt_bufnr)
    require("telescope.builtin").live_grep { cwd = path }
  end

  local search_git_files_from_browser = function(prompt_bufnr)
    local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
    local path
    if current_picker.finder.files then
      path = current_picker.finder.path
    else
      local selection = require("telescope.actions.state").get_selected_entry()
      path = selection and selection.Path:absolute() or current_picker.finder.path
    end
    require("telescope.actions").close(prompt_bufnr)
    require("git_grep").live_grep {
      cwd = path,
      use_git_root = false,
      skip_binary_files = true,
    }
  end

  -- local search_git_files_from_browser = function(prompt_bufnr)
  --   local current_picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
  --   local path
  --   if current_picker.finder.files then
  --     path = current_picker.finder.path
  --   else
  --     local selection = require("telescope.actions.state").get_selected_entry()
  --     path = selection and selection.Path:absolute() or current_picker.finder.path
  --   end
  --   require("telescope.actions").close(prompt_bufnr)
  --   require("telescope.builtin").live_grep({
  --     -- cwd = path,
  --     additional_args = function()
  --       return {
  --         "--glob=!.git/*",
  --         "-g",
  --         -- NOTE we should see if we can just pull in the git_command
  --         -- from git files to keep things consistent
  --         "$(git ls-files --exclude-standard --cached -- " .. path .. ")"
  --       }
  --     end
  --   })
  -- end

  local open_in_file_browser = function(prompt_bufnr)
    local selection = require("telescope.actions.state").get_selected_entry()
    if selection then
      if selection.Path:is_dir() then
        fb_actions.open_dir(prompt_bufnr, nil, selection.Path:absolute())
      else
        require("telescope.actions").select_default(prompt_bufnr)
      end
    end
  end

  telescope.setup {
    extensions = {
      file_browser = {
        select_buffer = true,
        grouped = true,
        collapse_dirs = true,
        mappings = {
          ["i"] = {
            ["<C-f>"] = git_files_from_browser,
            ["<C-F>"] = find_file_from_browser,
            ["<C-s>"] = search_git_files_from_browser,
            ["<C-S>"] = search_files_from_browser,
          },
          ["n"] = {
            ["f"] = git_files_from_browser,
            ["F"] = find_file_from_browser,
            ["s"] = search_git_files_from_browser,
            ["S"] = search_files_from_browser,
            ["h"] = fb_actions.goto_parent_dir,
            ["l"] = open_in_file_browser,
          },
        },
      },
    },
  }

  telescope.load_extension "file_browser"
end

local function get_project_root()
  -- TODO leverage NeovimProjects or something from projects.nvim here
  return get_git_root(vim.fn.getcwd()) or vim.fn.getcwd()
end

function M.git_grep_files_from_project()
  -- local project_root = get_project_root()
  require("git_grep").live_grep {
    -- not needed
    -- cwd = path,
    -- use_git_root = false,
    skip_binary_files = true,
  }
end

function M.git_grep_files_from_buffer()
  local buffer_dir = vim.fn.expand "%:p:h"
  require("git_grep").live_grep {
    cwd = path,
    use_git_root = false,
    skip_binary_files = true,
  }
end

function M.live_grep_from_buffer()
  local buffer_dir = vim.fn.expand "%:p:h"
  builtin.live_grep {
    cwd = buffer_dir,
  }
end

function M.find_files_from_buffer(opts)
  opts = opts or {}
  opts.cwd = vim.fn.expand "%:p:h"
  builtin.find_files(opts)
end

function M.file_browser()
  require("telescope").extensions.file_browser.file_browser {
    path = "%:p:h",
    select_buffer = true,
  }
end

-- Project root finding functionality
function M.find_project_root()
  -- Get current buffer's directory
  local buf_dir = vim.fn.expand "%:p:h"
  -- Try git root from buffer's directory
  local git_cmd = string.format("cd %s && git rev-parse --show-toplevel", vim.fn.shellescape(buf_dir))
  local git_dir = vim.fn.system(git_cmd):gsub("\n", "")
  if vim.v.shell_error == 0 and git_dir ~= "" then
    return git_dir
  end

  -- Try to use LSP workspace root
  local active_clients = vim.lsp.get_active_clients { bufnr = 0 }
  if #active_clients > 0 then
    local workspace = active_clients[1].config.root_dir
    if workspace then
      return workspace
    end
  end
  -- Fallback to current buffer's directory
  vim.notify("Falling back to current directory: " .. buf_dir, vim.log.levels.WARN)
  return buf_dir
end

function M.check_ready()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  local is_real_file = buf_name ~= "" and vim.fn.filereadable(buf_name) == 1
  local vim_ready = vim.v.vim_did_enter == 1
  return is_real_file and vim_ready
end

function M.find_default_file(root_dir)
  local patterns = {
    "README.org",
    "README.md",
    "README.*",
    ".*%.org",
    ".*%.md",
    ".*%.txt",
  }

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.glob(root_dir .. "/" .. pattern, false, true)
    if #matches > 0 then
      return matches[1]
    end
  end
  return nil
end

function M.open_file_browser(root)
  local default_file = M.find_default_file(root)
  local opts = {
    path = root,
    select_buffer = false,
    attach_mappings = function(prompt_bufnr, map)
      if default_file then
        vim.schedule(function()
          local action_state = require "telescope.actions.state"
          local current_picker = action_state.get_current_picker(prompt_bufnr)
          local finder = current_picker.finder
          require("telescope._extensions.file_browser.utils").selection_callback(current_picker, default_file)
          current_picker:refresh(finder, { reset_prompt = true, multi = current_picker._multi })
        end)
      end
      return true
    end,
  }

  require("telescope").extensions.file_browser.file_browser(opts)
end

function M.load_new_project()
  local timeout = 2000
  local start_time = vim.loop.now()

  local function check_condition()
    if M.check_ready() then
      local root = M.find_project_root()
      M.open_file_browser(root)
    elseif (vim.loop.now() - start_time) < timeout then
      vim.defer_fn(check_condition, 50)
    else
      vim.notify("Timed out waiting for project to be ready", vim.log.levels.ERROR)
    end
  end

  vim.schedule(check_condition)
end

function M.setup()
  -- Create augroup
  local augroup = vim.api.nvim_create_augroup("ProjectFileBrowser", { clear = true })

  -- Create a flag to track if we've already opened the file browser
  local browser_opened = false

  -- Set up autocmd for session load
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = augroup,
    desc = "Open file browser when session is loaded",
    callback = function()
      if not browser_opened then
        browser_opened = true
        M.load_new_project()
        browser_opened = false
      end
    end,
  })

  -- Set up keymaps
  vim.keymap.set(
    "n",
    "<leader>ff",
    ":Telescope file_browser<CR>",
    { noremap = true, silent = true, desc = "Find files (current dir)" }
  )

  vim.keymap.set("n", "<leader><leader>", function()
    local root = M.find_project_root()
    require("telescope").extensions.file_browser.file_browser {
      path = root,
      select_buffer = true,
    }
  end, { noremap = true, silent = true, desc = "Find files (project root)" })
end

return M
