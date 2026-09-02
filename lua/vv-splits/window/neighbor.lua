-- 解析物理和逻辑 split 邻窗，不暂时改变焦点

local direction = require('vv-splits.direction')

local M = {}

---@param win integer
---@param target integer
---@return boolean
local function same_tab(win, target)
  return vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_win_get_tabpage(target)
end

---@param win integer
---@param target integer
---@return boolean
local function valid_target(win, target)
  if target == 0 or target == win or not vim.api.nvim_win_is_valid(target) then return false end
  if not same_tab(win, target) then return false end
  return vim.api.nvim_win_get_config(target).relative == ''
end

---@param win integer
---@param target_direction VVSplitsDirection
---@return integer?
function M.physical(win, target_direction)
  if not vim.api.nvim_win_is_valid(win) then return nil end

  local ok, target = pcall(vim.api.nvim_win_call, win, function()
    local number = vim.fn.winnr(direction.keys[target_direction])
    return vim.fn.win_getid(number)
  end)
  if not ok or type(target) ~= 'number' or not valid_target(win, target) then return nil end
  return target
end

---@param win integer
---@param target_direction VVSplitsDirection
---@param skip_window fun(win: integer): boolean
---@return integer?
function M.logical(win, target_direction, skip_window)
  local visited = { [win] = true }
  local cursor = win

  while true do
    local target = M.physical(cursor, target_direction)
    if not target or visited[target] then return nil end
    visited[target] = true
    if not skip_window(target) then return target end
    cursor = target
  end
end

return M
