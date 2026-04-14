-- lua/lib/module.lua

---@class ModuleLib
local M = {}

M._registry = {}

---@class ModuleSpec
---@field name string
---@field domain string Organizational label, not a control surface
---@field depends_on string[]
---@field optional_deps string[]
---@field plugins table<string, table> plugin_string -> lazy spec fields
---@field setup fun() Called after plugins are loaded

function M.register(spec)
  vim.validate {
    name = { spec.name, 'string' },
    domain = { spec.domain, 'string' },
  }

  spec.depends_on = spec.depends_on or {}
  spec.optional_deps = spec.optional_deps or {}
  spec.plugins = spec.plugins or {}

  if M._registry[spec.name] then
    vim.notify(string.format("[module] Duplicate registration: '%s'", spec.name), vim.log.levels.WARN)
    return
  end

  M._registry[spec.name] = spec
  return spec
end

---Check whether a module is registered.
---@param module_name string
---@return boolean
function M.available(module_name) return M._registry[module_name] ~= nil end

---Check whether any registered module belongs to a domain.
---@param domain string
---@return boolean
function M.domain_active(domain)
  for _, spec in pairs(M._registry) do
    if spec.domain == domain then return true end
  end
  return false
end

---Validate the dependency graph.
---@return boolean
---@return string[]
function M.validate()
  local errors = {}

  for name, spec in pairs(M._registry) do
    for _, dep in ipairs(spec.depends_on) do
      if not M._registry[dep] then table.insert(errors, string.format("[module] '%s' depends on unregistered module '%s'", name, dep)) end
    end
  end

  local _, cycle_err = M._resolve_order()
  if cycle_err then table.insert(errors, cycle_err) end

  return #errors == 0, errors
end

---Topological sort of registered modules.
---@return string[]|nil
---@return string|nil
function M._resolve_order()
  local order = {}
  local visited = {}
  local in_progress = {}

  local function visit(name)
    if in_progress[name] then return nil, string.format("[module] Cycle at: '%s'", name) end
    if visited[name] then return true end

    in_progress[name] = true

    local spec = M._registry[name]
    if spec then
      for _, dep in ipairs(spec.depends_on) do
        if M._registry[dep] then
          local ok, err = visit(dep)
          if not ok then return nil, err end
        end
      end
    end

    in_progress[name] = nil
    visited[name] = true
    table.insert(order, name)
    return true
  end

  for name in pairs(M._registry) do
    if not visited[name] then
      local ok, err = visit(name)
      if not ok then return nil, err end
    end
  end

  return order
end

---Collect and merge plugin specs from all registered modules.
---
---Each module declares plugins as a dict of plugin_string -> spec fields.
---This function merges contributions to the same plugin across modules,
---then produces the flat list lazy.setup() expects.
---
---Merge strategy:
---  opts tables are deep merged (later modules extend earlier ones)
---  all other spec fields (event, cmd, ft, etc.) last writer wins
---  setup functions are not merged: use the setup() module hook instead
---
---@return table[]
function M.collect_plugin_specs()
  local merged = {} -- plugin_string -> merged spec
  local order, err = M._resolve_order()

  if not order then
    vim.notify(err, vim.log.levels.ERROR)
    return {}
  end

  for _, name in ipairs(order) do
    local spec = M._registry[name]
    if not spec then goto continue end

    for plugin_string, plugin_spec in pairs(spec.plugins) do
      if not merged[plugin_string] then
        -- First module to declare this plugin seeds the entry
        merged[plugin_string] = vim.deepcopy(plugin_spec)
        merged[plugin_string][1] = plugin_string
      else
        -- Subsequent modules extend the existing entry.
        -- opts is deep merged so both modules' options survive.
        if plugin_spec.opts then merged[plugin_string].opts = vim.tbl_deep_extend('force', merged[plugin_string].opts or {}, plugin_spec.opts) end
        -- Non-opts fields: extend the spec but don't overwrite
        -- fields already set (first declaration takes precedence
        -- for things like event, cmd, priority, lazy)
        for k, v in pairs(plugin_spec) do
          if k ~= 'opts' and merged[plugin_string][k] == nil then merged[plugin_string][k] = v end
        end
      end
    end

    ::continue::
  end

  -- Flatten to list for lazy
  local specs = {}
  for _, spec in pairs(merged) do
    table.insert(specs, spec)
  end

  return specs
end

---Run each registered module's setup() in dependency order.
---Called from init.lua after lazy.setup() completes.
function M.run_setup()
  local order, err = M._resolve_order()
  if not order then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  for _, name in ipairs(order) do
    local spec = M._registry[name]
    if spec and type(spec.setup) == 'function' then
      local ok, setup_err = pcall(spec.setup)
      if not ok then vim.notify(string.format("[module] Setup failed for '%s': %s", name, setup_err), vim.log.levels.ERROR) end
    end
  end
end

---Introspection
function M.status()
  local lines = { '# Module Registry', string.rep('─', 50), '' }

  local by_domain = {}
  for name, spec in pairs(M._registry) do
    by_domain[spec.domain] = by_domain[spec.domain] or {}
    table.insert(by_domain[spec.domain], { name = name, spec = spec })
  end

  local domains = vim.tbl_keys(by_domain)
  table.sort(domains)

  for _, domain in ipairs(domains) do
    table.insert(lines, '## ' .. domain)
    for _, entry in ipairs(by_domain[domain]) do
      table.insert(lines, string.format('  ✓ %s', entry.name))
      if #entry.spec.depends_on > 0 then table.insert(lines, string.format('    depends: %s', table.concat(entry.spec.depends_on, ', '))) end
      local plugin_count = vim.tbl_count(entry.spec.plugins)
      table.insert(lines, string.format('    plugins: %d', plugin_count))
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

---@return ModuleLib
return M
