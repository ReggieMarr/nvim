---@defgroup vim.ui.picker
---
---@brief Pickers ~
---
--- |vim.ui.picker| is a registry of named pickers that can be overridden by
--- plugins to provide custom implementations.
---
--- Plugins can override individual pickers: >lua
---
---   -- Override a single picker
---   vim.ui.picker.files = function(opts)
---     -- custom implementation
---   end
---
---   -- Extend with a new picker
---   vim.ui.picker.my_picker = function(opts)
---     -- custom implementation
---   end
--- <
---
--- To preserve original pickers: >lua
---
---   local orig_files = vim.ui.picker.files
---   require('myplugin').setup()
---   vim.ui.picker.files = orig_files
--- <
vim.ui.picker = vim.ui.picker or {}

--- Default file picker relative to a given directory using the built-in vim.ui.select.
---
---@type fun(opts: {cwd: string, show_hidden: boolean, show_recursive: boolean}): nil
vim.ui.picker.files = vim.ui.picker.files
  or function(opts)
    opts = opts or {} -- guard nil (called from registry.registry)
    local directory = vim.fn.resolve(vim.fn.expand(opts.cwd or vim.fn.getcwd()))
    local show_hidden = opts.show_hidden or false

    -- Build find command
    local cmd = { 'find', directory, '-type', 'f' }
    -- We basically never want to search in the .git dir so ignore that
    -- TODO account for .gitignore
    table.insert(cmd, '-not')
    table.insert(cmd, '-path')
    table.insert(cmd, '*/.git*')
    if not show_hidden then
      table.insert(cmd, '-not')
      table.insert(cmd, '-name')
      table.insert(cmd, '*/.*')
    end

    local files = vim.fn.systemlist(cmd)

    if vim.v.shell_error ~= 0 or #files == 0 then
      vim.notify('vim.ui.picker.files: no files found in ' .. directory, vim.log.levels.WARN)
      return
    end

    -- Show relative paths for readability
    local relative = vim.tbl_map(function(f) return vim.fn.fnamemodify(f, ':~:.') end, files)

    vim.ui.select(relative, {
      prompt = 'Files: ' .. vim.fn.fnamemodify(directory, ':~'),
      kind = 'file',
    }, function(choice)
      if choice then vim.cmd.edit(choice) end
    end)
  end

--- Pick from live grep results using vim's built-in quickfix integration.
--- Falls back to an incremental search using vim.ui.input and vimgrep.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.ui.input()| for the search pattern
---   - |:vimgrep| to perform the search
---   - |vim.ui.select()| to pick from results
---   - |vim.fn.getqflist()| to retrieve matches
---
---@param opts table|nil
---   - cwd (string): Directory to search from. Default: |getcwd()|
---   - prompt (string): Input prompt text. Default: "Grep: "
vim.ui.picker.grep = vim.ui.picker.grep
  or function(opts)
    opts = opts or {}
    local cwd = vim.fn.resolve(vim.fn.expand(opts.cwd or vim.fn.getcwd()))
    local prompt = opts.prompt or 'Grep: '

    vim.ui.input({ prompt = prompt }, function(pattern)
      if not pattern or pattern == '' then return end

      -- Run vimgrep recursively from cwd
      local ok, err = pcall(vim.cmd, string.format('silent! vimgrep /\\V%s/gj %s/**/*', vim.fn.escape(pattern, '/\\'), vim.fn.fnameescape(cwd)))

      if not ok then
        vim.notify('grep: no matches for ' .. pattern, vim.log.levels.INFO)
        return
      end

      local results = vim.fn.getqflist()
      if vim.tbl_isempty(results) then
        vim.notify('grep: no matches for ' .. pattern, vim.log.levels.INFO)
        return
      end

      -- Format results for selection
      local items = vim.tbl_map(function(entry)
        local fname = vim.fn.bufname(entry.bufnr)
        local relpath = vim.fn.fnamemodify(fname, ':.')
        return {
          label = string.format('%s:%d:%d  %s', relpath, entry.lnum, entry.col, vim.trim(entry.text)),
          bufnr = entry.bufnr,
          lnum = entry.lnum,
          col = entry.col,
          fname = fname,
        }
      end, results)

      vim.ui.select(items, {
        prompt = string.format('Grep: %s (%d matches)', pattern, #items),
        kind = 'grep',
        format_item = function(item) return item.label end,
      }, function(choice)
        if not choice then return end
        vim.cmd.edit(choice.fname)
        vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
      end)
    end)
  end

--- Pick from LSP references using vim's built-in quickfix integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.lsp.buf.references()| with a custom |on_list| handler
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "References: "
vim.ui.picker.lsp_references = vim.ui.picker.lsp_references
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'References: '
    local win = vim.api.nvim_get_current_win()
    vim.lsp.buf.references(nil, {
      on_list = function(list)
        if vim.tbl_isempty(list.items) then
          vim.notify('lsp: no references found', vim.log.levels.INFO)
          return
        end
        local items = vim.tbl_map(function(entry)
          local relpath = vim.fn.fnamemodify(entry.filename, ':.')
          return {
            label = string.format('%s:%d:%d  %s', relpath, entry.lnum, entry.col, vim.trim(entry.text or '')),
            fname = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end, list.items)
        vim.schedule(function()
          vim.api.nvim_set_current_win(win)
          vim.ui.select(items, {
            prompt = string.format('%s (%d)', prompt, #items),
            kind = 'lsp_references',
            format_item = function(item) return item.label end,
          }, function(choice)
            if not choice then return end
            vim.cmd.edit(choice.fname)
            vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
          end)
        end)
      end,
    })
  end

--- Pick from LSP document symbols using vim's built-in location-list integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.lsp.buf.document_symbol()| with a custom |on_list| handler
---   - |vim.ui.input()| for incremental filtering of results
---   - |vim.ui.select()| to pick from results
---
--- Note: |vim.fn.inputlist()| which backs the built-in |vim.ui.select()|
--- has a practical display limit. This implementation will prompt for a
--- filter query via |vim.ui.input()| when results exceed that limit,
--- and re-prompts if the filtered set is still too large.
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Document Symbols: "
---   - max_items (integer): Maximum items before forcing a filter step. Default: 30
vim.ui.picker.lsp_document_symbols = vim.ui.picker.lsp_document_symbols
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Document Symbols: '
    local max_items = opts.max_items or 30

    vim.lsp.buf.document_symbol {
      on_list = function(list)
        if vim.tbl_isempty(list.items) then
          vim.notify('lsp: no symbols found', vim.log.levels.INFO)
          return
        end

        local all_items = vim.tbl_map(function(entry)
          local kind = entry.kind or ''
          return {
            label = string.format('%s  [%s]  line %d', entry.text or '', kind, entry.lnum),
            -- Lower-cased copy for case-insensitive matching
            label_lower = string.lower(entry.text or ''),
            fname = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end, list.items)

        local function filter_items(query)
          if not query or query == '' then return all_items end
          local q = string.lower(query)
          return vim.tbl_filter(function(item) return item.label_lower:find(q, 1, true) ~= nil end, all_items)
        end

        local function open_select(items)
          vim.ui.select(items, {
            prompt = string.format('%s (%d)', prompt, #items),
            kind = 'lsp_document_symbols',
            format_item = function(item) return item.label end,
          }, function(choice)
            if not choice then return end
            vim.cmd.edit(choice.fname)
            vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
          end)
        end

        local function prompt_filter(items, previous_query)
          local count = #items
          local hint = previous_query and previous_query ~= '' and string.format(' (filtered from %d, query: %q)', #all_items, previous_query)
            or string.format(' (%d total)', #all_items)
          vim.notify(
            string.format('lsp: %d symbols exceeds display limit of %d%s — enter a filter query to narrow results', count, max_items, hint),
            vim.log.levels.WARN
          )
          vim.ui.input({
            prompt = string.format('Filter symbols%s: ', hint),
          }, function(query)
            if not query then return end
            local filtered = filter_items(query)
            if vim.tbl_isempty(filtered) then
              vim.notify(string.format('lsp: no symbols matched %q', query), vim.log.levels.WARN)
              -- Let the user try again rather than silently giving up
              vim.schedule(function() prompt_filter(items, previous_query) end)
              return
            end
            vim.schedule(function()
              if #filtered > max_items then
                prompt_filter(filtered, query)
              else
                open_select(filtered)
              end
            end)
          end)
        end

        vim.schedule(function()
          if #all_items > max_items then
            prompt_filter(all_items, nil)
          else
            open_select(all_items)
          end
        end)
      end,
    }
  end

--- Pick from LSP workspace symbols using vim's built-in quickfix integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.ui.input()| for an optional query string
---   - |vim.lsp.buf.workspace_symbol()| with a custom |on_list| handler
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Workspace Symbols: "
---   - query (string): Pre-filled query. If provided, skips |vim.ui.input()|.
vim.ui.picker.lsp_workspace_symbols = vim.ui.picker.lsp_workspace_symbols
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Workspace Symbols: '
    local win = vim.api.nvim_get_current_win()

    local function do_search(query)
      vim.lsp.buf.workspace_symbol(query, {
        on_list = function(list)
          if vim.tbl_isempty(list.items) then
            vim.notify('lsp: no symbols found', vim.log.levels.INFO)
            return
          end
          local items = vim.tbl_map(function(entry)
            local relpath = vim.fn.fnamemodify(entry.filename, ':.')
            local kind = entry.kind or ''
            return {
              label = string.format('%s  [%s]  %s:%d', entry.text or '', kind, relpath, entry.lnum),
              fname = entry.filename,
              lnum = entry.lnum,
              col = entry.col,
            }
          end, list.items)
          vim.schedule(function()
            vim.api.nvim_set_current_win(win)
            vim.ui.select(items, {
              prompt = string.format('%s (%d)', prompt, #items),
              kind = 'lsp_workspace_symbols',
              format_item = function(item) return item.label end,
            }, function(choice)
              if not choice then return end
              vim.cmd.edit(choice.fname)
              vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
            end)
          end)
        end,
      })
    end

    if opts.query ~= nil then
      do_search(opts.query)
    else
      vim.ui.input({ prompt = prompt }, function(query)
        if not query then return end
        do_search(query)
      end)
    end
  end

--- Pick from LSP implementations using vim's built-in quickfix integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.lsp.buf.implementation()| with a custom |on_list| handler
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Implementations: "
vim.ui.picker.lsp_implementations = vim.ui.picker.lsp_implementations
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Implementations: '
    local win = vim.api.nvim_get_current_win()
    vim.lsp.buf.implementation {
      on_list = function(list)
        if vim.tbl_isempty(list.items) then
          vim.notify('lsp: no implementations found', vim.log.levels.INFO)
          return
        end
        local items = vim.tbl_map(function(entry)
          local relpath = vim.fn.fnamemodify(entry.filename, ':.')
          return {
            label = string.format('%s:%d:%d  %s', relpath, entry.lnum, entry.col, vim.trim(entry.text or '')),
            fname = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end, list.items)
        vim.schedule(function()
          vim.api.nvim_set_current_win(win)
          vim.ui.select(items, {
            prompt = string.format('%s (%d)', prompt, #items),
            kind = 'lsp_implementations',
            format_item = function(item) return item.label end,
          }, function(choice)
            if not choice then return end
            vim.cmd.edit(choice.fname)
            vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
          end)
        end)
      end,
    }
  end

--- Pick from LSP type definitions using vim's built-in quickfix integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.lsp.buf.type_definition()| with a custom |on_list| handler
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Type Definitions: "
vim.ui.picker.lsp_type_definitions = vim.ui.picker.lsp_type_definitions
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Type Definitions: '
    local win = vim.api.nvim_get_current_win()
    vim.lsp.buf.type_definition {
      on_list = function(list)
        if vim.tbl_isempty(list.items) then
          vim.notify('lsp: no type definitions found', vim.log.levels.INFO)
          return
        end
        local items = vim.tbl_map(function(entry)
          local relpath = vim.fn.fnamemodify(entry.filename, ':.')
          return {
            label = string.format('%s:%d:%d  %s', relpath, entry.lnum, entry.col, vim.trim(entry.text or '')),
            fname = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end, list.items)
        vim.schedule(function()
          vim.api.nvim_set_current_win(win)
          vim.ui.select(items, {
            prompt = string.format('%s (%d)', prompt, #items),
            kind = 'lsp_type_definitions',
            format_item = function(item) return item.label end,
          }, function(choice)
            if not choice then return end
            vim.cmd.edit(choice.fname)
            vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
          end)
        end)
      end,
    }
  end

--- Pick from LSP incoming calls using vim's built-in quickfix integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.lsp.buf.incoming_calls()| with a custom |on_list| handler
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Incoming Calls: "
vim.ui.picker.lsp_incoming_calls = vim.ui.picker.lsp_incoming_calls
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Incoming Calls: '
    local win = vim.api.nvim_get_current_win()
    vim.lsp.buf.incoming_calls {
      on_list = function(list)
        if vim.tbl_isempty(list.items) then
          vim.notify('lsp: no incoming calls found', vim.log.levels.INFO)
          return
        end
        local items = vim.tbl_map(function(entry)
          local relpath = vim.fn.fnamemodify(entry.filename, ':.')
          return {
            label = string.format('%s:%d:%d  %s', relpath, entry.lnum, entry.col, vim.trim(entry.text or '')),
            fname = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end, list.items)
        vim.schedule(function()
          vim.api.nvim_set_current_win(win)
          vim.ui.select(items, {
            prompt = string.format('%s (%d)', prompt, #items),
            kind = 'lsp_incoming_calls',
            format_item = function(item) return item.label end,
          }, function(choice)
            if not choice then return end
            vim.cmd.edit(choice.fname)
            vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
          end)
        end)
      end,
    }
  end

--- Pick from LSP outgoing calls using vim's built-in quickfix integration.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.lsp.buf.outgoing_calls()| with a custom |on_list| handler
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Outgoing Calls: "
vim.ui.picker.lsp_outgoing_calls = vim.ui.picker.lsp_outgoing_calls
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Outgoing Calls: '
    local win = vim.api.nvim_get_current_win()
    vim.lsp.buf.outgoing_calls {
      on_list = function(list)
        if vim.tbl_isempty(list.items) then
          vim.notify('lsp: no outgoing calls found', vim.log.levels.INFO)
          return
        end
        local items = vim.tbl_map(function(entry)
          local relpath = vim.fn.fnamemodify(entry.filename, ':.')
          return {
            label = string.format('%s:%d:%d  %s', relpath, entry.lnum, entry.col, vim.trim(entry.text or '')),
            fname = entry.filename,
            lnum = entry.lnum,
            col = entry.col,
          }
        end, list.items)
        vim.schedule(function()
          vim.api.nvim_set_current_win(win)
          vim.ui.select(items, {
            prompt = string.format('%s (%d)', prompt, #items),
            kind = 'lsp_outgoing_calls',
            format_item = function(item) return item.label end,
          }, function(choice)
            if not choice then return end
            vim.cmd.edit(choice.fname)
            vim.api.nvim_win_set_cursor(0, { choice.lnum, choice.col - 1 })
          end)
        end)
      end,
    }
  end

-- ── Default picker implementations ──────────────────────────────

--- Pick from vim's built-in help tags.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.fn.getcompletion()| to enumerate all help tags
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Help: "
vim.ui.picker.help = vim.ui.picker.help
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Help: '
    local tags = vim.fn.getcompletion('', 'help')
    if vim.tbl_isempty(tags) then
      vim.notify('picker: no help tags found', vim.log.levels.WARN)
      return
    end
    vim.ui.select(tags, {
      prompt = string.format('%s (%d)', prompt, #tags),
      kind = 'help',
      format_item = function(item) return item end,
    }, function(choice)
      if not choice then return end
      vim.cmd.help(choice)
    end)
  end

--- Pick from all current keymaps.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.api.nvim_get_keymap()| and |vim.api.nvim_buf_get_keymap()|
---     to enumerate all global and buffer-local keymaps
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Keymaps: "
---   - mode (string): Mode to filter by. Default: shows all modes.
vim.ui.picker.keymaps = vim.ui.picker.keymaps
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Keymaps: '
    local modes = opts.mode and { opts.mode } or { 'n', 'v', 'i', 'x', 'o', 's', 't', 'c' }
    local seen = {}
    local items = {}

    local function add_maps(maps, scope)
      for _, map in ipairs(maps) do
        -- Use lhs+mode as dedup key since buffer maps shadow global ones
        local key = map.mode .. map.lhs
        if not seen[key] then
          seen[key] = true
          local rhs = map.rhs or (map.callback and '[lua]') or ''
          table.insert(items, {
            label = string.format('%-4s  %-20s  %-16s  %s', map.mode, map.lhs, scope, map.desc or rhs),
            lhs = map.lhs,
            mode = map.mode,
            desc = map.desc or rhs,
          })
        end
      end
    end

    local buf = vim.api.nvim_get_current_buf()
    for _, mode in ipairs(modes) do
      add_maps(vim.api.nvim_get_keymap(mode), 'global')
      add_maps(vim.api.nvim_buf_get_keymap(buf, mode), 'buffer')
    end

    table.sort(items, function(a, b) return a.label < b.label end)

    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'keymaps',
      format_item = function(item) return item.label end,
    }, function(choice)
      -- Keymaps are informational — navigate to definition if possible,
      -- otherwise just echo the details to the user.
      if not choice then return end
      vim.notify(string.format('mode=%s  lhs=%s\n%s', choice.mode, choice.lhs, choice.desc), vim.log.levels.INFO)
    end)
  end

--- Pick from all available Ex commands.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.fn.getcompletion()| to enumerate all commands
---   - |vim.api.nvim_get_commands()| to retrieve metadata
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Commands: "
vim.ui.picker.commands = vim.ui.picker.commands
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Commands: '

    -- Merge global and buffer-local user commands, then append all
    -- built-in completions so nothing is missed.
    local user_cmds = vim.tbl_extend('force', vim.api.nvim_get_commands {}, vim.api.nvim_buf_get_commands(0, {}))

    -- getcompletion gives us builtins that nvim_get_commands does not
    local all_names = vim.fn.getcompletion('', 'command')
    local seen = {}
    local items = {}

    for _, name in ipairs(all_names) do
      if not seen[name] then
        seen[name] = true
        local meta = user_cmds[name]
        table.insert(items, {
          label = string.format('%-30s  %s', name, (meta and meta.definition) or ''),
          name = name,
          desc = (meta and meta.definition) or '',
        })
      end
    end

    table.sort(items, function(a, b) return a.label < b.label end)

    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'commands',
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      -- Pre-fill the command line so the user can inspect or execute it
      vim.api.nvim_feedkeys(':' .. choice.name .. ' ', 'n', false)
    end)
  end

--- Pick from vim's runtime files (scripts, syntax, ftplugins, etc).
---
--- This default implementation requires no external plugins and uses:
---   - |vim.api.nvim_get_runtime_file()| to enumerate runtime files
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Runtime Files: "
---   - pattern (string): Glob pattern. Default: "**/*"
vim.ui.picker.runtime_files = vim.ui.picker.runtime_files
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Runtime Files: '
    local pattern = opts.pattern or '**/*'
    local paths = vim.api.nvim_get_runtime_file(pattern, true)
    if vim.tbl_isempty(paths) then
      vim.notify('picker: no runtime files found', vim.log.levels.WARN)
      return
    end
    local items = vim.tbl_map(function(p)
      return {
        label = vim.fn.fnamemodify(p, ':~'),
        path = p,
      }
    end, paths)
    table.sort(items, function(a, b) return a.label < b.label end)
    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'runtime_files',
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      vim.cmd.edit(choice.path)
    end)
  end

--- Pick from all loaded and available colorschemes.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.fn.getcompletion()| to enumerate colorschemes
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Colorschemes: "
vim.ui.picker.colorschemes = vim.ui.picker.colorschemes
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Colorschemes: '
    local current = vim.g.colors_name
    local schemes = vim.fn.getcompletion('', 'color')
    if vim.tbl_isempty(schemes) then
      vim.notify('picker: no colorschemes found', vim.log.levels.WARN)
      return
    end
    -- Surface the active scheme at the top
    table.sort(schemes, function(a, b)
      if a == current then return true end
      if b == current then return false end
      return a < b
    end)
    vim.ui.select(schemes, {
      prompt = string.format('%s (%d)', prompt, #schemes),
      kind = 'colorschemes',
      format_item = function(s) return s == current and s .. '  [active]' or s end,
    }, function(choice)
      if not choice then return end
      vim.cmd.colorscheme(choice)
    end)
  end

--- Pick from all sourced scripts (:scriptnames).
---
--- This default implementation requires no external plugins and uses:
---   - |vim.fn.execute()| to capture :scriptnames output
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Scripts: "
vim.ui.picker.scripts = vim.ui.picker.scripts
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Scripts: '
    local raw = vim.fn.execute 'scriptnames'
    local items = {}
    for line in raw:gmatch '[^\n]+' do
      local sid, path = line:match '%s*(%d+):%s+(.+)'
      if sid and path then
        table.insert(items, {
          label = string.format('%4s  %s', sid, vim.fn.fnamemodify(path, ':~')),
          path = vim.fn.expand(path),
          sid = tonumber(sid),
        })
      end
    end
    if vim.tbl_isempty(items) then
      vim.notify('picker: no scripts found', vim.log.levels.WARN)
      return
    end
    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'scripts',
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      vim.cmd.edit(choice.path)
    end)
  end

--- Pick from all active autocommands.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.api.nvim_get_autocmds()| to enumerate autocommands
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Autocommands: "
---   - event (string|table): Filter by event name(s).
---   - group (string|integer): Filter by augroup name or id.
---   - pattern (string|table): Filter by pattern(s).
vim.ui.picker.autocmds = vim.ui.picker.autocmds
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Autocommands: '
    local filter = {}
    if opts.event then filter.event = opts.event end
    if opts.group then filter.group = opts.group end
    if opts.pattern then filter.pattern = opts.pattern end
    local raw = vim.api.nvim_get_autocmds(filter)
    if vim.tbl_isempty(raw) then
      vim.notify('picker: no autocommands found', vim.log.levels.WARN)
      return
    end
    local items = vim.tbl_map(function(au)
      local group = au.group_name or ''
      local cb = au.desc or (au.callback and '[lua]') or au.command or ''
      return {
        label = string.format('%-30s  %-20s  %-20s  %s', au.event, au.pattern or '', group, cb),
        autocmd = au,
      }
    end, raw)
    table.sort(items, function(a, b) return a.label < b.label end)
    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'autocmds',
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      vim.notify(vim.inspect(choice.autocmd), vim.log.levels.INFO)
    end)
  end

--- Pick from all defined highlight groups.
---
--- This default implementation requires no external plugins and uses:
---   - |vim.fn.getcompletion()| to enumerate highlight groups
---   - |vim.api.nvim_get_hl()| to retrieve definition
---   - |vim.ui.select()| to pick from results
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Highlights: "
vim.ui.picker.highlights = vim.ui.picker.highlights
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Highlights: '
    local names = vim.fn.getcompletion('', 'highlight')
    if vim.tbl_isempty(names) then
      vim.notify('picker: no highlight groups found', vim.log.levels.WARN)
      return
    end
    local items = vim.tbl_map(function(name)
      local def = vim.api.nvim_get_hl(0, { name = name, link = false })
      local parts = {}
      if def.fg then table.insert(parts, string.format('fg=#%06x', def.fg)) end
      if def.bg then table.insert(parts, string.format('bg=#%06x', def.bg)) end
      if def.bold then table.insert(parts, 'bold') end
      if def.italic then table.insert(parts, 'italic') end
      if def.link then table.insert(parts, 'link=' .. def.link) end
      return {
        label = string.format('%-40s  %s', name, table.concat(parts, '  ')),
        name = name,
        def = def,
      }
    end, names)
    table.sort(items, function(a, b) return a.label < b.label end)
    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'highlights',
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      -- Inspect in a scratch buffer so the output is readable
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(vim.inspect(choice.def), '\n'))
      vim.bo[buf].filetype = 'lua'
      vim.cmd.sbuffer(buf)
    end)
  end

--- Pick from all currently registered vim.ui.picker entries.
---
--- Useful as a top-level "meta picker" — equivalent to Emacs M-x for pickers.
---
---@param opts table|nil
---   - prompt (string): Input prompt text. Default: "Pickers: "
vim.ui.picker.pickers = vim.ui.picker.pickers
  or function(opts)
    opts = opts or {}
    local prompt = opts.prompt or 'Pickers: '
    local items = {}
    for name, fn in pairs(vim.ui.picker) do
      if type(fn) == 'function' then table.insert(items, { label = name, name = name, fn = fn }) end
    end
    table.sort(items, function(a, b) return a.label < b.label end)
    vim.ui.select(items, {
      prompt = string.format('%s (%d)', prompt, #items),
      kind = 'pickers',
      format_item = function(item) return item.label end,
    }, function(choice)
      if not choice then return end
      -- Schedule so we are not opening a picker from inside a picker's callback
      vim.schedule(function() choice.fn() end)
    end)
  end

--- Default buffer picker using the built-in vim.ui.select.
---
---@type fun(opts: {show_unlisted: boolean}): nil
vim.ui.picker.buffers = vim.ui.picker.buffers
  or function(opts)
    opts = opts or {} -- guard nil (called from registry.registry)
    local show_unlisted = opts.show_unlisted or false

    -- Collect buffers
    local buffers = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      local is_listed = vim.bo[bufnr].buflisted
      if show_unlisted or is_listed then
        local name = vim.api.nvim_buf_get_name(bufnr)
        local display = name ~= '' and vim.fn.fnamemodify(name, ':~:.') or '[No Name]'
        local modified = vim.bo[bufnr].modified and ' [+]' or ''
        table.insert(buffers, {
          bufnr = bufnr,
          display = display .. modified,
        })
      end
    end

    if #buffers == 0 then
      vim.notify('vim.ui.picker.buffers: no buffers found', vim.log.levels.WARN)
      return
    end

    vim.ui.select(buffers, {
      prompt = 'Buffers:',
      kind = 'buffer',
      format_item = function(item) return item.display end,
    }, function(choice)
      if choice then vim.api.nvim_set_current_buf(choice.bufnr) end
    end)
  end

--- Default notification picker using the built-in vim.ui.select.
--- Reads from the built-in :messages command output.
---
---@type fun(opts: {}|nil): table|nil
vim.ui.picker.notifications = vim.ui.picker.notifications
  or function(opts)
    opts = opts or {} -- guard nil (called from registry.registry)

    -- Get messages from vim's built-in message history
    local messages = vim.fn.execute 'messages'
    if not messages or messages == '' then
      vim.notify('vim.ui.picker.notifications: no messages found', vim.log.levels.WARN)
      return
    end

    -- Split into lines and filter empty ones, preserving order (newest last)
    local lines = vim.tbl_filter(function(line) return line ~= '' end, vim.split(messages, '\n'))

    if #lines == 0 then
      vim.notify('vim.ui.picker.notifications: no messages found', vim.log.levels.WARN)
      return
    end

    -- Reverse so newest messages appear first
    local reversed = {}
    for i = #lines, 1, -1 do
      table.insert(reversed, lines[i])
    end

    vim.ui.select(reversed, {
      prompt = 'Notifications:',
      kind = 'notification',
    }, function(choice)
      -- Copy the selected message to the clipboard on confirm
      if choice then
        vim.fn.setreg('+', choice)
        vim.notify('Copied to clipboard: ' .. choice, vim.log.levels.INFO)
      end
    end)
  end
