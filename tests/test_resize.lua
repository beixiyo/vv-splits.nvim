-- 收集阶段只注册场景；每个场景由独立子进程执行。
local T, child = dofile('tests/child.lua').new_set()

T['双列两侧焦点移动同一分隔线并支持指定步长'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
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
    H.truthy(splits.resize({ direction = 'right' }), '左侧焦点向右移动边界已处理')
    H.equal(vim.api.nvim_win_get_width(left), 23, '左侧焦点向右移动共享分隔线')

    set_left_width(left, 20)
    vim.api.nvim_set_current_win(right)
    H.truthy(splits.resize({ direction = 'right' }), '右侧焦点向右移动边界已处理')
    H.equal(vim.api.nvim_win_get_width(left), 23, '右侧焦点移动同一分隔线')

    vim.api.nvim_set_current_win(left)
    H.truthy(splits.resize({ direction = 'left', amount = 6 }), '指定步长的缩放已处理')
    H.equal(vim.api.nvim_win_get_width(left), 17, '向左按指定步长移动分隔线')

  end)
end

T['中间列拥有右边界，最右列使用左边界且方向互逆'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local function set_left_width(win, width)
      vim.wo[win].winfixwidth = false
      vim.api.nvim_win_set_width(win, width)
      vim.wo[win].winfixwidth = true
    end

    local function widths(list)
      return vim.tbl_map(vim.api.nvim_win_get_width, list)
    end

    local windows, left, right
    splits.setup({ mux = false, amount = 3 })
    -- 三个列：中间窗口在两个方向都拥有其右边界，
    -- 所以左和右是反向操作，与 tmux `resize-pane -L/-R` 匹配
    windows = H.vertical(3)
    left, right = windows[1], windows[3]
    local middle = windows[2]
    vim.api.nvim_win_set_width(left, 18)
    vim.api.nvim_win_set_width(middle, 24)
    local before = widths(windows)
    vim.api.nvim_set_current_win(middle)
    H.truthy(splits.resize({ direction = 'right', amount = 3 }), '中列向右缩放已处理')
    H.equal(widths(windows), { before[1], before[2] + 3, before[3] - 3 },
      '中列向右缩放只从右列获取宽度')
    H.truthy(splits.resize({ direction = 'left', amount = 3 }), '中列向左缩放已处理')
    H.equal(widths(windows), before, '中列向左撤销向右缩放')
    H.truthy(splits.resize({ direction = 'left', amount = 3 }), '中列再次向左缩放已处理')
    H.equal(widths(windows), { before[1], before[2] - 3, before[3] + 3 },
      '中列向左缩放移动其右边界，不移动左边界')
    vim.api.nvim_set_current_win(right)
    H.truthy(splits.resize({ direction = 'left', amount = 3 }), '最右列向左缩放已处理')
    H.equal(widths(windows), { before[1], before[2] - 6, before[3] + 6 },
      '最后一列改为移动左边界')

  end)
end

T['上下窗口共享状态线且上下移动互逆'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local function set_left_width(win, width)
      vim.wo[win].winfixwidth = false
      vim.api.nvim_win_set_width(win, width)
      vim.wo[win].winfixwidth = true
    end

    local function widths(list)
      return vim.tbl_map(vim.api.nvim_win_get_width, list)
    end

    local windows, left, right
    splits.setup({ mux = false, amount = 3 })
    windows = H.horizontal(2)
    local top, bottom = windows[1], windows[2]
    vim.wo[top].winfixheight = false
    vim.api.nvim_win_set_height(top, 8)
    vim.wo[top].winfixheight = true
    vim.api.nvim_set_current_win(bottom)
    H.truthy(splits.resize({ direction = 'down', amount = 2 }), '下窗焦点向下缩放已处理')
    H.equal(vim.api.nvim_win_get_height(top), 10, '下窗焦点向下移动共享状态线')
    vim.api.nvim_set_current_win(top)
    H.truthy(splits.resize({ direction = 'up', amount = 2 }), '上窗焦点向上缩放已处理')
    H.equal(vim.api.nvim_win_get_height(top), 8, '上窗焦点向上恢复同一状态线')

  end)
end

T['最小宽度阻止移动且不改变布局'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local function set_left_width(win, width)
      vim.wo[win].winfixwidth = false
      vim.api.nvim_win_set_width(win, width)
      vim.wo[win].winfixwidth = true
    end

    local function widths(list)
      return vim.tbl_map(vim.api.nvim_win_get_width, list)
    end

    local windows, left, right
    splits.setup({ mux = false, amount = 3 })
    -- 无法移动的边界报告 false，而不是假装成功
    windows = H.vertical(2)
    left, right = windows[1], windows[2]
    vim.o.winminwidth = 10
    vim.api.nvim_win_set_width(right, 10)
    vim.api.nvim_set_current_win(left)
    local blocked_before = widths(windows)
    H.equal(splits.resize({ direction = 'right' }), false, '最小宽度阻止缩放时返回失败')
    H.equal(widths(windows), blocked_before, '被阻止的缩放不改变布局')
    vim.o.winminwidth = 1

  end)
end

T['布局事务先改变窗口，随后解析动作边界并保留焦点'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local function set_left_width(win, width)
      vim.wo[win].winfixwidth = false
      vim.api.nvim_win_set_width(win, width)
      vim.wo[win].winfixwidth = true
    end

    local function widths(list)
      return vim.tbl_map(vim.api.nvim_win_get_width, list)
    end

    local windows, left, right
    splits.setup({ mux = false, amount = 3 })
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
    H.equal(guard_calls, 1, '布局事务只执行一次')
    H.equal(vim.api.nvim_win_get_width(source), baseline + 3, '布局事务改变布局后才解析起点与边界')
    H.equal(vim.api.nvim_get_current_win(), source, '布局事务保留动作所属窗口')
    H.truthy(vim.api.nvim_win_is_valid(target), '缩放保留逻辑目标窗口')

  end)
end

T['浮窗缩放以前窗为起点但不窃取焦点'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local function set_left_width(win, width)
      vim.wo[win].winfixwidth = false
      vim.api.nvim_win_set_width(win, width)
      vim.wo[win].winfixwidth = true
    end

    local function widths(list)
      return vim.tbl_map(vim.api.nvim_win_get_width, list)
    end

    local windows, left, right
    splits.setup({ mux = false, amount = 3 })
    -- 从浮窗缩放作用于前一个 split 而不窃取焦点
    windows = H.vertical(2)
    left, right = windows[1], windows[2]
    vim.api.nvim_set_current_win(left)
    local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
      relative = 'editor', row = 2, col = 2, width = 20, height = 4,
    })
    splits.setup({ mux = false, amount = 3, float_behavior = 'previous' })
    local left_before = vim.api.nvim_win_get_width(left)
    H.truthy(splits.resize({ direction = 'right' }), '浮窗缩放以前窗为起点')
    H.equal(vim.api.nvim_win_get_width(left), left_before + 3, '浮窗缩放移动前窗边界')
    H.equal(vim.api.nvim_get_current_win(), float, '浮窗缩放保留浮窗焦点')

  end)
end

T['没有本地边界才允许适配器缩放回退'] = function()
  child.lua_func(function()
    -- 来自两个焦点侧的原生边界移动、固定窗口、守卫和 mux fallback

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    local function set_left_width(win, width)
      vim.wo[win].winfixwidth = false
      vim.api.nvim_win_set_width(win, width)
      vim.wo[win].winfixwidth = true
    end

    local function widths(list)
      return vim.tbl_map(vim.api.nvim_win_get_width, list)
    end

    local windows, left, right
    splits.setup({ mux = false, amount = 3 })
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
    H.truthy(splits.resize({ direction = 'right' }), '单窗口缩放回退至外层')
    H.equal(mux_resizes, 1, '无本地边界时只调用外层缩放一次')

    windows = H.vertical(2)
    vim.api.nvim_set_current_win(windows[1])
    splits.resize({ direction = 'right' })
    H.equal(mux_resizes, 1, '有本地分隔线时不允许外层回退')

    splits.setup({ mux = false })
  end)
end

return T
