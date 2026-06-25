-- lua/modules/orgmode.lua
-- Org-mode module: org-mode editing, agenda, capture, and export.
--
-- Mirrors the Doom Emacs org-mode workflow:
--   - Capture templates for quick note-taking (SPC o c)
--   - Agenda views (SPC o a)
--   - org-modern-style visual enhancements via org-bullets
--   - Concealed links, folded headings, TODO states
--
-- Keybindings follow Doom's SPC o prefix for org operations,
-- with buffer-local org keymaps using <localleader> (;).
--
-- Domain: orgmode

local env = require 'env'

return env.module.register {
  name = 'orgmode',
  domain = 'orgmode',
  depends_on = { 'text_editing' },
  optional_deps = {},

  plugins = {
    -- nvim-orgmode: full org-mode implementation for Neovim
    ['nvim-orgmode/orgmode'] = {
      event = 'VeryLazy',
      ft = { 'org' },
      dependencies = {
        'nvim-treesitter/nvim-treesitter',
      },
      opts = {
        org_agenda_files = '~/org/**/*',
        org_default_notes_file = '~/org/refile.org',

        -- TODO states matching Doom's default + custom workflow
        org_todo_keywords = { 'TODO(t)', 'NEXT(n)', 'PROJ(p)', 'WAIT(w)', '|', 'DONE(d)', 'CANCELLED(c)' },
        org_todo_keyword_faces = {
          TODO      = ':foreground #ff6c6b :weight bold',
          NEXT      = ':foreground #da8548 :weight bold',
          PROJ      = ':foreground #7cc3f2 :weight bold',
          WAIT      = ':foreground #ECBE7B :weight bold',
          DONE      = ':foreground #98be65 :weight bold',
          CANCELLED = ':foreground #5B6268 :weight bold',
        },

        -- Capture templates (mirrors Doom's SPC X / SPC o c)
        org_capture_templates = {
          t = {
            description = 'Task',
            template = '* TODO %?\n  %U\n  %a',
            target = '~/org/refile.org',
          },
          n = {
            description = 'Note',
            template = '* %?\n  %U\n  %a',
            target = '~/org/notes.org',
          },
          j = {
            description = 'Journal',
            template = '* %<%Y-%m-%d %H:%M> %?\n',
            target = '~/org/journal.org',
            datetree = true,
          },
        },

        -- Startup folded (matches Doom's #+STARTUP: overview fold)
        org_startup_folded = 'content',

        -- Source block editing in current window (matches Doom config)
        org_src_window_setup = 'current-window',

        -- Export settings
        org_export_headline_levels = 3,

        -- Conceal links (handled by conceallevel in base_config)
        org_hide_emphasis_markers = true,
        org_hide_leading_stars = true,

        -- Agenda settings
        org_agenda_span = 'week',
        org_agenda_start_on_weekday = 1,

        -- Refile targets — allow refiling to any heading up to 3 levels deep
        org_refile_targets = '~/org/**/*',

        -- Tag alignment
        org_tags_column = -80,

        -- Calendar popup for date picking
        calendar_week_start_day = 1,

        mappings = {
          -- Use localleader (;) for org buffer keymaps — mirrors Doom's localleader
          org = {
            org_toggle_checkbox = ';x',
            org_cycle = '<TAB>',
            org_global_cycle = '<S-TAB>',
            org_timestamp_up = '<C-a>',
            org_timestamp_down = '<C-x>',
            org_todo = ';t',
            org_todo_prev = ';T',
            org_priority = ';,',
            org_priority_up = ';+',
            org_priority_down = ';-',
            org_toggle_heading = ';h',
            org_set_tags_command = ';q',
            org_deadline = ';d',
            org_schedule = ';s',
            org_refile = ';r',
            org_archive = ';A',
            org_open_at_point = ';o',
            org_edit_special = ";<CR>",
            org_insert_heading_respect_content = ';<End>',
            org_insert_todo_heading = ';T',
            org_insert_todo_heading_respect_content = ';t',
            org_move_subtree_up = '<M-k>',
            org_move_subtree_down = '<M-j>',
            org_export = ';e',
            org_meta_return = '<M-CR>',
            org_return = '<CR>',
          },
          agenda = {
            org_agenda_later = 'f',
            org_agenda_earlier = 'b',
            org_agenda_goto_today = '.',
            org_agenda_day_view = 'vd',
            org_agenda_week_view = 'vw',
            org_agenda_month_view = 'vm',
            org_agenda_year_view = 'vy',
            org_agenda_quit = 'q',
            org_agenda_goto = '<CR>',
            org_agenda_switch_to = '<TAB>',
            org_agenda_todo = 't',
            org_agenda_clock_in = 'I',
            org_agenda_clock_out = 'O',
            org_agenda_clock_cancel = 'X',
            org_agenda_set_tags = ':',
            org_agenda_deadline = 'd',
            org_agenda_schedule = 's',
            org_agenda_filter = '/',
            org_agenda_priority = ',',
            org_agenda_archive = 'A',
            org_agenda_refile = 'r',
          },
          capture = {
            org_capture_finalize = '<C-c>',
            org_capture_refile = ';r',
            org_capture_kill = ';k',
          },
        },
      },
    },

    -- org-bullets: visual enhancements (like org-modern in Emacs)
    ['nvim-orgmode/org-bullets.nvim'] = {
      ft = { 'org' },
      opts = {
        concealcursor = true,
        symbols = {
          list = '•',
          headlines = { '◉', '○', '✸', '✿', '◆', '◇' },
          checkboxes = {
            half    = { '', '@org.checkbox.halfchecked' },
            done    = { '✓', '@org.keyword.done' },
            todo    = { '˟', '@org.keyword.todo' },
          },
        },
      },
    },

    -- headlines.nvim: background highlights for org headings
    ['lukas-reineke/headlines.nvim'] = {
      ft = { 'org', 'markdown' },
      dependencies = { 'nvim-treesitter/nvim-treesitter' },
      opts = {
        org = {
          headline_highlights = { 'Headline1', 'Headline2', 'Headline3' },
          fat_headlines = false,
          bullets = {},
        },
      },
    },
  },

  setup = function()
    -- Ensure org directory exists
    local org_dir = vim.fn.expand '~/org'
    if vim.fn.isdirectory(org_dir) == 0 then
      vim.fn.mkdir(org_dir, 'p')
    end

    -- Ensure default org files exist
    local default_files = { 'refile.org', 'notes.org', 'journal.org', 'todo.org' }
    for _, fname in ipairs(default_files) do
      local fpath = org_dir .. '/' .. fname
      if vim.fn.filereadable(fpath) == 0 then
        local title = fname:gsub('%.org$', ''):gsub('^%l', string.upper)
        vim.fn.writefile({ '#+TITLE: ' .. title, '#+STARTUP: overview fold', '' }, fpath)
      end
    end

    -- ── Org-mode global keymaps (SPC o prefix — Doom standard) ──────
    vim.keymap.set('n', '<leader>oa', function()
      require('orgmode').action('agenda.prompt')
    end, { desc = 'org.agenda', silent = true })

    vim.keymap.set('n', '<leader>oc', function()
      require('orgmode').action('capture.prompt')
    end, { desc = 'org.capture', silent = true })

    -- Quick-access to specific agenda views
    vim.keymap.set('n', '<leader>ot', function()
      require('orgmode').action('agenda.agenda', { type = 'todo' })
    end, { desc = 'org.todo_list', silent = true })

    -- Open org directory for browsing
    vim.keymap.set('n', '<leader>of', function()
      vim.ui.picker.files { cwd = vim.fn.expand '~/org' }
    end, { desc = 'org.find_file', silent = true })

    -- Grep org files
    vim.keymap.set('n', '<leader>og', function()
      vim.ui.picker.grep { cwd = vim.fn.expand '~/org' }
    end, { desc = 'org.grep', silent = true })

    -- SPC X — quick capture (Doom standard top-level binding)
    vim.keymap.set('n', '<leader>X', function()
      require('orgmode').action('capture.prompt')
    end, { desc = 'org.quick_capture', silent = true })

    -- ── Org-mode specific autocmds ─────────────────────────────────
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'org',
      group = vim.api.nvim_create_augroup('orgmode_settings', { clear = true }),
      callback = function()
        -- Soft wrap for org files (like Emacs visual-line-mode)
        vim.wo.wrap = true
        vim.wo.linebreak = true
        vim.wo.breakindent = true

        -- Spell checking on by default in org files
        vim.wo.spell = true
        vim.wo.spelllang = 'en'

        -- Conceal for clean rendering
        vim.wo.conceallevel = 2
        vim.wo.concealcursor = 'nc'
      end,
    })

    -- ── Display registrations ──────────────────────────────────────
    env.display.register {
      id = 'orgmode.bullets',
      kind = 'virtual_text',
      module = 'orgmode',
      desc = 'org-bullets — unicode heading/list/checkbox decorations',
    }
  end,
}
