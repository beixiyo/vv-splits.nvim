-- 收集阶段只注册场景；每个场景由独立子进程执行。
local T, child = dofile('tests/child.lua').new_set()

T['终端适配器命令携带所属窗格与步长'] = function()
  child.lua_func(function()
    -- 内置适配器命令执行、生命周期和真实隔离 tmux 行为

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')

    local wezterm_commands = {}
    local wezterm = require('vv-splits.mux.wezterm').new({
      env = { WEZTERM_PANE = '17' },
      run = function(command)
        wezterm_commands[#wezterm_commands + 1] = command
        return true, '', ''
      end,
    })
    H.truthy(wezterm.move('left'), 'WezTerm 接管导航命令')
    H.truthy(wezterm.resize('down', 3), 'WezTerm 接管缩放命令')
    H.equal(wezterm_commands[1], {
      'wezterm', 'cli', 'activate-pane-direction', '--pane-id', '17', 'Left',
    }, 'WezTerm 导航精确定位所属窗格')
    H.equal(wezterm_commands[2], {
      'wezterm', 'cli', 'adjust-pane-size', '--pane-id', '17', '--amount', '3', 'Down',
    }, 'WezTerm 缩放透传所属窗格与步长')

  end)
end

T['终端标记幂等处理挂起恢复与退出，嵌套进程不碰外层标记'] = function()
  child.lua_func(function()
    -- 内置适配器命令执行、生命周期和真实隔离 tmux 行为

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')

    local kitty_commands = {}
    local kitty_writes = {}
    local kitty = require('vv-splits.mux.kitty').new({
      env = { KITTY_LISTEN_ON = 'unix:/tmp/test-kitty', KITTY_WINDOW_ID = '42' },
      script = '/tmp/vv_splits.py',
      write = function(value)
        kitty_writes[#kitty_writes + 1] = value
        return true
      end,
      run = function(command)
        kitty_commands[#kitty_commands + 1] = command
        return true, '', ''
      end,
    })
    local SET = '\27]1337;SetUserVar=IS_NVIM=MQ==\7'
    local CLEAR = '\27]1337;SetUserVar=IS_NVIM\7'

    kitty.attach()
    kitty.attach()
    H.truthy(kitty.move('up'), 'Kitty 接管导航命令')
    H.truthy(kitty.resize('right', 3), 'Kitty 接管缩放命令')
    -- `kitten <file>.py` 只在子进程中运行 main()；handle_result 需要 `@ kitten`
    H.equal(kitty_commands[1], { 'kitten', '@', 'kitten', '--match', 'id:42', '/tmp/vv_splits.py', 'move', 'up', '42' },
      'Kitty 内执行随仓分发的脚本并精确定位窗口')
    H.equal(kitty_commands[2], { 'kitten', '@', 'kitten', '--match', 'id:42', '/tmp/vv_splits.py', 'resize', 'right', '3', '42' },
      'Kitty 内执行脚本并透传步长与准确窗口')

    -- Suspend 移除标记以便 shell 拥有按键；resume 重新激活
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    vim.api.nvim_exec_autocmds('VimResume', {})
    kitty.detach()
    kitty.detach()
    vim.api.nvim_exec_autocmds('VimSuspend', {})
    vim.api.nvim_exec_autocmds('VimResume', {})
    H.equal(kitty_writes, { SET, CLEAR, SET, CLEAR },
      'Kitty 挂载、挂起、恢复与卸载各写一次标记，卸载后不再写入')

    local nested_writes = 0
    local nested_kitty = require('vv-splits.mux.kitty').new({
      env = { KITTY_LISTEN_ON = 'x', KITTY_WINDOW_ID = '1', NVIM = 'parent' },
      script = '/tmp/vv_splits.py',
      write = function() nested_writes = nested_writes + 1 end,
    })
    nested_kitty.attach()
    nested_kitty.detach()
    H.equal(nested_writes, 0, '嵌套 Neovim 不清除外层 Kitty 标记')

  end)
end

T['复用器套接字路径保留内嵌逗号'] = function()
  child.lua_func(function()
    -- 内置适配器命令执行、生命周期和真实隔离 tmux 行为

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')

    local tmux_commands = {}
    local comma_tmux = require('vv-splits.mux.tmux').new({
      env = { TMUX = '/tmp/dir,with,commas/default,123,0', TMUX_PANE = '%3' },
      run = function(command)
        tmux_commands[#tmux_commands + 1] = command
        return true, '0', ''
      end,
    })
    comma_tmux.resize('right', 2)
    H.equal(tmux_commands[#tmux_commands], { 'tmux', '-S', '/tmp/dir,with,commas/default', 'resize-pane', '-t', '%3', '-R', '2' },
      '套接字路径保留内嵌逗号')

  end)
end

T['真实隔离复用器导航、缩放方向与放大窗格边界'] = function()
  child.lua_func(function()
    -- 内置适配器命令执行、生命周期和真实隔离 tmux 行为

    local H = dofile(vim.env.VV_TEST_REPO .. '/tests/helpers.lua')

    assert(vim.fn.executable('tmux') == 1, '真实跨窗格测试需要已安装 tmux')
    do
      local socket_path = vim.env.VV_TEST_TMP .. '/tmux.sock'
      vim.env.VV_TEST_TMUX_SOCKET = socket_path
      local base = { 'tmux', '-S', socket_path, '-f', '/dev/null' }

      local function tmux_run(args)
        local command = vim.deepcopy(base)
        vim.list_extend(command, args)
        local result = vim.system(command, { text = true }):wait()
        assert(result.code == 0, ('复用器命令失败：%s\n%s'):format(table.concat(command, ' '), result.stderr or ''))
        return vim.trim(result.stdout or '')
      end

      local function width_of(pane)
        return tonumber(tmux_run({ 'display-message', '-p', '-t', pane, '#{pane_width}' }))
      end

      local ok, err = xpcall(function()
        tmux_run({ 'new-session', '-d', '-s', 'vv-splits', '-x', '100', '-y', '30', '/bin/sleep', '60' })
        tmux_run({ 'split-window', '-h', '-t', 'vv-splits:0', '/bin/sleep', '60' })
        local panes = vim.split(tmux_run({ 'list-panes', '-t', 'vv-splits:0', '-F', '#{pane_id}' }), '\n', { trimempty = true })
        local first, second = panes[1], panes[2]
        local socket = tmux_run({ 'display-message', '-p', '#{socket_path}' })

        local adapter = require('vv-splits.mux.tmux').new({
          env = { TMUX = socket .. ',0,0', TMUX_PANE = first },
        })

        tmux_run({ 'select-pane', '-t', first })
        H.truthy(adapter.move('right'), '真实复用器导航成功')
        H.equal(tmux_run({ 'display-message', '-p', '-t', second, '#{pane_active}' }), '1',
          '真实复用器导航选中精确的相邻窗格')

        tmux_run({ 'select-pane', '-t', first })
        local width_before = width_of(first)
        H.truthy(adapter.resize('right', 3), '真实复用器缩放成功')
        H.equal(width_of(first), width_before + 3, '真实复用器缩放按配置步长改变目标窗格')

        local right_adapter = require('vv-splits.mux.tmux').new({
          env = { TMUX = socket .. ',0,0', TMUX_PANE = second },
        })
        local right_before = width_of(second)
        H.truthy(right_adapter.resize('right', 3), '对侧焦点的真实复用器缩放成功')
        H.equal(width_of(second), right_before - 3, '对侧焦点向右仍右移同一分隔线')

        -- 三个窗格：中间窗格拥有其右边界，与 Neovim 规则匹配
        tmux_run({ 'split-window', '-h', '-t', second, '/bin/sleep', '60' })
        tmux_run({ 'select-layout', '-t', 'vv-splits:0', 'even-horizontal' })
        panes = vim.split(tmux_run({ 'list-panes', '-t', 'vv-splits:0', '-F', '#{pane_id}' }), '\n', { trimempty = true })
        local left, middle, right = panes[1], panes[2], panes[3]
        local middle_adapter = require('vv-splits.mux.tmux').new({
          env = { TMUX = socket .. ',0,0', TMUX_PANE = middle },
        })
        local sizes = { width_of(left), width_of(middle), width_of(right) }
        H.truthy(middle_adapter.resize('left', 3), '真实复用器中窗格向左缩放成功')
        H.equal({ width_of(left), width_of(middle), width_of(right) }, { sizes[1], sizes[2] - 3, sizes[3] + 3 },
          '复用器中窗格向左移动右边界')
        H.truthy(middle_adapter.resize('right', 3), '真实复用器中窗格向右缩放成功')
        H.equal({ width_of(left), width_of(middle), width_of(right) }, sizes,
          '复用器中窗格向右撤销向左操作')

        tmux_run({ 'resize-pane', '-Z', '-t', first })
        H.equal(adapter.move('right'), false, '放大的复用器窗格阻止跨窗格导航')
      end, debug.traceback)

      pcall(tmux_run, { 'kill-server' })
      if not ok then error(err) end
    end
  end)
end

return T
