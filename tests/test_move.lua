-- 真实 split 导航、忽略窗口跳过、浮窗行为和 mux fallback

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h') .. '/helpers.lua')
local splits = require('vv-splits')

local windows = H.vertical(3)
local left, ignored, right = windows[1], windows[2], windows[3]
vim.w[ignored].vv_splits_skip = true
vim.api.nvim_set_current_win(left)

local focus_events = 0
local group = vim.api.nvim_create_augroup('VVSplitsTestMoveEvents', { clear = true })
vim.api.nvim_create_autocmd({ 'WinEnter', 'WinLeave' }, {
  group = group,
  callback = function() focus_events = focus_events + 1 end,
})

splits.setup({
  mux = false,
  skip_window = function(win) return vim.w[win].vv_splits_skip == true end,
})

H.truthy(splits.move({ direction = 'right' }), 'move right is handled')
H.equal(vim.api.nvim_get_current_win(), right, 'ignored window is transparent')
H.equal(focus_events, 2, 'only the final focus change fires WinLeave and WinEnter')

focus_events = 0
H.truthy(splits.move({ direction = 'left' }), 'move left is handled')
H.equal(vim.api.nvim_get_current_win(), left, 'reverse navigation skips the same ignored window')
H.equal(focus_events, 2, 'reverse navigation also changes focus once')

vim.api.nvim_del_augroup_by_id(group)

local mux_moves = 0
splits.setup({
  mux = {
    move = function(direction)
      mux_moves = mux_moves + 1
      return direction == 'left'
    end,
    resize = function() return false end,
  },
})
vim.api.nvim_set_current_win(left)
H.truthy(splits.move({ direction = 'left' }), 'edge navigation falls back to mux')
H.equal(mux_moves, 1, 'mux is called exactly once at a local edge')

windows = H.vertical(2)
left, right = windows[1], windows[2]
vim.api.nvim_set_current_win(left)
local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
  relative = 'editor', row = 2, col = 2, width = 20, height = 4,
})
splits.setup({ mux = false, float_behavior = 'previous' })
focus_events = 0
group = vim.api.nvim_create_augroup('VVSplitsTestMoveEvents', { clear = true })
vim.api.nvim_create_autocmd({ 'WinEnter', 'WinLeave' }, {
  group = group,
  callback = function() focus_events = focus_events + 1 end,
})
H.truthy(splits.move({ direction = 'right' }), 'float navigation continues from the previous split')
H.equal(vim.api.nvim_get_current_win(), right, 'float previous policy reaches the adjacent split')
H.equal(focus_events, 2, 'float navigation jumps straight to the target without visiting the previous split')
H.truthy(vim.api.nvim_win_is_valid(float), 'navigation does not destroy the float')
vim.api.nvim_del_augroup_by_id(group)

vim.api.nvim_set_current_win(float)
-- 前一个 split 现在是 `right`，它没有右邻窗
H.equal(splits.move({ direction = 'right' }), false, 'float navigation with no target is not handled')
H.equal(vim.api.nvim_get_current_win(), float, 'an unhandled float navigation leaves focus in the float')

vim.api.nvim_set_current_win(float)
splits.setup({ mux = false, float_behavior = 'stop' })
H.equal(splits.move({ direction = 'left' }), false, 'float stop policy leaves navigation untouched')
H.equal(vim.api.nvim_get_current_win(), float, 'float remains focused when policy is stop')

splits.setup({ mux = false })
