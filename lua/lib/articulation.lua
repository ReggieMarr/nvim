-- lua/lib/articulation.lua
-- Action registry and keymap management.
--
-- The core abstraction: an "action" is a named, documented, preconditioned
-- operation. Keybindings, commands, and agent calls are all ways of invoking
-- the same underlying action registry entry.
--
-- This means:
--   - the handler is defined once
--   - the precondition is checked consistently regardless of invocation path
--   - the action is introspectable and attributable

---@class ArticulationLib
local M = {}

---@type table<string, Action>
M._actions = {}

---@type table<string, string> maps "mode:lhs[@bufnr]" -> action_id for conflict detection
M._bindings = {}

---Convert a fully qualified action id to a valid user command name.
---"interface.find_buffers" -> "InterfaceFindBuffers"
---"filesystem.toggle_tree" -> "FilesystemToggleTree"
---@param id string
---@return string
local function id_to_cmd_name(id)
  local result = id
    -- Replace dots and underscores with a marker, capitalize next char
    :gsub('[%._](%a)', function(c) return c:upper() end)
    -- Capitalize the very first character
    :gsub('^%a', string.upper)
  return result
end

---@class Action
---@field id string Stable dot-namespaced identifier e.g. "navigation.find_files"
---@field handler fun(params?: table) The operation to perform
---@field desc string Human readable description
---@field module string Module that registered this action
---@field when? fun(state: table): boolean Precondition evaluated against env.state
---@field bindings? ActionBinding[] Keybindings that invoke this action
---@field params_schema? table Parameter schema for agent invocation
---@field allow_override? boolean

---@class ActionBinding
---@field lhs string Key sequence
---@field mode? string|string[] Defaults to "n"
---@field buffer? number Buffer-local binding

---Register an action and optionally bind it to keys.
---@param spec Action
function M.register(spec)
  vim.validate {
    id = { spec.module .. '.' .. spec.id, 'string' },
    handler = { spec.handler, 'function' },
    desc = { spec.desc, 'string' },
    module = { spec.module, 'string' },
  }

  if not spec.desc or spec.desc == '' then error(string.format("[articulation] Action '%s' from module '%s' must have a description", spec.id, spec.module)) end

  -- After: buffer-local actions are scoped, not global
  -- A duplicate is only a real conflict if both registrations are global
  -- or both are local to the same buffer
  local existing = M._actions[spec.id]
  if existing and not spec.allow_override then
    local both_global = not spec.bindings[0].buffer and not existing.bindings[0]
    local same_buffer = spec.bindings[0].buffer and existing.bindings[0].buffer and spec.bindings[0].buffer == existing.bindings[0].buffer

    if both_global or same_buffer then
      vim.notify(string.format("[articulation] Duplicate action '%s' from '%s'", spec.id, spec.module), vim.log.levels.WARN)
    end
    -- Else Different buffer scopes: silent overwrite is correct behavior
  end
  M._actions[spec.id] = spec

  -- Register keybindings if provided
  if spec.bindings then
    for _, binding in ipairs(spec.bindings) do
      M._bind(spec.id, binding)
    end
  end

  -- Derive command name from fully qualified id
  local cmd_name = id_to_cmd_name(spec.id)

  local ok = pcall(vim.api.nvim_create_user_command, cmd_name, function() M.execute(spec.id) end, { desc = spec.desc })

  if not ok then
    -- Command name collision is non-fatal
    vim.notify(string.format("[articulation] Could not create command ':%s' for action '%s'", cmd_name, spec.id), vim.log.levels.DEBUG)
  end
end

---Register a group of actions sharing a module context.
---@param module string
---@param actions Action[]
function M.register_group(module, actions)
  for _, spec in ipairs(actions) do
    spec.module = spec.module or module
    M.register(spec)
  end
end

---Bind an existing action to a key sequence.
---Separated from register() so bindings can be remapped without re-registering.
---@param action_id string
---@param binding ActionBinding
function M._bind(action_id, binding)
  local modes = type(binding.mode) == 'table' and binding.mode or { binding.mode or 'n' }

  for _, mode in ipairs(modes) do
    local buf_suffix = binding.buffer and ('@' .. binding.buffer) or '@global'
    local key = string.format('%s:%s%s', mode, binding.lhs, buf_suffix)

    if M._bindings[key] then
      local existing_id = M._bindings[key]
      if existing_id ~= action_id then
        vim.notify(
          string.format("[articulation] Binding conflict: '%s' (%s) used by '%s', overwriting with '%s'", binding.lhs, mode, existing_id, action_id),
          vim.log.levels.WARN
        )
      end
    end

    M._bindings[key] = action_id

    vim.keymap.set(mode, binding.lhs, function() M.execute(action_id, nil, binding.buffer) end, {
      desc = M._actions[action_id] and M._actions[action_id].desc or action_id,
      buffer = binding.buffer,
      silent = true,
    })
  end
end

---Execute a registered action by id.
---Evaluates the precondition against current state before dispatching.
---@param action_id string
---@param params? table Parameters passed to the handler
---@param buffer? number Buffer context for state evaluation
---@return boolean success
function M.execute(action_id, params, buffer)
  local action = M._actions[action_id]
  if not action then
    vim.notify(string.format("[articulation] Unknown action: '%s'", action_id), vim.log.levels.ERROR)
    return false
  end

  -- Evaluate precondition if present
  if action.when then
    local state = require('lib.state').snapshot()
    local ok, result = pcall(action.when, state)
    if not ok then
      vim.notify(string.format("[articulation] Precondition error for '%s': %s", action_id, result), vim.log.levels.WARN)
      return false
    end
    if not result then
      vim.notify(string.format("[articulation] Action '%s' precondition not met", action_id), vim.log.levels.INFO)
      return false
    end
  end

  local ok, err = pcall(action.handler, params)
  if not ok then
    vim.notify(string.format("[articulation] Action '%s' failed: %s", action_id, err), vim.log.levels.ERROR)
    return false
  end

  return true
end

---Get all actions registered by a module.
---@param module string
---@return Action[]
function M.get_by_module(module)
  local result = {}
  for _, action in pairs(M._actions) do
    if action.module == module then table.insert(result, action) end
  end
  return result
end

---Register a which-key group label.
---Deferred until which-key is available so load order doesn't matter.
---@param prefix string
---@param label string
---@param mode? string
function M.register_group_label(prefix, label, mode)
  vim.schedule(function()
    local ok, wk = pcall(require, 'which-key')
    if not ok then return end
    wk.add { { prefix, group = label, mode = mode or 'n' } }
  end)
end

---Introspection
function M.status()
  local lines = { '# Articulation Registry', string.rep('─', 50), '' }

  -- Group by module
  local by_module = {}
  for _, action in pairs(M._actions) do
    by_module[action.module] = by_module[action.module] or {}
    table.insert(by_module[action.module], action)
  end

  local modules = vim.tbl_keys(by_module)
  table.sort(modules)

  for _, mod in ipairs(modules) do
    table.insert(lines, '## ' .. mod)
    local actions = by_module[mod]
    table.sort(actions, function(a, b) return a.id < b.id end)

    for _, action in ipairs(actions) do
      table.insert(lines, string.format('  %s', action.id))
      table.insert(lines, string.format('    %s', action.desc))

      if action.bindings then
        for _, binding in ipairs(action.bindings) do
          local modes = type(binding.mode) == 'table' and table.concat(binding.mode, ',') or (binding.mode or 'n')
          table.insert(lines, string.format('    [%s] %s%s', modes, binding.lhs, binding.buffer and (' @buf:' .. binding.buffer) or ''))
        end
      end

      if action.when then
        -- Evaluate current precondition state for introspection
        local state = require('lib.state').snapshot()
        local ok, result = pcall(action.when, state)
        local status = ok and (result and '✓ met' or '✗ not met') or '! error'
        table.insert(lines, string.format('    when: %s', status))
      end

      table.insert(lines, '')
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, buf)
end

---@return ArticulationLib
return M
