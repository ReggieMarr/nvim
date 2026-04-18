-- NOTE this is ported from the partial implementation of project.nvim's
-- support for persistence as an exension

local MODSTR = 'project.extensions.session.persistence'
local uv = vim.uv or vim.loop
-- local Log = require 'project.utils.log'

-- **PersistenceLoadPre**: Before loading a session
-- **PersistenceSavePre**: Before saving a session
-- **PersistenceLoadPost**: After loading a session
-- **PersistenceSavePost**: After saving a session

---@class Project.Extension.Persistence
local M = {}

---@param session string
---@return string dir
function M.transform_session(session)
  local sessions_dir = require('persistence.config').options.dir
  local file = session:sub(sessions_dir:len() + 1, -5)
  local dir, _ = unpack(vim.split(file, '%%', { plain = true }))
  dir = dir:gsub('%%', '/')
  if jit.os:find 'Windows' then dir = dir:gsub('^(%w)/', '%1:/') end

  return dir
end

---@return string[]
function M.saved_projects()
  ---@type string[]
  local items = {}
  local recent = require('project').get_recent_projects() or {}
  for _, session in ipairs(require('persistence').list()) do
    if uv.fs_stat(session) then
      local dir = M.transform_session(session)
      if vim.list_contains(recent, dir) then table.insert(items, dir) end
    end
  end
  --
  local Util = require 'project.util'
  return Util.dedup(items)
end

---@param proj string
---@return boolean
function M.is_current(proj)
  local curr = M.transform_session(require('persistence').current { branch = false })
  -- Log.debug(('(%s.is_current): Current session: `%s`'):format(MODSTR, curr))
  return curr == proj
end

---@param sessions string[]
function M.save_sessions(sessions)
  for _, session in ipairs(sessions) do
    M.save_session(session)
  end
end

---@param proj string
function M.save_session(proj)
  -- Log.info(('(%s.save_session): Saving project `%s`.'):format(MODSTR, proj))
  require('persistence').save()
end

---@param proj string
---@param save? boolean
function M.open_session(proj, save)
  save = save ~= nil and save or false
  local sessions = M.saved_projects()
  if vim.list_contains(sessions, proj) then
    if not M.is_current(proj) then
      -- Log.info(('(%s.open_session): Project `%s` has session. Loading.'):format(MODSTR, proj))
      require('persistence').load()
      return
    end

    -- Log.info(('(%s.open_session): Session already loaded for `%s`'):format(MODSTR, proj))
    return
  end
  if save then
    -- Log.debug(('(%s.open_session): Saving is enabled.'):format(MODSTR))
    M.save_session(proj)
    return
  end

  -- Log.warn(('(%s.open_session): No session opening nor saving took place.'):format(MODSTR))
end

function M.init()
  -- local Options = require('project.config').options.integrations.persistence
  -- NOTE normally this could be configured in project.nvim's config
  -- since we've manually ported we've hardcoded this to be enabled
  -- if not Options.enabled then return end
  local augroup = vim.api.nvim_create_augroup('project.nvim.persistence', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function()
      local curr = require('project.api').current_project
      if curr then M.open_session(curr, true) end
    end,
  })
  -- if Options.auto_save then
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      local session_projects = require('project.util.history').session_projects
      if not vim.tbl_isempty(session_projects) then M.save_sessions(session_projects) end
    end,
  })
  -- end
end

return M
