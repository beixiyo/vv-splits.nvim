-- WezTerm 适配器，针对拥有此 Neovim 进程的窗格

local direction = require('vv-splits.direction')
local process = require('vv-splits.mux.process')

local M = {}

---@param opts? { env?: table, run?: fun(command: string[]): boolean, string, string }
---@return VVSplitsMuxAdapter
function M.new(opts)
  opts = opts or {}
  local env = opts.env or vim.env
  local run = opts.run or process.run

  local function pane_id()
    return type(env.WEZTERM_PANE) == 'string' and env.WEZTERM_PANE ~= '' and env.WEZTERM_PANE or nil
  end

  return {
    move = function(target_direction)
      local pane = pane_id()
      if not pane then return false end
      local ok = run({
        'wezterm', 'cli', 'activate-pane-direction',
        '--pane-id', pane, direction.title[target_direction],
      })
      return ok
    end,

    resize = function(target_direction, amount)
      local pane = pane_id()
      if not pane then return false end
      local ok = run({
        'wezterm', 'cli', 'adjust-pane-size',
        '--pane-id', pane, '--amount', tostring(amount), direction.title[target_direction],
      })
      return ok
    end,
  }
end

return M
