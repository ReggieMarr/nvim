-- lua/filesystem/pickers.lua
-- Vertico-style file browser

local M = {}

---@param local_opts {cwd: string, show_hidden: boolean}|nil
---@return nil
function M.find_file_at(local_opts)
  local MiniPick = require 'mini.pick'
  local fs_utils = require 'modules.filesystem.utils'

  local_opts = local_opts or {} -- guard nil
  local cwd = vim.fn.resolve(vim.fn.expand(local_opts.cwd or vim.fn.getcwd()))
  local show_hidden = local_opts.show_hidden or false

  -- Restart picker at a new directory
  local function navigate_to(dir)
    MiniPick.set_picker_query { '' }
    local current_opts = MiniPick.get_picker_opts()
    current_opts.source.name = 'Find: ' .. vim.fn.fnamemodify(dir, ':~')
    current_opts.source.cwd = dir
    MiniPick.set_picker_opts(current_opts)
    MiniPick.set_picker_items(fs_utils.get_files_in_dir(dir, show_hidden), { do_match = false, querytick = nil })
    MiniPick.refresh()
  end

  local function navigate_up()
    local current_opts = MiniPick.get_picker_opts()
    local dir = current_opts.source.cwd
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent ~= dir then navigate_to(parent) end
  end

  local function select_dwim(item)
    print("got selected")
    -- Current dir item → open in oil float at this directory
    if item.is_cwd then
      vim.schedule(function() require('utils.file_browsing.directory_editor').open(item.path) end)
      MiniPick.stop()
      return
    end

    -- Directory → navigate into it
    if item.is_dir then
      navigate_to(item.path)
      return
    end

    -- File → open it in target window
    local target_win = MiniPick.get_picker_state().windows.target
    vim.api.nvim_win_call(target_win, function() vim.cmd.edit(item.path) end)
    MiniPick.stop()
  end

  -- Store marks outside the function so they persist between picker sessions
  local marked_paths = {}

  MiniPick.start {
    source = {
      name = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
      cwd = cwd,
      items = fs_utils.get_files_in_dir(cwd, show_hidden),
      show = fs_utils.custom_show,
      -- don't set this but we also don't call 
      -- choose = nil

      preview = function(buf_id, item)
        if not item then return end
        if item.is_dir then
          -- Show directory listing as preview
          local entries = vim.fn.readdir(item.path)
          local lines = {}
          for _, name in ipairs(entries) do
            local full = item.path .. '/' .. name
            local suffix = vim.fn.isdirectory(full) == 1 and '/' or ''
            table.insert(lines, name .. suffix)
          end
          table.sort(lines)
          vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        else
          -- Default file preview
          MiniPick.default_preview(buf_id, item)
        end
      end,
    },

    mappings = {
      -- NOTE we need to disable the built-in first otherwise we'll get a warning
      delete_char = '',
      -- Backspace: go up if query empty, else delete char
      dwim_backspace = {
        char = '<BS>',
        func = function()
          local query = MiniPick.get_picker_query()
          if #query == 0 then
            navigate_up()
          else
            -- Remove last character from query
            local new_query = vim.list_slice(query, 1, #query - 1)
            MiniPick.set_picker_query(new_query)
          end
        end,
      },

      choose = '',
      dwim_choose = {
        char = '<CR>',
        func = function() 
            local matches = MiniPick.get_picker_matches()
            print(vim.inspect(item))
            item = matches and matches.current
            print(vim.inspect(item))

            if item then
              -- Delegate to your normal choose logic (extracted to a function)
              return select_dwim(item)
            end

            -- No item matched → create from query
            local file_query = table.concat(MiniPick.get_picker_query())
            if file_query == '' then return end
            local path = MiniPick.get_picker_opts().source.cwd .. '/' .. file_query
            fs_utils.create_dwim(path, M.find_file_at, local_opts)
            MiniPick.stop()
        end,
      },
      -- Tab: navigate into selected dir (or open file)
      navigate_in = {
        char = '<Tab>',
        func = function()

          local matches = MiniPick.get_picker_matches()
          item = matches and matches.current

          if item then
            -- Delegate to your normal choose logic (extracted to a function)
            return select_dwim(item)
          end
        end,
      },

      -- Toggle mark on current item
      -- TODO fix this, for some reason it's been overwriting choose behavior
      -- toggle_mark = {
      --   char = '<C-x>',
      --   func = function()
      --     local matches = MiniPick.get_picker_matches()
      --     if not matches or not matches.current then return end
      --     local path = matches.current.path
      --     if marked_paths[path] then
      --       marked_paths[path] = nil
      --     else
      --       marked_paths[path] = true
      --     end
      --     -- Refresh to show updated mark indicators
      --     MiniPick.refresh()
      --   end,
      -- },

      remove_query = {
        char = '<C-d>',
        func = function()
          local matches = MiniPick.get_picker_matches()
          if #matches.all == 0 then return end
          local path = matches.all[1].path

          fs_utils.delete_path(path)

          MiniPick.set_picker_query { '' }
          MiniPick.set_picker_items(fs_utils.get_files_in_dir(MiniPick.get_picker_opts().source.cwd, show_hidden), { do_match = false, querytick = nil })
          MiniPick.refresh()
        end,
      },

      move_down = '',
      create_query = {
        char = '<C-n>',
        func = function()
          local file_query = table.concat(MiniPick.get_picker_query())
          if file_query == '' then return end
          local path = MiniPick.get_picker_opts().source.cwd .. '/' .. file_query

          fs_utils.create_dwim(path, M.find_file_at, local_opts)
          MiniPick.stop()
        end,
      },

      -- Toggle hidden files
      scroll_left = '',
      toggle_hidden = {
        char = '<C-h>',
        func = function()
          show_hidden = not show_hidden
          MiniPick.set_picker_items(fs_utils.get_files_in_dir(cwd, show_hidden))
        end,
      },
    },
  }
end


return M
