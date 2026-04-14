-- lua/lib/keys.lua

local M = {}

M._registry = {}
M._action_registry = {}

---@class KeymapSpec
---@field lhs string Left hand side (the key sequence)
---@field rhs string|function Right hand side (action)
---@field mode? string|string[] Vim mode(s), defaults to "n"
---@field desc string Human readable description - required
---@field module? string Which module registered this - required for action registry
---@field buffer? number Buffer-local if set
---@field silent? boolean Defaults to true
---@field nowait? boolean
---@field expr? boolean
---@field when? function Returns true if action is currently valid
---@field category? string For agent action grouping, defaults to module
---@field allow_override? boolean

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

---@param mode string|string[]|nil
---@return string[]
local function normalize_mode(mode)
  if mode == nil then return { 'n' } end
  if type(mode) == 'string' then return { mode } end
  return mode
end

---@param mode string
---@param lhs string
---@param buffer number|nil
---@return string
local function registry_key(mode, lhs, buffer)
  local buf_suffix = buffer and ('@' .. buffer) or '@global'
  local normalized = lhs:lower():gsub('%s+', '')
  return string.format('%s:%s%s', mode, normalized, buf_suffix)
end

---Generate a stable action ID from module and description
---"navigation" + "Find files" -> "navigation.find_files"
---Note: descriptions are load-bearing for agent addressability
---Renaming a description will silently change its agent-facing ID
---@param module string
---@param desc string
---@return string
local function compose_id(module, desc)
  local normalized = desc
    :lower()
    :gsub('%s+', '_') -- spaces to underscores
    :gsub('[^%w_]', '') -- strip anything not alphanumeric or underscore
  return string.format('%s.%s', module, normalized)
end

---@param spec KeymapSpec
---@return boolean
---@return string? error
local function validate_spec(spec)
  if type(spec) ~= 'table' then return false, 'spec must be a table' end

  if not spec.lhs or spec.lhs == '' then return false, 'lhs is required' end

  if not spec.rhs then return false, 'rhs is required' end

  if not spec.desc or spec.desc == '' then return false, string.format("desc is required (lhs: '%s', module: '%s')", spec.lhs, spec.module or 'unknown') end

  if spec.when and type(spec.when) ~= 'function' then return false, string.format("when must be a function (lhs: '%s')", spec.lhs) end

  return true
end

-- ─── Public API ───────────────────────────────────────────────────────────────

---Register a single keymap
---@param spec KeymapSpec
function M.map(spec)
  local valid, err = validate_spec(spec)
  if not valid then
    vim.notify(string.format('[keys] Invalid keymap spec: %s', err), vim.log.levels.ERROR)
    return
  end

  local modes = normalize_mode(spec.mode)

  for _, mode in ipairs(modes) do
    local key = registry_key(mode, spec.lhs, spec.buffer)

    -- Conflict detection
    if not spec.allow_override and M._registry[key] then
      local existing = M._registry[key]
      vim.notify(
        string.format(
          "[keys] Conflict: '%s' (%s) [%s] already registered by '%s' [%s], overwriting from '%s'",
          spec.lhs,
          mode,
          spec.desc,
          existing.module or 'unknown',
          existing.desc,
          spec.module or 'unknown'
        ),
        vim.log.levels.WARN
      )
    end

    M._registry[key] = {
      lhs = spec.lhs,
      mode = mode,
      desc = spec.desc,
      module = spec.module,
      buffer = spec.buffer,
    }

    vim.keymap.set(mode, spec.lhs, spec.rhs, {
      desc = spec.desc,
      buffer = spec.buffer,
      silent = spec.silent ~= false,
      nowait = spec.nowait,
      expr = spec.expr,
    })
  end

  -- Action registry is mode-agnostic: an action is identified by
  -- what it does, not which mode it operates in. If a keymap spans
  -- multiple modes we store it once under a composed ID.
  -- Buffer-local keymaps are excluded: they are context-specific
  -- and should not be part of the global agent action surface.
  if spec.module and not spec.buffer then
    local id = compose_id(spec.module, spec.desc)

    if M._action_registry[id] then
      vim.notify(
        string.format("[keys] Action ID collision: '%s' already registered, skipping (desc: '%s', module: '%s')", id, spec.desc, spec.module),
        vim.log.levels.WARN
      )
    else
      M._action_registry[id] = {
        id = id,
        lhs = spec.lhs,
        rhs = spec.rhs,
        modes = normalize_mode(spec.mode),
        desc = spec.desc,
        module = spec.module,
        category = spec.category or spec.module,
        when = spec.when,
      }
    end
  end
end

---Register multiple keymaps sharing module context and common options
---@param module string Module name for attribution
---@param mappings KeymapSpec[]
---@param defaults? table Default values applied to all mappings in the group
function M.map_group(module, mappings, defaults)
  defaults = defaults or {}
  for _, spec in ipairs(mappings) do
    local merged = vim.tbl_extend('force', defaults, spec)
    merged.module = module
    M.map(merged)
  end
end

---Register a which-key group label
---Deferred via vim.schedule so which-key load order is not a concern
---@param prefix string
---@param label string
---@param mode? string
function M.register_group(prefix, label, mode)
  vim.schedule(function()
    local ok, wk = pcall(require, 'which-key')
    if not ok then return end
    wk.add { { prefix, group = label, mode = mode or 'n' } }
  end)
end

---Delete a keymap and remove from registries
---@param lhs string
---@param mode? string|string[]
---@param buffer? number
function M.unmap(lhs, mode, buffer)
  local modes = normalize_mode(mode)
  for _, m in ipairs(modes) do
    local key = registry_key(m, lhs, buffer)
    M._registry[key] = nil
    pcall(vim.keymap.del, m, lhs, { buffer = buffer })
  end
end

---Execute an action by composed ID
---@param id string e.g. "navigation.find_files"
---@param context? table Optional context passed to function actions
---@return boolean success
---@return string? error
function M.execute(id, context)
  local action = M._action_registry[id]

  if not action then return false, string.format("[keys] Unknown action: '%s'", id) end

  if action.when and not action.when() then return false, string.format("[keys] Action '%s' precondition not met", id) end

  if type(action.rhs) == 'function' then
    local ok, err = pcall(action.rhs, context)
    return ok, err
  end

  if type(action.rhs) == 'string' then
    local ok, err = pcall(vim.cmd, action.rhs)
    return ok, err
  end

  return false, string.format("[keys] Action '%s' has invalid rhs type: %s", id, type(action.rhs))
end

---Query available actions with optional filtering
---@param opts? { category?: string, module?: string, when?: boolean }
---@return table[]
function M.available_actions(opts)
  opts = opts or {}
  local results = {}

  for _, action in pairs(M._action_registry) do
    local include = true

    if opts.category and action.category ~= opts.category then include = false end

    if opts.module and action.module ~= opts.module then include = false end

    -- when=true means only return actions whose preconditions are met
    if opts.when and action.when and not action.when() then include = false end

    if include then
      table.insert(results, {
        id = action.id,
        lhs = action.lhs,
        modes = action.modes,
        desc = action.desc,
        module = action.module,
        category = action.category,
      })
    end
  end

  return results
end

---Get all keymaps registered by a specific module
---@param module string
---@return table[]
function M.get_by_module(module)
  local results = {}
  for _, reg in pairs(M._registry) do
    if reg.module == module then table.insert(results, reg) end
  end
  return results
end

-- ─── Introspection ────────────────────────────────────────────────────────────

function M.status()
  local by_module = {}

  for _, reg in pairs(M._registry) do
    local mod = reg.module or 'unknown'
    by_module[mod] = by_module[mod] or {}
    table.insert(by_module[mod], reg)
  end

  local lines = { '# Keymap Registry', string.rep('─', 50), '' }

  local module_names = vim.tbl_keys(by_module)
  table.sort(module_names)

  for _, mod in ipairs(module_names) do
    table.insert(lines, string.format('## %s', mod))

    local maps = by_module[mod]
    table.sort(maps, function(a, b) return a.lhs < b.lhs end)

    for _, reg in ipairs(maps) do
      local buf_label = reg.buffer and string.format(' [buf:%s]', reg.buffer) or ''

      table.insert(lines, string.format('  [%s]%-4s %-20s %s%s', reg.mode, '', reg.lhs, reg.desc or '(no description)', buf_label))
    end

    table.insert(lines, '')
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, buf)
end

return M
