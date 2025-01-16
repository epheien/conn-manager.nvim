local M = {}

M.defaults = {
  config_path = 'conn-manager.json',
  window_config = {
    width = 30,
    split = 'left',
    vertical = true,
    win = -1,
  },
  on_window_open = nil,
  on_buffer_create = nil,
  node = {
    on_open = nil,
    icons = {
      arrow_closed = ' ',
      arrow_open = ' ',
      closed_folder = ' ',
      opened_folder = ' ',
      terminal_conn = ' ',
    },
  },
}

M.config = M.defaults

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})
  return M.config
end

return M
