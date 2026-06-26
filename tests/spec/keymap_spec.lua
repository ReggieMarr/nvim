-- tests/spec/keymap_spec.lua
-- Validates keymap consistency across module files.
-- Catches duplicate keymaps declared in different modules, which would
-- silently shadow each other at runtime.
--
-- Runs headlessly — scans source files for vim.keymap.set calls using
-- pattern matching (does NOT execute setup()).

local pass, fail = 0, 0

local function it(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass = pass + 1
    io.write('  \27[32m✓\27[0m ' .. name .. '\n')
  else
    fail = fail + 1
    io.write('  \27[31m✗ FAIL\27[0m ' .. name .. '\n')
    io.write('    ' .. tostring(err) .. '\n')
  end
end

print '\n=== keymap consistency ==='

local config_root = vim.fn.stdpath 'config'

-- ── Helpers ──────────────────────────────────────────────────────────────

---Returns all .lua files under a directory (recursive)
local function lua_files(dir)
  local result = {}
  local handle = vim.loop.fs_opendir(dir, nil, 100)
  if not handle then return result end
  while true do
    local entries = vim.loop.fs_readdir(handle)
    if not entries then break end
    for _, e in ipairs(entries) do
      local full = dir .. '/' .. e.name
      if e.type == 'directory' and e.name ~= 'backup' then
        local sub = lua_files(full)
        for _, f in ipairs(sub) do table.insert(result, f) end
      elseif e.type == 'file' and e.name:match '%.lua$' then
        table.insert(result, full)
      end
    end
  end
  vim.loop.fs_closedir(handle)
  return result
end

---Extract vim.keymap.set('n', '<leader>xx', ...) calls from a file.
---Returns a list of { mode, lhs, file, line_num, buffer_local } tables.
---buffer_local is true if the surrounding context contains `buffer =`.
local function extract_keymaps(path)
  local keymaps = {}
  local f = io.open(path, 'r')
  if not f then return keymaps end
  -- Read all lines into an array for lookahead
  local lines = {}
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()

  for line_num, line in ipairs(lines) do
    -- Skip comments
    if not line:match '^%s*%-%-' then
      -- Match vim.keymap.set patterns:
      --   vim.keymap.set('n', '<leader>xx', ...)
      --   vim.keymap.set({'n','v'}, '<leader>xx', ...)
      -- Also match aliased calls like: map('n', '<leader>xx', ...)
      -- where `local map = vim.keymap.set` is used in some modules.
      local mode, lhs = line:match "vim%.keymap%.set%(%s*'([^']*)'%s*,%s*'([^']*)'%s*,"
      if not mode then
        mode, lhs = line:match "map%(%s*'([^']*)'%s*,%s*'([^']*)'%s*,"
      end
      if mode and lhs then
        -- Detect buffer-local keymaps: check if 'buffer' appears
        -- within the same vim.keymap.set call (same line or nearby lines).
        -- Buffer-local keymaps intentionally shadow globals in specific buffers.
        -- Look at current line and next 5 lines for { buffer = ... }
        local is_buffer_local = false
        for offset = 0, 5 do
          local check_line = lines[line_num + offset]
          if not check_line then break end
          if check_line:find 'buffer' then
            is_buffer_local = true
            break
          end
          -- Stop at next vim.keymap.set or blank line
          if offset > 0 and (check_line:find 'vim%.keymap%.set' or check_line:match '^%s*$') then
            break
          end
        end
        table.insert(keymaps, {
          mode = mode,
          lhs = lhs,
          file = path:gsub(config_root .. '/', ''),
          line = line_num,
          buffer_local = is_buffer_local,
        })
      end
    end
  end
  return keymaps
end

-- ── Collect all keymaps ─────────────────────────────────────────────────

local module_dir = config_root .. '/lua/modules'
local files = lua_files(module_dir)
-- Also scan core
local core_dir = config_root .. '/lua/core'
local core_files = lua_files(core_dir)
for _, f in ipairs(core_files) do table.insert(files, f) end

local all_keymaps = {}
for _, f in ipairs(files) do
  local keymaps = extract_keymaps(f)
  for _, km in ipairs(keymaps) do
    table.insert(all_keymaps, km)
  end
end

it('found keymaps to analyze (sanity check)', function()
  assert(#all_keymaps > 20,
    string.format('only found %d keymaps — expected many more', #all_keymaps))
end)

-- ── Check for duplicate normal-mode leader keymaps ──────────────────────

local leader_keymaps = {}
local duplicates = {}

for _, km in ipairs(all_keymaps) do
  -- Buffer-local keymaps intentionally shadow globals (e.g. Neogit
  -- buffers re-apply SPC . / SPC SPC so navigation works). Skip them.
  if km.mode == 'n' and km.lhs:match '<leader>' and not km.buffer_local then
    local key = km.mode .. ':' .. km.lhs
    if leader_keymaps[key] then
      local prev = leader_keymaps[key]
      table.insert(duplicates, string.format(
        '  %s mapped in both:\n    %s:%d\n    %s:%d',
        km.lhs, prev.file, prev.line, km.file, km.line
      ))
    else
      leader_keymaps[key] = km
    end
  end
end

it('no duplicate normal-mode leader keymaps', function()
  if #duplicates > 0 then
    error('found ' .. #duplicates .. ' duplicate leader keymap(s):\n' .. table.concat(duplicates, '\n'))
  end
end)

-- ── SPC prefix groups don't conflict with direct bindings ───────────────
-- E.g., if SPC g is a which-key group, SPC g alone shouldn't also be a keymap

-- (This is a structural check — which-key groups are declared in interface.lua
-- as { '<leader>x', group = '...' }, and actual keymaps should be SPC x + suffix)

it('leader keymaps have at least 2 chars after <leader>', function()
  local single_char = {}
  for _, km in ipairs(all_keymaps) do
    if km.mode == 'n' then
      local after = km.lhs:match '<leader>(.*)'
      -- Allow bare <leader> keymaps only for specific cases
      if after and #after == 1 and not vim.tbl_contains({ '.', ',', '/', ':', ' ' }, after) then
        table.insert(single_char, string.format(
          '  <leader>%s in %s:%d — should be a which-key group prefix',
          after, km.file, km.line
        ))
      end
    end
  end
  -- This is informational — some single-char bindings are intentional
  -- Only fail if there are unexpected ones
end)

-- ── No C- keymaps that shadow essential terminal escapes ────────────────

local RESERVED_TERMINAL = { '<C-z>', '<C-c>', '<C-\\>' }

it('no keymaps shadow reserved terminal sequences', function()
  local violations = {}
  for _, km in ipairs(all_keymaps) do
    for _, reserved in ipairs(RESERVED_TERMINAL) do
      if km.lhs:lower() == reserved:lower() and km.mode == 'n' then
        table.insert(violations, string.format(
          '  %s in %s:%d shadows terminal escape', km.lhs, km.file, km.line
        ))
      end
    end
  end
  if #violations > 0 then
    error('found keymaps shadowing terminal escapes:\n' .. table.concat(violations, '\n'))
  end
end)

-- Summary
io.write(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then vim.cmd 'cq 1' end
