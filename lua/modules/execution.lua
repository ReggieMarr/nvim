-- lua/modules/execution.lua
-- Execution module: task running and terminal management.
-- Provides task_runner capability via overseer.nvim.
-- Provides terminal capability via snacks.terminal.

local env = require("env")

env.module.register({
  name          = "execution",
  domain       = "execution",
  depends_on    = { "interface", "navigation" },
  optional_deps = {},

  providers = {
    -- Overseer: structured task running
    {
      "stevearc/overseer.nvim",
      config = function()
        local overseer = require("overseer")

        overseer.setup({
          -- Task list display configuration
          task_list = {
            direction = "bottom",
            min_height = 10,
            max_height = 20,
            default_detail = 1,
          },
          -- Component defaults applied to all tasks
          component_aliases = {
            default = {
              { "display_duration", detail_level = 2 },
              "on_output_summarize",
              "on_exit_set_status",
              "on_complete_notify",
              "on_complete_dispose",
            },
          },
        })

        -- Register task_runner capability
        env.capabilities.register("task_runner", {
          run = function(task_spec)
            local task = overseer.new_task(task_spec)
            task:start()
            return task
          end,

          list = function()
            return overseer.list_tasks()
          end,

          toggle = function()
            overseer.toggle({ direction = "bottom" })
          end,
        }, "execution")

        -- Feed task state into env.state
        -- Overseer provides a subscription mechanism for task events
        overseer.on_task_create(function(task)
          env.state._update("execution.active_tasks", overseer.list_tasks({
            status = { "RUNNING", "PENDING" },
          }))
        end)

        overseer.on_task_result(function(task)
          -- Update active task count
          env.state._update("execution.active_tasks", overseer.list_tasks({
            status = { "RUNNING", "PENDING" },
          }))

          -- Record last completed task result
          env.state._update("execution.last_result", {
            name      = task.name,
            status    = task.status,
            timestamp = os.time(),
          })
        end)
      end,
    },
  },

  display = {
    {
      "stevearc/overseer.nvim",
      opts = {},
    },

    -- Register display contribution for task status in statusline
    -- The actual rendering is done by the interface module reading this
    -- contribution's state; we just declare that we contribute to statusline
    {
      -- virtual plugin spec: no plugin to load, just registration side effects
      -- This pattern lets us register display contributions in the display
      -- section where they conceptually belong, even without a plugin spec
      dir = vim.fn.stdpath("config"),
      name = "execution-display-registration",
      lazy = false,
      config = function()
        env.display.register({
          id     = "execution.task_status",
          module = "execution",
          region = "statusline",
          desc   = "Active task count and last result status",
          when   = function(state)
            local tasks = state["execution.active_tasks"]
            return tasks ~= nil and #tasks > 0
          end,
          priority = 80,
        })
      end,
    },
  },

  articulation = {
    {
      "stevearc/overseer.nvim",
      config = function()
        -- Terminal capability via snacks
        -- Snacks is loaded by the navigation module which is a dependency,
        -- so this is safe to reference here
        local snacks = require("snacks")

        env.capabilities.register("terminal", {
          toggle = function(opts)
            snacks.terminal.toggle(nil, opts)
          end,
          run = function(cmd, opts)
            snacks.terminal.open(cmd, opts)
          end,
          send = function(text, opts)
            -- snacks doesn't have a native send; find active terminal and send
            local term = snacks.terminal.get()
            if term then
              local chan = vim.bo[term.buf].channel
              if chan then vim.fn.chansend(chan, text) end
            end
          end,
        }, "execution")

        -- Register state provider for terminal presence
        env.state.register_provider({
          id      = "execution.terminal_open",
          events  = { "BufEnter", "WinEnter", "TermOpen", "TermClose" },
          collect = function()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.bo[buf].buftype == "terminal" then
                if vim.fn.bufwinid(buf) ~= -1 then
                  return true
                end
              end
            end
            return false
          end,
          desc = "Whether a terminal window is currently visible",
        })

        env.articulation.register_group_label("<leader>t", "tasks")

        env.articulation.register_group("execution", {
          {
            id      = "execution.task_list",
            handler = function()
              env.use("task_runner").toggle()
            end,
            desc     = "Toggle task list",
            bindings = { { lhs = "<leader>tt" } },
          },
          {
            id      = "execution.run_task",
            handler = function()
              require("overseer").run_template()
            end,
            desc     = "Run task",
            bindings = { { lhs = "<leader>tr" } },
          },
          {
            id      = "execution.last_task",
            handler = function()
              local tasks = require("overseer").list_tasks({ recent_first = true })
              if tasks[1] then
                require("overseer").run_action(tasks[1], "restart")
              end
            end,
            desc     = "Restart last task",
            bindings = { { lhs = "<leader>tl" } },
          },
          {
            id      = "execution.terminal_toggle",
            handler = function()
              env.use("terminal").toggle()
            end,
            desc     = "Toggle terminal",
            bindings = {
              { lhs = "<leader>te" },
              { lhs = "<C-/>" },
            },
          },
          -- Also register a picker extension for tasks
          -- This is how modules extend the picker capability
          -- with domain-specific finders
          {
            id      = "execution.find_tasks",
            handler = function()
              -- Overseer provides a telescope extension;
              -- for snacks we build a simple picker
              local tasks   = require("overseer").list_tasks({ recent_first = true })
              local items   = vim.tbl_map(function(t)
                return {
                  text = string.format("[%s] %s", t.status, t.name),
                  task = t,
                }
              end, tasks)

              require("snacks").picker.pick({
                source  = "tasks",
                items   = items,
                format  = function(item) return item.text end,
                confirm = function(picker, item)
                  picker:close()
                  require("overseer").run_action(item.task, "open")
                end,
              })
            end,
            desc     = "Find tasks",
            bindings = { { lhs = "<leader>tf" } },
          },
        })

        -- Extend the picker capability with task finding
        env.capabilities.extend("picker", {
          tasks = function(opts)
            env.articulation.execute("execution.find_tasks", opts)
          end,
        }, "execution")
      end,
    },
  },
})
