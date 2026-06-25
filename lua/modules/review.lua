-- lua/modules/review.lua
-- Document review module: live preview + inline review comments.
--
-- Designed for a split-desktop workflow:
--   Left:  browser with live-reloading preview (Quartz / grip / python http)
--   Right: Neovim editing the org/markdown source
--
-- Preview backends (auto-detected in priority order):
--   1. x7-tools pages-preview.sh   (Quartz + x7-forge org→md pipeline)
--   2. grip                        (GitHub-flavored markdown preview)
--   3. python3 http.server          (fallback: serve rendered HTML)
--
-- Comment format (file-type aware):
--   org:      #+begin_review AUTHOR TIMESTAMP
--             comment body
--             #+end_review
--   markdown: <!-- REVIEW AUTHOR TIMESTAMP
--             comment body
--             -->
--
-- Keybindings:  SPC d  (document review prefix)
--
-- Domain: review

local env = require 'env'

-- ── Comment format helpers ──────────────────────────────────────────────

local function timestamp()
  return os.date '%Y-%m-%d %H:%M'
end

local function author()
  -- Try git user, fall back to system user
  local git_user = vim.fn.systemlist('git config user.name')[1]
  if vim.v.shell_error == 0 and git_user and git_user ~= '' then
    return git_user
  end
  return vim.env.USER or 'reviewer'
end

---Insert a review comment below the cursor.
---@param body string|nil optional pre-filled body text
local function insert_comment(body)
  local ft = vim.bo.filetype
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local a = author()
  local ts = timestamp()
  local lines

  if ft == 'org' then
    lines = {
      '#+begin_review ' .. a .. ' ' .. ts,
      body or '',
      '#+end_review',
    }
  elseif ft == 'markdown' or ft == 'quarto' then
    lines = {
      '<!-- REVIEW ' .. a .. ' ' .. ts,
      body or '',
      '-->',
    }
  else
    -- Generic fallback using line comments
    local cms = vim.bo.commentstring
    if cms and cms ~= '' then
      local prefix = cms:gsub('%%s', '')
      lines = {
        prefix .. ' REVIEW ' .. a .. ' ' .. ts,
        prefix .. ' ' .. (body or ''),
        prefix .. ' /REVIEW',
      }
    else
      lines = {
        '# REVIEW ' .. a .. ' ' .. ts,
        '# ' .. (body or ''),
        '# /REVIEW',
      }
    end
  end

  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
  -- Place cursor on the body line, in insert mode
  vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
  if not body then
    vim.cmd 'startinsert!'
  end
end

---Insert a single-line review note at end of current line.
local function insert_inline_comment()
  local ft = vim.bo.filetype
  local a = author()
  local ts = timestamp()
  local suffix

  if ft == 'org' then
    -- Org inline comment: org doesn't have true inline comments,
    -- use a tagged note that won't export
    suffix = '  # REVIEW(' .. a .. ' ' .. ts .. '): '
  elseif ft == 'markdown' or ft == 'quarto' then
    suffix = '  <!-- REVIEW(' .. a .. ' ' .. ts .. '): -->'
  else
    local cms = vim.bo.commentstring
    local prefix = cms and cms ~= '' and cms:gsub('%%s', '') or '# '
    suffix = '  ' .. prefix .. 'REVIEW(' .. a .. ' ' .. ts .. '): '
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { line .. suffix })
  -- Place cursor before the closing delimiter to type the comment
  vim.api.nvim_win_set_cursor(0, { row, #line + #suffix - (ft == 'markdown' and 4 or 1) })
  vim.cmd 'startinsert'
end

-- ── Comment navigation ──────────────────────────────────────────────────

local review_patterns = {
  org = { 'begin_review', 'REVIEW(' },
  markdown = { 'REVIEW ', 'REVIEW(' },
}

local function get_review_pattern()
  local ft = vim.bo.filetype
  local pats = review_patterns[ft]
  if pats then return pats end
  return { 'REVIEW' }
end

local function jump_comment(direction)
  local pats = get_review_pattern()
  local flags = direction == 'next' and 'W' or 'bW'
  for _, pat in ipairs(pats) do
    local found = vim.fn.search(vim.fn.escape(pat, '/\\'), flags)
    if found > 0 then return end
  end
  vim.notify('No more review comments ' .. direction, vim.log.levels.INFO)
end

---Resolve (delete) the review comment block under the cursor.
local function resolve_comment()
  local ft = vim.bo.filetype
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local line = lines[row] or ''

  if ft == 'org' then
    -- Find the begin_review / end_review block containing cursor
    local block_start, block_end
    for i = row, 1, -1 do
      if lines[i]:match '#+begin_review' then
        block_start = i
        break
      end
    end
    if block_start then
      for i = block_start, #lines do
        if lines[i]:match '#+end_review' then
          block_end = i
          break
        end
      end
    end
    if block_start and block_end then
      vim.api.nvim_buf_set_lines(0, block_start - 1, block_end, false, {})
      vim.notify('Resolved review comment (' .. (block_end - block_start + 1) .. ' lines)', vim.log.levels.INFO)
      return
    end
    -- Try inline comment
    if line:match '# REVIEW%(.*%):' then
      local cleaned = line:gsub('%s*# REVIEW%(.-%): ?.*$', '')
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, { cleaned })
      vim.notify('Resolved inline review comment', vim.log.levels.INFO)
      return
    end
  elseif ft == 'markdown' or ft == 'quarto' then
    -- Find <!-- REVIEW ... --> block
    local block_start, block_end
    for i = row, 1, -1 do
      if lines[i]:match '<!%-%- REVIEW ' then
        block_start = i
        break
      end
    end
    if block_start then
      for i = block_start, #lines do
        if lines[i]:match '%-%->' then
          block_end = i
          break
        end
      end
    end
    if block_start and block_end then
      vim.api.nvim_buf_set_lines(0, block_start - 1, block_end, false, {})
      vim.notify('Resolved review comment (' .. (block_end - block_start + 1) .. ' lines)', vim.log.levels.INFO)
      return
    end
    -- Inline
    if line:match '<!%-%- REVIEW%(.*%):' then
      local cleaned = line:gsub('%s*<!%-%- REVIEW%(.-%): ?%-%->', '')
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, { cleaned })
      vim.notify('Resolved inline review comment', vim.log.levels.INFO)
      return
    end
  end

  vim.notify('No review comment at cursor', vim.log.levels.WARN)
end

---Collect all review comments in the buffer for the picker.
local function list_comments()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local items = {}
  for i, line in ipairs(lines) do
    if line:match 'REVIEW' and (
      line:match 'begin_review' or
      line:match '<!%-%- REVIEW' or
      line:match 'REVIEW%(' or
      line:match '# REVIEW'
    ) then
      table.insert(items, {
        filename = vim.api.nvim_buf_get_name(0),
        lnum = i,
        text = vim.trim(line),
      })
    end
  end

  if #items == 0 then
    vim.notify('No review comments in this buffer', vim.log.levels.INFO)
    return
  end

  vim.fn.setloclist(0, items)
  vim.cmd 'lopen'
end

-- ── Preview server management ───────────────────────────────────────────

---@type number|nil overseer task id for the preview server
local preview_task_id = nil

---Detect the best preview backend for the current project.
---@return { cmd: string[], port: number, name: string }|nil
local function detect_preview_backend()
  local root = env.state.get 'workspace.root' or vim.fn.getcwd()

  -- 1. x7-tools pages-preview.sh
  local pages_script = root .. '/tools/pages-preview.sh'
  if vim.fn.filereadable(pages_script) == 1 then
    return {
      cmd = { 'bash', pages_script, '--port', '8080' },
      port = 8080,
      name = 'Quartz (pages-preview)',
      cwd = root,
    }
  end

  -- 2. grip (GitHub-flavored markdown)
  local ft = vim.bo.filetype
  if vim.fn.executable 'grip' == 1 and (ft == 'markdown' or ft == 'org') then
    local file = vim.fn.expand '%:p'
    return {
      cmd = { 'grip', file, '6419', '--browser' },
      port = 6419,
      name = 'grip',
      cwd = root,
    }
  end

  -- 3. python3 http.server fallback for any project with docs/
  if vim.fn.executable 'python3' == 1 then
    local docs_dir = root .. '/docs'
    if vim.fn.isdirectory(docs_dir) == 1 then
      return {
        cmd = { 'python3', '-m', 'http.server', '8080', '--directory', docs_dir },
        port = 8080,
        name = 'python3 http.server',
        cwd = root,
      }
    end
  end

  return nil
end

---Start the preview server (via overseer for output/status tracking).
local function start_preview()
  local backend = detect_preview_backend()
  if not backend then
    vim.notify(
      'review: no preview backend detected.\n'
        .. 'Supports: tools/pages-preview.sh, grip, python3 http.server (docs/)',
      vim.log.levels.WARN
    )
    return
  end

  -- If already running, just open the browser
  if preview_task_id then
    local overseer = require 'overseer'
    local task = overseer.get_task(preview_task_id)
    if task and not task:is_complete() then
      vim.ui.open('http://localhost:' .. backend.port)
      vim.notify('review: preview already running — opened browser', vim.log.levels.INFO)
      return
    end
  end

  local overseer = require 'overseer'
  local task = overseer.new_task {
    name = '📖 ' .. backend.name,
    cmd = backend.cmd,
    cwd = backend.cwd,
    components = {
      'default',
      -- Keep output but don't flood quickfix
      { 'on_output_quickfix', open = false, set_diagnostics = false },
    },
    -- Long-running server, don't auto-dispose
    metadata = { is_preview_server = true },
  }

  task:start()
  preview_task_id = task.id

  -- Open browser after a short delay for the server to start
  vim.defer_fn(function()
    vim.ui.open('http://localhost:' .. backend.port)
  end, 2000)

  vim.notify(
    'review: started ' .. backend.name .. ' on port ' .. backend.port,
    vim.log.levels.INFO
  )
end

---Stop the preview server.
local function stop_preview()
  if not preview_task_id then
    vim.notify('review: no preview server running', vim.log.levels.INFO)
    return
  end

  local overseer = require 'overseer'
  local task = overseer.get_task(preview_task_id)
  if task and not task:is_complete() then
    task:stop()
    vim.notify('review: stopped preview server', vim.log.levels.INFO)
  end
  preview_task_id = nil
end

---Open browser to preview (start server if needed).
local function open_preview()
  local backend = detect_preview_backend()
  if not backend then
    start_preview()
    return
  end

  -- Check if server is already running
  if preview_task_id then
    local overseer = require 'overseer'
    local task = overseer.get_task(preview_task_id)
    if task and not task:is_complete() then
      vim.ui.open('http://localhost:' .. backend.port)
      return
    end
  end

  -- Not running, start it
  start_preview()
end

-- ── Highlight review comments ───────────────────────────────────────────

local function setup_review_highlights()
  -- Create highlight groups for review comments
  vim.api.nvim_set_hl(0, 'ReviewComment', { bg = '#3d3520', italic = true })
  vim.api.nvim_set_hl(0, 'ReviewCommentBorder', { fg = '#e0af68', bold = true })

  -- Org: highlight #+begin_review ... #+end_review
  vim.fn.matchadd('ReviewCommentBorder', '#+begin_review.*$')
  vim.fn.matchadd('ReviewCommentBorder', '#+end_review')

  -- Markdown: highlight <!-- REVIEW ... -->
  vim.fn.matchadd('ReviewCommentBorder', '<!-- REVIEW.*$')

  -- Inline review comments
  vim.fn.matchadd('ReviewComment', 'REVIEW([^)]*):.*')
end

-- ════════════════════════════════════════════════════════════════════════

return env.module.register {
  name = 'review',
  domain = 'review',
  depends_on = { 'interface' },
  optional_deps = { 'workspace', 'terminal', 'orgmode' },

  plugins = {},

  setup = function()
    ----------------------------------------------------------------
    -- Which-key group
    ----------------------------------------------------------------

    local ok_wk, wk = pcall(require, 'which-key')
    if ok_wk then
      wk.add {
        { '<leader>d', group = 'review' },
      }
    end

    ----------------------------------------------------------------
    -- Preview keymaps (SPC d p / SPC d P / SPC d o)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>dp', start_preview, {
      desc = 'review.start_preview',
      silent = true,
    })

    vim.keymap.set('n', '<leader>dP', stop_preview, {
      desc = 'review.stop_preview',
      silent = true,
    })

    vim.keymap.set('n', '<leader>do', open_preview, {
      desc = 'review.open_browser',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Comment keymaps (SPC d c / SPC d i / SPC d r / SPC d l)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>dc', insert_comment, {
      desc = 'review.add_comment',
      silent = true,
    })

    vim.keymap.set('v', '<leader>dc', function()
      -- Get visual selection as the comment body
      vim.cmd 'normal! "vy'
      local selection = vim.fn.getreg 'v'
      -- Exit visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
      -- Insert comment wrapping the selection
      insert_comment('RE: ' .. selection)
    end, {
      desc = 'review.comment_on_selection',
      silent = true,
    })

    vim.keymap.set('n', '<leader>di', insert_inline_comment, {
      desc = 'review.inline_comment',
      silent = true,
    })

    vim.keymap.set('n', '<leader>dr', resolve_comment, {
      desc = 'review.resolve_comment',
      silent = true,
    })

    vim.keymap.set('n', '<leader>dl', list_comments, {
      desc = 'review.list_comments',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Comment navigation (]r / [r)
    ----------------------------------------------------------------

    vim.keymap.set('n', ']r', function() jump_comment 'next' end, {
      desc = 'review.next_comment',
      silent = true,
    })

    vim.keymap.set('n', '[r', function() jump_comment 'prev' end, {
      desc = 'review.prev_comment',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Grep all review comments across project
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>dg', function()
      local root = env.state.get 'workspace.root' or vim.fn.getcwd()
      Snacks.picker.grep {
        search = 'REVIEW|begin_review',
        regex = true,
        cwd = root,
        layout = { preset = 'vertical', cycle = true },
        preview = true,
      }
    end, {
      desc = 'review.grep_comments',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Auto-highlight review comments in org/markdown buffers
    ----------------------------------------------------------------

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('review_highlights', { clear = true }),
      pattern = { 'org', 'markdown', 'quarto' },
      callback = setup_review_highlights,
    })

    ----------------------------------------------------------------
    -- User command for quick access
    ----------------------------------------------------------------

    vim.api.nvim_create_user_command('ReviewPreview', function(opts)
      if opts.bang then
        stop_preview()
      else
        start_preview()
      end
    end, {
      bang = true,
      desc = 'Start (or stop with !) the document preview server',
    })

    vim.api.nvim_create_user_command('ReviewComment', function(opts)
      insert_comment(opts.args ~= '' and opts.args or nil)
    end, {
      nargs = '?',
      desc = 'Insert a review comment (optional body text)',
    })
  end,
}
