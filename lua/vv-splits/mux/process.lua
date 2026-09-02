-- 内置 mux 适配器共享的免 shell 进程执行

local M = {}

---@param command string[]
---@return boolean, string, string
function M.run(command)
  local ok, process = pcall(vim.system, command, { text = true })
  if not ok then return false, '', tostring(process) end

  local result = process:wait()
  return result.code == 0, vim.trim(result.stdout or ''), vim.trim(result.stderr or '')
end

return M
