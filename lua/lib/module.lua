-- lua/lib/module.lua
-- Module system: registration, dependency resolution, and lifecycle management.
-- Modules are the primary unit of organization in this config.
-- Each module maps to a feature flag and declares its plugin specs
-- split into display and articulation concerns.

local M = {}

M._registry = {}

-- ─── Types ────────────────────────────────────────────────────────────────────

---@class ModuleSpec
---@field name string          Unique module identifier
---@field feature string       Feature flag this module belongs to
---@field depends_on? string[] Module names that must be present and enabled
---@field optional_deps? string[] Modules that enhance this one if available
---@field display? table[]     Plugin specs whose primary concern is rendering
---@field articulation? table[] Plugin specs whose primary concern is interaction
---@field providers? table[]   Plugin specs that serve both or are infrastructure

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

---Collect plugin specs from a module, flattening display, articulation,
---and providers into a single list for lazy.
---Preserves the categorical distinction for organizational purposes
---without requiring lazy to know about it.
---@param spec ModuleSpec
---@return table[]
local function collect_specs(spec)
  local result = {}
  for _, group in ipairs({ spec.display, spec.articulation, spec.providers }) do
    for _, plugin_spec in ipairs(group) do
      table.insert(result, plugin_spec)
    end
  end
  return result
end

-- ─── Dependency Resolution ────────────────────────────────────────────────────

---Resolve module load order via topological sort of the dependency DAG.
---Returns an ordered list of module names or nil and an error on cycle detection.
---All registered modules are considered active by definition of being registered.
---@return string[]|nil
---@return string|nil error
local function resolve_order()
  local order       = {}
  local visited     = {}
  local in_progress = {}

  local function visit(name)
    if in_progress[name] then
      return nil, string.format(
        "[module] Dependency cycle detected at: '%s'",
        name
      )
    end
    if visited[name] then return true end

    in_progress[name] = true

    local spec = M._registry[name]
    if spec then
      for _, dep in ipairs(spec.depends_on) do
        -- Only traverse dependencies that are registered.
        -- Unregistered dependencies are caught in validate().
        -- No feature check needed: registered == active.
        if M._registry[dep] then
          local ok, err = visit(dep)
          if not ok then return nil, err end
        end
      end
    end

    in_progress[name] = nil
    visited[name]     = true
    table.insert(order, name)
    return true
  end

  -- Iterate all registered modules. No feature filter needed.
  for name, _ in pairs(M._registry) do
    if not visited[name] then
      local ok, err = visit(name)
      if not ok then return nil, err end
    end
  end

  return order
end

-- ─── Public API ───────────────────────────────────────────────────────────────

---Register a module with the system.
---Called from each module file before lazy loads plugins.
---Registration is unconditional - feature flag checking happens at
---collect time so the registry always reflects the full picture.
---@param spec ModuleSpec
function M.register(spec)
  -- Structural validation
  if type(spec) ~= "table" then
    vim.notify(
      "[module] register() expects a table",
      vim.log.levels.ERROR
    )
    return
  end

  for _, required_field in ipairs({ "name" }) do
    if not spec[required_field] or spec[required_field] == "" then
      vim.notify(
        string.format(
          "[module] Module spec missing required field: '%s'",
          required_field
        ),
        vim.log.levels.ERROR
      )
      return
    end
  end

  -- Duplicate registration guard
  if M._registry[spec.name] then
    vim.notify(
      string.format(
        "[module] Duplicate registration: '%s' - ignoring",
        spec.name
      ),
      vim.log.levels.WARN
    )
    return
  end

  -- Apply defaults so downstream code never needs nil checks
  -- on these fields
  spec.depends_on   = spec.depends_on   or {}
  spec.optional_deps = spec.optional_deps or {}
  spec.display      = spec.display      or {}
  spec.articulation = spec.articulation or {}
  spec.providers    = spec.providers    or {}

  M._registry[spec.name] = spec
end

---Check whether a module is registered and loaded.
---This is the new control surface: if it's in the registry, it's active.
---@param module_name string
---@return boolean
function M.available(module_name)
  return M._registry[module_name] ~= nil
end

---Check whether any module belonging to a domain is loaded.
---Domain is the `feature` field on module specs, used for grouping.
---@param domain string e.g. "language", "execution"
---@return boolean
function M.domain_active(domain)
  for _, spec in pairs(M._registry) do
    if spec.name == domain then
      return true
    end
  end
  return false
end

---Validate the module graph.
---Checks that:
---  1. All hard dependencies of registered modules are themselves registered
---  2. No dependency cycles exist
---
---A missing dependency means the module file is either not in the manifest
---in init.lua or failed to call module.register(). Both are explicit gaps.
---
---Called in init.lua after all module files are required, before lazy.setup().
---@return boolean
---@return string[]
function M.validate()
  local errors = {}

  for name, spec in pairs(M._registry) do
    for _, dep in ipairs(spec.depends_on) do
      if not M._registry[dep] then
        -- Clearer error: "not registered" rather than "feature disabled"
        -- The fix is always: add the module to the manifest in init.lua
        table.insert(errors, string.format(
          "[module] '%s' depends on '%s' which is not registered. " ..
          "Add it to the module manifest in init.lua.",
          name, dep
        ))
      end
    end
  end

  -- Cycle detection runs independently so both classes of error
  -- are reported in a single validate() call
  local _, cycle_err = resolve_order()
  if cycle_err then
    table.insert(errors, cycle_err)
  end

  -- Optional dependency availability warnings.
  -- Non-fatal: module loads with reduced functionality.
  -- Runs after error collection so warnings don't suppress errors.
  for name, spec in pairs(M._registry) do
    for _, dep in ipairs(spec.optional_deps) do
      if not M.available(dep) then
        vim.notify(
          string.format(
            "[module] '%s' optional dep '%s' is not registered " ..
            "- some functionality will be reduced",
            name, dep
          ),
          vim.log.levels.INFO
        )
      end
    end
  end

  return #errors == 0, errors
end

---Collect all lazy plugin specs from registered modules in dependency order.
---This is the value passed directly to lazy.setup().
---@return table[]
function M.collect_plugin_specs()
  local specs = {}

  local order, err = resolve_order()
  if not order then
    vim.notify(err, vim.log.levels.ERROR)
    return specs
  end

  for _, name in ipairs(order) do
    local spec = M._registry[name]
    -- resolve_order() only returns registered modules
    -- so this guard is defensive rather than meaningful
    if spec then
      for _, plugin_spec in ipairs(collect_specs(spec)) do
        table.insert(specs, plugin_spec)
      end
    end
  end

  return specs
end

-- ─── Introspection ────────────────────────────────────────────────────────────

function M.status()
  local lines = { "# Module Registry", string.rep("─", 50), "" }

  -- Run validation so status reflects current graph health.
  -- validate() is called here for display only; init.lua calls it
  -- authoritatively before lazy.setup().
  local valid, errors = M.validate()
  if not valid then
    table.insert(lines, "## ✗ Validation Errors")
    for _, err in ipairs(errors) do
      table.insert(lines, string.format("  %s", err))
    end
    table.insert(lines, "")
  else
    table.insert(lines, "## ✓ Graph valid")
    table.insert(lines, "")
  end

  -- Group by domain (previously grouped by feature).
  -- Domain is the organizational label on the module spec.
  -- All groups shown here are active - inactive modules are
  -- not registered and therefore not visible here.
  -- To see what is *not* loaded, check the manifest in init.lua.
  local by_domain = {}
  for name, spec in pairs(M._registry) do
    local d = spec.name or "ungrouped"
    by_domain[d] = by_domain[d] or {}
    table.insert(by_domain[d], { name = name, spec = spec })
  end

  local domain_names = vim.tbl_keys(by_domain)
  table.sort(domain_names)

  for _, domain in ipairs(domain_names) do
    local modules = by_domain[domain]
    table.insert(lines, string.format(
      "## %s  (%d module%s)",
      domain,
      #modules,
      #modules == 1 and "" or "s"
    ))

    table.sort(modules, function(a, b) return a.name < b.name end)

    for _, mod in ipairs(modules) do
      local spec_count = (
        #mod.spec.display +
        #mod.spec.articulation +
        #mod.spec.providers
      )
      -- All registered modules are active, so no enabled/disabled icon needed.
      -- Use the space for something more useful: spec count per category.
      table.insert(lines, string.format(
        "  %-30s  %dp %dd %da",
        mod.name,
        #mod.spec.providers,
        #mod.spec.display,
        #mod.spec.articulation
      ))

      if #mod.spec.depends_on > 0 then
        -- Annotate whether each hard dep is satisfied
        local annotated = {}
        for _, dep in ipairs(mod.spec.depends_on) do
          table.insert(annotated, string.format(
            "%s%s",
            dep,
            M._registry[dep] and "" or " ✗ MISSING"
          ))
        end
        table.insert(lines, string.format(
          "      requires:  %s",
          table.concat(annotated, ", ")
        ))
      end

      if #mod.spec.optional_deps > 0 then
        local annotated = {}
        for _, dep in ipairs(mod.spec.optional_deps) do
          table.insert(annotated, string.format(
            "%s%s",
            dep,
            M._registry[dep] and "" or " (absent)"
          ))
        end
        table.insert(lines, string.format(
          "      optional:  %s",
          table.concat(annotated, ", ")
        ))
      end
    end

    table.insert(lines, "")
  end

  -- Load order for debugging dependency resolution
  local order, err = resolve_order()
  if order then
    table.insert(lines, "## Load Order")
    for i, name in ipairs(order) do
      table.insert(lines, string.format("  %2d. %s", i, name))
    end
  else
    table.insert(lines, string.format(
      "## Load Order\n  ✗ %s", err
    ))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype   = "markdown"
  vim.bo[buf].modifiable = false
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

return M
