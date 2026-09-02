-- vv-splits 测试的共享真实窗口 fixtures 和断言

local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fn.fnamemodify(source, ':p:h:h')
vim.opt.rtp:prepend(root)

local M = { root = root }

---@param actual any
---@param expected any
---@param message string
function M.equal(actual, expected, message)
  assert(vim.deep_equal(actual, expected), ('%s\nexpected: %s\nactual:   %s')
    :format(message, vim.inspect(expected), vim.inspect(actual)))
end

---@param value any
---@param message string
function M.truthy(value, message)
  assert(value, message)
end

function M.reset()
  vim.cmd('silent! only')
  vim.o.equalalways = false
  vim.o.splitright = true
  vim.o.splitbelow = true
  vim.o.winminwidth = 1
  vim.o.winminheight = 1
  vim.o.laststatus = 0

  local current = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(current, vim.api.nvim_create_buf(false, true))
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= vim.api.nvim_win_get_buf(current) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
end

---@param count integer
---@return integer[]
function M.vertical(count)
  M.reset()
  for _ = 2, count do vim.cmd('rightbelow vsplit') end

  local windows = vim.api.nvim_tabpage_list_wins(0)
  table.sort(windows, function(a, b)
    return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
  end)
  return windows
end

---@param count integer
---@return integer[]
function M.horizontal(count)
  M.reset()
  for _ = 2, count do vim.cmd('rightbelow split') end

  local windows = vim.api.nvim_tabpage_list_wins(0)
  table.sort(windows, function(a, b)
    return vim.api.nvim_win_get_position(a)[1] < vim.api.nvim_win_get_position(b)[1]
  end)
  return windows
end

return M
