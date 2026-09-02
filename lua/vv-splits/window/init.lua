-- 窗口接口：操作模块唯一的导入入口

local neighbor = require('vv-splits.window.neighbor')
local origin = require('vv-splits.window.origin')

return {
  logical_neighbor = neighbor.logical,
  physical_neighbor = neighbor.physical,
  resolve_origin = origin.resolve,
}
