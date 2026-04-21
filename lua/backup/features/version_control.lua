local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  -- Magit-style git interface
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim', -- optional but enables picker integration
    },
    cmd = { 'Neogit' },
    keys = { '<leader>gg', '<leader>gc', '<leader>gp', '<leader>gP' },
    event = 'VeryLazy',
  },

  -- Diff viewer and merge tool
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = {
      'DiffviewOpen',
      'DiffviewClose',
      'DiffviewToggleFiles',
      'DiffviewFocusFiles',
      'DiffviewFileHistory',
      'DiffviewRefresh',
    },
  },

  -- Gutter signs, hunk staging, inline blame
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
  },

  -- Conflict resolution UI
  {
    'akinsho/git-conflict.nvim',
    version = '*',
    event = { 'BufReadPost', 'BufNewFile' },
  },

  -- Per-line commit message popup
  {
    'rhysd/git-messenger.vim',
    keys = { '<leader>gm' },
    cmd = { 'GitMessenger' },
  },

  -- Permalink generation (GitHub / GitLab / Gitea / Forgejo)
  {
    'linrongbin16/gitlinker.nvim',
    cmd = { 'GitLink' },
    keys = { '<leader>gl', '<leader>gL' },
  },
}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

-- Diff/merge layout constants
local DIFF_LAYOUT = 'diff2_horizontal' -- options: diff1_plain, diff2_horizontal,
--          diff2_vertical, diff3_horizontal,
--          diff4_mixed

-- ============================================================================
-- NEOGIT SETUP
-- ============================================================================
function M.setup_neogit()
  require('neogit').setup {
    -- -----------------------------------------------------------------------
    -- Behaviour
    -- -----------------------------------------------------------------------
    -- Disable the built-in commit editor in favour of a proper split buffer
    disable_commit_confirmation = false,
    disable_builtin_notifications = false,
    disable_hint = false,
    disable_context_highlighting = false,
    disable_signs = false,
    disable_insert_on_commit = 'auto',

    -- Auto-fetch on open (set false if on a slow/metered link)
    fetch_after_checkout = true,

    -- Graph style: 'ascii' | 'unicode' (unicode looks nicer, ascii is safer)
    graph_style = 'unicode',

    -- -----------------------------------------------------------------------
    -- Integrations
    -- -----------------------------------------------------------------------
    integrations = {
      -- Use diffview.nvim for all diff operations
      diffview = true,
      -- Use telescope for branch/remote pickers
      telescope = true,
      -- fzf-lua fallback (set true if you ever switch to fzf)
      fzf_lua = false,
    },

    -- -----------------------------------------------------------------------
    -- UI
    -- -----------------------------------------------------------------------
    -- Open Neogit in a tab (like Magit's full-frame mode)
    -- Options: 'tab' | 'replace' | 'floating' | 'split' | 'split_above' | 'vsplit' | 'auto'
    kind = 'tab',

    -- Commit popup in a split rather than a float
    commit_editor = {
      kind = 'split',
      show_staged_diff = true,
      staged_diff_split_kind = 'vsplit',
    },

    -- Commit select view
    commit_select_view = { kind = 'tab' },

    -- Log view
    log_view = { kind = 'tab' },

    -- Rebase editor
    rebase_editor = { kind = 'split' },

    -- Reflog view
    reflog_view = { kind = 'tab' },

    -- Merge editor
    merge_editor = { kind = 'split' },

    -- Preview window for diffs in status buffer
    preview_buffer = { kind = 'split' },

    -- Popup window
    popup = { kind = 'split' },

    -- Signs shown in the status buffer
    signs = {
      -- { CLOSED, OPENED }
      hunk = { '', '' },
      item = { '›', '⌄' },
      section = { '›', '⌄' },
    },

    -- -----------------------------------------------------------------------
    -- Sections shown in the status buffer (mirrors Magit's status)
    -- -----------------------------------------------------------------------
    sections = {
      -- Untracked files
      untracked = {
        folded = false,
        hidden = false,
      },
      -- Unstaged changes
      unstaged = {
        folded = false,
        hidden = false,
      },
      -- Staged changes
      staged = {
        folded = false,
        hidden = false,
      },
      -- Stashes
      stashes = {
        folded = true,
        hidden = false,
      },
      -- Unpulled from upstream
      unpulled_upstream = {
        folded = true,
        hidden = false,
      },
      -- Unmerged into upstream
      unmerged_upstream = {
        folded = false,
        hidden = false,
      },
      -- Unpulled from pushremote
      unpulled_pushremote = {
        folded = true,
        hidden = false,
      },
      -- Unmerged into pushremote
      unmerged_pushremote = {
        folded = false,
        hidden = false,
      },
      -- Recent commits
      recent = {
        folded = true,
        hidden = false,
      },
      -- Rebase status
      rebase = {
        folded = false,
        hidden = false,
      },
    },

    -- -----------------------------------------------------------------------
    -- Mappings inside the Neogit status buffer
    -- -----------------------------------------------------------------------
    mappings = {
      -- Finder (branch/commit pickers)
      finder = {
        ['<cr>'] = 'Select',
        ['<c-c>'] = 'Close',
        ['<esc>'] = 'Close',
        ['<c-n>'] = 'Next',
        ['<c-p>'] = 'Previous',
        ['<c-k>'] = 'Previous',
        ['<c-j>'] = 'Next',
        ['<tab>'] = 'MultiselectToggleNext',
        ['<s-tab>'] = 'MultiselectTogglePrevious',
      },

      -- Status buffer
      status = {
        -- Navigation
        ['k'] = 'MoveUp',
        ['j'] = 'MoveDown',
        ['q'] = 'Close',
        ['o'] = 'OpenTree',
        -- ['?'] = 'HelpPopup',

        -- Git operations (mirrors Magit mnemonics)
        ['s'] = 'Stage',
        ['S'] = 'StageUnstaged',
        ['<c-s>'] = 'StageAll',
        ['u'] = 'Unstage',
        ['U'] = 'UnstageStaged',
        -- ['d'] = 'DiffAtFile',
        -- ['D'] = 'DiffPopup',
        ['x'] = 'Discard',
        ['<cr>'] = 'Toggle',
        ['<tab>'] = 'Toggle',
        ['1'] = 'Depth1',
        ['2'] = 'Depth2',
        ['3'] = 'Depth3',
        ['4'] = 'Depth4',

        -- Popups
        -- ['b'] = 'BranchPopup',
        -- ['B'] = 'BisectPopup',
        -- ['c'] = 'CommitPopup',
        -- ['f'] = 'FetchPopup',
        -- ['l'] = 'LogPopup',
        -- ['m'] = 'MergePopup',
        -- ['p'] = 'PullPopup',
        -- ['P'] = 'PushPopup',
        -- ['r'] = 'RebasePopup',
        -- ['R'] = 'RemotePopup',
        -- ['t'] = 'TagPopup',
        -- ['T'] = 'RevertPopup',
        -- ['v'] = 'ResetPopup',
        -- ['w'] = 'WorktreePopup',
        -- ['W'] = 'CherryPickPopup',
        -- ['Z'] = 'StashPopup',
        -- ['X'] = 'RunPopup',

        -- Refresh
        ['<f5>'] = 'RefreshBuffer',
        ['gr'] = 'RefreshBuffer',
      },
    },
  }
end

-- ============================================================================
-- DIFFVIEW SETUP
-- ============================================================================
function M.setup_diffview()
  local actions = require 'diffview.actions'

  require('diffview').setup {
    diff_binaries = false,
    enhanced_diff_hl = true, -- extra highlights for changed regions within lines
    git_cmd = { 'git' },
    hg_cmd = { 'hg' },
    use_icons = true,

    -- Show icons in file panel
    show_help_hints = true,
    watch_index = true, -- auto-refresh when index changes

    -- -----------------------------------------------------------------------
    -- Layout
    -- -----------------------------------------------------------------------
    view = {
      -- Two-panel horizontal diff (old | new)
      default = {
        layout = DIFF_LAYOUT,
        winbar_info = true,
      },
      -- Three-way merge layout
      merge_tool = {
        layout = 'diff3_horizontal',
        disable_diagnostics = true, -- keep merge view clean
        winbar_info = true,
      },
      -- File history layout
      file_history = {
        layout = DIFF_LAYOUT,
        winbar_info = true,
      },
    },

    -- -----------------------------------------------------------------------
    -- File panel (left sidebar)
    -- -----------------------------------------------------------------------
    file_panel = {
      listing_style = 'tree', -- 'list' | 'tree'
      tree_options = {
        flatten_dirs = true, -- collapse single-child dirs
        folder_statuses = 'only_folded',
      },
      win_config = {
        position = 'left',
        width = 35,
        win_opts = {},
      },
    },

    -- -----------------------------------------------------------------------
    -- File history panel (bottom strip)
    -- -----------------------------------------------------------------------
    file_history_panel = {
      log_options = {
        git = {
          single_file = {
            diff_merges = 'combined',
            follow = true, -- follow renames (critical for refactored embedded code)
          },
          multi_file = {
            diff_merges = 'first-parent',
          },
        },
      },
      win_config = {
        position = 'bottom',
        height = 14,
        win_opts = {},
      },
    },

    -- -----------------------------------------------------------------------
    -- Conflict markers style
    -- -----------------------------------------------------------------------
    conflict_markers = {
      enabled = true,
      ancestor_style = 'diff3',
    },

    -- -----------------------------------------------------------------------
    -- Hooks
    -- -----------------------------------------------------------------------
    hooks = {
      -- Keep diff view clean
      diff_buf_read = function(bufnr)
        vim.opt_local.wrap = false
        vim.opt_local.list = false
        vim.opt_local.colorcolumn = ''
        vim.opt_local.relativenumber = false
      end,

      -- Focus the file panel on open
      view_opened = function(view) vim.notify('Diffview: ' .. view.class:name(), vim.log.levels.INFO, { title = 'version-control' }) end,
    },

    -- -----------------------------------------------------------------------
    -- Keymaps inside diffview buffers
    -- -----------------------------------------------------------------------
    keymaps = {
      disable_defaults = false,

      view = {
        { 'n', '<tab>', actions.select_next_entry, { desc = 'Next file' } },
        { 'n', '<s-tab>', actions.select_prev_entry, { desc = 'Prev file' } },
        { 'n', 'gf', actions.goto_file_edit, { desc = 'Open in prev win' } },
        { 'n', '<C-w><C-f>', actions.goto_file_split, { desc = 'Open in split' } },
        { 'n', '<C-w>gf', actions.goto_file_tab, { desc = 'Open in tab' } },
        { 'n', '<leader>e', actions.focus_files, { desc = 'Focus file panel' } },
        { 'n', '<leader>b', actions.toggle_files, { desc = 'Toggle file panel' } },
        -- Cycle layout: useful to flip between 2-panel and unified
        { 'n', 'g<C-x>', actions.cycle_layout, { desc = 'Cycle diff layout' } },
        -- Hunk navigation
        { 'n', '[x', actions.prev_conflict, { desc = 'Prev conflict' } },
        { 'n', ']x', actions.next_conflict, { desc = 'Next conflict' } },
        -- Conflict resolution (choose ours / theirs / both)
        { 'n', '<leader>co', actions.conflict_choose 'ours', { desc = 'Conflict: ours' } },
        { 'n', '<leader>ct', actions.conflict_choose 'theirs', { desc = 'Conflict: theirs' } },
        { 'n', '<leader>cb', actions.conflict_choose 'base', { desc = 'Conflict: base' } },
        { 'n', '<leader>ca', actions.conflict_choose 'all', { desc = 'Conflict: all' } },
        { 'n', '<leader>cX', actions.conflict_choose 'none', { desc = 'Conflict: none' } },
      },

      file_panel = {
        { 'n', 'j', actions.next_entry, { desc = 'Next file' } },
        { 'n', 'k', actions.prev_entry, { desc = 'Prev file' } },
        { 'n', '<cr>', actions.select_entry, { desc = 'Open diff' } },
        { 'n', 's', actions.toggle_stage_entry, { desc = 'Stage/unstage' } },
        { 'n', 'S', actions.stage_all, { desc = 'Stage all' } },
        { 'n', 'U', actions.unstage_all, { desc = 'Unstage all' } },
        { 'n', 'X', actions.restore_entry, { desc = 'Restore file' } },
        { 'n', 'R', actions.refresh_files, { desc = 'Refresh' } },
        { 'n', 'L', actions.open_commit_log, { desc = 'Commit log' } },
        { 'n', 'i', actions.listing_style, { desc = 'Toggle list/tree' } },
        { 'n', 'f', actions.toggle_flatten_dirs, { desc = 'Toggle flatten dirs' } },
        { 'n', '<tab>', actions.select_next_entry, { desc = 'Next file' } },
        { 'n', '<s-tab>', actions.select_prev_entry, { desc = 'Prev file' } },
        { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } },
        { 'n', '?', actions.help 'file_panel', { desc = 'Help' } },
      },

      file_history_panel = {
        { 'n', 'j', actions.next_entry, { desc = 'Next entry' } },
        { 'n', 'k', actions.prev_entry, { desc = 'Prev entry' } },
        { 'n', '<cr>', actions.select_entry, { desc = 'Open diff' } },
        { 'n', 'y', actions.copy_hash, { desc = 'Copy commit hash' } },
        { 'n', 'L', actions.open_commit_log, { desc = 'Show commit' } },
        { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close' } },
        { 'n', '?', actions.help 'file_history_panel', { desc = 'Help' } },
      },
    },
  }
end

-- ============================================================================
-- GITSIGNS SETUP
-- ============================================================================
function M.setup_gitsigns()
  require('gitsigns').setup {
    -- -----------------------------------------------------------------------
    -- Signs in the gutter
    -- -----------------------------------------------------------------------
    signs = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '▁' },
      topdelete = { text = '▔' },
      changedelete = { text = '▎' },
      untracked = { text = '▎' },
    },

    -- Signs for staged hunks (second sign column)
    signs_staged = {
      add = { text = '▎' },
      change = { text = '▎' },
      delete = { text = '▁' },
      topdelete = { text = '▔' },
      changedelete = { text = '▎' },
    },
    signs_staged_enable = true,

    -- -----------------------------------------------------------------------
    -- Behaviour
    -- -----------------------------------------------------------------------
    signcolumn = true,
    numhl = false, -- highlight line numbers instead of signs
    linehl = false, -- highlight whole line
    word_diff = false, -- inline word-level diff (toggle with keymap)
    watch_gitdir = {
      follow_files = true,
    },
    auto_attach = true,
    attach_to_untracked = true,

    -- Show blame at end of line while in insert mode (like VS Code)
    current_line_blame = false, -- toggled via keymap
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = 'eol',
      delay = 600,
      ignore_whitespace = true,
      virt_text_priority = 100,
    },
    current_line_blame_formatter = ' <author>, <author_time:%Y-%m-%d> · <summary>',

    sign_priority = 6,
    update_debounce = 100,
    status_formatter = nil,
    max_file_length = 40000, -- disable for very large generated files
    preview_config = {
      border = 'rounded',
      style = 'minimal',
      relative = 'cursor',
      row = 0,
      col = 1,
    },

    -- -----------------------------------------------------------------------
    -- Keymaps (defined inside on_attach for buffer-local scoping)
    -- -----------------------------------------------------------------------
    on_attach = function(bufnr)
      local gs = require 'gitsigns'
      local map = function(mode, lhs, rhs, opts)
        opts = vim.tbl_extend('force', { buffer = bufnr }, opts or {})
        vim.keymap.set(mode, lhs, rhs, opts)
      end

      -- ── Hunk navigation ────────────────────────────────────────────────
      map('n', ']h', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gs.nav_hunk 'next'
        end
      end, { desc = 'Git: Next Hunk' })

      map('n', '[h', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gs.nav_hunk 'prev'
        end
      end, { desc = 'Git: Prev Hunk' })

      map('n', ']H', function() gs.nav_hunk 'last' end, { desc = 'Git: Last Hunk' })
      map('n', '[H', function() gs.nav_hunk 'first' end, { desc = 'Git: First Hunk' })

      -- ── Staging ────────────────────────────────────────────────────────
      map({ 'n', 'v' }, '<leader>hs', '<cmd>Gitsigns stage_hunk<cr>', { desc = 'Git: Stage Hunk' })
      map({ 'n', 'v' }, '<leader>hr', '<cmd>Gitsigns reset_hunk<cr>', { desc = 'Git: Reset Hunk' })
      map('n', '<leader>hS', gs.stage_buffer, { desc = 'Git: Stage Buffer' })
      map('n', '<leader>hR', gs.reset_buffer, { desc = 'Git: Reset Buffer' })
      map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'Git: Undo Stage Hunk' })

      -- ── Preview ────────────────────────────────────────────────────────
      map('n', '<leader>hp', gs.preview_hunk, { desc = 'Git: Preview Hunk' })
      map('n', '<leader>hP', gs.preview_hunk_inline, { desc = 'Git: Preview Hunk Inline' })

      -- ── Blame ──────────────────────────────────────────────────────────
      map('n', '<leader>hb', function() gs.blame_line { full = true } end, { desc = 'Git: Blame Line (full)' })
      map('n', '<leader>hB', gs.toggle_current_line_blame, { desc = 'Git: Toggle Inline Blame' })

      -- ── Diff ───────────────────────────────────────────────────────────
      map('n', '<leader>hd', gs.diffthis, { desc = 'Git: Diff This' })
      map('n', '<leader>hD', function() gs.diffthis '~' end, { desc = 'Git: Diff This ~' })

      -- ── Toggles ────────────────────────────────────────────────────────
      map('n', '<leader>hw', gs.toggle_word_diff, { desc = 'Git: Toggle Word Diff' })
      map('n', '<leader>hx', gs.toggle_deleted, { desc = 'Git: Toggle Deleted' })

      -- ── Text objects ───────────────────────────────────────────────────
      map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<cr>', { desc = 'Git: Select Hunk' })
      map({ 'o', 'x' }, 'ah', ':<C-U>Gitsigns select_hunk<cr>', { desc = 'Git: Select Hunk (outer)' })
    end,
  }
end

-- ============================================================================
-- GIT-CONFLICT SETUP
-- ============================================================================
function M.setup_git_conflict()
  require('git-conflict').setup {
    default_mappings = false, -- we define our own below
    default_commands = true,
    disable_diagnostics = true, -- don't show LSP errors inside conflict markers
    list_opener = 'copen',
    highlights = {
      incoming = 'DiffAdd',
      current = 'DiffText',
      ancestor = 'DiffChange',
    },
  }

  -- Buffer-local conflict keymaps (active only when conflicts are detected)
  vim.api.nvim_create_autocmd('User', {
    pattern = 'GitConflictDetected',
    callback = function(ev)
      local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { buffer = ev.buf, desc = desc }) end

      map('<leader>co', '<Plug>(git-conflict-ours)', 'Conflict: Choose Ours')
      map('<leader>ct', '<Plug>(git-conflict-theirs)', 'Conflict: Choose Theirs')
      map('<leader>cb', '<Plug>(git-conflict-base)', 'Conflict: Choose Base')
      map('<leader>ca', '<Plug>(git-conflict-both)', 'Conflict: Choose Both')
      map('<leader>cX', '<Plug>(git-conflict-none)', 'Conflict: Choose None')
      map(']x', '<Plug>(git-conflict-next-conflict)', 'Conflict: Next')
      map('[x', '<Plug>(git-conflict-prev-conflict)', 'Conflict: Prev')
      map('<leader>cq', '<cmd>GitConflictListQf<cr>', 'Conflict: List in QF')

      vim.notify('Merge conflicts detected — <leader>c* to resolve', vim.log.levels.WARN, { title = 'version-control' })
    end,
  })
end

-- ============================================================================
-- GIT-MESSENGER SETUP
-- ============================================================================
function M.setup_git_messenger()
  -- Configuration via globals (plugin uses g: vars)
  vim.g.git_messenger_no_default_mappings = true
  vim.g.git_messenger_always_into_popup = true
  vim.g.git_messenger_include_diff = 'current' -- 'none' | 'current' | 'all'
  vim.g.git_messenger_max_popup_height = 30
  vim.g.git_messenger_max_popup_width = 80
  vim.g.git_messenger_floating_win_opts = { border = 'rounded' }
  vim.g.git_messenger_popup_content_margins = true
  -- Show the diff of the commit that last touched this line
  vim.g.git_messenger_date_format = '%Y-%m-%d %H:%M'
end

-- ============================================================================
-- GITLINKER SETUP
-- ============================================================================
function M.setup_gitlinker()
  require('gitlinker').setup {
    opts = {
      -- Open the link in the browser as well as copying it
      action_callback = require('gitlinker.actions').copy_to_clipboard,
      print_url = true,
    },
    callbacks = {
      -- Add your self-hosted Gitea/Forgejo instance here if needed:
      -- ['git.mycompany.com'] = require('gitlinker.hosts').get_gitea_type_url,
    },
    -- Default mapping (we override below in setup_keymaps)
    mappings = nil,
  }
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Open Neogit status (Magit-style  SPC g g)
function M.open_neogit(opts) require('neogit').open(opts or {}) end

-- Open Neogit for a specific cwd (useful for monorepos or submodules)
function M.open_neogit_cwd()
  vim.ui.input({ prompt = 'Git root: ', default = vim.fn.getcwd(), completion = 'dir' }, function(dir)
    if dir and dir ~= '' then require('neogit').open { cwd = dir } end
  end)
end

-- Toggle diffview (open if closed, close if open)
function M.toggle_diffview()
  local lib = require 'diffview.lib'
  local view = lib.get_current_view()
  if view then
    vim.cmd 'DiffviewClose'
  else
    vim.cmd 'DiffviewOpen'
  end
end

-- File history for current file
function M.file_history() vim.cmd 'DiffviewFileHistory %' end

-- File history for visual selection (range)
function M.file_history_range()
  -- works in visual mode: passes the line range to DiffviewFileHistory
  vim.cmd "'<,'>DiffviewFileHistory %"
end

-- Open diffview against a specific branch/commit
function M.diff_against()
  vim.ui.input({ prompt = 'Diff against (branch/commit/tag): ', default = 'HEAD~1' }, function(ref)
    if ref and ref ~= '' then vim.cmd('DiffviewOpen ' .. ref) end
  end)
end

-- Quick commit with message inline (for small WIP commits)
function M.quick_commit()
  vim.ui.input({ prompt = 'Commit message: ' }, function(msg)
    if msg and msg ~= '' then
      -- Stage everything modified and commit
      vim.fn.system 'git add -u'
      local result = vim.fn.system('git commit -m ' .. vim.fn.shellescape(msg))
      vim.notify(result, vim.log.levels.INFO, { title = 'version-control' })
    end
  end)
end

-- Copy the current branch name to the clipboard
function M.copy_branch_name()
  local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD'):gsub('\n', '')
  if branch == '' or branch:match '^fatal' then
    vim.notify('Not in a git repository', vim.log.levels.WARN, { title = 'version-control' })
    return
  end
  vim.fn.setreg('+', branch)
  vim.notify('Copied branch: ' .. branch, vim.log.levels.INFO, { title = 'version-control' })
end

-- Show a compact git log in a floating window (quick overview)
function M.show_git_log()
  local lines = vim.fn.systemlist 'git log --oneline --graph --decorate --color=never -30'
  if #lines == 0 then
    vim.notify('No git log available', vim.log.levels.WARN, { title = 'version-control' })
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'git'

  local width = math.min(100, vim.o.columns - 8)
  local height = math.min(#lines + 2, 30)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' git log ',
    title_pos = 'center',
  })

  -- Close with q or Esc
  for _, key in ipairs { 'q', '<Esc>' } do
    vim.keymap.set('n', key, function() vim.api.nvim_win_close(win, true) end, { buffer = buf, nowait = true, desc = 'Close git log' })
  end
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup('VersionControl', { clear = true })

  -- Set good defaults for git-related buffers
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = { 'gitcommit', 'gitrebase', 'NeogitCommitMessage' },
    callback = function()
      -- Wrap at 72 chars (git convention)
      vim.opt_local.textwidth = 72
      vim.opt_local.colorcolumn = '73'
      vim.opt_local.spell = true
      vim.opt_local.spelllang = 'en_us'
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      -- Start in insert mode for commit messages
      vim.cmd 'startinsert'
    end,
  })

  -- Refresh gitsigns / neogit after a shell command that may have changed git state
  vim.api.nvim_create_autocmd('FocusGained', {
    group = augroup,
    callback = function()
      -- Only do this if we are in a git repo
      if vim.fn.finddir('.git', vim.fn.getcwd() .. ';') ~= '' then
        vim.cmd 'checktime'
        pcall(require('gitsigns').refresh)
      end
    end,
  })

  -- After writing any file, refresh gitsigns for that buffer
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = augroup,
    callback = function() pcall(require('gitsigns').refresh) end,
  })

  -- Recognise .env files as gitignore-pattern files for syntax
  vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
    group = augroup,
    pattern = { '.gitignore', '.git/info/exclude' },
    callback = function() vim.bo.filetype = 'gitignore' end,
  })
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  local map = vim.keymap.set

  -- ── Neogit (Magit-style) ──────────────────────────────────────────────
  map('n', '<leader>gg', function() M.open_neogit() end, { desc = 'Git: Status (Neogit)' })
  map('n', '<leader>gG', function() M.open_neogit { kind = 'vsplit' } end, { desc = 'Git: Status (vsplit)' })
  map('n', '<leader>g.', M.open_neogit_cwd, { desc = 'Git: Status (custom cwd)' })
  map('n', '<leader>gc', function() M.open_neogit { 'commit' } end, { desc = 'Git: Commit' })
  map('n', '<leader>gp', function() M.open_neogit { 'pull' } end, { desc = 'Git: Pull' })
  map('n', '<leader>gP', function() M.open_neogit { 'push' } end, { desc = 'Git: Push' })
  map('n', '<leader>gr', function() M.open_neogit { 'rebase' } end, { desc = 'Git: Rebase' })
  map('n', '<leader>gQ', M.quick_commit, { desc = 'Git: Quick Commit' })

  -- ── Diffview ──────────────────────────────────────────────────────────
  map('n', '<leader>gd', M.toggle_diffview, { desc = 'Git: Toggle Diffview' })
  map('n', '<leader>gD', M.diff_against, { desc = 'Git: Diff Against Ref' })
  map('n', '<leader>gh', M.file_history, { desc = 'Git: File History' })
  map('v', '<leader>gh', M.file_history_range, { desc = 'Git: File History (range)' })
  map('n', '<leader>gH', '<cmd>DiffviewFileHistory<cr>', { desc = 'Git: Repo History' })

  -- ── Gitsigns (hunk-level ops defined in on_attach above) ─────────────
  -- Top-level toggles accessible outside on_attach
  map('n', '<leader>gb', '<cmd>Gitsigns toggle_current_line_blame<cr>', { desc = 'Git: Toggle Blame' })
  map('n', '<leader>gw', '<cmd>Gitsigns toggle_word_diff<cr>', { desc = 'Git: Toggle Word Diff' })

  -- ── Utilities ─────────────────────────────────────────────────────────
  map('n', '<leader>gm', '<cmd>GitMessenger<cr>', { desc = 'Git: Commit at Cursor' })
  map('n', '<leader>gl', function() require('gitlinker').get_buf_range_url 'n' end, { desc = 'Git: Copy Permalink' })
  map('v', '<leader>gl', function() require('gitlinker').get_buf_range_url 'v' end, { desc = 'Git: Copy Permalink (range)' })
  map('n', '<leader>gL', M.show_git_log, { desc = 'Git: Log (float)' })
  map('n', '<leader>gB', M.copy_branch_name, { desc = 'Git: Copy Branch Name' })
end

-- ============================================================================
-- MAIN SETUP
-- ============================================================================
function M.setup()
  M.setup_neogit()
  M.setup_diffview()
  M.setup_gitsigns()
  M.setup_git_conflict()
  M.setup_git_messenger()
  M.setup_gitlinker()
  M.setup_autocmds()
  M.setup_keymaps()
end

return M
