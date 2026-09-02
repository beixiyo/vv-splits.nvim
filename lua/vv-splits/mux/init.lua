-- Multiplexer 适配器的解析、生命周期和操作接口

local M = {}

local lifecycle_group = 'VVSplitsMuxLifecycle'

---@type VVSplitsMuxAdapter?
local adapter

local function clear_lifecycle()
  pcall(vim.api.nvim_del_augroup_by_name, lifecycle_group)
end

---@param name 'tmux'|'kitty'|'wezterm'
---@return VVSplitsMuxAdapter
local function builtin(name)
  return require('vv-splits.mux.' .. name).new()
end

---@param requested VVSplitsMuxName|false|VVSplitsMuxAdapter
---@return VVSplitsMuxAdapter?
local function resolve(requested)
  if requested == false or vim.g.neovide then return nil end
  if type(requested) == 'table' then return requested end
  if requested ~= 'auto' then return builtin(requested) end

  if vim.env.TMUX and vim.env.TMUX_PANE then return builtin('tmux') end
  if vim.env.KITTY_LISTEN_ON and vim.env.KITTY_WINDOW_ID then return builtin('kitty') end
  if vim.env.WEZTERM_PANE then return builtin('wezterm') end
end

function M.detach()
  clear_lifecycle()
  if adapter and adapter.detach then adapter.detach() end
  adapter = nil
end

---@param requested VVSplitsMuxName|false|VVSplitsMuxAdapter
function M.setup(requested)
  M.detach()
  adapter = resolve(requested)
  if not adapter then return end

  if adapter.attach then adapter.attach() end
  if adapter.detach then
    local group = vim.api.nvim_create_augroup(lifecycle_group, { clear = true })
    vim.api.nvim_create_autocmd('VimLeavePre', {
      group = group,
      once = true,
      callback = function()
        if adapter and adapter.detach then adapter.detach() end
      end,
    })
  end
end

---@param target_direction VVSplitsDirection
---@return boolean
function M.move(target_direction)
  return adapter ~= nil and adapter.move(target_direction) == true
end

---@param target_direction VVSplitsDirection
---@param amount integer
---@return boolean
function M.resize(target_direction, amount)
  return adapter ~= nil and adapter.resize(target_direction, amount) == true
end

return M
