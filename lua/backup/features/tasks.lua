local M = {}

-- ============================================================================
-- PLUGIN DEPENDENCIES
-- ============================================================================
M.dependencies = {
  -- Task runner / build system
  {
    'stevearc/overseer.nvim',
    cmd = {
      'OverseerRun',
      'OverseerToggle',
      'OverseerOpen',
      'OverseerClose',
      'OverseerInfo',
      'OverseerBuild',
      'OverseerQuickAction',
      'OverseerTaskAction',
      'OverseerClearCache',
    },
    event = { 'BufReadPost', 'BufNewFile' },
  },
  -- Auto-formatter
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
  },
  -- Linting
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPost', 'BufWritePost', 'BufNewFile' },
  },
}

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local FORMATTERS = {
  -- Systems
  rust = { 'rustfmt' },
  c = { 'clang_format' },
  cpp = { 'clang_format' },
  -- Scripting
  python = { 'ruff_format', 'black' },
  bash = { 'shfmt' },
  sh = { 'shfmt' },
  -- Config / Data
  lua = { 'stylua' },
  json = { 'jq' },
  yaml = { 'yamlfmt' },
  toml = { 'taplo' },
  -- Markup
  markdown = { 'prettier' },
}

local LINTERS = {
  -- Systems
  c = { 'cppcheck' },
  cpp = { 'cppcheck' },
  python = { 'ruff' },
  bash = { 'shellcheck' },
  sh = { 'shellcheck' },
  -- Config
  yaml = { 'yamllint' },
  -- Markup
  markdown = { 'markdownlint' },
}

-- ============================================================================
-- CONFORM (FORMATTER) SETUP
-- ============================================================================
function M.setup_conform()
  local conform = require 'conform'

  conform.setup {
    -- Map filetypes to formatters. First available formatter wins
    -- unless stop_after_first = false.
    formatters_by_ft = FORMATTERS,

    -- -------------------------------------------------------------------------
    -- Format-on-save
    -- -------------------------------------------------------------------------
    format_on_save = function(bufnr)
      -- Disable for buffers where we've opted out
      if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then return nil end

      -- Disable for large files
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
      if ok and stats and stats.size > 200 * 1024 then
        vim.notify('tasks: skipping format-on-save for large file', vim.log.levels.WARN)
        return nil
      end

      return {
        timeout_ms = 3000,
        lsp_fallback = true, -- Fall back to LSP formatting if no formatter found
      }
    end,

    -- -------------------------------------------------------------------------
    -- Formatter-specific overrides
    -- -------------------------------------------------------------------------
    formatters = {
      -- Rust: honour project-level rustfmt.toml
      rustfmt = {
        args = { '--edition', '2021', '--emit=stdout' },
      },

      -- Python: only use black if ruff_format isn't available
      black = {
        prepend_args = { '--line-length', '88' },
      },

      ruff_format = {
        prepend_args = { '--line-length', '88' },
      },

      -- Shell: indent with spaces, simplify syntax
      shfmt = {
        prepend_args = { '-i', '2', '-ci' },
      },

      -- JSON: 2-space indent
      jq = {
        prepend_args = { '--indent', '2' },
      },

      -- Stylua: use project config when available, else sane defaults
      stylua = {
        prepend_args = {
          '--indent-type',
          'Spaces',
          '--indent-width',
          '2',
          '--column-width',
          '100',
        },
      },

      -- Prettier: consistent prose wrapping
      prettier = {
        prepend_args = { '--prose-wrap', 'always', '--print-width', '80' },
      },
    },

    -- Show a notification when formatting takes longer than expected
    notify_on_error = true,
  }
end

-- ============================================================================
-- NVIM-LINT SETUP
-- ============================================================================
function M.setup_lint()
  local lint = require 'lint'

  lint.linters_by_ft = LINTERS

  -- -------------------------------------------------------------------------
  -- Linter overrides
  -- -------------------------------------------------------------------------
  -- Point cppcheck at the compile_commands.json when present
  lint.linters.cppcheck = vim.tbl_deep_extend('force', lint.linters.cppcheck or {}, {
    args = {
      '--enable=all',
      '--inconclusive',
      '--inline-suppr',
      '--project=compile_commands.json',
      '--quiet',
    },
  })

  -- -------------------------------------------------------------------------
  -- Trigger linting
  -- -------------------------------------------------------------------------
  local augroup = vim.api.nvim_create_augroup('Lint', { clear = true })

  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
    group = augroup,
    callback = function(ev)
      -- Skip large files
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
      if ok and stats and stats.size > 200 * 1024 then return end
      lint.try_lint()
    end,
  })
end

-- ============================================================================
-- OVERSEER SETUP
-- ============================================================================
function M.setup_overseer()
  local overseer = require 'overseer'

  overseer.setup {
    -- -------------------------------------------------------------------------
    -- UI
    -- -------------------------------------------------------------------------
    task_list = {
      direction = 'bottom',
      min_height = 12,
      max_height = 20,
      default_detail = 1,
      -- Column layout shown in the task list panel
      columns = {
        { 'status', padding = 1 },
        { 'name', padding = 1 },
        { 'duration', padding = 1 },
      },
    },

    -- Float window used for task details / logs
    task_win = {
      padding = 2,
      border = 'rounded',
      win_opts = { winblend = 0 },
    },

    -- -------------------------------------------------------------------------
    -- Component defaults applied to every task
    -- -------------------------------------------------------------------------
    component_aliases = {
      default = {
        -- Re-run on file save (opt-in via task definition)
        { 'on_output_summarize', max_lines = 8 },
        'on_exit_set_status',
        'on_complete_notify',
        { 'on_complete_dispose', require_view = { 'SUCCESS', 'FAILURE' } },
      },
    },

    -- -------------------------------------------------------------------------
    -- Template providers
    -- -------------------------------------------------------------------------
    templates = {
      'builtin', -- make, cargo, shell, …
      'user.tasks', -- lua/overseer/templates/user/tasks.lua  (project-local)
    },

    -- -------------------------------------------------------------------------
    -- Strategy: how tasks are run
    -- -------------------------------------------------------------------------
    strategy = {
      'terminal',
      direction = 'horizontal',
      open_on_start = true,
    },

    -- -------------------------------------------------------------------------
    -- Integrations
    -- -------------------------------------------------------------------------
    -- Populate vim.g.overseer_task_count so statuslines can display it
    dap = false, -- set true if you use nvim-dap

    -- Auto-detect Makefiles / Cargo.toml / pyproject.toml etc.
    auto_detect_success_color = true,
  }

  -- -------------------------------------------------------------------------
  -- Built-in templates for common project types
  -- -------------------------------------------------------------------------
  M.register_overseer_templates(overseer)
end

-- Register project-type-aware task templates
function M.register_overseer_templates(overseer)
  -- Helper: check if a file exists relative to cwd
  local function has_file(name) return vim.loop.fs_stat(vim.fn.getcwd() .. '/' .. name) ~= nil end

  -- ── Rust ──────────────────────────────────────────────────────────────────
  overseer.register_template {
    name = 'cargo build',
    priority = 10,
    condition = { callback = function() return has_file 'Cargo.toml' end },
    builder = function()
      return {
        name = 'cargo build',
        cmd = { 'cargo', 'build' },
        components = {
          { 'on_output_parse', problem_matcher = '$rustc' },
          'default',
        },
      }
    end,
  }

  overseer.register_template {
    name = 'cargo build --release',
    priority = 11,
    condition = { callback = function() return has_file 'Cargo.toml' end },
    builder = function()
      return {
        name = 'cargo build --release',
        cmd = { 'cargo', 'build', '--release' },
        components = {
          { 'on_output_parse', problem_matcher = '$rustc' },
          'default',
        },
      }
    end,
  }

  overseer.register_template {
    name = 'cargo test',
    priority = 12,
    condition = { callback = function() return has_file 'Cargo.toml' end },
    builder = function()
      return {
        name = 'cargo test',
        cmd = { 'cargo', 'test' },
        components = {
          { 'on_output_parse', problem_matcher = '$rustc' },
          'default',
        },
      }
    end,
  }

  overseer.register_template {
    name = 'cargo clippy',
    priority = 13,
    condition = { callback = function() return has_file 'Cargo.toml' end },
    builder = function()
      return {
        name = 'cargo clippy',
        cmd = { 'cargo', 'clippy', '--', '-D', 'warnings' },
        components = {
          { 'on_output_parse', problem_matcher = '$rustc' },
          'default',
        },
      }
    end,
  }

  -- ── C / C++ ───────────────────────────────────────────────────────────────
  overseer.register_template {
    name = 'cmake configure',
    priority = 20,
    condition = { callback = function() return has_file 'CMakeLists.txt' end },
    builder = function()
      return {
        name = 'cmake configure',
        cmd = {
          'cmake',
          '-S',
          '.',
          '-B',
          'build',
          '-DCMAKE_BUILD_TYPE=Debug',
          '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON',
        },
        components = { 'default' },
      }
    end,
  }

  overseer.register_template {
    name = 'cmake build',
    priority = 21,
    condition = { callback = function() return has_file 'CMakeLists.txt' end },
    builder = function()
      return {
        name = 'cmake build',
        cmd = { 'cmake', '--build', 'build', '--parallel' },
        components = {
          { 'on_output_parse', problem_matcher = '$gcc' },
          'default',
        },
      }
    end,
  }

  overseer.register_template {
    name = 'make',
    priority = 22,
    condition = { callback = function() return has_file 'Makefile' end },
    builder = function()
      return {
        name = 'make',
        cmd = { 'make', '-j' .. tostring(vim.loop.available_parallelism() or 4) },
        components = {
          { 'on_output_parse', problem_matcher = '$gcc' },
          'default',
        },
      }
    end,
  }

  -- ── Python ────────────────────────────────────────────────────────────────
  overseer.register_template {
    name = 'python: run file',
    priority = 30,
    condition = { filetype = { 'python' } },
    builder = function()
      return {
        name = 'python ' .. vim.fn.expand '%:t',
        cmd = { 'python3', vim.fn.expand '%:p' },
        components = { 'default' },
      }
    end,
  }

  overseer.register_template {
    name = 'pytest',
    priority = 31,
    condition = {
      callback = function()
        return has_file 'pyproject.toml' or has_file 'setup.py' or has_file 'pytest.ini'
      end,
    },
    builder = function()
      return {
        name = 'pytest',
        cmd = { 'python3', '-m', 'pytest', '-v' },
        components = { 'default' },
      }
    end,
  }

  overseer.register_template {
    name = 'ruff check',
    priority = 32,
    condition = {
      callback = function() return has_file 'pyproject.toml' or has_file 'ruff.toml' end,
    },
    builder = function()
      return {
        name = 'ruff check',
        cmd = { 'ruff', 'check', '.' },
        components = { 'default' },
      }
    end,
  }
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Toggle format-on-save for the current buffer
function M.toggle_autoformat()
  vim.b.disable_autoformat = not vim.b.disable_autoformat
  vim.notify(
    'Format-on-save: ' .. (vim.b.disable_autoformat and 'disabled' or 'enabled'),
    vim.log.levels.INFO,
    { title = 'tasks' }
  )
end

-- Toggle format-on-save globally
function M.toggle_autoformat_global()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify(
    'Format-on-save (global): ' .. (vim.g.disable_autoformat and 'disabled' or 'enabled'),
    vim.log.levels.INFO,
    { title = 'tasks' }
  )
end

-- Format current buffer manually, with optional range
function M.format(opts)
  opts = opts or {}
  require('conform').format(vim.tbl_extend('keep', opts, {
    timeout_ms = 5000,
    lsp_fallback = true,
    async = false,
  }))
end

-- Show which formatter(s) would run on the current buffer
function M.show_formatter_info() vim.cmd 'ConformInfo' end

-- Run the linter manually on the current buffer
function M.run_linter()
  require('lint').try_lint()
  vim.notify('Linter triggered for ' .. vim.bo.filetype, vim.log.levels.INFO, { title = 'tasks' })
end

-- Quick-pick an overseer task to run
function M.run_task() require('overseer').run_template() end

-- Open the overseer task list
function M.toggle_task_list() require('overseer').toggle { direction = 'bottom' } end

-- Rerun the most recent overseer task
function M.rerun_last_task()
  local overseer = require 'overseer'
  local tasks = overseer.list_tasks { recent_first = true }
  if vim.tbl_isempty(tasks) then
    vim.notify('No recent tasks to rerun', vim.log.levels.WARN, { title = 'tasks' })
    return
  end
  overseer.run_action(tasks[1], 'restart')
end

-- Show a summary of active / recent overseer tasks
function M.task_status()
  local overseer = require 'overseer'
  local tasks = overseer.list_tasks { recent_first = true }
  if vim.tbl_isempty(tasks) then
    vim.notify('No tasks running', vim.log.levels.INFO, { title = 'tasks' })
    return
  end
  for _, task in ipairs(tasks) do
    vim.notify(
      string.format('[%s] %s', task.status, task.name),
      vim.log.levels.INFO,
      { title = 'tasks' }
    )
  end
end

-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup('Tasks', { clear = true })

  -- Restore format-on-save preference from a project-local .nvim.lua if present
  vim.api.nvim_create_autocmd('DirChanged', {
    group = augroup,
    callback = function()
      local project_cfg = vim.fn.getcwd() .. '/.nvim.lua'
      if vim.loop.fs_stat(project_cfg) then dofile(project_cfg) end
    end,
  })

  -- Show overseer task results in the quickfix list on completion
  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'OverseerTaskComplete',
    callback = function(ev)
      local task = ev.data and ev.data.task
      if task and task.status == 'FAILURE' then
        vim.defer_fn(function() vim.cmd 'OverseerQuickAction open output' end, 100)
      end
    end,
  })

  -- Auto-lint on filetype change (e.g. after detecting a new filetype)
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = vim.tbl_keys(LINTERS),
    callback = function() require('lint').try_lint() end,
  })
end

-- ============================================================================
-- KEYMAPS
-- ============================================================================
function M.setup_keymaps()
  local map = vim.keymap.set

  -- ── Formatting ─────────────────────────────────────────────────────────
  map({ 'n', 'v' }, '<leader>ff', M.format, { desc = 'Format Buffer/Range' })
  map('n', '<leader>fF', M.toggle_autoformat, { desc = 'Toggle Format-on-save (buffer)' })
  map('n', '<leader>fG', M.toggle_autoformat_global, { desc = 'Toggle Format-on-save (global)' })
  map('n', '<leader>fi', M.show_formatter_info, { desc = 'Formatter Info' })

  -- ── Linting ────────────────────────────────────────────────────────────
  map('n', '<leader>fl', M.run_linter, { desc = 'Run Linter' })

  -- ── Overseer tasks ─────────────────────────────────────────────────────
  map('n', '<leader>rr', M.run_task, { desc = 'Run Task' })
  map('n', '<leader>rt', M.toggle_task_list, { desc = 'Toggle Task List' })
  map('n', '<leader>rl', M.rerun_last_task, { desc = 'Rerun Last Task' })
  map('n', '<leader>rs', M.task_status, { desc = 'Task Status' })

  -- Overseer direct commands (when you know exactly what you want)
  map('n', '<leader>rb', '<cmd>OverseerBuild<cr>', { desc = 'Overseer Build' })
  map('n', '<leader>rq', '<cmd>OverseerQuickAction<cr>', { desc = 'Overseer Quick Action' })
  map('n', '<leader>ri', '<cmd>OverseerInfo<cr>', { desc = 'Overseer Info' })
end

-- ============================================================================
-- MAIN SETUP
-- ============================================================================
function M.setup()
  M.setup_conform()
  -- M.setup_lint()
  M.setup_overseer()
  M.setup_autocmds()
  M.setup_keymaps()
end

return M
