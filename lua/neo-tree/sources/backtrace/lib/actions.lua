local log = require("neo-tree.log")
local utils = require("neo-tree.sources.backtrace.lib.utils")

---@class Action
---@field manager MarksManager
---@field selected_flow string
local Action = {
  ---@param self Action
  start = function(self, opts)
    local mgr = require("neo-tree.sources.backtrace.lib.manager")
    local path = utils.current(opts)
    local uv = vim.uv or vim.loop

    if not uv.fs_stat(path) or vim.fn.isdirectory(path) == 1 then
      self.manager = mgr:new()
      return
    end

    local buffer = vim.json.decode(vim.fn.readfile(path)[1])
    self.manager = mgr:loads(buffer)
    if self.manager:size() == 1 then
      self.selected_flow = self.manager:flows()[1]
      log.debug(("Auto select flow: %s"):format(self.selected_flow))
    end
  end,

  ---@param self Action
  save = function(self, opts)
    if not self.manager.mDirty then
      return true
    end
    local buffer = vim.json.encode(self.manager:dumps())
    return pcall(vim.fn.writefile, { buffer }, utils.current(opts))
  end,
}

function Action:sel_flow(name)
  self.selected_flow = name
end

---@param name string
function Action:add_flow(name)
  if self.manager:addFlow(name) then
    self.manager:setIsDirty(true)
    return true
  end
  return false
end

---@param name string
function Action:del_flow(name)
  if self.manager:delFlow(name) then
    self.manager:setIsDirty(true)
  end
end

function Action:mod_flow(old, new)
  if self.manager:modFlow(old, new) then
    self.manager:setIsDirty(true)
  end
end

function Action:add_mark()
  local Mark = require("neo-tree.sources.backtrace.lib.mark")
  if self.selected_flow == nil then
    return false
  end
  local flow = assert(self.selected_flow, ("flow %s not found"):format(self.selected_flow))
  local path = vim.api.nvim_buf_get_name(0)
  local bufnr = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)
  local symbol = utils.getContext(bufnr, cur[1], cur[2])
  local mark = Mark:new(path, cur[1], cur[2], symbol)
  self.manager:getFlow(flow):addMark(mark)
  self.manager:setIsDirty(true)
  return true
end

---@param flow string
---@param index integer
function Action:del_mark(flow, index)
  self.manager:getFlow(flow):delMark(index)
  self.manager:setIsDirty(true)
end

---@param flow string
---@param index integer
---@param name string
function Action:mod_mark(flow, index, name)
  self.manager:getFlow(flow):getMark(index):mod(name)
  self.manager:setIsDirty(true)
end

function Action:to_nodes()
  return self.manager:toNode(self.selected_flow)
end

return Action
