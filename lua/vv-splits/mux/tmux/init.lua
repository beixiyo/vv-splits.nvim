-- 无状态 tmux 适配器，每条命令都使用拥有的 socket 和 pane ID

local direction = require('vv-splits.direction')
local process = require('vv-splits.mux.process')

local M = {}

local edge_formats = {
  left = '#{pane_at_left}',
  right = '#{pane_at_right}',
  up = '#{pane_at_top}',
  down = '#{pane_at_bottom}',
}

---@param opts? { env?: table, run?: fun(command: string[]): boolean, string, string }
---@return VVSplitsMuxAdapter
function M.new(opts)
  opts = opts or {}
  local env = opts.env or vim.env
  local run = opts.run or process.run

  -- $TMUX 格式为 `<socket path>,<server pid>,<session index>`；以最后两个数字字段为锚点，
  -- 这样 socket 路径中的逗号也能正确解析
  local function identity()
    local socket = type(env.TMUX) == 'string' and env.TMUX:match('^(.+),%d+,%d+$') or nil
    local pane = env.TMUX_PANE
    if not socket or socket == '' or not pane or pane == '' then return nil end
    return socket, pane
  end

  ---@param args string[]
  ---@return boolean, string
  local function execute(args)
    local socket = identity()
    if not socket then return false, '' end

    local command = { 'tmux', '-S', socket }
    vim.list_extend(command, args)
    local ok, stdout = run(command)
    return ok, stdout
  end

  ---@param format string
  ---@return string?
  local function query(format)
    local _, pane = identity()
    if not pane then return nil end
    local ok, stdout = execute({ 'display-message', '-p', '-t', pane, format })
    return ok and stdout or nil
  end

  local function is_zoomed()
    return query('#{window_zoomed_flag}') == '1'
  end

  return {
    move = function(target_direction)
      local _, pane = identity()
      if not pane or is_zoomed() or query(edge_formats[target_direction]) == '1' then return false end
      local ok = execute({ 'select-pane', '-t', pane, '-' .. direction.tmux[target_direction] })
      return ok
    end,

    resize = function(target_direction, amount)
      local _, pane = identity()
      if not pane or is_zoomed() then return false end
      local ok = execute({ 'resize-pane', '-t', pane, '-' .. direction.tmux[target_direction], tostring(amount) })
      return ok
    end,
  }
end

return M
