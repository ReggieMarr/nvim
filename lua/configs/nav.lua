local M = {}

local function get_git_root(path)
  local git_cmd = vim.fn.system(string.format("cd %s && git rev-parse --show-toplevel", path))
  local git_root = string.gsub(git_cmd, "\n", "")
  return git_root ~= "" and git_root or nil
end

local builtin = require("telescope.builtin")
function M.browser_setup()
  local telescope = require("telescope")
  local fb_actions = require "telescope".extensions.file_browser.actions
  local Path = require("plenary.path")

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
      print("Not a git repository")
      return
    end

    -- Calculate the relative path from git root to the selected path
    local relative_path = Path:new(path):make_relative(git_root)

    require("telescope.actions").close(prompt_bufnr)

    builtin.git_files({
      git_command = {
        "git",
        "ls-files",
        "--exclude-standard",
        "--cached",
        "--",
        relative_path
      },
    })

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
    require("telescope.builtin").find_files({ cwd = path })
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
    require("telescope.builtin").live_grep({ cwd = path })
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
    require("git_grep").live_grep({
      cwd = path,
      use_git_root = false,
      skip_binary_files = true,
    })
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

  telescope.load_extension("file_browser")
end

local function get_project_root()
  -- TODO leverage NeovimProjects or something from projects.nvim here
  return get_git_root(vim.fn.getcwd()) or vim.fn.getcwd()
end

function M.git_grep_files_from_project()
  -- local project_root = get_project_root()
  require("git_grep").live_grep({
    -- not needed 
    -- cwd = path,
    -- use_git_root = false,
    skip_binary_files = true,
  })
end

function M.git_grep_files_from_buffer()
  local buffer_dir = vim.fn.expand("%:p:h")
  require("git_grep").live_grep({
    cwd = path,
    use_git_root = false,
    skip_binary_files = true,
  })
end

function M.live_grep_from_buffer()
  local buffer_dir = vim.fn.expand("%:p:h")
  builtin.live_grep({
    cwd = buffer_dir,
  })
end

function M.find_files_from_buffer(opts)
  opts = opts or {}
  opts.cwd = vim.fn.expand("%:p:h")
  builtin.find_files(opts)
end

function M.file_browser()
  require("telescope").extensions.file_browser.file_browser({
    path = "%:p:h",
    select_buffer = true,
  })
end

return M
