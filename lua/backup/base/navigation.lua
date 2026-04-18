local M = {}
local IMG_PATH = vim.fn.expand '/home/reggiemarr/Pictures/Wallpapers/tent_in_nf.jpg'

M.dependencies = {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
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
}

M.opts = {
  neo_tree = {
    -- don't use a sidebar — open in whatever window called it
    window = {
      position = 'current',
    },

    filesystem = {
      -- follow the current buffer automatically
      follow_current_file = {
        enabled = false,
        leave_dirs_open = false,
      },
      close_if_last_window = true,
      use_libuv_file_watcher = true,
      group_empty_dirs = true, -- when true, empty folders will be grouped together
      hijack_netrw_behavior = 'open_default', -- netrw disabled, opening a directory opens neo-tree
      -- dired shows all files
      filtered_items = {
        visible = true, -- show hidden/filtered items, dimmed
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      -- true creates a 2-way binding between vim's cwd and neo-tree's root
      bind_to_cwd = false,
      commands = {
        open_or_set_root = function(state)
          local node = state.tree:get_node()

          if node.type == 'directory' then
            require('neo-tree.sources.filesystem.commands').set_root(state)
          else
            require('neo-tree.sources.filesystem.commands').open(state)
          end
        end,
        create_dwim = function(state)
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
        end,
      },

      -- when opening a file, use the window neo-tree displaced
      -- rather than splitting — pure buffer-swap like dired
      window = {
        mappings = {
          -- dired-style navigation
          ['<CR>'] = 'open', -- open file OR enter dir
          ['<Tab>'] = 'open',
          ['<SPC>sb'] = 'fuzzy_finder',
          ['l'] = 'open_or_set_root', -- also on l (ranger-style)
          ['h'] = 'navigate_up', -- go to parent dir
          ['-'] = 'navigate_up', -- emacs dired uses - for this
          ['q'] = 'close_window',
          ['<c-h>'] = 'toggle_hidden',
          ['R'] = 'refresh',
          ['?'] = 'show_help',
          ['+'] = 'create_dwim',

          -- dired file operations
          ['c'] = 'copy',
          -- ["m"]     = "move",
          ['d'] = 'delete',
          ['r'] = 'rename',
          ['a'] = 'add', -- create file
          ['A'] = 'add_directory', -- create dir
          ['yy'] = 'copy_to_clipboard',
          ['p'] = 'paste_from_clipboard',

          -- open without leaving neo-tree (dired's o)
          ['o'] = { 'open', config = { stay_in_tree = true } },
        },
        fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
          ['<down>'] = 'move_cursor_down',
          ['<up>'] = 'move_cursor_up',
          ['<esc>'] = 'close',
          ['<S-CR>'] = 'close_keep_filter',
          ['<C-CR>'] = 'close_clear_filter',
          ['<C-w>'] = { '<C-S-w>', raw = true },
          {
            -- normal mode mappings
            n = {
              ['j'] = 'move_cursor_down',
              ['k'] = 'move_cursor_up',
              ['<S-CR>'] = 'close_keep_filter',
              ['<C-CR>'] = 'close_clear_filter',
              ['<esc>'] = 'close',
            },
          },
        },
      },
    },
  },
  snacks = {
    dashboard = {
      enabled = true,
      preset = {
        keys = {
          { icon = ' ', key = 'a', desc = 'New File', action = ':ene | startinsert' },
          { icon = ' ', key = 'r', desc = 'Restore Session', section = 'session' },
          {
            icon = ' ',
            key = 'sf',
            desc = 'Find File',
            action = ":lua Snacks.dashboard.pick('files')",
          },
          {
            icon = ' ',
            key = 'sg',
            desc = 'Find Text',
            action = ":lua Snacks.dashboard.pick('live_grep')",
          },
          {
            icon = ' ',
            key = 'so',
            desc = 'Recent Files',
            action = ":lua Snacks.dashboard.pick('oldfiles')",
          },
          {
            icon = ' ',
            key = 'sc',
            desc = 'Config',
            action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
          },
          {
            icon = ' ',
            key = 'zm',
            desc = 'Mason',
            action = ':Mason',
          },
          {
            icon = '󰒲 ',
            key = 'zl',
            desc = 'Lazy',
            action = ':Lazy',
            enabled = package.loaded.lazy ~= nil,
          },
          {
            icon = '󰖟 ',
            key = 'o',
            desc = 'Open Repo',
            action = ':lua Snacks.gitbrowse()',
            enabled = function() return Snacks.git.get_root() ~= nil end,
          },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
        },
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
      },
      sections = {
        {
          enabled = function() return (vim.fn.executable 'chafa' == 1) and (vim.fn.filereadable(IMG_PATH) == 1) end,
          {
            section = 'terminal',
            cmd = 'chafa ' .. IMG_PATH .. ' --format symbols --symbols vhalf --size 60x17 --stretch',
            height = 17,
            padding = 1,
          },
          {
            pane = 2,
            { section = 'keys', gap = 1, padding = 1 },
            { section = 'startup' },
          },
        },
        {
          enabled = function() return not ((vim.fn.executable 'chafa' == 1) and (vim.fn.filereadable(IMG_PATH) == 1)) end,
          { section = 'header' },
          { section = 'keys', gap = 1, padding = 1 },
          { section = 'startup' },
        },
      },
    },
    picker = {
      enabled = true,
      -- layout = {
      --   preset = "ivy",
      --   layout = { title = "{title} {live} {flags} - {preview}" },
      -- },
      matcher = {
        frecency = true,
        history_bonus = true,
      },
      previewers = {
        diff = {
          style = 'terminal',
          cmd = { 'delta' },
        },
      },
      sources = {
        -- git_log = git_actions,
        -- git_log_file = git_actions,
        -- git_log_line = git_actions,
        -- rga = rga_source,
        -- astgrep = astgrep_source,
        explorer = {
          auto_close = true,
          layout = { preset = 'ivy', preview = true },
          matcher = { fuzzy = true },
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
            explorer_dwim = function(picker_state)
              local item = picker_state:current()
              if item then
                if item.dir then
                  -- Navigate into directory
                  picker_state:cd(item.file)
                else
                  -- Open file
                  vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
                  picker_state:close()
                end
              end
            end,
          },
          win = {
            input = {
              keys = {
                ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
                ['<a-j>'] = { 'list_down', mode = { 'n' } },
                ['<a-k>'] = { 'list_up', mode = { 'n' } },
                ['<BS>'] = { 'explorer_up', mode = { 'n' } },
                ['h'] = { 'explorer_up', mode = { 'n' } },
                ['c-p'] = { 'toggle_preview', mode = { 'n', 'i' } },
                ['l'] = { 'explorer_focus', mode = { 'n' } },
                ['<ESC>'] = { 'focus_list', mode = { 'n', 'i' } },
              },
            },
            list = {
              keys = {
                ['.'] = 'explorer_focus',
                ['<BS>'] = 'explorer_up',
                ['<space>'] = 'select_and_next',
                ['<Tab>'] = { 'confirm', mode = { 'n', 'i' } },
                ['<a-j>'] = { 'list_down', mode = { 'n' } },
                ['<a-k>'] = { 'list_up', mode = { 'n' } },
                ['a'] = 'explorer_add',
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
        },
      },
      -- debug = {
      --   scores = true,
      -- },
      transform = function(item)
        if not item.file then return item end

        -- Lower priority for files inside deps/
        if item.file:match 'deps/' then item.score_add = (item.score_add or 0) - 100 end

        return item
      end,
    },
    animate = {
      enabled = true,
      fps = 120,
    },
    bigfile = {
      enabled = true,
    },
    dim = {
      enabled = true,
    },
    explorer = {
      enabled = true,
      replace_netrw = true,
    },
    image = {
      enabled = true,
      doc = {
        inline = false,
        img_dirs = {
          'img',
          'images',
          'assets',
          'static',
          'public',
          'media',
          'attachments',
          'resources',
        },
      },
      math = {
        enabled = false,
      },
    },
    indent = {
      enabled = true,
      animate = {
        enabled = false,
      },
      scope = {
        enabled = true,
      },
    },
    input = {
      enabled = true,
    },
    lazygit = {
      enabled = true,
      theme = {
        selectedLineBgColor = { bg = 'CursorLine' },
      },
      -- Make fullscreen
      win = {
        width = 0,
        height = 0,
      },
    },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = {
      enabled = true,
    },
    scope = {
      enabled = true,
    },
    scratch = {
      enabled = true,
    },
    scroll = {
      enabled = false,
    },
    terminal = {
      enabled = true,
    },
    words = {
      enabled = true,
      debounce = 100,
    },
    zen = {
      enabled = true,
    },
    styles = {
      notification = {
        wo = { wrap = true }, -- Wrap notifications
      },
      snacks_image = {
        relative = 'editor',
        col = -1,
      },
    },
  },
}

-- TODO this comes from custom.files. Make this commonly accessible for both
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

  -- navigate to parent of current cwd
  local function navigate_up(picker)
    local parent = vim.fn.fnamemodify(cwd, ':h')
    if parent ~= cwd then -- guard against filesystem root
      navigate_to(picker, parent)
    end
  end
  -- open neo-tree at cwd
  local function open_neotree(picker)
    picker:close()
    vim.schedule(function() vim.cmd(('Neotree dir=%s reveal position=current'):format(vim.fn.fnameescape(cwd))) end)
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
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<BS>', true, false, true), 'n', false)
        end
      end,
    },

    confirm = function(picker, item)
      local search = picker.input:get() or ''

      -- no input at all → open neotree
      if search == '' and not item then
        open_neotree(picker)
        return
      end

      -- item exists and is a directory → navigate into it
      if item and item.dir and search ~= vim.fn.fnamemodify(item.file, ':t') then
        cwd = item.file
        find_file_at(cwd)
        return
      end

      -- item exists and is a file → open it
      if item and not item.dir then
        picker:close()
        vim.schedule(function() vim.cmd.edit(item.file) end)
        return
      end

      -- no matching item but there is input → vertico-style create
      -- treat the search string as the name to create
      if search ~= '' and not item then
        local target = cwd .. '/' .. search
        picker:close()
        vim.schedule(function()
          if search:match '%.[^./]+$' ~= nil then
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
        },
      },
      list = {
        keys = {
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

local function setup_file_support(augroup)
  require('neo-tree').setup(M.opts.neo_tree)
  require('snacks').setup(M.opts.snacks)

  -- [[ Neotree Autocommands ]]
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      if vim.fn.winnr '$' == 1 and vim.bo.filetype == 'neo-tree' then vim.cmd 'quit' end
    end,
  })

  -- Closes all terminal instances and automatically save a session leveraging persistance
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function(ev) pcall(vim.cmd, 'Neotree close') end,
  })

  -- Since neo-tree's mapping config doesn't support key sequences like this
  -- we have to add it manually
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'neo-tree',
    callback = function(ev)
      vim.keymap.set('n', '<leader>sf', function()
        local state = require('neo-tree.sources.manager').get_state_for_window()
        local node = state.tree:get_node()
        local path = node:get_id()
        find_file_at(path)
      end, { buffer = ev.buf, noremap = true })

      vim.keymap.set('n', '<leader>sg', function()
        local state = require('neo-tree.sources.manager').get_state_for_window()
        local node = state.tree:get_node()
        local path = node:get_id()

        -- if node is a file, search from its parent directory
        if node.type == 'file' then path = vim.fn.fnamemodify(path, ':h') end
        require('snacks').picker.grep { cwd = path }
      end, { buffer = ev.buf, noremap = true })
    end,
  })

  vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<cr>', { desc = 'Toggle Explorer' })

  -- search for files in the same directory as the current buffer
  vim.keymap.set('n', '<leader>sd', function()
    local path = vim.fn.expand '%:p:h' -- current file's parent directory
    require('snacks').picker.files { cwd = path }
  end, { noremap = true })

  -- Both keybindings to the same thing
  print 'Setup find file'

  vim.keymap.set('n', '<leader>ff', function()
    local dir = vim.fn.expand '%:p:h'
    find_file_at(dir ~= '' and dir or vim.fn.getcwd())
  end, { desc = 'Find file from buffer directory' })
  vim.keymap.set('n', '<leader>sf', function()
    local dir = vim.fn.expand '%:p:h'
    find_file_at(dir ~= '' and dir or vim.fn.getcwd())
  end, { desc = 'Find file from buffer directory' })
end

function setup_text_support(augroup)
  vim.keymap.set('n', '<leader>sb', function()
    local current_buf = vim.api.nvim_get_current_buf()
    local current_win = vim.api.nvim_get_current_win()

    require('snacks').picker.lines {
      buf = current_buf,
      layout = {
        preset = 'dropdown',
        preview = false,
        layout = {
          height = 0.4,
        },
      },
      -- Jump to line in original window as selection changes
      on_change = function(picker, item)
        if item and vim.api.nvim_win_is_valid(current_win) then
          vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
          vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
        end
      end,
      -- On confirm, jump to the selected line and close
      confirm = function(picker, item)
        picker:close()
        if item and vim.api.nvim_win_is_valid(current_win) then
          vim.api.nvim_win_set_cursor(current_win, { item.pos[1], 0 })
          vim.api.nvim_win_call(current_win, function() vim.cmd 'normal! zz' end)
        end
      end,
    }
  end, { desc = 'Search in buffer' })
end

-- ============================================================================
-- MAIN SETUP FUNCTION
-- ============================================================================
function M.setup()
  local augroup = vim.api.nvim_create_augroup('BaseNavigation', { clear = true })

  setup_file_support(augroup)
  setup_text_support(augroup)
end

return M
