-- Kitty 适配器和 IS_NVIM 生命周期；窗格几何信息保存在捆绑的 kitten 中

local process = require('vv-splits.mux.process')

local M = {}

local SET_NVIM = '\27]1337;SetUserVar=IS_NVIM=MQ==\7'
local CLEAR_NVIM = '\27]1337;SetUserVar=IS_NVIM\7'
local lifecycle_group = 'VVSplitsKittyLifecycle'

---通过附加的 UI 发送原始转义序列
---没有 UI 时无法标记 Kitty 窗口，不会写入任何内容
---@param value string
---@return boolean sent
local function send_to_ui(value)
  if #vim.api.nvim_list_uis() == 0 then return false end
  vim.api.nvim_ui_send(value)
  return true
end

---@param opts? { env?: table, run?: fun(command: string[]): boolean, string, string, write?: fun(value: string): boolean?, script?: string }
---@return VVSplitsMuxAdapter
function M.new(opts)
  opts = opts or {}
  local env = opts.env or vim.env
  local run = opts.run or process.run
  local write = opts.write or send_to_ui
  local script = opts.script
    or vim.api.nvim_get_runtime_file('kitty/vv_splits.py', false)[1]
  local nested = type(env.NVIM) == 'string' and env.NVIM ~= ''
  -- 期望的标记状态，不是"写入一次"：suspend/resume 会从它重新派生
  local attached = false

  local function window_id()
    if type(env.KITTY_LISTEN_ON) ~= 'string' or env.KITTY_LISTEN_ON == '' then return nil end
    if type(env.KITTY_WINDOW_ID) ~= 'string' or env.KITTY_WINDOW_ID == '' then return nil end
    if type(script) ~= 'string' or script == '' then return nil end
    return env.KITTY_WINDOW_ID
  end

  -- `kitten <file>.py` 只在子进程中运行 kitten 的 main()；
  -- `handle_result` hook 需要 `@ kitten`，它在 kitty 内部执行
  local function execute(args)
    local id = window_id()
    if not id then return false end
    local command = { 'kitten', '@', 'kitten', '--match', 'id:' .. id, script }
    vim.list_extend(command, args)
    command[#command + 1] = id
    local ok = run(command)
    return ok
  end

  local function mark()
    if not attached then return false end
    return write(SET_NVIM) == true
  end

  local function unmark()
    write(CLEAR_NVIM)
  end

  local function clear_lifecycle()
    pcall(vim.api.nvim_del_augroup_by_name, lifecycle_group)
  end

  return {
    attach = function()
      if nested or attached or not window_id() then return end
      attached = true

      local group = vim.api.nvim_create_augroup(lifecycle_group, { clear = true })
      vim.api.nvim_create_autocmd('VimSuspend', { group = group, callback = unmark })
      vim.api.nvim_create_autocmd('VimResume', { group = group, callback = mark })
      if not mark() then
        -- 还没有 UI（或写入器无法投递）：在 UI 附加后标记
        vim.api.nvim_create_autocmd('UIEnter', { group = group, once = true, callback = mark })
      end
    end,

    detach = function()
      if nested or not attached then return end
      attached = false
      clear_lifecycle()
      unmark()
    end,

    move = function(target_direction)
      return execute({ 'move', target_direction })
    end,

    resize = function(target_direction, amount)
      return execute({ 'resize', target_direction, tostring(amount) })
    end,
  }
end

return M
