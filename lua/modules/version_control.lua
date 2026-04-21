-- lua/modules/version_control.lua
-- Version control module: git integration via Neogit, gitsigns, and diffview.
--
-- Neogit provides the primary git interface, closely mirroring Magit's
-- workflow: status buffer, transient popups for operations, interactive
-- staging, and commit editing.
--
-- gitsigns provides the buffer-level display layer: sign column indicators,
-- inline blame, and hunk-level navigation and staging from within files.
--
-- diffview.nvim provides the diff and merge conflict resolution surface.
--
-- Provides:
--   No new capabilities (consumes picker, notifier)
--
-- Extends capabilities:
--   picker — git-specific finders (commits, branches, status, stash)
--
-- Registers state:
--   vcs.branch          — current branch name
--   vcs.status          — working tree status summary
--   vcs.head_commit     — HEAD commit hash and message
--   vcs.is_repo         — whether cwd is inside a git repo
--   vcs.hunk_count      — number of changed hunks in current buffer
--
-- Registers display:
--   version_control.signs        — gitsigns sign column indicators
--   version_control.blame        — inline git blame virtual text
--   version_control.hunk_preview — hunk preview float
--
-- Domain: version_control

local env = require 'env'

-- ── Shared git utility ─────────────────────────────────────────────────
-- Thin wrapper around vim.system for synchronous git queries.
-- Used by state providers. Async variants use vim.system callbacks directly.
local function git(args, opts)
  local result = vim.system(vim.list_extend({ 'git' }, args), vim.tbl_extend('force', { text = true }, opts or {})):wait()
  if result.code ~= 0 then return nil end
  return result.stdout and result.stdout:gsub('%s+$', '') or nil
end

-- ── Module registration ────────────────────────────────────────────────

return env.module.register {
  name = 'version_control',
  domain = 'version_control',
  depends_on = { 'interface' },
  optional_deps = { 'filesystem', 'language' },

  -- ── Plugin option contributions ──────────────────────────────────────

  plugins = {
    -- Neogit: Magit-inspired git interface
    -- https://github.com/NeogitOrg/neogit
    ['NeogitOrg/neogit'] = {
      dependencies = {
        'nvim-lua/plenary.nvim',
        'sindrets/diffview.nvim',
      },
      cmd = { 'Neogit' },
      opts = {
        graph_style = 'unicode',
        diff_viewer = 'codediff',
        integrations = {
          codediff = true,
          mini_pick = true,
          snacks = false,
          telescope = false,
          fzf_lua = false,
        },
        sections = {
          untracked = { folded = false, hidden = false },
          unstaged = { folded = false, hidden = false },
          staged = { folded = false, hidden = false },
          stashes = { folded = true, hidden = false },
          unpulled_upstream = { folded = true, hidden = false },
          unmerged_upstream = { folded = false, hidden = false },
          unpulled_pushRemote = { folded = true, hidden = false },
          unmerged_pushRemote = { folded = false, hidden = false },
          recent = { folded = true, hidden = false },
          rebase = { folded = false, hidden = false },
        },
        commit_editor = {
          kind = 'replace',
          show_staged_diff = true,
          staged_diff_split_kind = 'vsplit',
        },
        popup = {
          kind = 'replace',
        },
        kind = 'replace',
        disable_hint = false,
        auto_refresh = true,
        status = {
          recent_commit_count = 10,
        },
        use_default_keymaps = true,
        auto_show_console = true,
        mappings = {
          finder = {
            ['<CR>'] = 'Select',
            ['<C-c>'] = 'Close',
            ['<Esc>'] = 'Close',
          },
          -- Only valid status commands from the validator list:
          status = {
            ['<tab>'] = 'Toggle',
            ['<space>'] = 'Stage',
            ['s'] = 'Stage',
            ['S'] = 'StageAll',
            ['u'] = 'Unstage',
            ['<CR>'] = 'OpenOrScrollDown',
            ['q'] = 'Close',
            ['x'] = 'Discard',
          },
        },
      },
    },

    -- gitsigns: buffer-level git integration
    -- Sign column indicators, inline blame, hunk operations
    -- ['lewis6991/gitsigns.nvim'] = {
    --   event = { 'BufReadPre', 'BufNewFile' },
    --   opts = {
    --     signs = {
    --       add = { text = '│' },
    --       change = { text = '│' },
    --       delete = { text = '_' },
    --       topdelete = { text = '‾' },
    --       changedelete = { text = '~' },
    --       untracked = { text = '┆' },
    --     },
    --     signs_staged = {
    --       add = { text = '║' },
    --       change = { text = '║' },
    --       delete = { text = '═' },
    --       topdelete = { text = '═' },
    --       changedelete = { text = '≈' },
    --     },
    --     signs_staged_enable = true,
    --     signcolumn = true,
    --     numhl = false,
    --     linehl = false,
    --     word_diff = false,
    --     watch_gitdir = { follow_files = true },
    --     auto_attach = true,
    --     attach_to_untracked = false,
    --     current_line_blame = false, -- toggled via action, off by default
    --     current_line_blame_opts = {
    --       virt_text = true,
    --       virt_text_pos = 'eol',
    --       delay = 500,
    --       ignore_whitespace = false,
    --       virt_text_formatter = function(name, blame_info)
    --         -- Format: "Author, N days ago • message"
    --         if blame_info.author == 'Not Committed Yet' then return { { '  Not committed yet', 'GitSignsCurrentLineBlame' } } end
    --         local date_time = os.difftime(os.time(), blame_info.author_time)
    --         local unit, value
    --         if date_time < 60 then
    --           unit, value = 'sec', date_time
    --         elseif date_time < 3600 then
    --           unit, value = 'min', math.floor(date_time / 60)
    --         elseif date_time < 86400 then
    --           unit, value = 'hr', math.floor(date_time / 3600)
    --         elseif date_time < 2592000 then
    --           unit, value = 'day', math.floor(date_time / 86400)
    --         else
    --           unit, value = 'month', math.floor(date_time / 2592000)
    --         end
    --         local time_str = string.format('%d %s%s ago', value, unit, value ~= 1 and 's' or '')
    --         local msg = blame_info.summary
    --         if #msg > 45 then msg = msg:sub(1, 42) .. '...' end
    --         return {
    --           {
    --             string.format('  %s, %s • %s', blame_info.author, time_str, msg),
    --             'GitSignsCurrentLineBlame',
    --           },
    --         }
    --       end,
    --     },
    --     preview_config = {
    --       border = 'rounded',
    --       style = 'minimal',
    --       relative = 'cursor',
    --       row = 0,
    --       col = 1,
    --     },
    --     -- Gitsigns callback: fires when gitsigns attaches to a buffer.
    --     -- Used to register buffer-local hunk navigation actions
    --     -- and update env.state with hunk information.
    --     on_attach = function(bufnr)
    --       local gs = require 'gitsigns'
    --
    --       -- Guard: don't attach to non-file buffers
    --       -- gitsigns calls on_attach for any buffer it tracks but
    --       -- we only want to register actions for real file buffers
    --       if not vim.api.nvim_buf_is_valid(bufnr) then return end
    --       if vim.bo[bufnr].buftype ~= '' then return end
    --
    --       -- Safe hunk count: get_hunks returns nil before initial diff completes
    --       local function update_hunk_count()
    --         local hunks = gs.get_hunks(bufnr)
    --         env.state._update('vcs.hunk_count', hunks and #hunks or 0)
    --       end
    --
    --       update_hunk_count()
    --
    --       -- Refresh hunk count when the buffer changes
    --       -- Use a buffer-local autocmd so it cleans up when the buffer is wiped
    --       vim.api.nvim_create_autocmd({ 'BufWritePost', 'TextChanged' }, {
    --         buffer = bufnr,
    --         group = vim.api.nvim_create_augroup('env_vcs_hunk_count_' .. bufnr, { clear = true }),
    --         callback = update_hunk_count,
    --       })
    --
    --       -- Buffer-local action registration.
    --       -- Action IDs are suffixed with the bufnr to avoid duplicate ID warnings
    --       -- when multiple buffers are open simultaneously.
    --       -- The desc remains human-readable without the suffix.
    --       local function buf_id(name) return string.format('version_control.%s_%d', name, bufnr) end
    --
    --       -- Helper: register a single buffer-local action cleanly
    --       -- Reduces repetition in the registrations below
    --       local function buf_action(name, handler, desc, lhs, extra_bindings, when)
    --         local bindings = { { lhs = lhs, buffer = bufnr } }
    --         if extra_bindings then
    --           for _, b in ipairs(extra_bindings) do
    --             b.buffer = bufnr
    --             table.insert(bindings, b)
    --           end
    --         end
    --
    --         require('lib.articulation').register {
    --           id = buf_id(name),
    --           handler = handler,
    --           desc = desc,
    --           module = 'version_control',
    --           bindings = bindings,
    --           when = when,
    --           buffer = bufnr,
    --         }
    --       end
    --
    --       -- Hunk navigation
    --       buf_action('hunk_next', function()
    --         if vim.wo.diff then
    --           vim.cmd.normal { ']c', bang = true }
    --         else
    --           gs.nav_hunk 'next'
    --         end
    --       end, 'Next hunk', ']c')
    --
    --       buf_action('hunk_prev', function()
    --         if vim.wo.diff then
    --           vim.cmd.normal { '[c', bang = true }
    --         else
    --           gs.nav_hunk 'prev'
    --         end
    --       end, 'Previous hunk', '[c')
    --
    --       -- -- Hunk staging
    --       -- buf_action('stage_hunk', function() gs.stage_hunk() end, 'Stage hunk', '<leader>gs', { { lhs = '<leader>gs', mode = 'v' } })
    --       --
    --       -- buf_action('unstage_hunk', gs.undo_stage_hunk, 'Unstage hunk', '<leader>gu')
    --       --
    --       -- buf_action('reset_hunk', function() gs.reset_hunk() end, 'Reset hunk to HEAD', '<leader>gx', { { lhs = '<leader>gx', mode = 'v' } })
    --       --
    --       -- buf_action('stage_buffer', gs.stage_buffer, 'Stage entire buffer', '<leader>gS')
    --       --
    --       -- buf_action('reset_buffer', gs.reset_buffer, 'Reset entire buffer to HEAD', '<leader>gX')
    --       --
    --       -- -- Hunk display
    --       -- buf_action('preview_hunk', gs.preview_hunk, 'Preview hunk diff', '<leader>gp')
    --       --
    --       -- buf_action('toggle_blame', gs.toggle_current_line_blame, 'Toggle inline git blame', '<leader>gb')
    --       --
    --       -- -- Diff
    --       -- buf_action('diff_this', function() gs.diffthis() end, 'Diff buffer against index', '<leader>gd')
    --       --
    --       -- buf_action('diff_this_head', function() gs.diffthis 'HEAD' end, 'Diff buffer against HEAD', '<leader>gD')
    --       --
    --       -- -- Text objects
    --       -- buf_action('textobj_hunk', function() gs.select_hunk() end, 'Select hunk as text object', 'ih', { { lhs = 'ah', mode = { 'o', 'x' } } }, nil)
    --       -- -- Fix: the primary binding above only registers "ih"
    --       -- -- "ah" needs its own registration for the alternate text object
    --       -- require('lib.articulation').register {
    --       --   id = buf_id 'textobj_hunk_outer',
    --       --   handler = function() gs.select_hunk() end,
    --       --   desc = 'Select hunk as text object (outer)',
    --       --   module = 'version_control',
    --       --   bindings = {
    --       --     { lhs = 'ah', buffer = bufnr, mode = { 'o', 'x' } },
    --       --   },
    --       -- }
    --
    --       -- Clean up buffer-local state when the buffer is wiped
    --       vim.api.nvim_create_autocmd('BufWipeout', {
    --         buffer = bufnr,
    --         once = true,
    --         callback = function()
    --           -- Remove this buffer's hunk count from state
    --           -- so stale data doesn't persist
    --           env.state._update('vcs.hunk_count', nil)
    --         end,
    --       })
    --     end,
    --   },
    -- },

    -- diffview.nvim: file history and merge conflict resolution
    -- Provides the diff view surface used by Neogit
    ['esmuellert/codediff.nvim'] = {
      cmd = 'CodeDiff',
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────

  setup = function()
    -- ── State providers ────────────────────────────────────────────
    -- vcs.branch: already referenced by lualine in interface module.
    -- Collected via async git call to avoid blocking on startup.
    env.state.register_provider {
      id = 'vcs.branch',
      events = { 'BufEnter', 'FocusGained', 'DirChanged', 'User' },
      pattern = { '*', 'NeogitStatusRefreshed' },
      collect = function()
        -- Return cached value immediately, update async
        vim.system({ 'git', 'branch', '--show-current' }, { text = true }, function(result)
          if result.code == 0 and result.stdout then env.state._update('vcs.branch', result.stdout:gsub('%s+$', '')) end
        end)
        return env.state.get 'vcs.branch'
      end,
      desc = 'Current git branch name',
    }

    env.state.register_provider {
      id = 'vcs.is_repo',
      events = { 'BufEnter', 'DirChanged' },
      collect = function()
        local result = vim.system({ 'git', 'rev-parse', '--is-inside-work-tree' }, { text = true }):wait()
        return result.code == 0
      end,
      desc = 'Whether the current directory is inside a git repo',
    }

    env.state.register_provider {
      id = 'vcs.head_commit',
      events = { 'User', 'BufEnter' },
      pattern = { 'NeogitStatusRefreshed', 'NeogitCommitComplete', '*' },
      collect = function()
        local hash = git { 'rev-parse', '--short', 'HEAD' }
        local msg = git { 'log', '-1', '--format=%s' }
        if not hash then return nil end
        return { hash = hash, message = msg or '' }
      end,
      desc = 'HEAD commit hash and subject line',
    }

    env.state.register_provider {
      id = 'vcs.status',
      events = { 'BufWritePost', 'User' },
      pattern = { '*', 'NeogitStatusRefreshed' },
      collect = function()
        -- Porcelain v2 gives structured output
        local result = vim.system({ 'git', 'status', '--porcelain=v2', '--branch' }, { text = true }):wait()
        if result.code ~= 0 or not result.stdout then return nil end

        local staged, unstaged, untracked, conflicts = 0, 0, 0, 0
        for line in result.stdout:gmatch '[^\n]+' do
          if line:match '^1 ' or line:match '^2 ' then
            local xy = line:match '^[12] (%S%S)'
            if xy then
              if xy:sub(1, 1) ~= '.' then staged = staged + 1 end
              if xy:sub(2, 2) ~= '.' then unstaged = unstaged + 1 end
            end
          elseif line:match '^u ' then
            conflicts = conflicts + 1
          elseif line:match '^? ' then
            untracked = untracked + 1
          end
        end

        return {
          staged = staged,
          unstaged = unstaged,
          untracked = untracked,
          conflicts = conflicts,
          clean = (staged + unstaged + untracked + conflicts) == 0,
        }
      end,
      desc = 'Working tree status summary (staged/unstaged/untracked counts)',
    }

    -- ── Display contributions ──────────────────────────────────────
    env.display.register {
      id = 'version_control.signs',
      module = 'version_control',
      region = 'signs',
      priority = 90,
      desc = 'Gitsigns add/change/delete indicators in sign column',
      when = function(state) return state['vcs.is_repo'] == true and state['buffer.is_real'] == true end,
    }

    env.display.register {
      id = 'version_control.blame',
      module = 'version_control',
      region = 'virtual_text',
      priority = 70,
      desc = 'Inline git blame on current line',
      when = function(state)
        -- Only show blame in real file buffers inside a repo
        return state['vcs.is_repo'] == true and state['buffer.is_real'] == true
      end,
    }

    env.display.register {
      id = 'version_control.conflict_markers',
      module = 'version_control',
      region = 'highlight',
      priority = 110, -- above diagnostics: conflicts must be visible
      desc = 'Merge conflict marker highlighting',
      when = function(state)
        local status = state['vcs.status']
        return status ~= nil and status.conflicts > 0
      end,
      on_enable = function()
        -- When conflicts exist, open diffview merge tool automatically
        -- if not already in a diffview buffer
        if vim.bo.filetype ~= 'DiffviewFiles' then vim.notify('Merge conflicts detected. Use <leader>gM to open merge tool.', vim.log.levels.WARN) end
      end,
    }

    -- ── Picker capability extensions ───────────────────────────────
    env.capabilities.extend('picker', {
      git_commits = function(o) require('snacks').picker.git_log(o) end,
      git_branches = function(o) require('snacks').picker.git_branches(o) end,
      git_status = function(o) require('snacks').picker.git_status(o) end,
      git_stash = function(o) require('snacks').picker.git_stash(o) end,
      git_log_file = function(o) require('snacks').picker.git_log_file(o) end,
      git_diff = function(o) require('snacks').picker.git_diff(o) end,
    }, 'version_control')

    -- ── Articulation: global git operations ───────────────────────
    -- These are the primary entry points, mirroring Magit's SPC-g prefix.
    -- Buffer-local hunk operations are registered in gitsigns on_attach above.
    env.articulation.register_group_label('<leader>g', 'git')

    env.articulation.register_group('version_control', {

      -- ── Neogit: the Magit equivalent entry points ─────────────
      {
        id = 'version_control.status',
        handler = function() require('neogit').open() end,
        desc = 'Open Neogit status  (Magit equivalent)',
        bindings = {
          { lhs = '<leader>gg' }, -- primary: matches Magit's SPC-g-g muscle memory
          { lhs = '<leader>gG' }, -- alternate for consistency
        },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.commit',
        handler = function() require('neogit').open { 'commit' } end,
        desc = 'Open Neogit commit popup',
        bindings = { { lhs = '<leader>gc' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.push',
        handler = function() require('neogit').open { 'push' } end,
        desc = 'Open Neogit push popup',
        bindings = { { lhs = '<leader>gP' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.pull',
        handler = function() require('neogit').open { 'pull' } end,
        desc = 'Open Neogit pull popup',
        bindings = { { lhs = '<leader>gF' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.fetch',
        handler = function() require('neogit').open { 'fetch' } end,
        desc = 'Open Neogit fetch popup',
        bindings = { { lhs = '<leader>gf' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.branch',
        handler = function() require('neogit').open { 'branch' } end,
        desc = 'Open Neogit branch popup',
        bindings = { { lhs = '<leader>gB' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.rebase',
        handler = function() require('neogit').open { 'rebase' } end,
        desc = 'Open Neogit rebase popup',
        bindings = { { lhs = '<leader>gr' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.stash',
        handler = function() require('neogit').open { 'stash' } end,
        desc = 'Open Neogit stash popup',
        bindings = { { lhs = '<leader>gz' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.log',
        handler = function() require('neogit').open { 'log' } end,
        desc = 'Open Neogit log popup',
        bindings = { { lhs = '<leader>gl' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },

      -- ── Diffview: diff and file history ───────────────────────
      {
        id = 'version_control.diff_open',
        handler = function() vim.cmd 'DiffviewOpen' end,
        desc = 'Open diffview for working tree',
        bindings = { { lhs = '<leader>gv' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.diff_close',
        handler = function() vim.cmd 'DiffviewClose' end,
        desc = 'Close diffview',
        bindings = { { lhs = '<leader>gV' } },
        when = function(state)
          -- Only show this action when diffview is actually open
          for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
              local buf = vim.api.nvim_win_get_buf(win)
              local ft = vim.bo[buf].filetype
              if ft == 'DiffviewFiles' or ft == 'DiffviewFileHistory' then return true end
            end
          end
          return false
        end,
      },
      {
        id = 'version_control.file_history',
        handler = function() vim.cmd 'DiffviewFileHistory %' end,
        desc = 'File history for current buffer',
        bindings = { { lhs = '<leader>gh' } },
        when = function(state) return state['vcs.is_repo'] == true and state['buffer.is_real'] == true end,
      },
      {
        id = 'version_control.repo_history',
        handler = function() vim.cmd 'DiffviewFileHistory' end,
        desc = 'File history for entire repo',
        bindings = { { lhs = '<leader>gH' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.merge_tool',
        handler = function() vim.cmd 'DiffviewOpen HEAD' end,
        desc = 'Open merge conflict resolution tool',
        bindings = { { lhs = '<leader>gM' } },
        when = function(state)
          local status = state['vcs.status']
          return status ~= nil and status.conflicts > 0
        end,
      },

      -- ── Picker-based git operations ────────────────────────────
      {
        id = 'version_control.find_commits',
        handler = function() env.use('picker').git_commits() end,
        desc = 'Browse git commit log',
        bindings = { { lhs = '<leader>gL' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.find_branches',
        handler = function() env.use('picker').git_branches() end,
        desc = 'Find and switch git branches',
        bindings = { { lhs = '<leader>g<space>' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.find_status',
        handler = function() env.use('picker').git_status() end,
        desc = 'Browse changed files (git status)',
        bindings = { { lhs = '<leader>gw' } },
        when = function(state) return state['vcs.is_repo'] == true end,
      },
      {
        id = 'version_control.find_stash',
        handler = function() env.use('picker').git_stash() end,
        desc = 'Browse git stash',
        bindings = { { lhs = '<leader>gZ' } },
        when = function(state)
          local status = state['vcs.status']
          return state['vcs.is_repo'] == true
        end,
      },
      {
        id = 'version_control.find_file_commits',
        handler = function() env.use('picker').git_log_file() end,
        desc = 'Browse commits for current file',
        bindings = { { lhs = '<leader>gk' } },
        when = function(state) return state['vcs.is_repo'] == true and state['buffer.is_real'] == true end,
      },
    })

    -- ── Neogit autocmds: feed events back into env.state ──────────
    -- Neogit emits User events after operations complete.
    -- We use these to refresh vcs state immediately rather than
    -- waiting for the next BufEnter trigger.
    local vc_augroup = vim.api.nvim_create_augroup('env_version_control', { clear = true })

    vim.api.nvim_create_autocmd('User', {
      group = vc_augroup,
      pattern = {
        'NeogitStatusRefreshed',
        'NeogitCommitComplete',
        'NeogitPushComplete',
        'NeogitFetchComplete',
        'NeogitPullComplete',
        'NeogitRebaseComplete',
      },
      callback = function()
        -- Force immediate refresh of git state after Neogit operations
        vim.schedule(function()
          -- Branch
          vim.system({ 'git', 'branch', '--show-current' }, { text = true }, function(r)
            if r.code == 0 then env.state._update('vcs.branch', r.stdout:gsub('%s+$', '')) end
          end)
          -- HEAD commit
          local hash = git { 'rev-parse', '--short', 'HEAD' }
          local msg = git { 'log', '-1', '--format=%s' }
          if hash then env.state._update('vcs.head_commit', {
            hash = hash,
            message = msg or '',
          }) end
        end)
      end,
    })
  end,
}
