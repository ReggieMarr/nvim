-- lua/modules/navigation.lua
-- Navigation module: fuzzy finding, picking, and search.
-- Provides the picker capability using snacks.picker.
-- All other modules that need picking consume the capability,
-- not snacks directly.

local env = require("env")

env.module.register({
  name         = "navigation",
  domain      = "navigation",
  depends_on   = { "interface" },
  optional_deps = {},

  providers = {
    {
      "folke/snacks.nvim",
      priority = 1000,
      lazy     = false,
      ---@type snacks.Config
      opts = {
        picker = {
          -- Snacks picker configuration
          -- Keep this focused on snacks behavior, not on what we do with it
          ui_select = true, -- override vim.ui.select with snacks picker
          layout    = {
            preset = "default",
          },
          formatters = {
            file = { filename_first = true },
          },
        },
        -- Other snacks modules we use in navigation context
        notifier = { enabled = false }, -- notifier lives in interface module
        bigfile  = { enabled = true },
      },
      config = function(_, opts)
        local snacks = require("snacks")
        snacks.setup(opts)

        -- Register the picker capability once snacks is initialized.
        -- Every key maps to a function with a consistent (opts?) signature
        -- so consumers don't need to know snacks' API shape.
        env.capabilities.register("picker", {
          files   = function(o) snacks.picker.files(o) end,
          grep    = function(o) snacks.picker.grep(o) end,
          buffers = function(o) snacks.picker.buffers(o) end,
          keymaps = function(o) snacks.picker.keymaps(o) end,
          commands = function(o) snacks.picker.commands(o) end,
        }, "navigation")
      end,
    },
  },

  display = {
    -- Snacks dim: dims inactive code blocks
    -- Pure display, no interaction concern
    {
      "folke/snacks.nvim", -- lazy deduplicates same plugin across specs
      opts = {
        dim = { enabled = true },
        scroll = { enabled = true },
      },
    },
  },

  articulation = {
    {
      "folke/snacks.nvim",
      config = function()
        -- All navigation actions go through env.articulation
        -- so they are registered in the action registry, get conflict
        -- detection, precondition evaluation, and agent accessibility

        env.articulation.register_group_label("<leader>f", "find")
        env.articulation.register_group_label("<leader>b", "buffers")

        env.articulation.register_group("navigation", {
          {
            id      = "navigation.find_files",
            handler = function()
              env.use("picker").files()
            end,
            desc     = "Find files",
            bindings = { { lhs = "<leader>ff" } },
            when     = function(state)
              return state["workspace.cwd"] ~= nil
            end,
          },
          {
            id      = "navigation.grep",
            handler = function()
              env.use("picker").grep()
            end,
            desc     = "Grep project",
            bindings = { { lhs = "<leader>fg" } },
            when     = function(state)
              return state["workspace.cwd"] ~= nil
            end,
          },
          {
            id      = "navigation.find_buffers",
            handler = function()
              env.use("picker").buffers()
            end,
            desc     = "Find open file buffers",
            bindings = { { lhs = "<leader>fb" } },
          },
          {
            id      = "navigation.find_keymaps",
            handler = function()
              env.use("picker").keymaps()
            end,
            desc     = "Find keymaps",
            bindings = { { lhs = "<leader>fk" } },
          },
          {
            id      = "navigation.find_commands",
            handler = function()
              env.use("picker").commands()
            end,
            desc     = "Find commands",
            bindings = { { lhs = "<leader>fc" } },
          },
          -- Buffer-scope actions
          {
            id      = "navigation.recent_files",
            handler = function()
              require("snacks").picker.recent()
            end,
            desc     = "Recent files",
            bindings = { { lhs = "<leader>fr" } },
          },
          {
            id       = "navigation.find_config",
            handler  = function()
              env.use("picker").files({
                cwd = vim.fn.stdpath("config")
              })
            end,
            desc     = "Find in config",
            bindings = { { lhs = "<leader>fc" } },
          },
        })
      end,
    },
  },
})
