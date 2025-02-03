local M = {}

M.defaults = {
  config_file = vim.fs.joinpath(vim.fn.stdpath('config') --[[@as string]], 'conn-manager.json'),
  keymaps = true, -- add default keymaps
  window_config = {
    width = 30,
    split = 'left',
    vertical = true,
    win = -1,
  },
  on_window_open = nil,
  on_buffer_create = nil,
  node = {
    window_picker = nil, -- window_picker for builtin node open, function(node) end
    on_open = nil, -- (node, fallback, opts)
    icons = {
      arrow_closed = ' ',
      arrow_open = ' ',
      closed_folder = ' ',
      opened_folder = ' ',
      terminal_conn = ' ',
    },
  },
  help = {
    cursorline = true,
    sort_by = 'key',
    winhl = 'NormalFloat:Normal',
    window_config = {
      relative = 'editor',
      border = 'single',
      row = 1,
      col = 0,
      style = 'minimal',
      noautocmd = true,
    },
  },
  filter = {
    prefix = '[FILTER]: ',
  },
}

M.config = M.defaults

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})
  return M.config
end

return M
