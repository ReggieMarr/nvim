-- ============================================================================
-- File Operations
-- ============================================================================
local M = {}

--   Error  06:58:36 PM notify.error [Neo-tree ERROR] debounce  filesystem_navigate  error:  ....local/share/nvim/lazy/nui.nvim/lua/nui/utils/keymap.lua:112: invalid key: mode
function M.setup()
  -- Helper functions for file operations
  local function copy_this_file()
    local src = vim.fn.expand '%:p'
    local dst = vim.fn.input('Copy to: ', src, 'file')
    if dst ~= '' and dst ~= src then
      vim.fn.system('cp ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dst))
      print('File copied to ' .. dst)
    end
  end

  local function delete_this_file()
    local file = vim.fn.expand '%:p'
    local choice = vim.fn.input('Delete ' .. file .. '? (y/n): ')
    if choice:lower() == 'y' then
      vim.cmd 'bdelete!'
      vim.fn.delete(file)
      print('File deleted: ' .. file)
    end
  end

  local function move_this_file()
    local src = vim.fn.expand '%:p'
    local dst = vim.fn.input('Move to: ', src, 'file')
    if dst ~= '' and dst ~= src then
      vim.fn.system('mv ' .. vim.fn.shellescape(src) .. ' ' .. vim.fn.shellescape(dst))
      vim.cmd('edit ' .. vim.fn.fnameescape(dst))
      print('File moved to ' .. dst)
    end
  end

  local function yank_buffer_path(relative)
    local path = vim.fn.expand '%:p'
    if relative then path = vim.fn.fnamemodify(path, ':.') end
    vim.fn.setreg('+', path)
    print('Yanked: ' .. path)
  end

  -- NOTE this is heavily based on the explorer picker
  -- TODO move to its own picker module
  local function make_finder(cwd)
    ---@param opts snacks.picker.files.Config
    ---@param ctx snacks.picker.Context
    return function(opts, ctx)
      opts = Snacks.picker.util.shallow_copy(opts)

      -- constrain to single directory, include dirs in results
      opts.cmd = 'fd'
      opts.cwd = cwd
      opts.dirs = { cwd }
      opts.notify = false
      opts.args = {
        '--max-depth',
        '1', -- ← the key difference from M.search
        '--type',
        'd', -- dirs (files are default in files.lua)
        '--path-separator',
        '/',
      }

      local fd_stream = require('snacks.picker.source.files').files(opts, ctx)

      return function(cb)
        fd_stream(function(item)
          -- fd marks dirs with trailing slash
          local is_dir = item.file:sub(-1) == '/'
          if is_dir then
            item.file = item.file:sub(1, -2)
            item.dir = true
          end

          -- strip cwd prefix → basename only for display + matching
          local basename = item.file:match '[^/]+$' or item.file
          item.text = is_dir and (basename .. '/') or basename
          item.hidden = basename:sub(1, 1) == '.'

          -- simple sort: dirs before files, then alpha
          item.sort = is_dir and ('!' .. basename) or ('#' .. basename)

          cb(item)
        end)
      end
    end
  end
  local function has_extension(name) return name:match '%.[^./]+$' ~= nil end

  local function create_file(path)
    local dir = vim.fn.fnamemodify(path, ':h')
    vim.fn.mkdir(dir, 'p')
    local ok, err = pcall(vim.fn.writefile, {}, path)
    if not ok then
      vim.notify('Failed to create file: ' .. err, vim.log.levels.ERROR)
      return false
    end
    return true
  end

  local function create_directory(path)
    local ok = vim.fn.mkdir(path, 'p')
    if ok == 0 then
      vim.notify('Failed to create directory: ' .. path, vim.log.levels.ERROR)
      return false
    end
    return true
  end

  local function find_file_at(cwd)
    -- navigate into dir, re-using the picker instance
    local function navigate_to(picker, dir)
      cwd = vim.fn.resolve(dir)
      picker.opts.title = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~')
      picker.opts.finder = make_finder(cwd)
      picker.opts.cwd = cwd
      picker.input:set ''
      picker:find()
    end
    local create_dwim = function(state)
      local node = state.tree:get_node()

      -- get the directory to create in
      local dir
      if node.type == 'directory' then
        dir = node:get_id()
      else
        dir = vim.fn.fnamemodify(node:get_id(), ':h')
      end

      vim.ui.input({
        prompt = 'Create in ' .. vim.fn.fnamemodify(dir, ':~') .. ': ',
        completion = 'file',
      }, function(input)
        if not input or input == '' then return end

        local target = dir .. '/' .. input

        if input:match '%.[^./]+$' then
          -- has extension → create file
          vim.fn.mkdir(vim.fn.fnamemodify(target, ':h'), 'p')
          local ok, err = pcall(vim.fn.writefile, {}, target)
          if not ok then
            vim.notify('Failed to create file: ' .. err, vim.log.levels.ERROR)
            return
          end
          vim.notify('Created file: ' .. input)
          -- open the new file
          vim.schedule(function() vim.cmd.edit(target) end)
        else
          -- no extension → create directory
          local ok = vim.fn.mkdir(target, 'p')
          if ok == 0 then
            vim.notify('Failed to create directory: ' .. target, vim.log.levels.ERROR)
            return
          end
          vim.notify('Created directory: ' .. input)
        end

        -- refresh neo-tree so the new item appears
        require('neo-tree.sources.manager').refresh 'filesystem'
      end)
    end

    -- navigate to parent of current cwd
    local function navigate_up(picker)
      cwd = vim.fn.resolve(vim.fn.expand(cwd))
      local parent = vim.fn.fnamemodify(cwd, ':h')
      if parent ~= cwd then -- guard against filesystem root
        navigate_to(picker, parent)
      end
    end
    -- open neo-tree at cwd
    local function open_neotree(picker)
      cwd = picker:cwd()
      picker:close()
      vim.schedule(
        function() vim.cmd(('Neotree dir=%s reveal'):format(vim.fn.fnameescape(cwd))) end
      )
    end
    -- TODO make this it's own picker module
    Snacks.picker.pick {
      title = 'Find: ' .. vim.fn.fnamemodify(cwd, ':~'),
      finder = make_finder(cwd),

      -- text is now basename only → fuzzy match is scoped to current level
      -- this is exactly the vertico find-file behaviour
      format = 'file',
      formatters = { file = { filename_only = true } },
      actions = {
        yank_relative_cwd = function(_, item)
          local path = vim.fn.fnamemodify(item.file, ':.')
          vim.fn.setreg('+', path)
          vim.fn.setreg('"', path)
          vim.notify('Yanked: ' .. path)
        end,
        yank_relative_home = function(_, item)
          local path = vim.fn.fnamemodify(item.file, ':~')
          vim.fn.setreg('+', path)
          vim.fn.setreg('"', path)
          vim.notify('Yanked: ' .. path)
        end,
        -- DWIM backspace: no input → navigate up, else delete char
        dwim_backspace = function(picker)
          local search = picker.input:get() or ''
          print('backspace with ' .. search)
          if search == '' then
            local cwd = vim.fn.resolve(vim.fn.expand(cwd))
            print('find file at ' .. cwd .. ' parent ' .. vim.fs.dirname(cwd))
            find_file_at(vim.fs.dirname(cwd))
          else
            -- delegate to the built-in backspace behaviour
            vim.api.nvim_feedkeys(
              vim.api.nvim_replace_termcodes('<BS>', true, false, true),
              'n',
              false
            )
          end
        end,
      },

      confirm = function(picker, item)
        local search = picker.input:get() or ''

        -- no input at all → open neotree
        if search == '' then
          open_neotree(picker)
          return
        end

        -- item exists and is a directory → navigate into it
        if item and item.dir then
          print 'opening file dir'
          find_file_at(item.file)
          return
        end

        -- item exists and is a file → open it
        if item and not item.dir then
          print 'opening file'
          picker:close()
          vim.schedule(function() vim.cmd.edit(item.file) end)
          return
        end

        -- no matching item but there is input → vertico-style create
        -- treat the search string as the name to create
        if search ~= '' and not item then
          print 'creating new file'
          local target = cwd .. '/' .. search
          picker:close()
          vim.schedule(function()
            if has_extension(search) then
              -- has extension → create as file and open it
              if create_file(target) then vim.cmd.edit(target) end
            else
              -- no extension → create as directory, navigate into it
              if create_directory(target) then find_file_at(target) end
            end
          end)
          return
        end
      end,
      win = {
        input = {
          keys = {
            ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
            ['<a-j>'] = { 'list_down', mode = { 'n' } },
            ['<a-k>'] = { 'list_up', mode = { 'n' } },
            ['<BS>'] = { 'dwim_backspace', mode = { 'n', 'i' } },
            ['h'] = { 'dwim_backspace', mode = { 'n' } },
            ['<c-p>'] = { 'toggle_preview', mode = { 'n', 'i' } },
            ['<c-h>'] = { 'toggle_hidden', mode = { 'n', 'i' } },
            ['l'] = { 'confirm', mode = { 'n' } },
            ['<c-ESC>'] = { 'focus_list', mode = { 'n', 'i' } },
            ['<ESC>'] = { 'close', mode = { 'n' } },

            ['<c-+>'] = { 'create_dwim', mode = { 'n', 'i' } },
          },
        },
        list = {
          keys = {
            ['+'] = { 'create_dwim', mode = { 'n', 'i' } },
            ['.'] = 'explorer_focus',
            ['<BS>'] = 'explorer_up',
            ['<space>'] = 'select_and_next',
            ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
            ['<a-j>'] = { 'list_down', mode = { 'n' } },
            ['<a-k>'] = { 'list_up', mode = { 'n' } },
            ['a'] = 'explorer_add',
            ['<c-h>'] = { 'toggle_hidden', mode = { 'n', 'i' } },
            ['c'] = 'explorer_copy',
            ['d'] = 'explorer_del',
            ['l'] = 'explorer_focus',
            ['h'] = { 'explorer_up', mode = { 'n' } },
            ['i'] = { 'focus_input', mode = { 'n' } },
            ['m'] = 'explorer_move',
            ['r'] = 'explorer_rename',
            ['<c-o>'] = 'explorer_yank',
            ['y'] = 'yank_relative_cwd',
            ['Y'] = 'yank_relative_home',
          },
        },
      },

      layout = { preset = 'default', preview = false },
      focus = 'input',
    }
  end

  -- TODO add this with explorer
  local function vertico_style_explorer()
    local dir = vim.fn.expand '%:p:h'
    find_file_at(dir ~= '' and dir or vim.fn.getcwd())
  end

  vim.keymap.set(
    'n',
    '<leader>ff',
    vertico_style_explorer,
    { desc = 'Explore buffer directory (vertico style)' }
  )
  -- search for files in the same directory as the current buffer
  vim.keymap.set('n', '<leader>sd', function()
    local path = vim.fn.expand '%:p:h' -- current file's parent directory
    require('snacks').picker.files { cwd = path }
  end, { noremap = true })

  -- grep in the same directory as the current buffer
  vim.keymap.set('n', '<leader>sg', function()
    local path = vim.fn.expand '%:p:h'
    require('snacks').picker.grep { cwd = path }
  end, { noremap = true })
  vim.keymap.set(
    'n',
    '<leader>sf',
    vertico_style_explorer,
    { desc = 'Find file from buffer directory' }
  )
  vim.keymap.set('n', '<leader>fC', copy_this_file, { desc = 'Copy this file' })
  vim.keymap.set('n', '<leader>fD', delete_this_file, { desc = 'Delete this file' })
  vim.keymap.set('n', '<leader>fR', move_this_file, { desc = 'Rename/move this file' })
  vim.keymap.set('n', '<leader>fr', '<cmd>Telescope oldfiles<CR>', { desc = 'Recent files' })
  vim.keymap.set('n', '<leader>fs', '<cmd>w<CR>', { desc = 'Save file' })
  vim.keymap.set(
    'n',
    '<leader>fy',
    function() yank_buffer_path(false) end,
    { desc = 'Yank file path' }
  )
  vim.keymap.set(
    'n',
    '<leader>fY',
    function() yank_buffer_path(true) end,
    { desc = 'Yank relative file path' }
  )
end

return M
