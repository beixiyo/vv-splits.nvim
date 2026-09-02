-- 导航、缩放和 mux 适配器共享的方向常量和验证

local M = {}

M.keys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

M.tmux = {
  left = 'L',
  right = 'R',
  up = 'U',
  down = 'D',
}

M.title = {
  left = 'Left',
  right = 'Right',
  up = 'Up',
  down = 'Down',
}

---@param direction unknown
---@return direction: VVSplitsDirection
function M.validate(direction)
  assert(type(direction) == 'string' and M.keys[direction] ~= nil, 'direction must be left, right, up, or down')
  return direction
end

return M
