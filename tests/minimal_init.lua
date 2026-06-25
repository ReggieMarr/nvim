-- tests/minimal_init.lua
-- Minimal Neovim init for headless test runs.
-- Adds the nvim config to rtp so lua modules can be required directly.
-- Does NOT load plugins (no lazy bootstrap) — tests only exercise lib/* and
-- pure data modules that have no plugin dependencies.

local config_path = vim.fn.stdpath 'config'
vim.opt.rtp:prepend(config_path)

-- Silence vim.notify during tests (tests assert on return values, not notifications)
vim.notify = function(msg, level)
  -- Uncomment to debug: print(string.format('[notify %s] %s', level, msg))
end
