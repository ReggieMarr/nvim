-- lua/lib/capabilities.lua
-- Capability registration and interface validation.
-- Capabilities are the adapter layer between what modules need and what
-- plugins provide. Registering a capability makes an implementation
-- available to any module without that module knowing the plugin behind it.

local M = {}

M._capabilities = {}

-- Known interface shapes. Implementations are validated against these.
-- nil values mean "key must exist, type is not constrained".
M.interfaces = {
  picker = {
    -- Core picking operations all modules may need
    files        = nil,  -- function(opts?)
    grep         = nil,  -- function(opts?)
    buffers      = nil,  -- function(opts?)
    keymaps      = nil,  -- function(opts?)
    commands     = nil,  -- function(opts?)
    -- Extended operations registered by other modules
    -- e.g. lsp_references, git_commits, diagnostics
  },

  notifier = {
    info     = nil,  -- function(msg, opts?)
    warn     = nil,  -- function(msg, opts?)
    error    = nil,  -- function(msg, opts?)
    progress = nil,  -- function(token, opts?)
  },

  terminal = {
    toggle = nil,  -- function(opts?)
    run    = nil,  -- function(cmd, opts?)
    send   = nil,  -- function(text, opts?)
  },

  task_runner = {
    run    = nil,  -- function(task_spec)
    list   = nil,  -- function(): task[]
    toggle = nil,  -- function() toggle task UI
  },

  filesystem = {
    open_tree    = nil,  -- function(path?)
    reveal_file  = nil,  -- function(filepath?)
    close_tree   = nil,  -- function()
  },
}

local function validate_interface(impl, interface, name)
  local errors = {}
  for key, _ in pairs(interface) do
    if impl[key] == nil then
      table.insert(errors, string.format("  missing key: '%s'", key))
    end
  end
  return #errors == 0, errors
end

---Register a capability implementation.
---@param name string
---@param impl table
---@param provider string Module providing this capability
function M.register(name, impl, provider)
  if M._capabilities[name] then
    vim.notify(
      string.format(
        "[capabilities] '%s' already provided by '%s', overwriting with '%s'",
        name, M._capabilities[name].provider, provider
      ),
      vim.log.levels.WARN
    )
  end

  if M.interfaces[name] then
    local ok, errors = validate_interface(impl, M.interfaces[name], name)
    if not ok then
      vim.notify(
        string.format(
          "[capabilities] '%s' from '%s' has interface gaps:\n%s",
          name, provider, table.concat(errors, "\n")
        ),
        vim.log.levels.WARN
      )
    end
  end

  M._capabilities[name] = { name = name, provider = provider, impl = impl }
end

---Extend an existing capability with additional operations.
---Used by modules that add domain-specific pickers to the picker capability.
---@param name string
---@param extensions table
---@param provider string
function M.extend(name, extensions, provider)
  if not M._capabilities[name] then
      M.register(name, extensions, provider)
    return
  end

  for key, value in pairs(extensions) do
    if M._capabilities[name].impl[key] then
      vim.notify(
        string.format(
          "[capabilities] '%s' extension from '%s' overwrites '%s'",
          name, provider, key
        ),
        vim.log.levels.DEBUG
      )
    end
    M._capabilities[name].impl[key] = value
  end
end

---Get a capability implementation. Returns nil if not registered.
---@param name string
---@return table|nil
function M.get(name)
  local cap = M._capabilities[name]
  return cap and cap.impl or nil
end

---Get a capability, raising an error if not found.
---Use when the capability is truly required for the operation.
---@param name string
---@return table
function M.require(name)
  local impl = M.get(name)
  if not impl then
    error(string.format(
      "[capabilities] Required capability '%s' is not registered. " ..
      "Check feature flags and module load order.",
      name
    ))
  end
  return impl
end

---@param name string
---@return boolean
function M.has(name)
  return M._capabilities[name] ~= nil
end

function M.status()
  local lines = { "# Capability Registry", string.rep("─", 50), "" }

  for name, cap in pairs(M._capabilities) do
    table.insert(lines, string.format("## %s  (provided by: %s)", name, cap.provider))

    local interface = M.interfaces[name]
    if interface then
      for key, _ in pairs(interface) do
        local status = cap.impl[key] and "  ✓" or "  ✗"
        table.insert(lines, string.format("%s %s", status, key))
      end

      -- Show extended keys not in the base interface
      for key, _ in pairs(cap.impl) do
        if interface[key] == nil then
          table.insert(lines, string.format("  + %s  (extension)", key))
        end
      end
    else
      table.insert(lines, "  (freeform capability, no interface defined)")
      for key, _ in pairs(cap.impl) do
        table.insert(lines, string.format("  · %s", key))
      end
    end
    table.insert(lines, "")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype   = "markdown"
  vim.bo[buf].modifiable = false
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

return M
