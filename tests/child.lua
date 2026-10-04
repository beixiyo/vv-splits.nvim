-- 每个具名用例拥有独立子进程与 /tmp 根目录；失败也由父进程兜底清理
local M = {}
local Processes = dofile(assert(vim.env.VV_UTILS) .. '/dev/test/process.lua')

function M.new_set()
  local MiniTest = require('mini.test')
  local child = MiniTest.new_child_neovim()
  local root, pid
  local T = MiniTest.new_set({ hooks = {
    pre_case = function()
      pid = nil
      assert(type(vim.env.VV_TEST_REPO) == 'string' and vim.env.VV_TEST_REPO ~= '', '被测仓库路径不能为空')
      assert(type(vim.env.VV_UTILS) == 'string' and vim.env.VV_UTILS ~= '', '共享工具路径不能为空')
      root = assert(vim.uv.fs_mkdtemp('/tmp/vv-splits-test-XXXXXX'))
      local environment = {
        HOME = root .. '/home', TMPDIR = root .. '/tmp', VV_TEST_TMP = root,
        XDG_CONFIG_HOME = root .. '/config', XDG_DATA_HOME = root .. '/data',
        XDG_STATE_HOME = root .. '/state', XDG_CACHE_HOME = root .. '/cache',
      }
      local previous = {}
      for key, value in pairs(environment) do
        assert(type(value) == 'string' and value ~= '', '隔离环境路径不能为空：' .. key)
        vim.fn.mkdir(value, 'p')
        previous[key], vim.env[key] = vim.env[key], value
      end
      -- 启动前注入环境与 cwd；父进程在连接成功或失败时都恢复原环境
      local tempname = vim.fn.tempname
      vim.fn.tempname = function() return root .. '/child.sock' end
      local started, start_err = pcall(child.start, {
        '-u', 'NONE', '-i', 'NONE', '-n', '--cmd', 'cd ' .. vim.fn.fnameescape(root),
      }, { nvim_executable = vim.v.progpath })
      vim.fn.tempname = tempname
      for key in pairs(environment) do vim.env[key] = previous[key] end
      if child.job then pid = vim.fn.jobpid(child.job.id) end
      assert(started, '启动隔离子进程失败：' .. tostring(start_err))
      child.lua([[
        local root = assert(vim.env.VV_TEST_TMP, '临时根目录不能为空')
        assert(root ~= '' and vim.fn.isdirectory(root) == 1, '临时根目录必须存在')
        assert(vim.uv.fs_realpath(vim.fn.getcwd()) == vim.uv.fs_realpath(root), '子进程 cwd 必须在本场景 fixture')
        for _, key in ipairs({ 'HOME', 'TMPDIR', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME' }) do
          local path = vim.env[key]
          assert(type(path) == 'string' and path:sub(1, #root + 1) == root .. '/', '环境路径未隔离：' .. key)
        end
        for _, kind in ipairs({ 'config', 'data', 'state', 'cache' }) do
          assert(vim.fn.stdpath(kind):sub(1, #root + 1) == root .. '/', '持久目录未隔离：' .. kind)
        end
        assert(type(vim.env.VV_TEST_REPO) == 'string' and vim.env.VV_TEST_REPO ~= '', '被测仓库路径不能为空')
        assert(type(vim.env.VV_UTILS) == 'string' and vim.env.VV_UTILS ~= '', '共享工具路径不能为空')
        assert(vim.fn.isdirectory(vim.env.VV_TEST_REPO) == 1, '被测仓库路径必须存在')
        assert(vim.fn.isdirectory(vim.env.VV_UTILS) == 1, '共享工具路径必须存在')
        vim.opt.runtimepath:prepend(vim.env.VV_TEST_REPO)
        vim.opt.runtimepath:prepend(vim.env.VV_UTILS)
        vim.env.GIT_CONFIG_GLOBAL, vim.env.GIT_CONFIG_SYSTEM = '/dev/null', '/dev/null'
        vim.env.GIT_INDEX_FILE, vim.env.GIT_DIR, vim.env.GIT_WORK_TREE = nil, nil, nil
        vim.env.GIT_CONFIG_COUNT = nil
        local counter = 0
        vim.fn.tempname = function()
          counter = counter + 1
          return vim.env.VV_TEST_TMP .. '/fixture-' .. counter
        end
        async_errors, allowed_errors = {}, {}
        local schedule = vim.schedule
        vim.schedule = function(callback)
          schedule(function()
            local ok, err = xpcall(callback, debug.traceback)
            if not ok then async_errors[#async_errors + 1] = tostring(err) end
          end)
        end
        vim.v.errmsg = ''
      ]])
    end,
    post_case = function()
      -- 取证失败不能绕过进程停止与目录删除；不调用可能已被测试替换的生产接口
      local ok, err = pcall(function()
        local errors = child.lua_get([[(function()
          local errors = vim.deepcopy(async_errors)
          if vim.v.errmsg ~= '' then errors[#errors + 1] = vim.v.errmsg end
          local unexpected = {}
          for _, message in ipairs(errors) do
            local allowed = false
            for _, expected in ipairs(allowed_errors) do
              if message:gsub('[\r\n]+$', '') == expected then allowed = true end
            end
            if not allowed then unexpected[#unexpected + 1] = message end
          end
          return unexpected
        end)()]])
        assert(#errors == 0, '子进程出现未预期的异步错误：' .. vim.inspect(errors))
      end)
      local descendants_ok, descendants_err = pcall(Processes.stop_descendants, pid)
      local stopped, stop_err = pcall(child.stop)
      pid = nil
      local tmux_ok, tmux_err = true, nil
      if root and vim.fn.executable('tmux') == 1 then
        tmux_ok, tmux_err = pcall(function()
          vim.system({ 'tmux', '-S', root .. '/tmux.sock', 'kill-server' }, { text = true }):wait()
        end)
      end
      local cleaned = not root or vim.fn.delete(root, 'rf') == 0
      root = nil
      assert(cleaned, '清理场景 fixture 失败')
      assert(tmux_ok, '清理隔离复用器失败：' .. tostring(tmux_err))
      assert(stopped, '停止子进程失败：' .. tostring(stop_err))
      assert(descendants_ok, '清理子进程后代失败：' .. tostring(descendants_err))
      assert(ok, err)
    end,
  } })
  return T, child
end

return M
