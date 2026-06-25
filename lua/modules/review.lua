-- lua/modules/review.lua
-- Document review module: live preview sync + inline review comments.
--
-- Designed for a split-desktop workflow:
--   Left:  browser with live-reloading preview (Quartz / grip / etc.)
--   Right: Neovim editing the org/markdown source
--
-- The preview server may be started from inside neovim (SPC d p) or
-- externally (e.g. ./tools/pages-preview.sh in a terminal).  Either
-- way, neovim can sync the browser to the current file and heading.
--
-- Preview detection (searched in order):
--   tools/pages-preview.sh
--   tools/x7-forge/implementation/x7-tools/run.sh pages preview
--   tools/x7-forge/tools/run.sh pages preview
--   grip (GitHub markdown)
--   python3 http.server (docs/ fallback)
--
-- Browser sync:
--   SPC d s  — sync browser to current file + nearest heading
--   SPC d S  — toggle auto-sync on cursor movement
--   File path → URL mapping is project-configurable via .nvim.lua:
--     vim.b.review_url_base = "http://localhost:8080"
--     vim.b.review_path_map = function(file) return "/page" end
--
-- Comment format (file-type aware):
--   org:      #+begin_review AUTHOR TIMESTAMP ... #+end_review
--   markdown: <!-- REVIEW AUTHOR TIMESTAMP ... -->
--
-- Keybindings:  SPC d  (document review prefix)
--
-- Domain: review

local env = require 'env'

-- ══════════════════════════════════════════════════════════════════════════
-- COMMENT SYSTEM
-- ══════════════════════════════════════════════════════════════════════════

local function timestamp()
  return os.date '%Y-%m-%d %H:%M'
end

local function author()
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
    local cms = vim.bo.commentstring
    local prefix = (cms and cms ~= '') and cms:gsub('%%s', '') or '# '
    lines = {
      prefix .. ' REVIEW ' .. a .. ' ' .. ts,
      prefix .. ' ' .. (body or ''),
      prefix .. ' /REVIEW',
    }
  end

  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
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
    suffix = '  # REVIEW(' .. a .. ' ' .. ts .. '): '
  elseif ft == 'markdown' or ft == 'quarto' then
    suffix = '  <!-- REVIEW(' .. a .. ' ' .. ts .. '): -->'
  else
    local cms = vim.bo.commentstring
    local prefix = (cms and cms ~= '') and cms:gsub('%%s', '') or '# '
    suffix = '  ' .. prefix .. 'REVIEW(' .. a .. ' ' .. ts .. '): '
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ''
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { line .. suffix })
  vim.api.nvim_win_set_cursor(0, { row, #line + #suffix - (ft == 'markdown' and 4 or 1) })
  vim.cmd 'startinsert'
end

-- ── Comment navigation ──────────────────────────────────────────────────

local function jump_comment(direction)
  local flags = direction == 'next' and 'W' or 'bW'
  local pats = { 'begin_review', 'REVIEW(', '<!-- REVIEW' }
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
    local block_start, block_end
    for i = row, 1, -1 do
      if lines[i]:match '#+begin_review' then block_start = i; break end
    end
    if block_start then
      for i = block_start, #lines do
        if lines[i]:match '#+end_review' then block_end = i; break end
      end
    end
    if block_start and block_end then
      vim.api.nvim_buf_set_lines(0, block_start - 1, block_end, false, {})
      vim.notify('Resolved review comment (' .. (block_end - block_start + 1) .. ' lines)')
      return
    end
    if line:match '# REVIEW%(.*%):' then
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, { line:gsub('%s*# REVIEW%(.-%): ?.*$', '') })
      vim.notify 'Resolved inline review comment'
      return
    end
  elseif ft == 'markdown' or ft == 'quarto' then
    local block_start, block_end
    for i = row, 1, -1 do
      if lines[i]:match '<!%-%- REVIEW ' then block_start = i; break end
    end
    if block_start then
      for i = block_start, #lines do
        if lines[i]:match '%-%->' then block_end = i; break end
      end
    end
    if block_start and block_end then
      vim.api.nvim_buf_set_lines(0, block_start - 1, block_end, false, {})
      vim.notify('Resolved review comment (' .. (block_end - block_start + 1) .. ' lines)')
      return
    end
    if line:match '<!%-%- REVIEW%(.*%):' then
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, { line:gsub('%s*<!%-%- REVIEW%(.-%): ?%-%->', '') })
      vim.notify 'Resolved inline review comment'
      return
    end
  end

  vim.notify('No review comment at cursor', vim.log.levels.WARN)
end

---List all review comments in the buffer via loclist.
local function list_comments()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local items = {}
  for i, line in ipairs(lines) do
    if line:match 'REVIEW' and (
      line:match 'begin_review' or line:match '<!%-%- REVIEW' or
      line:match 'REVIEW%(' or line:match '# REVIEW'
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

-- ══════════════════════════════════════════════════════════════════════════
-- PREVIEW SERVER
-- ══════════════════════════════════════════════════════════════════════════

---@class review.PreviewState
---@field task_id number|nil   overseer task id (nil if started externally)
---@field port number          preview server port
---@field url_base string      e.g. "http://localhost:8080"
---@field managed boolean      true if neovim started it
local preview = {
  task_id = nil,
  port = 8080,
  url_base = 'http://localhost:8080',
  managed = false,
}

---Detect the best preview command for the current project.
---Searches multiple known x7-tools layouts.
---@return { cmd: string[], port: number, name: string, cwd: string }|nil
local function detect_preview_backend()
  local root = env.state.get 'workspace.root' or vim.fn.getcwd()

  -- Search paths in priority order
  local candidates = {
    -- Standalone pages-preview.sh wrapper
    {
      path = root .. '/tools/pages-preview.sh',
      cmd = function(p) return { 'bash', p, '--port', tostring(preview.port) } end,
      name = 'Quartz (pages-preview.sh)',
    },
    -- x7-forge submodule: run.sh pages preview
    {
      path = root .. '/tools/x7-forge/implementation/x7-tools/run.sh',
      cmd = function(p) return { 'bash', p, 'pages', 'preview' } end,
      name = 'x7-tools pages preview',
      env = { X7_NO_DOCKER = '1', X7_PROJECT_ROOT = root },
    },
    -- x7-forge submodule: nested tools/run.sh
    {
      path = root .. '/tools/x7-forge/tools/run.sh',
      cmd = function(p) return { 'bash', p, 'pages', 'preview' } end,
      name = 'x7-forge pages preview',
      env = { X7_NO_DOCKER = '1', X7_PROJECT_ROOT = root },
    },
  }

  for _, c in ipairs(candidates) do
    if vim.fn.filereadable(c.path) == 1 then
      return {
        cmd = c.cmd(c.path),
        port = preview.port,
        name = c.name,
        cwd = root,
        env = c.env,
      }
    end
  end

  -- grip (GitHub-flavored markdown)
  local ft = vim.bo.filetype
  if vim.fn.executable 'grip' == 1 and (ft == 'markdown' or ft == 'org') then
    return {
      cmd = { 'grip', vim.fn.expand '%:p', tostring(preview.port) },
      port = preview.port,
      name = 'grip',
      cwd = root,
    }
  end

  -- python3 http.server fallback
  if vim.fn.executable 'python3' == 1 then
    local docs_dir = root .. '/docs'
    if vim.fn.isdirectory(docs_dir) == 1 then
      return {
        cmd = { 'python3', '-m', 'http.server', tostring(preview.port), '--directory', docs_dir },
        port = preview.port,
        name = 'python3 http.server',
        cwd = root,
      }
    end
  end

  return nil
end

---Start the preview server via overseer.
local function start_preview()
  local backend = detect_preview_backend()
  if not backend then
    vim.notify(
      'review: no preview backend detected.\n'
        .. 'Searched: tools/pages-preview.sh,\n'
        .. '         tools/x7-forge/implementation/x7-tools/run.sh,\n'
        .. '         tools/x7-forge/tools/run.sh,\n'
        .. '         grip, python3 http.server (docs/)\n\n'
        .. 'Use :ReviewAttach <port> to attach to an external server.',
      vim.log.levels.WARN
    )
    return
  end

  -- If already running, just open browser
  if preview.task_id then
    local overseer = require 'overseer'
    local task = overseer.get_task(preview.task_id)
    if task and not task:is_complete() then
      vim.ui.open(preview.url_base)
      vim.notify('review: preview already running — opened browser', vim.log.levels.INFO)
      return
    end
  end

  local overseer = require 'overseer'
  local task = overseer.new_task {
    name = '📖 ' .. backend.name,
    cmd = backend.cmd,
    cwd = backend.cwd,
    env = backend.env,
    components = {
      'default',
      { 'on_output_quickfix', open = false, set_diagnostics = false },
    },
    metadata = { is_preview_server = true },
  }

  task:start()
  preview.task_id = task.id
  preview.port = backend.port
  preview.url_base = 'http://localhost:' .. backend.port
  preview.managed = true

  vim.defer_fn(function()
    vim.ui.open(preview.url_base)
  end, 2500)

  vim.notify('review: started ' .. backend.name .. ' on port ' .. backend.port, vim.log.levels.INFO)
end

---Stop the preview server (only if we started it).
local function stop_preview()
  if not preview.task_id then
    if preview.managed then
      vim.notify('review: no preview server running', vim.log.levels.INFO)
    else
      preview.url_base = ''
      preview.managed = false
      vim.notify('review: detached from external preview', vim.log.levels.INFO)
    end
    return
  end

  local overseer = require 'overseer'
  local task = overseer.get_task(preview.task_id)
  if task and not task:is_complete() then
    task:stop()
  end
  preview.task_id = nil
  preview.managed = true
  vim.notify('review: stopped preview server', vim.log.levels.INFO)
end

---Attach to an externally-running preview server.
---@param port number
local function attach_preview(port)
  preview.port = port
  preview.url_base = 'http://localhost:' .. port
  preview.managed = false
  preview.task_id = nil
  vim.notify('review: attached to http://localhost:' .. port, vim.log.levels.INFO)
end

-- ══════════════════════════════════════════════════════════════════════════
-- BROWSER SYNC — navigate browser to match current file + heading
-- ══════════════════════════════════════════════════════════════════════════

---Slugify a heading string the way Quartz/Hugo/most SSGs do.
---@param heading string  raw heading text (without the # or * prefix)
---@return string slug    URL-safe anchor
local function slugify(heading)
  return heading
    :lower()
    :gsub('[^%w%s%-]', '')  -- strip non-alnum
    :gsub('%s+', '-')       -- spaces → hyphens
    :gsub('%-+', '-')       -- collapse hyphens
    :gsub('^%-', '')        -- trim leading
    :gsub('%-$', '')        -- trim trailing
end

---Find the nearest heading above (or at) the cursor.
---@return string|nil heading_slug
local function nearest_heading_slug()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, row, false)
  local ft = vim.bo.filetype

  -- Search backwards from cursor for the nearest heading
  for i = #lines, 1, -1 do
    local line = lines[i]
    local heading
    if ft == 'org' then
      -- Org headings: * Heading, ** Sub-heading, etc.
      heading = line:match '^%*+ (.+)$'
    elseif ft == 'markdown' or ft == 'quarto' then
      -- Markdown headings: # Heading, ## Sub-heading, etc.
      heading = line:match '^#+ (.+)$'
    end
    if heading then
      return slugify(heading)
    end
  end
  return nil
end

---Map the current buffer's file path to a preview URL path.
---
---Priority:
---  1. Buffer-local vim.b.review_path_map function
---  2. Project-local g:review_path_map function
---  3. Built-in heuristics for x7-tools / Quartz projects
---
---@return string url_path  e.g. "/Repository_Management_Plan"
local function file_to_url_path()
  local file = vim.fn.expand '%:p'
  local root = env.state.get 'workspace.root' or vim.fn.getcwd()

  -- 1. Buffer-local override: vim.b.review_path_map = function(file) ... end
  if vim.b.review_path_map then
    local result = vim.b.review_path_map(file)
    if result then return result end
  end

  -- 2. Global/project override: vim.g.review_path_map
  if vim.g.review_path_map then
    local result = vim.g.review_path_map(file)
    if result then return result end
  end

  -- 3. Built-in: strip project root and known prefixes, convert to URL
  local rel = file:gsub('^' .. vim.pesc(root) .. '/', '')

  -- Strip common documentation prefixes
  rel = rel
    :gsub('^documentation/', '')
    :gsub('^content/', '')
    :gsub('^docs/', '')
    :gsub('^plans/', '')

  -- Strip file extension
  rel = rel:gsub('%.org$', ''):gsub('%.md$', ''):gsub('%.markdown$', '')

  -- Use the filename as the page slug (Quartz default: flat namespace)
  -- but also support nested paths
  local basename = vim.fn.fnamemodify(rel, ':t')

  -- Try both: full path and just basename (Quartz flattens by default)
  return '/' .. basename
end

---Sync the browser to the current file and nearest heading.
---Uses xdg-open which navigates in the existing browser.
local function sync_browser()
  if preview.url_base == '' then
    vim.notify(
      'review: no preview attached.\n'
        .. 'Use SPC d p to start, or :ReviewAttach <port> for external server.',
      vim.log.levels.WARN
    )
    return
  end

  local path = file_to_url_path()
  local slug = nearest_heading_slug()
  local url = preview.url_base .. path
  if slug then
    url = url .. '#' .. slug
  end

  vim.ui.open(url)
end

---Auto-sync state
local auto_sync_enabled = false
local auto_sync_augroup = nil

local function toggle_auto_sync()
  auto_sync_enabled = not auto_sync_enabled

  if auto_sync_enabled then
    if preview.url_base == '' then
      vim.notify(
        'review: cannot enable auto-sync — no preview attached.\n'
          .. 'Use SPC d p to start, or :ReviewAttach <port> first.',
        vim.log.levels.WARN
      )
      auto_sync_enabled = false
      return
    end

    auto_sync_augroup = vim.api.nvim_create_augroup('review_auto_sync', { clear = true })

    -- Sync on buffer enter (page-level)
    vim.api.nvim_create_autocmd('BufEnter', {
      group = auto_sync_augroup,
      pattern = { '*.org', '*.md', '*.markdown', '*.qmd' },
      callback = function()
        -- Debounce: only sync after settling
        vim.defer_fn(function()
          if auto_sync_enabled then
            sync_browser()
          end
        end, 300)
      end,
    })

    -- Sync on cursor hold (heading-level — less aggressive than CursorMoved)
    vim.api.nvim_create_autocmd('CursorHold', {
      group = auto_sync_augroup,
      pattern = { '*.org', '*.md', '*.markdown', '*.qmd' },
      callback = function()
        if auto_sync_enabled then
          sync_browser()
        end
      end,
    })

    vim.notify('review: auto-sync ON (syncs on buffer switch + cursor hold)', vim.log.levels.INFO)
  else
    if auto_sync_augroup then
      vim.api.nvim_del_augroup_by_id(auto_sync_augroup)
      auto_sync_augroup = nil
    end
    vim.notify('review: auto-sync OFF', vim.log.levels.INFO)
  end
end

-- ── Highlight review comments ───────────────────────────────────────────

local function setup_review_highlights()
  vim.api.nvim_set_hl(0, 'ReviewComment', { bg = '#3d3520', italic = true })
  vim.api.nvim_set_hl(0, 'ReviewCommentBorder', { fg = '#e0af68', bold = true })

  vim.fn.matchadd('ReviewCommentBorder', '#+begin_review.*$')
  vim.fn.matchadd('ReviewCommentBorder', '#+end_review')
  vim.fn.matchadd('ReviewCommentBorder', '<!-- REVIEW.*$')
  vim.fn.matchadd('ReviewComment', 'REVIEW([^)]*):.*')
end

-- ══════════════════════════════════════════════════════════════════════════
-- MODULE REGISTRATION
-- ══════════════════════════════════════════════════════════════════════════

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
    -- Preview management (SPC d p / SPC d P / SPC d o)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>dp', start_preview, {
      desc = 'review.start_preview', silent = true,
    })

    vim.keymap.set('n', '<leader>dP', stop_preview, {
      desc = 'review.stop_preview', silent = true,
    })

    vim.keymap.set('n', '<leader>do', function()
      if preview.url_base ~= '' then
        vim.ui.open(preview.url_base)
      else
        start_preview()
      end
    end, {
      desc = 'review.open_browser', silent = true,
    })

    ----------------------------------------------------------------
    -- Browser sync (SPC d s / SPC d S)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>ds', sync_browser, {
      desc = 'review.sync_browser', silent = true,
    })

    vim.keymap.set('n', '<leader>dS', toggle_auto_sync, {
      desc = 'review.toggle_auto_sync', silent = true,
    })

    ----------------------------------------------------------------
    -- Comments (SPC d c / SPC d i / SPC d r / SPC d l / SPC d g)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>dc', insert_comment, {
      desc = 'review.add_comment', silent = true,
    })

    vim.keymap.set('v', '<leader>dc', function()
      vim.cmd 'normal! "vy'
      local selection = vim.fn.getreg 'v'
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
      insert_comment('RE: ' .. selection)
    end, {
      desc = 'review.comment_on_selection', silent = true,
    })

    vim.keymap.set('n', '<leader>di', insert_inline_comment, {
      desc = 'review.inline_comment', silent = true,
    })

    vim.keymap.set('n', '<leader>dr', resolve_comment, {
      desc = 'review.resolve_comment', silent = true,
    })

    vim.keymap.set('n', '<leader>dl', list_comments, {
      desc = 'review.list_comments', silent = true,
    })

    ----------------------------------------------------------------
    -- Comment navigation (]r / [r)
    ----------------------------------------------------------------

    vim.keymap.set('n', ']r', function() jump_comment 'next' end, {
      desc = 'review.next_comment', silent = true,
    })

    vim.keymap.set('n', '[r', function() jump_comment 'prev' end, {
      desc = 'review.prev_comment', silent = true,
    })

    ----------------------------------------------------------------
    -- Grep comments across project
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
      desc = 'review.grep_comments', silent = true,
    })

    ----------------------------------------------------------------
    -- Auto-highlight review comments
    ----------------------------------------------------------------

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('review_highlights', { clear = true }),
      pattern = { 'org', 'markdown', 'quarto' },
      callback = setup_review_highlights,
    })

    ----------------------------------------------------------------
    -- User commands
    ----------------------------------------------------------------

    vim.api.nvim_create_user_command('ReviewPreview', function(opts)
      if opts.bang then stop_preview() else start_preview() end
    end, {
      bang = true,
      desc = 'Start (or stop with !) the document preview server',
    })

    vim.api.nvim_create_user_command('ReviewAttach', function(opts)
      local port = tonumber(opts.args)
      if not port then
        vim.notify('Usage: :ReviewAttach <port>', vim.log.levels.ERROR)
        return
      end
      attach_preview(port)
    end, {
      nargs = 1,
      desc = 'Attach to an externally-running preview server on <port>',
    })

    vim.api.nvim_create_user_command('ReviewDetach', function()
      preview.url_base = ''
      preview.managed = false
      preview.task_id = nil
      if auto_sync_enabled then toggle_auto_sync() end
      vim.notify('review: detached', vim.log.levels.INFO)
    end, {
      desc = 'Detach from preview server (stop sync, keep server running)',
    })

    vim.api.nvim_create_user_command('ReviewComment', function(opts)
      insert_comment(opts.args ~= '' and opts.args or nil)
    end, {
      nargs = '?',
      desc = 'Insert a review comment (optional body text)',
    })

    vim.api.nvim_create_user_command('ReviewSync', sync_browser, {
      desc = 'Sync browser to current file + heading',
    })

    vim.api.nvim_create_user_command('ReviewPort', function(opts)
      local port = tonumber(opts.args)
      if not port then
        vim.notify('Current preview port: ' .. preview.port, vim.log.levels.INFO)
        return
      end
      preview.port = port
      preview.url_base = 'http://localhost:' .. port
      vim.notify('review: port set to ' .. port, vim.log.levels.INFO)
    end, {
      nargs = '?',
      desc = 'Get or set the preview server port',
    })
  end,
}
