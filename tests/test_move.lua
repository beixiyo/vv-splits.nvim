-- 收集阶段只注册场景；每个场景由独立子进程执行。
local T, child = dofile('tests/child.lua').new_set()

T['透明窗口正反导航只触发最终焦点事件'] = function()
  child.lua_func(function()
    -- 真实 split 导航、忽略窗口跳过、浮窗行为和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
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

    H.truthy(splits.move({ direction = 'right' }), '向右导航已处理')
    H.equal(vim.api.nvim_get_current_win(), right, '被忽略窗口对导航透明')
    H.equal(focus_events, 2, '仅最终焦点切换触发离开与进入事件')

    focus_events = 0
    H.truthy(splits.move({ direction = 'left' }), '向左导航已处理')
    H.equal(vim.api.nvim_get_current_win(), left, '反向导航跳过同一忽略窗口')
    H.equal(focus_events, 2, '反向导航也只改变一次焦点')

    vim.api.nvim_del_augroup_by_id(group)

  end)
end

T['边缘导航交给外层适配器一次'] = function()
  child.lua_func(function()
    -- 真实 split 导航、忽略窗口跳过、浮窗行为和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local left = H.vertical(2)[1]
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
    H.truthy(splits.move({ direction = 'left' }), '边缘导航回退至外层适配器')
    H.equal(mux_moves, 1, '本地边缘只调用外层适配器一次')

  end)
end

T['浮窗以前窗为起点，失败或停止策略保留焦点'] = function()
  child.lua_func(function()
    -- 真实 split 导航、忽略窗口跳过、浮窗行为和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local focus_events, group
    local windows, left, right
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
    H.truthy(splits.move({ direction = 'right' }), '浮窗导航以前窗为起点')
    H.equal(vim.api.nvim_get_current_win(), right, '浮窗前窗策略到达相邻窗口')
    H.equal(focus_events, 2, '浮窗导航直接到目标，不短暂访问前窗')
    H.truthy(vim.api.nvim_win_is_valid(float), '导航不销毁浮窗')
    vim.api.nvim_del_augroup_by_id(group)

    vim.api.nvim_set_current_win(float)
    -- 前一个 split 现在是 `right`，它没有右邻窗
    H.equal(splits.move({ direction = 'right' }), false, '没有目标时不处理浮窗导航')
    H.equal(vim.api.nvim_get_current_win(), float, '未处理的导航保留浮窗焦点')

    vim.api.nvim_set_current_win(float)
    splits.setup({ mux = false, float_behavior = 'stop' })
    H.equal(splits.move({ direction = 'left' }), false, '浮窗停止策略不执行导航')
    H.equal(vim.api.nvim_get_current_win(), float, '停止策略保留浮窗焦点')

    splits.setup({ mux = false })
  end)
end

return T
