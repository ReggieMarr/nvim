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
  optional_deps = { 'filesystem', 'text_editing' },

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
        -- Mirrors Doom's magit settings:
        --   (setq magit-diff-refine-hunk 'all)
        --   (setq magit-commit-show-diff t)
        --   (setq magit-pull-or-fetch t)
        graph_style = 'unicode',
        diff_viewer = 'codediff',
        integrations = {
          codediff  = true,
          mini_pick = false,
          snacks    = true,   -- use snacks.picker for Neogit finder UIs
          telescope = false,
          fzf_lua   = false,
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
    -- Sign column indicators, inline blame, hunk operations.
    -- on_attach registers keymaps via env.articulation so they appear in :ConfigStatus keys.
    -- Doom alignment: ]c/[c nav, SPC g s/u/x staging, SPC g p/b/d/D display, ih/ah textobjs
    ['lewis6991/gitsigns.nvim'] = {
      event = { 'BufReadPre', 'BufNewFile' },
      opts = {
        signs = {
          add          = { text = '│' },
          change       = { text = '│' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '~' },
          untracked    = { text = '┆' },
        },
        signs_staged = {
          add          = { text = '║' },
          change       = { text = '║' },
          delete       = { text = '═' },
          topdelete    = { text = '═' },
          changedelete = { text = '≈' },
        },
        signs_staged_enable  = true,
        signcolumn           = true,
        numhl                = false,
        linehl               = false,
        word_diff            = false,
        watch_gitdir         = { follow_files = true },
        auto_attach          = true,
        attach_to_untracked  = false,
        current_line_blame   = false, -- toggled via <leader>gb
        current_line_blame_opts = {
          virt_text     = true,
          virt_text_pos = 'eol',
          delay         = 500,
          ignore_whitespace = false,
          virt_text_formatter = function(name, info)
            if info.author == 'Not Committed Yet' then
              return { { '  Not committed yet', 'GitSignsCurrentLineBlame' } }
            end
            local dt = os.difftime(os.time(), info.author_time)
            local unit, val
            if     dt < 60      then unit, val = 'sec',   dt
            elseif dt < 3600    then unit, val = 'min',   math.floor(dt / 60)
            elseif dt < 86400   then unit, val = 'hr',    math.floor(dt / 3600)
            elseif dt < 2592000 then unit, val = 'day',   math.floor(dt / 86400)
            else                     unit, val = 'month', math.floor(dt / 2592000)
            end
            local t_str = string.format('%d %s%s ago', val, unit, val ~= 1 and 's' or '')
            local msg   = info.summary
            if #msg > 45 then msg = msg:sub(1, 42) .. '...' end
            return { { string.format('  %s, %s • %s', info.author, t_str, msg), 'GitSignsCurrentLineBlame' } }
          end,
        },
        preview_config = { border = 'rounded', style = 'minimal', relative = 'cursor', row = 0, col = 1 },

        on_attach = function(bufnr)
          local gs = require 'gitsigns'

          -- Guard: skip non-file buffers
          if not vim.api.nvim_buf_is_valid(bufnr) then return end
          if vim.bo[bufnr].buftype ~= '' then return end

          -- Helper: register a buffer-local action via articulation (sets keymap + records).
          -- Action IDs include bufnr so multiple buffers coexist without collision.
          local function act(lhs, mode, fn, desc)
            env.articulation.register {
              id       = string.format('version_control.%s_%d', desc:match('%.(.+)$') or desc, bufnr),
              handler  = fn,
              desc     = desc,
              module   = 'version_control',
              bindings = { { lhs = lhs, mode = mode, buffer = bufnr } },
            }
          end

          -- ── Hunk navigation (]c / [c — standard diff convention) ──────────
          -- In diff mode these become native ]c/[c; otherwise gitsigns
          act(']c', 'n', function()
            if vim.wo.diff then vim.cmd.normal { ']c', bang = true }
            else gs.nav_hunk 'next' end
          end, 'version_control.hunk_next')

          act('[c', 'n', function()
            if vim.wo.diff then vim.cmd.normal { '[c', bang = true }
            else gs.nav_hunk 'prev' end
          end, 'version_control.hunk_prev')

          -- ── Staging (Doom: SPC g s/u/x/S/X) ──────────────────────────────
          act('<leader>gs', 'n', function() gs.stage_hunk() end,                        'version_control.stage_hunk')
          act('<leader>gs', 'v', function() gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' } end, 'version_control.stage_hunk_visual')
          act('<leader>gu', 'n', gs.undo_stage_hunk,                                    'version_control.unstage_hunk')
          act('<leader>gx', 'n', function() gs.reset_hunk() end,                        'version_control.reset_hunk')
          act('<leader>gx', 'v', function() gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' } end, 'version_control.reset_hunk_visual')
          act('<leader>gS', 'n', gs.stage_buffer,                                       'version_control.stage_buffer')
          act('<leader>gX', 'n', gs.reset_buffer,                                       'version_control.reset_buffer')

          -- ── Display (Doom: SPC g p/b/d/D) ────────────────────────────────
          act('<leader>gp', 'n', gs.preview_hunk,                                       'version_control.preview_hunk')
          act('<leader>gb', 'n', gs.toggle_current_line_blame,                          'version_control.toggle_blame')
          act('<leader>gd', 'n', function() gs.diffthis() end,                          'version_control.diff_index')
          act('<leader>gD', 'n', function() gs.diffthis 'HEAD' end,                     'version_control.diff_head')

          -- ── Text objects (ih / ah — in/around hunk) ───────────────────────
          act('ih', { 'o', 'x' }, gs.select_hunk, 'version_control.textobj_hunk_inner')
          act('ah', { 'o', 'x' }, gs.select_hunk, 'version_control.textobj_hunk_outer')

          -- ── Hunk count state (feeds lualine diff indicator) ───────────────
          local function update_hunk_count()
            local hunks = gs.get_hunks(bufnr)
            env.state._update('vcs.hunk_count', hunks and #hunks or 0)
          end
          update_hunk_count()
          vim.api.nvim_create_autocmd({ 'BufWritePost', 'TextChanged' }, {
            buffer   = bufnr,
            group    = vim.api.nvim_create_augroup('env_vcs_hunk_count_' .. bufnr, { clear = true }),
            callback = update_hunk_count,
          })
          vim.api.nvim_create_autocmd('BufWipeout', {
            buffer   = bufnr,
            once     = true,
            callback = function() env.state._update('vcs.hunk_count', nil) end,
          })
        end,
      },
    },

    -- codediff.nvim: diff viewer used by Neogit
    ['esmuellert/codediff.nvim'] = {
      cmd = 'CodeDiff',
    },
  },

  -- ── Setup ─────────────────────────────────────────────────────────────

  setup = function()
    -- ── Display registrations ─────────────────────────────────────
    env.display.register { id = 'version_control.signs',        kind = 'signs',        module = 'version_control', desc = 'gitsigns — add/change/delete/untracked in sign column' }
    env.display.register { id = 'version_control.staged_signs', kind = 'signs',        module = 'version_control', desc = 'gitsigns — staged hunk indicators' }
    env.display.register { id = 'version_control.blame',        kind = 'virtual_text', module = 'version_control', desc = 'gitsigns — inline git blame (toggled via <leader>gb)' }

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

    -- ── Picker capability extensions ───────────────────────────────
    env.capabilities.extend('picker', {
      git_commits = function(o) require('snacks').picker.git_log(o) end,
      git_branches = function(o) require('snacks').picker.git_branches(o) end,
      git_status = function(o) require('snacks').picker.git_status(o) end,
      git_stash = function(o) require('snacks').picker.git_stash(o) end,
      git_log_file = function(o) require('snacks').picker.git_log_file(o) end,
      git_diff = function(o) require('snacks').picker.git_diff(o) end,
    }, 'version_control')

    -- ── global git operations ───────────────────────
    -- These are the primary entry points, mirroring Magit's SPC-g prefix.
    -- Buffer-local hunk operations are registered in gitsigns on_attach above.

    -- ── Version Control keymaps ─────────────────────────────────────
    local state = env.state.get()

    -- if not state['vcs.is_repo'] then return end

    ----------------------------------------------------------------
    -- Neogit
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>gg', '', {
      silent = true,
      callback = function() require('neogit').open() end,
      desc = 'version_control.status',
    })

    -- SPC g G is lazygit (terminal module)

    vim.keymap.set('n', '<leader>gc', '', {
      silent = true,
      callback = function() require('neogit').open { 'commit' } end,
      desc = 'version_control.commit',
    })

    vim.keymap.set('n', '<leader>gP', '', {
      silent = true,
      callback = function() require('neogit').open { 'push' } end,
      desc = 'version_control.push',
    })

    vim.keymap.set('n', '<leader>gF', '', {
      silent = true,
      callback = function() require('neogit').open { 'pull' } end,
      desc = 'version_control.pull',
    })

    vim.keymap.set('n', '<leader>gf', '', {
      silent = true,
      callback = function() require('neogit').open { 'fetch' } end,
      desc = 'version_control.fetch',
    })

    vim.keymap.set('n', '<leader>gB', '', {
      silent = true,
      callback = function() require('neogit').open { 'branch' } end,
      desc = 'version_control.branch',
    })

    vim.keymap.set('n', '<leader>gr', '', {
      silent = true,
      callback = function() require('neogit').open { 'rebase' } end,
      desc = 'version_control.rebase',
    })

    vim.keymap.set('n', '<leader>gz', '', {
      silent = true,
      callback = function() require('neogit').open { 'stash' } end,
      desc = 'version_control.stash',
    })

    vim.keymap.set('n', '<leader>gl', '', {
      silent = true,
      callback = function() require('neogit').open { 'log' } end,
      desc = 'version_control.log',
    })

    ----------------------------------------------------------------
    -- Diffview
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>gv', '', {
      silent = true,
      callback = function() vim.cmd 'DiffviewOpen' end,
      desc = 'version_control.diff_open',
    })

    ---Close diffview if open
    local function diff_close()
      for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.bo[buf].filetype
          if ft == 'DiffviewFiles' or ft == 'DiffviewFileHistory' then
            vim.cmd 'DiffviewClose'
            return
          end
        end
      end
    end

    vim.keymap.set('n', '<leader>gV', '', {
      silent = true,
      callback = diff_close,
      desc = 'version_control.diff_close',
    })

    vim.keymap.set('n', '<leader>gH', '', {
      silent = true,
      callback = function() vim.cmd 'DiffviewFileHistory' end,
      desc = 'version_control.repo_history',
    })

    ----------------------------------------------------------------
    -- Picker-based operations
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>gL', '', {
      silent = true,
      callback = function() env.use('picker').git_commits() end,
      desc = 'version_control.find_commits',
    })

    vim.keymap.set('n', '<leader>g<space>', '', {
      silent = true,
      callback = function() env.use('picker').git_branches() end,
      desc = 'version_control.find_branches',
    })

    vim.keymap.set('n', '<leader>gw', '', {
      silent = true,
      callback = function() env.use('picker').git_status() end,
      desc = 'version_control.find_status',
    })

    vim.keymap.set('n', '<leader>gZ', '', {
      silent = true,
      callback = function() env.use('picker').git_stash() end,
      desc = 'version_control.find_stash',
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
