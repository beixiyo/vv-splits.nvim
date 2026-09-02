-- 原生分隔符缩放，带调用方所有的布局事务和 mux fallback

local boundary = require('vv-splits.resize.boundary')
local window = require('vv-splits.window')

local M = {}

---移动边界并报告是否有任何窗口几何实际改变
---`win_move_separator()` / `win_move_statusline()` 只要窗口存在就返回 TRUE，
---即使 'winminwidth' 或屏幕边缘阻止了移动
---@param item VVSplitsBoundary
---@return boolean changed
local function move_boundary(item)
  local before = vim.fn.winrestcmd()
  local found
  if item.kind == 'separator' then
    found = vim.fn.win_move_separator(item.owner, item.offset)
  else
    found = vim.fn.win_move_statusline(item.owner, item.offset)
  end
  return found ~= 0 and vim.fn.winrestcmd() ~= before
end

---@param opts { direction: VVSplitsDirection, amount: integer }
---@param config VVSplitsConfig
---@param mux table
---@return boolean
function M.resize(opts, config, mux)
  local result = config.with_resize(function()
    -- 在守卫移除语义辅助 split 之后解析
    local origin = window.resolve_origin(config.float_behavior)
    if not origin then return false end

    -- 无法移动的本地边界报告为 false，永远不会委托给
    -- multiplexer：用户正在处理 Neovim 自己的布局
    local item = boundary.resolve(origin, opts.direction, opts.amount)
    if item then return move_boundary(item) end
    return mux.resize(opts.direction, opts.amount)
  end)

  return result == true
end

return M
