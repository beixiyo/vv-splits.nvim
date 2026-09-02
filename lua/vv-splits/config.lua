-- vv-splits 的公共配置规范化和验证

local M = {}

---@alias VVSplitsDirection 'left'|'right'|'up'|'down'
---@alias VVSplitsMuxName 'auto'|'tmux'|'kitty'|'wezterm'
---@alias VVSplitsFloatBehavior 'previous'|'stop'

---@class VVSplitsMuxAdapter
---@field attach? fun()
---@field detach? fun()
---@field move fun(direction: VVSplitsDirection): boolean
---@field resize fun(direction: VVSplitsDirection, amount: integer): boolean

---@class VVSplitsSetupOpts
---@field amount? integer 每次缩放的列数或行数 @default 3
---@field mux? VVSplitsMuxName|false|VVSplitsMuxAdapter Multiplexer 适配器或自动检测 @default 'auto'
---@field float_behavior? VVSplitsFloatBehavior 处理来自浮窗的操作的方式 @default 'previous'
---@field skip_window? fun(win: integer): boolean 导航专用的透明窗口判定函数 @default function() return false end
---@field with_resize? fun(action: fun(): boolean): boolean 包装每次缩放操作的布局事务 @default function(action) return action() end

---@class VVSplitsConfig
---@field amount integer 每次缩放的列数或行数
---@field mux VVSplitsMuxName|false|VVSplitsMuxAdapter Multiplexer 适配器或自动检测
---@field float_behavior VVSplitsFloatBehavior 处理来自浮窗的操作的方式
---@field skip_window fun(win: integer): boolean 导航专用的透明窗口判定函数
---@field with_resize fun(action: fun(): boolean): boolean 包装每次缩放操作的布局事务

local defaults = {
  amount = 3,
  mux = 'auto',
  float_behavior = 'previous',
  skip_window = function() return false end,
  with_resize = function(action) return action() end,
}

---@type VVSplitsConfig
local config = vim.tbl_extend('force', {}, defaults)

---规范化和验证部分公共配置
---@param opts? VVSplitsSetupOpts
---@return VVSplitsConfig
function M.setup(opts)
  assert(opts == nil or type(opts) == 'table', 'opts must be a table or nil')

  local next_config = vim.tbl_extend('force', {}, defaults, opts or {})
  assert(type(next_config.amount) == 'number'
    and next_config.amount > 0
    and next_config.amount % 1 == 0, 'amount must be a positive integer')
  assert(next_config.float_behavior == 'previous'
    or next_config.float_behavior == 'stop', 'float_behavior must be previous or stop')
  assert(type(next_config.skip_window) == 'function', 'skip_window must be a function')
  assert(type(next_config.with_resize) == 'function', 'with_resize must be a function')

  local mux_type = type(next_config.mux)
  assert(next_config.mux == false or mux_type == 'string' or mux_type == 'table', 'mux must be false, a name, or an adapter')
  if mux_type == 'string' then
    assert(vim.tbl_contains({ 'auto', 'tmux', 'kitty', 'wezterm' }, next_config.mux),
      'mux must be auto, tmux, kitty, wezterm, false, or an adapter')
  elseif mux_type == 'table' then
    assert(type(next_config.mux.move) == 'function', 'custom mux adapter must provide move()')
    assert(type(next_config.mux.resize) == 'function', 'custom mux adapter must provide resize()')
  end

  config = next_config
  return config
end

---@return VVSplitsConfig
function M.current()
  return config
end

---@return VVSplitsConfig
function M.get()
  return vim.deepcopy(config)
end

return M
