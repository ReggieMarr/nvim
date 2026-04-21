-- lua/lib/articulation.lua
-- Thin registry over vim's native keymap API.
-- Only stores what vim cannot: preconditions, module attribution, schema.
-- Keymaps themselves are the source of truth; use nvim_get_keymap for introspection.

---@class ArticulationLib
local M = {}

---@class ActionMeta
---@field id string
---@field module string
---@field when? fun(): boolean  -- No state arg; closure captures what it needs
---@field params_schema? table

---@type table<string, ActionMeta>  -- action_id -> meta
M._meta = {}

---@class ActionBinding
---@field lhs string
---@field mode? string|string[]
---@field buffer? number

---@class ActionSpec
---@field id string
---@field module string
---@field handler fun(params?: table)
---@field desc string
---@field bindings? ActionBinding[]
---@field when? fun(): boolean
---@field params_schema? table
---@field allow_override? boolean

---Register an action and its keybindings.
---The keymap callback IS the action. No intermediate dispatch.
---@param spec ActionSpec
function M.register(spec)
  local fqid = spec.module .. '.' .. spec.id

  -- Build the guarded handler once; shared by keymap callback and command
  local function invoke(params)
    if spec.when then
      local ok, result = pcall(spec.when)
      if not ok then
        vim.notify(('[articulation] precondition error %s: %s'):format(fqid, result), vim.log.levels.WARN)
        return
      end
      if not result then
        vim.notify(('[articulation] precondition not met: %s'):format(fqid), vim.log.levels.INFO)
        return
      end
    end
    local ok, err = pcall(spec.handler, params)
    if not ok then vim.notify(('[articulation] %s failed: %s'):format(fqid, err), vim.log.levels.ERROR) end
  end

  -- Store only what vim cannot represent natively
  M._meta[fqid] = {
    id = spec.id,
    module = spec.module,
    when = spec.when,
    params_schema = spec.params_schema,
  }

  -- Keybindings: vim.keymap.set with callback; desc is the contract
  for _, binding in ipairs(spec.bindings or {}) do
    local modes = type(binding.mode) == 'table' and binding.mode or { binding.mode or 'n' }
    vim.keymap.set(modes, binding.lhs, invoke, {
      desc = spec.desc,
      buffer = binding.buffer,
      silent = true,
    })
  end

  -- User command for agent/manual invocation
  -- nvim_create_user_command does not support buffer-local + params cleanly,
  -- so we register one global command per action id.
  -- Buffer-local actions invoked via command run against current buffer,
  -- which is the correct semantic for agent calls.
  local cmd = M._to_cmd_name(fqid)
  pcall(vim.api.nvim_create_user_command, cmd, function(cmd_args)
    -- Parse args as key=value pairs for agent invocation
    local params = M._parse_cmd_args(cmd_args.args)
    invoke(params)
  end, {
    desc = spec.desc,
    nargs = '?',
  })
end

---Register a group sharing a module.
---@param module string
---@param specs ActionSpec[]
function M.register_group(module, specs)
  for _, spec in ipairs(specs) do
    spec.module = spec.module or module
    M.register(spec)
  end
end

---Execute an action by fully-qualified id (agent entry point).
---@param fqid string e.g. "language.go_to_definition"
---@param params? table
function M.execute(fqid, params)
  -- We stored the guarded handler in the command; for direct agent calls
  -- we re-resolve through the command to avoid duplicating dispatch logic.
  -- Alternatively, store invoke in _meta if you prefer not going through commands.
  local cmd = M._to_cmd_name(fqid)
  -- Build args string from params table if provided
  local args = ''
  if params then
    local parts = {}
    for k, v in pairs(params) do
      parts[#parts + 1] = k .. '=' .. tostring(v)
    end
    args = table.concat(parts, ' ')
  end
  local ok, err = pcall(vim.cmd, cmd .. (args ~= '' and (' ' .. args) or ''))
  if not ok then vim.notify(('[articulation] execute failed for %s: %s'):format(fqid, err), vim.log.levels.ERROR) end
end

---Introspect using vim's native keymap storage as source of truth.
---Augments with precondition state from _meta.
function M.status()
  local lines = { '# Articulation Registry', ('─'):rep(50), '' }

  -- Group meta by module for the header structure
  local by_module = {}
  for fqid, meta in pairs(M._meta) do
    by_module[meta.module] = by_module[meta.module] or {}
    by_module[meta.module][fqid] = meta
  end

  local modules = vim.tbl_keys(by_module)
  table.sort(modules)

  for _, mod in ipairs(modules) do
    lines[#lines + 1] = '## ' .. mod
    local actions = by_module[mod]

    -- Pull actual keymaps from vim; this is the real source of truth
    local keymaps_by_desc = M._collect_keymaps_by_desc()

    for fqid, meta in vim.spairs(actions) do
      lines[#lines + 1] = ('  %s'):format(fqid)

      -- Get bindings from vim's own tables, not our registry
      local bound = keymaps_by_desc[fqid] or {}
      for _, km in ipairs(bound) do
        local loc = km.buffer ~= 0 and (' @buf:%d'):format(km.buffer) or ''
        lines[#lines + 1] = ('    [%s] %s%s'):format(km.mode, km.lhs, loc)
      end

      if meta.when then
        local ok, result = pcall(meta.when)
        local status = ok and (result and '✓ met' or '✗ not met') or '! error'
        lines[#lines + 1] = ('    when: %s'):format(status)
      end

      lines[#lines + 1] = ''
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, buf)
end

---Collect all keymaps (global + all open buffers) indexed by desc.
---desc is the stable contract between the keymap and the action registry.
---@return table<string, table[]>
function M._collect_keymaps_by_desc()
  local result = {}
  local function collect(maps, bufnr)
    for _, km in ipairs(maps) do
      if km.desc then
        result[km.desc] = result[km.desc] or {}
        -- nvim_get_keymap returns buffer=0 for global; normalize
        km.buffer = bufnr
        result[km.desc][#result[km.desc] + 1] = km
      end
    end
  end

  for _, mode in ipairs { 'n', 'v', 'i', 'x' } do
    collect(vim.api.nvim_get_keymap(mode), 0)
  end

  -- Buffer-local: check all listed buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      for _, mode in ipairs { 'n', 'v', 'i', 'x' } do
        local ok, maps = pcall(vim.api.nvim_buf_get_keymap, bufnr, mode)
        if ok then collect(maps, bufnr) end
      end
    end
  end

  return result
end

---@param fqid string
---@return string
function M._to_cmd_name(fqid)
  return fqid:gsub('[%._](%a)', function(c) return c:upper() end):gsub('^%a', string.upper)
end

---Parse "key=value key2=value2" from command args.
---@param args string
---@return table
function M._parse_cmd_args(args)
  local params = {}
  if not args or args == '' then return params end
  for k, v in args:gmatch '(%w+)=(%S+)' do
    -- Attempt numeric coercion
    params[k] = tonumber(v) or v
  end
  return params
end

return M
