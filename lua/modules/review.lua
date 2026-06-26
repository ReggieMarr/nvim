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
-- Browser sync (two modes):
--   Page-level  (BufEnter / SPC d s) — uses xdg-open, focus steal OK
--   Heading-level (auto-sync)        — pushes via in-process WebSocket
--     relay (lua/utils/websocket.lua), a userscript in the browser
--     connects and scrolls without stealing focus
--
-- File path -> URL mapping:
--   Auto-detects docs_root by searching for known content directories
--   (documentation/content > documentation > docs).  Strips docs_root
--   from file path, removes extension, lowercases.
--   Override: workspace.docs_root state key, vim.g/b.review_path_map.
--
-- Re-export:
--   SPC d e  — re-run x7-tools pages prepare to regenerate markdown
--              from the current org source (runs as an overseer task)
--
-- Comment format (file-type aware):
--   org:      #+begin_review AUTHOR TIMESTAMP ... #+end_review
--   markdown: <!-- REVIEW AUTHOR TIMESTAMP ... -->
--
-- Keybindings:  SPC d  (document review prefix)
-- Domain: review

local env = require 'env'

-- ══════════════════════════════════════════════════════════════════════════
-- CACHED STATE
-- ══════════════════════════════════════════════════════════════════════════

---@type string|nil  memoised git user.name (session lifetime)
local cached_author = nil

---@type table<number, string|nil>  last synced heading slug per bufnr
local last_synced_slug = {}

---@type table<number, boolean>  buffers already warned about boundary check
local warned_bufs = {}

---@type number|nil  debounce timer handle
local sync_timer = nil

-- ══════════════════════════════════════════════════════════════════════════
-- COMMENT SYSTEM
-- ══════════════════════════════════════════════════════════════════════════

local function timestamp()
  return os.date '%Y-%m-%d %H:%M'
end

local function author()
  if cached_author then
    return cached_author
  end
  local git_user = vim.fn.systemlist('git config user.name')[1]
  if vim.v.shell_error == 0 and git_user and git_user ~= '' then
    cached_author = git_user
    return cached_author
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
    if found > 0 then
      return
    end
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
      vim.notify('Resolved review comment (' .. (block_end - block_start + 1) .. ' lines)')
      return
    end
    if line:match '<!%-%- REVIEW%(.*%):' then
      vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
        line:gsub('%s*<!%-%- REVIEW%(.-%): ?%-%->', ''),
      })
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
    if
      line:match 'REVIEW'
      and (
        line:match 'begin_review'
        or line:match '<!%-%- REVIEW'
        or line:match 'REVIEW%('
        or line:match '# REVIEW'
      )
    then
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
---@field task_id number|nil   overseer task id for preview server
---@field ws_server table|nil  websocket.Server instance for heading-level sync
---@field port number          preview server port
---@field relay_port number    WebSocket relay port (port + 10000)
---@field url_base string      e.g. "http://localhost:8080"
---@field managed boolean      true if neovim started the preview server
local preview = {
  task_id = nil,
  ws_server = nil,
  port = 8080,
  relay_port = 18080,
  url_base = 'http://localhost:8080',
  managed = false,
}

---Detect the best preview command for the current project.
---@return { cmd: string[], port: number, name: string, cwd: string, env: table|nil }|nil
local function detect_preview_backend()
  local root = env.state.get 'workspace.root' or vim.fn.getcwd()

  local candidates = {
    {
      path = root .. '/tools/pages-preview.sh',
      cmd = function(p)
        return { 'bash', p, '--port', tostring(preview.port) }
      end,
      name = 'Quartz (pages-preview.sh)',
    },
    {
      path = root .. '/tools/x7-forge/implementation/x7-tools/run.sh',
      cmd = function(p)
        return { 'bash', p, 'pages', 'preview' }
      end,
      name = 'x7-tools pages preview',
      env = { X7_NO_DOCKER = '1', X7_PROJECT_ROOT = root },
    },
    {
      path = root .. '/tools/x7-forge/tools/run.sh',
      cmd = function(p)
        return { 'bash', p, 'pages', 'preview' }
      end,
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

---Start the WebSocket relay server for heading-level sync.
---Runs inside Neovim via vim.uv (no external process).
local function start_relay()
  if preview.ws_server and preview.ws_server:is_running() then
    return -- already running
  end

  local websocket = require 'utils.websocket'
  preview.relay_port = preview.port + 10000
  local ws = websocket.new(preview.relay_port)

  local ok, err = ws:start()
  if not ok then
    vim.notify('review: WebSocket relay failed to start on :' .. preview.relay_port .. ' -- ' .. tostring(err), vim.log.levels.WARN)
    return
  end

  preview.ws_server = ws
end

---Stop the WebSocket relay server.
local function stop_relay()
  if preview.ws_server then
    preview.ws_server:stop()
    preview.ws_server = nil
  end
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
      vim.notify('review: preview already running -- opened browser', vim.log.levels.INFO)
      return
    end
  end

  local overseer = require 'overseer'
  local task = overseer.new_task {
    name = string.format('%s %s', '\xF0\x9F\x93\x96', backend.name),
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

  -- Also start the WebSocket relay for heading-level sync
  start_relay()

  vim.defer_fn(function()
    vim.ui.open(preview.url_base)
  end, 2500)

  vim.notify(
    'review: started ' .. backend.name .. ' on port ' .. backend.port
      .. (preview.ws_server and ' (ws relay :' .. preview.relay_port .. ')' or ''),
    vim.log.levels.INFO
  )
end

---Stop the preview server.
local function stop_preview()
  if not preview.task_id then
    if not preview.managed then
      preview.url_base = ''
      preview.managed = false
      stop_relay()
      vim.notify('review: detached from external preview', vim.log.levels.INFO)
    else
      vim.notify('review: no preview server running', vim.log.levels.INFO)
    end
    return
  end

  local overseer = require 'overseer'
  local task = overseer.get_task(preview.task_id)
  if task and not task:is_complete() then
    task:stop()
  end
  preview.task_id = nil
  preview.managed = false
  stop_relay()
  vim.notify('review: stopped preview server', vim.log.levels.INFO)
end

---Attach to an externally-running preview server.
---@param port number
local function attach_preview(port)
  preview.port = port
  preview.relay_port = port + 10000
  preview.url_base = 'http://localhost:' .. port
  preview.managed = false
  preview.task_id = nil
  -- Start WebSocket relay for heading-level sync even with external server
  start_relay()
  vim.notify(
    'review: attached to http://localhost:' .. port
      .. (preview.ws_server and ' (ws relay :' .. preview.relay_port .. ')' or ''),
    vim.log.levels.INFO
  )
end

-- ══════════════════════════════════════════════════════════════════════════
-- BROWSER SYNC
-- ══════════════════════════════════════════════════════════════════════════

---Slugify a heading string the way Quartz/Hugo/most SSGs do.
---@param heading string  raw heading text (without the # or * prefix)
---@return string slug    URL-safe anchor
--- Slugify a heading to match github-slugger (used by Quartz/rehype-slug).
--- Key difference from a naive slugify: each space becomes ONE hyphen
--- independently, consecutive hyphens are NOT collapsed.  This matters
--- for headings containing em dashes ("A — B" → "a--b", not "a-b").
local function slugify(heading)
  return heading
    :lower()
    :gsub('[^%w%s%-]', '') -- strip non-alnum (keep [a-zA-Z0-9_ ], spaces, hyphens)
    :gsub(' ', '-') -- each space → one hyphen (do NOT collapse %s+)
    :gsub('^%-+', '') -- trim leading hyphens
    :gsub('%-+$', '') -- trim trailing hyphens
end

---Find the nearest heading above (or at) the cursor.
---@return string|nil heading_slug
--- Heading index cache: maps bufnr → { tick, headings }.
--- headings is a sorted list of { row, slug } entries built from a single
--- full-buffer scan.  The cache is invalidated when b:changedtick advances
--- (any buffer edit) so we never re-scan on cursor movement alone.
---@type table<number, { tick: number, headings: { row: number, slug: string }[] }>
local heading_cache = {}

--- Build (or return cached) heading index for the current buffer.
---@return { row: number, slug: string }[]
local function get_heading_index()
  local bufnr = vim.api.nvim_get_current_buf()
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cached = heading_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.headings
  end

  local ft = vim.bo[bufnr].filetype
  local pat
  if ft == 'org' then
    pat = '^%*+ (.+)$'
  elseif ft == 'markdown' or ft == 'quarto' then
    pat = '^#+ (.+)$'
  else
    heading_cache[bufnr] = { tick = tick, headings = {} }
    return {}
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local headings = {}
  for i, line in ipairs(lines) do
    local heading = line:match(pat)
    if heading then
      headings[#headings + 1] = { row = i, slug = slugify(heading) }
    end
  end

  heading_cache[bufnr] = { tick = tick, headings = headings }
  return headings
end

--- Find the nearest heading at or above the cursor.
--- Uses the cached heading index — O(log N) binary search on a list that
--- is rebuilt only when the buffer text changes, not on every cursor move.
---@return string|nil heading_slug
local function nearest_heading_slug()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local headings = get_heading_index()
  if #headings == 0 then
    return nil
  end

  -- Binary search: find the last heading with row <= cursor row
  local lo, hi = 1, #headings
  local best = nil
  while lo <= hi do
    local mid = math.floor((lo + hi) / 2)
    if headings[mid].row <= row then
      best = mid
      lo = mid + 1
    else
      hi = mid - 1
    end
  end

  return best and headings[best].slug or nil
end

--- Docs-root cache: avoids repeated isdirectory() syscalls on every sync.
--- Invalidated when workspace.root changes (keyed on project root path).
---@type table<string, string>  project_root -> relative docs root
local docs_root_cache = {}

---Auto-detect the docs root for the current project.
---Searches for known content directories in priority order.
---Result is cached per project root (isdirectory is only called on first use).
---@param root string|nil  project root (defaults to workspace.root)
---@return string  relative path from project root (e.g. 'documentation/content')
local function get_docs_root(root)
  -- Manual override takes priority (not cached — can change at runtime)
  local override = env.state.get 'workspace.docs_root'
  if override then
    return override
  end

  root = root or env.state.get 'workspace.root' or vim.fn.getcwd()

  -- Cache hit
  if docs_root_cache[root] then
    return docs_root_cache[root]
  end

  -- Search in priority order: most specific first
  local candidates = {
    'documentation/content',  -- x7-cavorite layout
    'documentation',          -- x7-wiki layout
    'docs',                   -- generic
    'content',                -- Hugo/Quartz direct
  }
  local result = 'documentation' -- fallback
  for _, candidate in ipairs(candidates) do
    if vim.fn.isdirectory(root .. '/' .. candidate) == 1 then
      result = candidate
      break
    end
  end

  docs_root_cache[root] = result
  return result
end

---Get the full absolute docs root path.
---@param root string|nil  project root (defaults to workspace.root)
---@return string
local function get_full_docs_root(root)
  root = root or env.state.get 'workspace.root' or vim.fn.getcwd()
  return root .. '/' .. get_docs_root(root)
end

---Validate that the current buffer is a doc file inside the docs root.
---@return boolean ok
---@return string|nil reason  human-readable failure reason
local function validate_sync_target()
  local ft = vim.bo.filetype
  if ft ~= 'org' and ft ~= 'markdown' and ft ~= 'quarto' then
    return false, 'buffer filetype is "' .. ft .. '", not org/markdown/quarto'
  end

  local file = vim.fn.expand '%:p'
  local full_docs = get_full_docs_root()
  if not vim.startswith(file, full_docs) then
    return false, 'file is outside docs root (' .. get_docs_root() .. '/)'
  end

  return true, nil
end

---Map the current buffer's file path to a preview URL path.
---@return string url_path  e.g. "/plans/icmp/interface_control_model_plan"
local function file_to_url_path()
  local file = vim.fn.expand '%:p'

  -- 1. Buffer-local override
  if vim.b.review_path_map then
    local result = vim.b.review_path_map(file)
    if result then
      return result
    end
  end

  -- 2. Global/project override
  if vim.g.review_path_map then
    local result = vim.g.review_path_map(file)
    if result then
      return result
    end
  end

  -- 3. Built-in: strip full_docs_root, strip extension, lowercase
  local full_docs = get_full_docs_root()
  local rel = file:gsub('^' .. vim.pesc(full_docs) .. '/', '')

  -- Strip file extension (last .xxx component)
  rel = rel:gsub('%.[^/]+$', '')

  -- Lowercase the whole relative path
  rel = rel:lower()

  return '/' .. rel
end

---Push the target URL to all connected WebSocket clients.
---Does NOT open the browser (no focus steal).
---@param url string
---@param msg_type string|nil  "scroll" or "navigate" (default "scroll")
local function push_sync_url(url, msg_type)
  if preview.ws_server and preview.ws_server:is_running() then
    -- Parse URL to extract path and anchor separately
    local path_part = url:match 'https?://[^/]+(.*)' or '/'
    local anchor = path_part:match '#(.+)$'
    local clean_path = path_part:gsub('#.*$', '')
    preview.ws_server:broadcast_json {
      type = msg_type or 'scroll',
      url = url,
      path = clean_path,
      anchor = anchor or '',
    }
  end
end

---Sync the browser to the current file and nearest heading.
---@param opts { heading_only: boolean, push_only: boolean }|nil
---  heading_only — send "scroll" type (heading-level, same page assumed)
---  push_only   — send "navigate" type via WebSocket but do NOT open browser
---               (used by auto-sync BufEnter to avoid stealing window focus)
local function sync_browser(opts)
  opts = opts or {}

  if preview.url_base == '' then
    vim.notify(
      'review: no preview attached.\n' .. 'Use SPC d p to start, or :ReviewAttach <port> for external server.',
      vim.log.levels.WARN
    )
    return
  end

  -- Boundary check
  local ok, reason = validate_sync_target()
  if not ok then
    local bufnr = vim.api.nvim_get_current_buf()
    if not warned_bufs[bufnr] then
      vim.notify('review: cannot sync -- ' .. (reason or 'unknown'), vim.log.levels.WARN)
      warned_bufs[bufnr] = true
    end
    return
  end

  local path = file_to_url_path()
  local slug = nearest_heading_slug()
  local url = preview.url_base .. path
  if slug then
    url = url .. '#' .. slug
  end

  if opts.heading_only then
    -- Heading-level: push via WebSocket, no focus steal
    push_sync_url(url, 'scroll')
  elseif opts.push_only then
    -- Page-level via WebSocket only (auto-sync BufEnter: no focus steal)
    push_sync_url(url, 'navigate')
  else
    -- Manual sync (SPC d s): push via WebSocket AND open browser
    push_sync_url(url, 'navigate')
    vim.ui.open(url)
  end
end

-- ── Auto-sync ───────────────────────────────────────────────────────────

local auto_sync_enabled = false
local auto_sync_augroup = nil

local function toggle_auto_sync()
  auto_sync_enabled = not auto_sync_enabled

  if auto_sync_enabled then
    if preview.url_base == '' then
      vim.notify(
        'review: cannot enable auto-sync -- no preview attached.\n'
          .. 'Use SPC d p to start, or :ReviewAttach <port> first.',
        vim.log.levels.WARN
      )
      auto_sync_enabled = false
      return
    end

    -- Start relay if not already running
    start_relay()

    auto_sync_augroup = vim.api.nvim_create_augroup('review_auto_sync', { clear = true })

    -- Page-level sync on buffer enter (WebSocket push, no focus steal).
    -- Uses "navigate" type so the userscript triggers SPA navigation in
    -- the browser without opening a new tab or stealing window focus.
    vim.api.nvim_create_autocmd('BufEnter', {
      group = auto_sync_augroup,
      pattern = { '*.org', '*.md', '*.markdown', '*.qmd' },
      callback = function()
        if not auto_sync_enabled then
          return
        end
        local bufnr = vim.api.nvim_get_current_buf()
        -- Clear caches for the new buffer
        last_synced_slug[bufnr] = nil
        warned_bufs[bufnr] = nil
        -- Debounce page-level sync (push only, no xdg-open)
        vim.defer_fn(function()
          if auto_sync_enabled then
            sync_browser { heading_only = false, push_only = true }
          end
        end, 300)
      end,
    })

    -- Heading-level sync on cursor movement (debounced, no focus steal).
    -- Performance: nearest_heading_slug() uses a cached heading index that
    -- rebuilds only when the buffer text changes (changedtick), so the
    -- CursorMoved callback is a cheap O(log N) binary search on cache hit.
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = auto_sync_augroup,
      pattern = { '*.org', '*.md', '*.markdown', '*.qmd' },
      callback = function()
        if not auto_sync_enabled then
          return
        end

        -- Quick check: same heading as last sync? (O(log N) with cache)
        local bufnr = vim.api.nvim_get_current_buf()
        local slug = nearest_heading_slug()
        if slug == last_synced_slug[bufnr] then
          return -- same heading, skip
        end

        -- Heading changed: start/restart 500ms debounce.
        -- Capture the slug now so the timer callback doesn't need to
        -- recompute it (avoids a redundant second call).
        if sync_timer then
          vim.fn.timer_stop(sync_timer)
        end

        local pending_slug = slug
        sync_timer = vim.fn.timer_start(500, function()
          sync_timer = nil
          last_synced_slug[bufnr] = pending_slug
          vim.schedule(function()
            sync_browser { heading_only = true }
          end)
        end)
      end,
    })

    vim.notify('review: auto-sync ON (page on BufEnter, heading on CursorMoved)', vim.log.levels.INFO)
  else
    if sync_timer then
      vim.fn.timer_stop(sync_timer)
      sync_timer = nil
    end
    if auto_sync_augroup then
      vim.api.nvim_del_augroup_by_id(auto_sync_augroup)
      auto_sync_augroup = nil
    end
    vim.notify('review: auto-sync OFF', vim.log.levels.INFO)
  end
end

-- ══════════════════════════════════════════════════════════════════════════
-- RE-EXPORT (org -> markdown via x7-tools pages prepare)
-- ══════════════════════════════════════════════════════════════════════════

---Re-export the current org file (or the whole docs tree) to markdown.
---Runs x7-tools pages prepare as an overseer task.
---@param current_only boolean  if true, pass only the current file
local function re_export(current_only)
  local root = env.state.get 'workspace.root' or vim.fn.getcwd()

  -- Find the x7-tools run.sh
  local run_sh
  local candidates = {
    root .. '/tools/x7-forge/implementation/x7-tools/run.sh',
    root .. '/tools/x7-forge/tools/run.sh',
  }
  for _, c in ipairs(candidates) do
    if vim.fn.filereadable(c) == 1 then
      run_sh = c
      break
    end
  end

  if not run_sh then
    -- Fallback: try pages-preview.sh with --rebuild
    local pages_sh = root .. '/tools/pages-preview.sh'
    if vim.fn.filereadable(pages_sh) == 1 then
      local overseer = require 'overseer'
      local task = overseer.new_task {
        name = string.format('%s re-export (pages-preview)', '\xF0\x9F\x94\x84'),
        cmd = { 'bash', pages_sh, '--rebuild', '--port', tostring(preview.port) },
        cwd = root,
        components = { 'default', { 'on_output_quickfix', open = false } },
      }
      task:start()
      vim.notify('review: re-exporting via pages-preview.sh --rebuild', vim.log.levels.INFO)
      return
    end

    vim.notify('review: no x7-tools run.sh or pages-preview.sh found', vim.log.levels.WARN)
    return
  end

  local cmd = { 'bash', run_sh, 'pages', 'prepare' }
  if current_only then
    local file = vim.fn.expand '%:p'
    table.insert(cmd, file)
  end

  local overseer = require 'overseer'
  local task = overseer.new_task {
    name = string.format(
      '%s re-export%s',
      '\xF0\x9F\x94\x84',
      current_only and ' (' .. vim.fn.expand '%:t' .. ')' or ' (all)'
    ),
    cmd = cmd,
    cwd = root,
    env = { X7_NO_DOCKER = '1', X7_PROJECT_ROOT = root },
    components = { 'default', { 'on_output_quickfix', open = false } },
  }
  task:start()
  vim.notify(
    'review: re-exporting ' .. (current_only and vim.fn.expand '%:t' or 'all docs'),
    vim.log.levels.INFO
  )
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
    -- No hooks registered at load time.  Auto-sync hooks are only
    -- created when the user enables auto-sync (SPC d S).

    ----------------------------------------------------------------
    -- Which-key group
    ----------------------------------------------------------------

    local ok_wk, wk = pcall(require, 'which-key')
    if ok_wk then
      wk.add {
        { '<leader>D', group = 'review' },
      }
    end

    ----------------------------------------------------------------
    -- Preview management (SPC d p / SPC d P / SPC d o)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>Dp', start_preview, {
      desc = 'review.start_preview',
      silent = true,
    })

    vim.keymap.set('n', '<leader>DP', stop_preview, {
      desc = 'review.stop_preview',
      silent = true,
    })

    vim.keymap.set('n', '<leader>Do', function()
      if preview.url_base ~= '' then
        vim.ui.open(preview.url_base)
      else
        start_preview()
      end
    end, {
      desc = 'review.open_browser',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Browser sync (SPC d s / SPC d S)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>Ds', function()
      -- Manual sync: clear slug cache so it always fires
      local bufnr = vim.api.nvim_get_current_buf()
      last_synced_slug[bufnr] = nil
      warned_bufs[bufnr] = nil
      sync_browser()
    end, {
      desc = 'review.sync_browser',
      silent = true,
    })

    vim.keymap.set('n', '<leader>DS', toggle_auto_sync, {
      desc = 'review.toggle_auto_sync',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Re-export (SPC d e / SPC d E)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>De', function()
      re_export(true)
    end, {
      desc = 'review.re_export_current',
      silent = true,
    })

    vim.keymap.set('n', '<leader>DE', function()
      re_export(false)
    end, {
      desc = 'review.re_export_all',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Comments (SPC d c / SPC d i / SPC d r / SPC d l / SPC d g)
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>Dc', insert_comment, {
      desc = 'review.add_comment',
      silent = true,
    })

    vim.keymap.set('v', '<leader>Dc', function()
      vim.cmd 'normal! "vy'
      local selection = vim.fn.getreg 'v'
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
      insert_comment('RE: ' .. selection)
    end, {
      desc = 'review.comment_on_selection',
      silent = true,
    })

    vim.keymap.set('n', '<leader>Di', insert_inline_comment, {
      desc = 'review.inline_comment',
      silent = true,
    })

    vim.keymap.set('n', '<leader>Dr', resolve_comment, {
      desc = 'review.resolve_comment',
      silent = true,
    })

    vim.keymap.set('n', '<leader>Dl', list_comments, {
      desc = 'review.list_comments',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Comment navigation (]r / [r)
    ----------------------------------------------------------------

    vim.keymap.set('n', ']r', function()
      jump_comment 'next'
    end, {
      desc = 'review.next_comment',
      silent = true,
    })

    vim.keymap.set('n', '[r', function()
      jump_comment 'prev'
    end, {
      desc = 'review.prev_comment',
      silent = true,
    })

    ----------------------------------------------------------------
    -- Grep comments across project
    ----------------------------------------------------------------

    vim.keymap.set('n', '<leader>Dg', function()
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
    -- Auto-highlight review comments (FileType is lightweight)
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
      if opts.bang then
        stop_preview()
      else
        start_preview()
      end
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
      stop_relay()
      if auto_sync_enabled then
        toggle_auto_sync()
      end
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

    vim.api.nvim_create_user_command('ReviewSync', function()
      local bufnr = vim.api.nvim_get_current_buf()
      last_synced_slug[bufnr] = nil
      warned_bufs[bufnr] = nil
      sync_browser()
    end, {
      desc = 'Sync browser to current file + heading',
    })

    vim.api.nvim_create_user_command('ReviewPort', function(opts)
      local port = tonumber(opts.args)
      if not port then
        vim.notify('Current preview port: ' .. preview.port, vim.log.levels.INFO)
        return
      end
      preview.port = port
      preview.relay_port = port + 10000
      preview.url_base = 'http://localhost:' .. port
      vim.notify('review: port set to ' .. port, vim.log.levels.INFO)
    end, {
      nargs = '?',
      desc = 'Get or set the preview server port',
    })

    vim.api.nvim_create_user_command('ReviewExport', function(opts)
      re_export(not opts.bang)
    end, {
      bang = true,
      desc = 'Re-export current file (or all with !) via x7-tools pages prepare',
    })

    vim.api.nvim_create_user_command('ReviewDocsRoot', function(opts)
      if opts.args == '' then
        vim.notify('docs_root: ' .. get_docs_root() .. '\nfull: ' .. get_full_docs_root(), vim.log.levels.INFO)
      else
        env.state.set('workspace.docs_root', opts.args)
        vim.notify('review: docs_root set to ' .. opts.args, vim.log.levels.INFO)
      end
    end, {
      nargs = '?',
      desc = 'Get or set the docs root (relative to project root)',
    })

    ----------------------------------------------------------------
    -- Cleanup on exit
    ----------------------------------------------------------------

    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = vim.api.nvim_create_augroup('review_cleanup', { clear = true }),
      callback = function()
        stop_relay()
      end,
    })
  end,

  -- Expose internals for testing (not part of the public API)
  _test = {
    get_docs_root = get_docs_root,
    get_full_docs_root = get_full_docs_root,
    file_to_url_path = file_to_url_path,
    slugify = slugify,
    nearest_heading_slug = nearest_heading_slug,
    validate_sync_target = validate_sync_target,
  },
}
