-- 内置适配器命令执行、生命周期和真实隔离 tmux 行为

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h') .. '/helpers.lua')

local wezterm_commands = {}
local wezterm = require('vv-splits.mux.wezterm').new({
  env = { WEZTERM_PANE = '17' },
  run = function(command)
    wezterm_commands[#wezterm_commands + 1] = command
    return true, '', ''
  end,
})
H.truthy(wezterm.move('left'), 'WezTerm move command is handled')
H.truthy(wezterm.resize('down', 3), 'WezTerm resize command is handled')
H.equal(wezterm_commands[1], {
  'wezterm', 'cli', 'activate-pane-direction', '--pane-id', '17', 'Left',
}, 'WezTerm move targets the owning pane')
H.equal(wezterm_commands[2], {
  'wezterm', 'cli', 'adjust-pane-size', '--pane-id', '17', '--amount', '3', 'Down',
}, 'WezTerm resize targets the owning pane and amount')

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
H.truthy(kitty.move('up'), 'Kitty move command is handled')
H.truthy(kitty.resize('right', 3), 'Kitty resize command is handled')
-- `kitten <file>.py` 只在子进程中运行 main()；handle_result 需要 `@ kitten`
H.equal(kitty_commands[1], { 'kitten', '@', 'kitten', '--match', 'id:42', '/tmp/vv_splits.py', 'move', 'up', '42' },
  'Kitty move runs the bundled kitten inside kitty against the exact window ID')
H.equal(kitty_commands[2], { 'kitten', '@', 'kitten', '--match', 'id:42', '/tmp/vv_splits.py', 'resize', 'right', '3', '42' },
  'Kitty resize runs the bundled kitten inside kitty with amount and exact window ID')

-- Suspend 移除标记以便 shell 拥有按键；resume 重新激活
vim.api.nvim_exec_autocmds('VimSuspend', {})
vim.api.nvim_exec_autocmds('VimResume', {})
kitty.detach()
kitty.detach()
vim.api.nvim_exec_autocmds('VimSuspend', {})
vim.api.nvim_exec_autocmds('VimResume', {})
H.equal(kitty_writes, { SET, CLEAR, SET, CLEAR },
  'Kitty lifecycle writes attach, suspend, resume, detach markers exactly once each and nothing after detach')

local nested_writes = 0
local nested_kitty = require('vv-splits.mux.kitty').new({
  env = { KITTY_LISTEN_ON = 'x', KITTY_WINDOW_ID = '1', NVIM = 'parent' },
  script = '/tmp/vv_splits.py',
  write = function() nested_writes = nested_writes + 1 end,
})
nested_kitty.attach()
nested_kitty.detach()
H.equal(nested_writes, 0, 'nested Neovim does not clear the outer Kitty marker')

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
  '$TMUX socket path keeps embedded commas')

if vim.fn.executable('tmux') == 1 then
  local socket_name = 'vv-splits-test-' .. tostring(vim.fn.getpid())
  local base = { 'tmux', '-L', socket_name, '-f', '/dev/null' }

  local function tmux_run(args)
    local command = vim.deepcopy(base)
    vim.list_extend(command, args)
    local result = vim.system(command, { text = true }):wait()
    assert(result.code == 0, ('tmux command failed: %s\n%s'):format(table.concat(command, ' '), result.stderr or ''))
    return vim.trim(result.stdout or '')
  end

  local function width_of(pane)
    return tonumber(tmux_run({ 'display-message', '-p', '-t', pane, '#{pane_width}' }))
  end

  local ok, err = xpcall(function()
    tmux_run({ 'new-session', '-d', '-s', 'vv-splits', '-x', '100', '-y', '30' })
    tmux_run({ 'split-window', '-h', '-t', 'vv-splits:0' })
    local panes = vim.split(tmux_run({ 'list-panes', '-t', 'vv-splits:0', '-F', '#{pane_id}' }), '\n', { trimempty = true })
    local first, second = panes[1], panes[2]
    local socket = tmux_run({ 'display-message', '-p', '#{socket_path}' })

    local adapter = require('vv-splits.mux.tmux').new({
      env = { TMUX = socket .. ',0,0', TMUX_PANE = first },
    })

    tmux_run({ 'select-pane', '-t', first })
    H.truthy(adapter.move('right'), 'real tmux move succeeds')
    H.equal(tmux_run({ 'display-message', '-p', '-t', second, '#{pane_active}' }), '1',
      'real tmux move selects the exact neighboring pane')

    tmux_run({ 'select-pane', '-t', first })
    local width_before = width_of(first)
    H.truthy(adapter.resize('right', 3), 'real tmux resize succeeds')
    H.equal(width_of(first), width_before + 3, 'real tmux resize applies the configured amount to the target pane')

    local right_adapter = require('vv-splits.mux.tmux').new({
      env = { TMUX = socket .. ',0,0', TMUX_PANE = second },
    })
    local right_before = width_of(second)
    H.truthy(right_adapter.resize('right', 3), 'real tmux resize from the opposite focus side succeeds')
    H.equal(width_of(second), right_before - 3, 'right still moves the shared separator right from the opposite side')

    -- 三个窗格：中间窗格拥有其右边界，与 Neovim 规则匹配
    tmux_run({ 'split-window', '-h', '-t', second })
    tmux_run({ 'select-layout', '-t', 'vv-splits:0', 'even-horizontal' })
    panes = vim.split(tmux_run({ 'list-panes', '-t', 'vv-splits:0', '-F', '#{pane_id}' }), '\n', { trimempty = true })
    local left, middle, right = panes[1], panes[2], panes[3]
    local middle_adapter = require('vv-splits.mux.tmux').new({
      env = { TMUX = socket .. ',0,0', TMUX_PANE = middle },
    })
    local sizes = { width_of(left), width_of(middle), width_of(right) }
    H.truthy(middle_adapter.resize('left', 3), 'real tmux resize left from the middle pane succeeds')
    H.equal({ width_of(left), width_of(middle), width_of(right) }, { sizes[1], sizes[2] - 3, sizes[3] + 3 },
      'tmux left from the middle pane moves its right boundary left')
    H.truthy(middle_adapter.resize('right', 3), 'real tmux resize right from the middle pane succeeds')
    H.equal({ width_of(left), width_of(middle), width_of(right) }, sizes,
      'tmux right undoes left from the middle pane')

    tmux_run({ 'resize-pane', '-Z', '-t', first })
    H.equal(adapter.move('right'), false, 'zoomed tmux pane blocks cross-pane navigation')
  end, debug.traceback)

  pcall(tmux_run, { 'kill-server' })
  if not ok then error(err) end
end
