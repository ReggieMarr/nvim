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
