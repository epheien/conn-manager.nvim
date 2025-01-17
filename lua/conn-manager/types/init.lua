local M = {}

---@class ConnectionConfig
---@field type string 'folder'|''
---@field display_name string
---@field description string
---@field computer_name string
---@field port integer
---@field username string
---@field password string
---@field private_key_file? string
M.ConnectionConfig = {}
M.ConnectionConfig.__index = M.ConnectionConfig
function M.ConnectionConfig.new()
  local self = setmetatable({}, M.ConnectionConfig)
  return vim.tbl_extend('force', self, {
    type = '',
    display_name = '',
    description = '',
    computer_name = '',
    port = 22,
    username = '',
    password = '',
    private_key_file = '',
  })
end

return M
