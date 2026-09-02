-- 逻辑 split 导航，支持透明窗口跳过和 mux fallback

local window = require('vv-splits.window')

local M = {}

---@param opts { direction: VVSplitsDirection }
---@param config VVSplitsConfig
---@param mux table
---@return boolean
function M.move(opts, config, mux)
  local origin = window.resolve_origin(config.float_behavior)
  if not origin then return false end

  local target = window.logical_neighbor(origin, opts.direction, config.skip_window)
  if target then
    vim.api.nvim_set_current_win(target)
    return true
  end

  return mux.move(opts.direction)
end

return M
