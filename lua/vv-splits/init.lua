-- 提供方向性 Neovim split 导航、缩放和 mux fallback 的公共接口

local config = require('vv-splits.config')
local direction = require('vv-splits.direction')
local mux = require('vv-splits.mux')
local navigation = require('vv-splits.navigation')
local resize = require('vv-splits.resize')

local M = {}

---配置本地 split 行为和可选的 multiplexer 适配器
---@param opts? VVSplitsSetupOpts
function M.setup(opts)
  local next_config = config.setup(opts)
  mux.setup(next_config.mux)
end

---返回规范化公共配置的隔离副本
---@return VVSplitsConfig
function M.get_config()
  return config.get()
end

---将焦点移动到下一个逻辑 split 或 multiplexer 窗格
---@param opts { direction: VVSplitsDirection }
---@return boolean handled
function M.move(opts)
  assert(type(opts) == 'table', 'opts must be a table')
  local target_direction = direction.validate(opts.direction)
  return navigation.move({ direction = target_direction }, config.current(), mux)
end

---按请求的方向移动分隔符或状态栏
---@param opts { direction: VVSplitsDirection, amount?: integer }
---@return boolean handled
function M.resize(opts)
  assert(type(opts) == 'table', 'opts must be a table')
  local target_direction = direction.validate(opts.direction)
  local amount = opts.amount or config.current().amount
  assert(type(amount) == 'number' and amount > 0 and amount % 1 == 0, 'amount must be a positive integer')

  return resize.resize({ direction = target_direction, amount = amount }, config.current(), mux)
end

return M
