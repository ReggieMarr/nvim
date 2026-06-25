-- lua/modules/workspace.lua
-- Workspace module: project management, session persistence, and context.
--
-- Mirrors Doom's projectile workflow:
--   SPC p p  — switch project (discover + recent, with session restore)
--   SPC p f  — find file in project
--   SPC p g  — grep in project
--   SPC p r  — recent files in project
--   SPC p b  — buffers in project
--   SPC p d  — browse project root (oil)
--   SPC p t  — terminal at project root
--   SPC p a  — agent at project root
--   SPC p !  — shell command at project root
--   SPC p s  — save project session
--   SPC p l  — load/list project sessions
--   SPC p k  — close all project buffers
--   SPC p e  — edit project-local config (.nvim.lua / .editorconfig)
--
-- Project discovery uses snacks.picker.projects which combines:
--   - fd-based scanning of configured dev directories
--   - git roots of recently opened files
--   - explicitly pinned project paths
--
-- Per-project sessions are saved/restored automatically:
--   - On project switch the previous session is saved, new one loaded
--   - Manual save/load for explicit checkpointing
--
-- Registers state:
--   workspace.root         — project root directory (LSP or marker-based)
--   workspace.project_name — basename of the root
--
-- Domain: workspace

local env = require 'env'

-- ── Shared project utilities ───────────────────────────────────────────

local markers = {
  '.git',
  '.hg',
  'Makefile',
  'package.json',
  'Cargo.toml',
  'pyproject.toml',
  'go.mod',
  'flake.nix',
  'CMakeLists.txt',
  'justfile',
}

--- Resolve project root: LSP root → marker detection → git root → cwd
local function detect_root()
  -- Prefer LSP-reported root
  local clients = vim.lsp.get_clients { bufnr = 0 }
  for _, client in ipairs(clients) do
    if client.config.root_dir then return client.config.root_dir end
  end

  -- Marker-based detection
  local path = vim.fn.expand '%:p:h'
  if path ~= '' then
    local root = vim.fs.root(path, markers)
    if root then return root end
  end

  -- Git root fallback
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error == 0 and git_root and git_root ~= '' then return git_root end

  return vim.fn.getcwd()
end

--- Canonical project root accessor for use by other modules.
--- Reads from env.state when available, falls back to detect_root().
local function project_root()
  return env.state.get 'workspace.root' or detect_root()
end

-- ── Session persistence ────────────────────────────────────────────────

local session_dir = vim.fn.stdpath 'data' .. '/sessions'

--- Encode a project path into a safe session filename.
---@param root string
---@return string
local function session_file(root)
  -- Replace path separators with double underscores for a flat filename
  local name = root:gsub('^/', ''):gsub('/', '__')
  return session_dir .. '/' .. name .. '.vim'
end

--- Save session for the given project root.
local function save_session(root)
  root = root or project_root()
  vim.fn.mkdir(session_dir, 'p')
  local file = session_file(root)
  -- Only save if we have real buffers open (don't save empty sessions)
  local has_bufs = false
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
      has_bufs = true
      break
    end
  end
  if has_bufs then
    vim.cmd('mksession! ' .. vim.fn.fnameescape(file))
  end
end

--- Load session for the given project root if one exists.
---@param root string
---@return boolean loaded  Whether a session was loaded
local function load_session(root)
  local file = session_file(root)
  if vim.fn.filereadable(file) == 1 then
    -- Close all current buffers cleanly before loading
    vim.cmd '%bdelete!'
    vim.cmd('silent! source ' .. vim.fn.fnameescape(file))
    return true
  end
  return false
end

--- Delete session for the given project root.
local function delete_session(root)
  local file = session_file(root)
  if vim.fn.filereadable(file) == 1 then
    os.remove(file)
    vim.notify('Deleted session for ' .. vim.fn.fnamemodify(root, ':t'), vim.log.levels.INFO)
  end
end

--- List all saved sessions as { root = path, name = basename, file = session_file } tables.
---@return table[]
local function list_sessions()
  local sessions = {}
  local files = vim.fn.glob(session_dir .. '/*.vim', false, true)
  for _, file in ipairs(files) do
    local name = vim.fn.fnamemodify(file, ':t:r')
    local root = '/' .. name:gsub('__', '/')
    table.insert(sessions, {
      root = root,
      name = vim.fn.fnamemodify(root, ':t'),
      file = file,
    })
  end
  -- Sort by modification time (most recent first)
  table.sort(sessions, function(a, b)
    local a_time = vim.fn.getftime(a.file)
    local b_time = vim.fn.getftime(b.file)
    return a_time > b_time
  end)
  return sessions
end

-- ── Module registration ────────────────────────────────────────────────

return env.module.register {
  name = 'workspace',
  domain = 'workspace',
  depends_on = {},
  optional_deps = { 'agents' },

  plugins = {},

  setup = function()
    local snacks = require 'snacks'

    -- ── State providers ─────────────────────────────────────────────
    env.state.register_provider {
      id = 'workspace.root',
      events = { 'BufEnter', 'LspAttach', 'DirChanged' },
      collect = detect_root,
      desc = 'Project root directory for the current buffer',
    }

    env.state.register_provider {
      id = 'workspace.project_name',
      events = { 'BufEnter', 'DirChanged' },
      collect = function()
        local root = env.state.get 'workspace.root' or vim.fn.getcwd()
        return vim.fn.fnamemodify(root, ':t')
      end,
      desc = 'Name of the current project (basename of root)',
    }

    -- ── LspAttach — immediate root update ───────────────────────────
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('workspace_lsp_root', { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.config.root_dir then
          env.state._update('workspace.root', client.config.root_dir)
          env.state._update('workspace.project_name', vim.fn.fnamemodify(client.config.root_dir, ':t'))
        end
      end,
    })

    -- ── Auto-save session on exit ───────────────────────────────────
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('workspace_session_save', { clear = true }),
      callback = function()
        local root = project_root()
        if root then save_session(root) end
      end,
      desc = 'Auto-save project session on exit',
    })

    -- ── Project switch helper ───────────────────────────────────────
    --- Switch to a project: save current session, cd, load target session.
    ---@param target_root string
    local function switch_project(target_root)
      -- Save current project's session
      local current_root = project_root()
      if current_root then save_session(current_root) end

      -- Change directory
      vim.fn.chdir(target_root)
      env.state._update('workspace.root', target_root)
      env.state._update('workspace.project_name', vim.fn.fnamemodify(target_root, ':t'))

      -- Try to load the target session, otherwise open the file finder
      if not load_session(target_root) then
        vim.schedule(function()
          snacks.picker.files {
            cwd   = target_root,
            title = 'Files — ' .. vim.fn.fnamemodify(target_root, ':t'),
          }
        end)
      end
    end

    -- ── Keymaps ─────────────────────────────────────────────────────

    ----------------------------------------------------------------
    -- SPC p p — Switch project (Doom: projectile-switch-project)
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pp', function()
      snacks.picker.projects {
        dev = {
          '~/Projects',
          '~/dev',
          '~/src',
          '~/repos',
          '~/work',
        },
        patterns = markers,
        recent   = true,
        confirm  = function(picker, item)
          if item then
            picker:close()
            switch_project(item.file)
          end
        end,
        title = 'Switch Project',
      }
    end, { desc = 'project.switch', silent = true })

    ----------------------------------------------------------------
    -- SPC p f — Find file in project (already exists in filesystem,
    --           duplicated here for completeness under SPC p)
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pf', function()
      local root = project_root()
      snacks.picker.files {
        cwd   = root,
        title = 'Project Files — ' .. vim.fn.fnamemodify(root, ':t'),
      }
    end, { desc = 'project.find_file', silent = true })

    ----------------------------------------------------------------
    -- SPC p g — Grep in project
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pg', function()
      local root = project_root()
      snacks.picker.grep {
        cwd   = root,
        title = 'Project Grep — ' .. vim.fn.fnamemodify(root, ':t'),
      }
    end, { desc = 'project.grep', silent = true })

    -- SPC s p — alias (Doom: +default/search-project)
    vim.keymap.set('n', '<leader>sp', function()
      local root = project_root()
      snacks.picker.grep {
        cwd   = root,
        title = 'Search Project — ' .. vim.fn.fnamemodify(root, ':t'),
      }
    end, { desc = 'project.search_project', silent = true })

    ----------------------------------------------------------------
    -- SPC p r — Recent files in project
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pr', function()
      local root = project_root()
      snacks.picker.recent {
        filter = { cwd = root },
        title  = 'Recent — ' .. vim.fn.fnamemodify(root, ':t'),
      }
    end, { desc = 'project.recent_files', silent = true })

    ----------------------------------------------------------------
    -- SPC p b — Buffers in project
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pb', function()
      local root = project_root()
      snacks.picker.buffers {
        filter = { cwd = root },
        title  = 'Buffers — ' .. vim.fn.fnamemodify(root, ':t'),
      }
    end, { desc = 'project.buffers', silent = true })

    ----------------------------------------------------------------
    -- SPC p d — Browse project root in oil (Doom: project-dired)
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pd', function()
      local root = project_root()
      require('oil').open(root)
    end, { desc = 'project.browse_root', silent = true })

    ----------------------------------------------------------------
    -- SPC p t — Terminal at project root
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pt', function()
      local root = project_root()
      snacks.terminal.toggle(vim.o.shell, {
        cwd = root,
        win = {
          position = 'float',
          border   = 'rounded',
          title    = ' Terminal — ' .. vim.fn.fnamemodify(root, ':t') .. ' ',
          title_pos = 'center',
          width    = 0.85,
          height   = 0.85,
        },
      })
    end, { desc = 'project.terminal', silent = true })

    ----------------------------------------------------------------
    -- SPC p a — Agent at project root
    -- If the agents module loaded, toggle the last agent at project root.
    -- Falls back to a plain terminal.
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pa', function()
      -- Try to use the agents module's keybinding
      local ok = pcall(vim.cmd, 'normal \\<leader>aa')
      if not ok then
        -- Fallback: open a terminal at project root
        local root = project_root()
        snacks.terminal.toggle(vim.o.shell, { cwd = root })
      end
    end, { desc = 'project.agent', silent = true })

    ----------------------------------------------------------------
    -- SPC p ! — Run shell command at project root
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>p!', function()
      local root = project_root()
      vim.ui.input({ prompt = 'Shell command (' .. vim.fn.fnamemodify(root, ':t') .. '): ' }, function(cmd)
        if not cmd or cmd == '' then return end
        snacks.terminal.open(cmd, {
          cwd = root,
          interactive = false,
          win = {
            position = 'float',
            border   = 'rounded',
            title    = ' ' .. cmd .. ' ',
            title_pos = 'center',
            width    = 0.8,
            height   = 0.6,
          },
        })
      end)
    end, { desc = 'project.shell_command', silent = true })

    ----------------------------------------------------------------
    -- SPC p s — Save project session
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>ps', function()
      local root = project_root()
      save_session(root)
      vim.notify('Session saved: ' .. vim.fn.fnamemodify(root, ':t'), vim.log.levels.INFO)
    end, { desc = 'project.save_session', silent = true })

    ----------------------------------------------------------------
    -- SPC p l — Load/list project sessions
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pl', function()
      local sessions = list_sessions()
      if #sessions == 0 then
        vim.notify('No saved sessions', vim.log.levels.INFO)
        return
      end

      vim.ui.select(
        sessions,
        {
          prompt = 'Load session:',
          format_item = function(item)
            local mtime = vim.fn.getftime(item.file)
            local ago = ''
            if mtime > 0 then
              local dt = os.time() - mtime
              if     dt < 3600    then ago = string.format('%dm ago', math.floor(dt / 60))
              elseif dt < 86400   then ago = string.format('%dh ago', math.floor(dt / 3600))
              else                     ago = string.format('%dd ago', math.floor(dt / 86400))
              end
            end
            return string.format('%s  (%s)  %s', item.name, ago, item.root)
          end,
        },
        function(choice)
          if choice then switch_project(choice.root) end
        end
      )
    end, { desc = 'project.load_session', silent = true })

    ----------------------------------------------------------------
    -- SPC p k — Kill all project buffers
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pk', function()
      local root = project_root()
      local count = 0
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
          local name = vim.api.nvim_buf_get_name(buf)
          if name ~= '' and vim.startswith(name, root) then
            vim.api.nvim_buf_delete(buf, { force = false })
            count = count + 1
          end
        end
      end
      vim.notify(string.format('Closed %d buffer(s) in %s', count, vim.fn.fnamemodify(root, ':t')), vim.log.levels.INFO)
    end, { desc = 'project.kill_buffers', silent = true })

    ----------------------------------------------------------------
    -- SPC p e — Edit project-local config
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pe', function()
      local root = project_root()
      -- Prefer .nvim.lua (Neovim's native exrc), fall back to .editorconfig
      local candidates = { '.nvim.lua', '.editorconfig', '.dir-locals.el' }
      for _, fname in ipairs(candidates) do
        local fpath = root .. '/' .. fname
        if vim.fn.filereadable(fpath) == 1 then
          vim.cmd.edit(fpath)
          return
        end
      end
      -- None found — create .nvim.lua
      local fpath = root .. '/.nvim.lua'
      vim.cmd.edit(fpath)
      if vim.fn.filereadable(fpath) == 0 then
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          '-- Project-local Neovim configuration',
          '-- This file is sourced automatically via vim.secure.read()',
          '-- See :help exrc',
          '',
        })
      end
    end, { desc = 'project.edit_config', silent = true })

    ----------------------------------------------------------------
    -- SPC p D — Delete project session
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pD', function()
      local root = project_root()
      delete_session(root)
    end, { desc = 'project.delete_session', silent = true })

    ----------------------------------------------------------------
    -- SPC p i — Project info (show root, name, session status)
    ----------------------------------------------------------------
    vim.keymap.set('n', '<leader>pi', function()
      local root = project_root()
      local name = vim.fn.fnamemodify(root, ':t')
      local has_session = vim.fn.filereadable(session_file(root)) == 1
      local bufs = 0
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
          local bname = vim.api.nvim_buf_get_name(buf)
          if bname ~= '' and vim.startswith(bname, root) then bufs = bufs + 1 end
        end
      end
      local lines = {
        '── Project ──────────────────────────────────────────',
        '  Name:     ' .. name,
        '  Root:     ' .. root,
        '  Buffers:  ' .. bufs,
        '  Session:  ' .. (has_session and '✓ saved' or '✗ none'),
      }
      vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, { desc = 'project.info', silent = true })
  end,
}
