-- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h') .. '/helpers.lua')
local splits = require('vv-splits')

local function set_left_width(win, width)
  vim.wo[win].winfixwidth = false
  vim.api.nvim_win_set_width(win, width)
  vim.wo[win].winfixwidth = true
end

local function widths(list)
  return vim.tbl_map(vim.api.nvim_win_get_width, list)
end

local windows = H.vertical(2)
local left, right = windows[1], windows[2]
splits.setup({ mux = false, amount = 3 })

set_left_width(left, 20)
vim.api.nvim_set_current_win(left)
H.truthy(splits.resize({ direction = 'right' }), 'right boundary from left focus is handled')
H.equal(vim.api.nvim_win_get_width(left), 23, 'right moves the shared separator right from left focus')

set_left_width(left, 20)
vim.api.nvim_set_current_win(right)
H.truthy(splits.resize({ direction = 'right' }), 'right boundary from right focus is handled')
H.equal(vim.api.nvim_win_get_width(left), 23, 'right moves the same separator from right focus')

vim.api.nvim_set_current_win(left)
H.truthy(splits.resize({ direction = 'left', amount = 6 }), 'custom amount is handled')
H.equal(vim.api.nvim_win_get_width(left), 17, 'left moves the separator left with the requested amount')

-- 三个列：中间窗口在两个方向都拥有其右边界，
-- 所以左和右是反向操作，与 tmux `resize-pane -L/-R` 匹配
windows = H.vertical(3)
left, right = windows[1], windows[3]
local middle = windows[2]
vim.api.nvim_win_set_width(left, 18)
vim.api.nvim_win_set_width(middle, 24)
local before = widths(windows)
vim.api.nvim_set_current_win(middle)
H.truthy(splits.resize({ direction = 'right', amount = 3 }), 'middle right is handled')
H.equal(widths(windows), { before[1], before[2] + 3, before[3] - 3 },
  'right from the middle column grows it against the right column only')
H.truthy(splits.resize({ direction = 'left', amount = 3 }), 'middle left is handled')
H.equal(widths(windows), before, 'left from the middle column undoes right')
H.truthy(splits.resize({ direction = 'left', amount = 3 }), 'middle left again is handled')
H.equal(widths(windows), { before[1], before[2] - 3, before[3] + 3 },
  'left from the middle column moves its right boundary left, not its left boundary')
vim.api.nvim_set_current_win(right)
H.truthy(splits.resize({ direction = 'left', amount = 3 }), 'rightmost left is handled')
H.equal(widths(windows), { before[1], before[2] - 6, before[3] + 6 },
  'the last column moves its left boundary instead')

windows = H.horizontal(2)
local top, bottom = windows[1], windows[2]
vim.wo[top].winfixheight = false
vim.api.nvim_win_set_height(top, 8)
vim.wo[top].winfixheight = true
vim.api.nvim_set_current_win(bottom)
H.truthy(splits.resize({ direction = 'down', amount = 2 }), 'down from bottom focus is handled')
H.equal(vim.api.nvim_win_get_height(top), 10, 'down moves the shared statusline from bottom focus')
vim.api.nvim_set_current_win(top)
H.truthy(splits.resize({ direction = 'up', amount = 2 }), 'up from top focus is handled')
H.equal(vim.api.nvim_win_get_height(top), 8, 'up from top focus moves the same statusline back')

-- 无法移动的边界报告 false，而不是假装成功
windows = H.vertical(2)
left, right = windows[1], windows[2]
vim.o.winminwidth = 10
vim.api.nvim_win_set_width(right, 10)
vim.api.nvim_set_current_win(left)
local blocked_before = widths(windows)
H.equal(splits.resize({ direction = 'right' }), false, 'resize blocked by winminwidth returns false')
H.equal(widths(windows), blocked_before, 'blocked resize leaves the layout untouched')
vim.o.winminwidth = 1

windows = H.vertical(3)
local source, bar, target = windows[1], windows[2], windows[3]
vim.api.nvim_set_current_win(source)
local guard_calls = 0
local baseline
splits.setup({
  mux = false,
  amount = 3,
  with_resize = function(action)
    guard_calls = guard_calls + 1
    vim.api.nvim_win_close(bar, true)
    baseline = vim.api.nvim_win_get_width(source)
    return action()
  end,
})
splits.resize({ direction = 'right' })
H.equal(guard_calls, 1, 'resize guard runs exactly once')
H.equal(vim.api.nvim_win_get_width(source), baseline + 3, 'origin and boundary resolve after the guard changes layout')
H.equal(vim.api.nvim_get_current_win(), source, 'resize guard preserves the action owner')
H.truthy(vim.api.nvim_win_is_valid(target), 'resize keeps the logical target window')

-- 从浮窗缩放作用于前一个 split 而不窃取焦点
windows = H.vertical(2)
left, right = windows[1], windows[2]
vim.api.nvim_set_current_win(left)
local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
  relative = 'editor', row = 2, col = 2, width = 20, height = 4,
})
splits.setup({ mux = false, amount = 3, float_behavior = 'previous' })
local left_before = vim.api.nvim_win_get_width(left)
H.truthy(splits.resize({ direction = 'right' }), 'float resize continues from the previous split')
H.equal(vim.api.nvim_win_get_width(left), left_before + 3, 'float resize moves the previous split boundary')
H.equal(vim.api.nvim_get_current_win(), float, 'float resize keeps the float focused')

H.reset()
local mux_resizes = 0
splits.setup({
  mux = {
    move = function() return false end,
    resize = function(direction, amount)
      mux_resizes = mux_resizes + 1
      return direction == 'right' and amount == 3
    end,
  },
})
H.truthy(splits.resize({ direction = 'right' }), 'single-window resize falls back to mux')
H.equal(mux_resizes, 1, 'mux resize is called exactly once without a local separator')

windows = H.vertical(2)
vim.api.nvim_set_current_win(windows[1])
splits.resize({ direction = 'right' })
H.equal(mux_resizes, 1, 'a local separator prevents mux fallback')

splits.setup({ mux = false })
