-- lua/lib/state.lua
-- Observable state model for the development environment.
--
-- Modules register providers that describe:
--   - what data they collect
--   - which events trigger a collection
--   - the schema of the collected data
--
-- The state table is the single place other surfaces (display conditions,
-- articulation preconditions, agent context) read editor state from.
-- Direct vim API calls for state in those surfaces are discouraged.

local M = {}

---@alias StateValue any

---Internal state table. Keys are dot-namespaced strings.
---e.g. "buffer.filetype", "lsp.attached_servers", "vcs.branch"
---@type table<string, StateValue>
M._store = {}

---Registered providers
---@type table<string, StateProvider>
M._providers = {}

---@class StateProvider
---@field id string Dot-namespaced identifier e.g. "buffer.filetype"
---@field events string[] Autocommand events that trigger collection
---@field collect fun(): StateValue Function that returns the current value
---@field pattern? string|string[] Autocommand pattern, defaults to "*"
---@field desc? string Human readable description of what this provides

---Register a state provider.
---The provider's collect function will be called on each triggering event
---and the result stored under provider.id.
---@param spec StateProvider
function M.register_provider(spec)
  vim.validate({
    id      = { spec.id, "string" },
    events  = { spec.events, "table" },
    collect = { spec.collect, "function" },
  })

  if M._providers[spec.id] then
    vim.notify(
      string.format("[state] Duplicate provider: '%s'", spec.id),
      vim.log.levels.WARN
    )
  end

  M._providers[spec.id] = spec

  -- Create a dedicated augroup per provider for clean lifecycle management.
  -- Named deterministically so re-registration replaces rather than duplicates.
  local augroup_name = "env_state_" .. spec.id:gsub("%.", "_")
  local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  vim.api.nvim_create_autocmd(spec.events, {
    group    = augroup,
    pattern  = spec.pattern or "*",
    desc     = spec.desc or ("env/state: collect " .. spec.id),
    callback = function()
      -- Wrap in pcall so a broken provider doesn't cascade
      local ok, value = pcall(spec.collect)
      if ok then
        M._store[spec.id] = value
      else
        vim.notify(
          string.format("[state] Provider '%s' error: %s", spec.id, value),
          vim.log.levels.WARN
        )
      end
    end,
  })

  -- Collect immediately so state is populated before the first event fires
  local ok, value = pcall(spec.collect)
  if ok then
    M._store[spec.id] = value
  end
end

---Read a state value by id.
---Returns nil if the provider is not registered or hasn't collected yet.
---@param id string
---@return StateValue
function M.get(id)
  return M._store[id]
end

---Write a state value directly, bypassing the provider system.
---Used by providers that collect asynchronously and push results in a callback.
---Also used in tests.
---@param id string
---@param value StateValue
function M._update(id, value)
  M._store[id] = value
end

---Return a snapshot of the full state store.
---Used by agents and introspection commands.
---@return table<string, StateValue>
function M.snapshot()
  -- Shallow copy so callers can't mutate the store directly
  return vim.tbl_extend("force", {}, M._store)
end

---Register the built-in core state providers.
---Called once during env initialization.
---These cover the state that is universally needed regardless of features.
function M._register_core_providers()
  -- Buffer
  M.register_provider({
    id      = "buffer.path",
    events  = { "BufEnter", "BufFilePost" },
    collect = function() return vim.api.nvim_buf_get_name(0) end,
    desc    = "Absolute path of the current buffer",
  })

  M.register_provider({
    id      = "buffer.filetype",
    events  = { "BufEnter", "FileType" },
    collect = function() return vim.bo.filetype end,
    desc    = "Filetype of the current buffer",
  })

  M.register_provider({
    id      = "buffer.modified",
    events  = { "BufEnter", "TextChanged", "InsertLeave" },
    collect = function() return vim.bo.modified end,
    desc    = "Whether the current buffer has unsaved changes",
  })

  M.register_provider({
    id      = "buffer.is_real",
    events  = { "BufEnter" },
    collect = function()
      local bufnr  = vim.api.nvim_get_current_buf()
      local bt     = vim.bo[bufnr].buftype
      local name   = vim.api.nvim_buf_get_name(bufnr)
      -- A "real" buffer is one backed by a file, not a plugin UI or scratch
      return bt == "" and name ~= ""
    end,
    desc    = "Whether the current buffer is a normal file buffer",
  })

  -- Window
  M.register_provider({
    id      = "window.id",
    events  = { "WinEnter" },
    collect = function() return vim.api.nvim_get_current_win() end,
    desc    = "Current window handle",
  })

  M.register_provider({
    id      = "window.is_float",
    events  = { "WinEnter" },
    collect = function()
      local cfg = vim.api.nvim_win_get_config(0)
      return cfg.relative ~= ""
    end,
    desc    = "Whether the current window is a floating window",
  })

  -- Workspace
  M.register_provider({
    id      = "workspace.cwd",
    events  = { "DirChanged" },
    collect = function() return vim.fn.getcwd() end,
    desc    = "Current working directory",
  })

  -- Editor mode
  M.register_provider({
    id      = "editor.mode",
    events  = { "ModeChanged" },
    collect = function() return vim.api.nvim_get_mode().mode end,
    desc    = "Current editor mode string",
  })
end

---Introspection: open state store in a scratch buffer
function M.status()
  local snapshot = M.snapshot()
  local lines    = { "# Environment State", string.rep("─", 50), "" }

  -- Sort keys for stable output
  local keys = vim.tbl_keys(snapshot)
  table.sort(keys)

  -- Group by namespace prefix
  local current_ns = nil
  for _, key in ipairs(keys) do
    local ns = key:match("^([^.]+)")
    if ns ~= current_ns then
      if current_ns ~= nil then table.insert(lines, "") end
      table.insert(lines, "## " .. ns)
      current_ns = ns
    end

    local value    = snapshot[key]
    local rendered = type(value) == "table"
      and vim.inspect(value):gsub("\n", " ")
      or tostring(value)

    table.insert(lines, string.format("  %-35s %s", key, rendered))
  end

  -- Also list registered providers that haven't collected yet
  local uncollected = {}
  for id, _ in pairs(M._providers) do
    if snapshot[id] == nil then
      table.insert(uncollected, id)
    end
  end

  if #uncollected > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Registered but not yet collected")
    for _, id in ipairs(uncollected) do
      table.insert(lines, "  " .. id)
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype    = "markdown"
  vim.bo[buf].modifiable  = false
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

return M
