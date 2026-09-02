-- 将方向缩放请求映射到拥有该边界的 Neovim 分隔符
--
-- 边界规则（与 tmux `resize-pane -L/-R/-U/-D` 相同）：
--   * 当邻窗存在时，窗口自己的右/下边界会移动
--   * 只有该轴上的最后一个窗口会改为移动其左/上边界
-- 所以左/右（和上/下）从每个窗口来看都是反向操作，
-- 共享两列边界的两个窗口会操作同一个分隔符

local window = require('vv-splits.window')

local M = {}

---@class VVSplitsBoundary
---@field kind 'separator'|'statusline'
---@field owner integer
---@field offset integer

---@param win integer
---@param target_direction VVSplitsDirection
---@param amount integer
---@return VVSplitsBoundary?
function M.resolve(win, target_direction, amount)
  if target_direction == 'left' or target_direction == 'right' then
    local left = window.physical_neighbor(win, 'left')
    local right = window.physical_neighbor(win, 'right')
    if not left and not right then return nil end

    return {
      kind = 'separator',
      owner = right and win or left,
      offset = target_direction == 'right' and amount or -amount,
    }
  end

  local above = window.physical_neighbor(win, 'up')
  local below = window.physical_neighbor(win, 'down')
  if not above and not below then return nil end

  return {
    kind = 'statusline',
    owner = below and win or above,
    offset = target_direction == 'down' and amount or -amount,
  }
end

return M
