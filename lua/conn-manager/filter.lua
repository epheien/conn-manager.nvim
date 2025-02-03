local config = require('conn-manager.config').config

local M = {}

M.winid = -1
M.bufnr = -1
M.filter_pattern = ''

function M.live_filter_close()
  if M.winid ~= -1 then
    vim.api.nvim_win_close(M.winid, false)
    M.winid = -1
  end
end

function M.live_filter_clear()
  M.filter_pattern = ''
  if M.bufnr ~= -1 then
    vim.api.nvim_buf_set_lines(M.bufnr, 0, 1, false, { '' })
  end
  M.live_filter_close()
end

---@param refresh function
function M.live_filter_open(refresh)
  M.live_filter_close()
  if M.bufnr == -1 then
    M.bufnr = vim.api.nvim_create_buf(false, true)
  end
  M.winid = vim.api.nvim_open_win(M.bufnr, true, {
    relative = 'win',
    row = 0,
    col = 0,
    width = config.window_config.width,
    height = 1,
    border = 'none',
  })
  vim.wo.number = false
  vim.wo.statuscolumn = string.format('%%#ConnManagerLiveFilterPrefix#%s', config.filter.prefix)
  local confirm = function(keep_open)
    local line = vim.api.nvim_get_current_line()
    M.filter_pattern = line
    refresh(M.filter_pattern)
    if not keep_open then
      vim.cmd.stopinsert()
      M.live_filter_close()
    end
  end
  local o = { buffer = M.bufnr }
  vim.keymap.set('i', '<CR>', confirm, o)
  vim.keymap.set('i', '<C-c>', '<Esc>', o)
  vim.keymap.set('i', '<C-o>', '<Esc>', o)
  vim.keymap.set('i', '<Esc>', confirm, o)
  vim.api.nvim_create_autocmd({ 'WinLeave', 'InsertLeave' }, {
    buffer = M.bufnr,
    callback = M.live_filter_close,
  })
  vim.api.nvim_create_autocmd('CursorMovedI', {
    buffer = M.bufnr,
    callback = function()
      local line = vim.api.nvim_get_current_line()
      if line == M.filter_pattern then
        return
      end
      confirm(true)
    end,
  })
  vim.api.nvim_feedkeys('A', 'n', false)
end

return M
