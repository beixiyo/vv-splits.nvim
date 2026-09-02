-- 解析拥有一个操作的 split，包括配置的浮窗策略
-- 纯查询：焦点只由实际成功的操作改变

local M = {}

---@param win integer
---@return boolean
local function is_float(win)
  return vim.api.nvim_win_get_config(win).relative ~= ''
end

---@param behavior VVSplitsFloatBehavior
---@return integer?
function M.resolve(behavior)
  if vim.fn.getcmdwintype() ~= '' then return nil end

  local current = vim.api.nvim_get_current_win()
  if not is_float(current) then return current end
  if behavior == 'stop' then return nil end

  local previous = vim.fn.win_getid(vim.fn.winnr('#'))
  if previous == 0
    or previous == current
    or not vim.api.nvim_win_is_valid(previous)
    or is_float(previous)
  then
    return nil
  end

  return previous
end

return M
