local M = {}

local scratch_winids = {}
---@param title string
---@return integer bufnr
---@return integer winid
M.create_scratch_floatwin = function(title)
  title = string.format(' %s ', title) or ' More Prompt '
  local scratch_winid = scratch_winids[title] or -1
  local bufid
  if not vim.api.nvim_win_is_valid(scratch_winid) then
    bufid = vim.api.nvim_create_buf(false, true)
    local bo = vim.bo[bufid]
    bo.bufhidden = 'wipe'
    bo.buftype = 'nofile'
    bo.swapfile = false
    local width = math.min(vim.o.columns, 100)
    local col = math.floor((vim.o.columns - width) / 2)
    scratch_winid = vim.api.nvim_open_win(bufid, false, {
      relative = 'editor',
      row = math.floor((vim.o.lines - 2) / 4),
      col = col,
      width = width,
      height = math.floor(vim.o.lines / 2),
      border = 'single',
      title = title,
      title_pos = 'center',
    })
    vim.keymap.set('n', 'q', '<C-w>q', { buffer = bufid, remap = false })
  else
    bufid = vim.api.nvim_win_get_buf(scratch_winid)
    local config = vim.api.nvim_win_get_config(scratch_winid)
    config.title = title
    vim.api.nvim_win_set_config(scratch_winid, config)
  end
  vim.api.nvim_set_current_win(scratch_winid)
  vim.opt_local.number = false
  vim.opt_local.colorcolumn = {}
  local opt = vim.opt_local.winhighlight
  if not opt:get().NormalFloat then
    opt:append({ NormalFloat = 'Normal' })
  end
  scratch_winids[title] = scratch_winid
  return bufid, scratch_winid
end

-- 类似 vim.fn.empty()
---param v any
---@return boolean
function M.empty(v)
  if v == nil then
    return true
  end
  -- The possible results of this function are "nil" (a string, not the value nil),
  -- "number", "string", "boolean", "table", "function", "thread", and "userdata".
  local t = type(v)
  if t == 'number' then
    return v == 0
  elseif t == 'string' then
    return v == ''
  elseif t == 'boolean' then
    return not v
  elseif t == 'table' then
    for _, _ in pairs(v) do
      return false
    end
    return true
  end
  return false
end

---展开 '~/abc/xyz' 路径为 '$HOME/abc/xyz'
---@param path string
---@return string
function M.expand_user(path)
  local home = os.getenv('HOME')
  if M.empty(home) then
    return path
  end
  return (path:gsub('^~/', home .. '/'))
end

---@param opts table { default = '', window_config = {} }
---@param on_confirm function
function M.overlay_input(opts, on_confirm)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if opts.default then
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { opts.default })
  end
  local winid = vim.api.nvim_open_win(
    bufnr,
    true,
    vim.tbl_deep_extend('force', {
      relative = 'win',
      row = 0,
      col = 0,
      width = 78,
      height = 1,
      border = 'none',
    }, opts.window_config or {})
  )
  vim.wo.number = false
  vim.bo.bufhidden = 'wipe'
  local confirm = function(cancel)
    local line = vim.api.nvim_get_current_line()
    if not cancel and on_confirm then
      on_confirm(line)
    end
    vim.cmd.stopinsert() -- NOTE: tirgger InsertLeave event to close window
  end
  local o = { buffer = bufnr or true }
  vim.keymap.set('i', '<CR>', confirm, o)
  vim.keymap.set('i', '<C-c>', '<Esc>', o)
  vim.keymap.set('i', '<C-o>', '<Esc>', o)
  vim.keymap.set('i', '<Esc>', function() confirm(true) end, o)
  vim.api.nvim_create_autocmd({ 'WinLeave', 'InsertLeave' }, {
    buffer = bufnr,
    callback = function() vim.api.nvim_win_close(winid, false) end,
  })
  vim.api.nvim_feedkeys('A', 'n', false)
end

return M
