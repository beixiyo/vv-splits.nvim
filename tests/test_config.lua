-- 收集阶段只注册场景；每个场景由独立子进程执行。
local T, child = dofile('tests/child.lua').new_set()

T['配置副本、非法输入拒绝与适配器切换生命周期'] = function()
  child.lua_func(function()
    -- 公共配置和 mux 生命周期约定

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')
    local splits = require('vv-splits')

    splits.setup({ mux = false })
    local defaults = splits.get_config()
    H.equal(defaults.amount, 3, '默认缩放步长')
    H.equal(defaults.float_behavior, 'previous', '默认浮窗策略')

    defaults.amount = 99
    H.equal(splits.get_config().amount, 3, '配置读取返回独立副本')

    local attached = 0
    local detached = 0
    local adapter = {
      attach = function() attached = attached + 1 end,
      detach = function() detached = detached + 1 end,
      move = function() return false end,
      resize = function() return false end,
    }

    splits.setup({ mux = adapter })
    H.equal(attached, 1, '自定义适配器只挂载一次')
    splits.setup({ mux = false })
    H.equal(detached, 1, '重新配置卸载前一适配器')

    H.truthy(not pcall(splits.setup, { amount = 0 }), '零步长必须被拒绝')
    H.truthy(not pcall(splits.setup, { mux = 'unknown' }), '未知适配器必须被拒绝')
    H.truthy(not pcall(splits.move, { direction = 'diagonal' }), '未知方向必须被拒绝')

    splits.setup({ mux = false })
  end)
end

return T
