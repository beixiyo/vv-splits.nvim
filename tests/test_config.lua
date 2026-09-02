-- 公共配置和 mux 生命周期约定

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h') .. '/helpers.lua')
local splits = require('vv-splits')

splits.setup({ mux = false })
local defaults = splits.get_config()
H.equal(defaults.amount, 3, 'default resize amount')
H.equal(defaults.float_behavior, 'previous', 'default float behavior')

defaults.amount = 99
H.equal(splits.get_config().amount, 3, 'get_config returns a copy')

local attached = 0
local detached = 0
local adapter = {
  attach = function() attached = attached + 1 end,
  detach = function() detached = detached + 1 end,
  move = function() return false end,
  resize = function() return false end,
}

splits.setup({ mux = adapter })
H.equal(attached, 1, 'custom mux attaches once')
splits.setup({ mux = false })
H.equal(detached, 1, 'reconfiguring detaches the previous mux')

H.truthy(not pcall(splits.setup, { amount = 0 }), 'zero amount must be rejected')
H.truthy(not pcall(splits.setup, { mux = 'unknown' }), 'unknown mux must be rejected')
H.truthy(not pcall(splits.move, { direction = 'diagonal' }), 'unknown direction must be rejected')

splits.setup({ mux = false })
