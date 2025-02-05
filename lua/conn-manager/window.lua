local M = {}

function M.buf_in_win_count(buf_nr)
  local count = 0
  local win_nr = 1
  while true do
    local win_buf_nr = vim.fn.winbufnr(win_nr)
    if win_buf_nr < 0 then
      break
    end
    if win_buf_nr == buf_nr then
      count = count + 1
    end
    win_nr = win_nr + 1
  end
  return count
end

---检测窗口是否可用(这个窗口可替换为其他缓冲区)
---@param winnr integer
---@return boolean
function M.is_window_usable(winnr)
  local winid = vim.fn.win_getid(winnr)
  if winnr <= 0 or winid == 0 or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  local bufnr = vim.fn.winbufnr(winid)
  -- 特殊窗口,如特殊缓冲类型的窗口、预览窗口
  local is_special_window = vim.api.nvim_get_option_value('buftype', { buf = bufnr }) ~= ''
    or vim.api.nvim_get_option_value('previewwindow', { win = winid })
  if is_special_window then
    return false
  end

  -- 窗口缓冲是否已修改
  local modified = vim.api.nvim_get_option_value('modified', { buf = bufnr })

  -- 如果可允许隐藏,则无论缓冲是否修改
  if vim.o.hidden then
    return true
  end

  -- 如果缓冲区没有修改,或者,已修改,但是同时有其他窗口打开着,则表示可用
  if not modified or M.buf_in_win_count(bufnr) >= 2 then
    return true
  else
    return false
  end
end

function M.get_first_usable_winnr()
  local i = 1
  local last_winnr = vim.fn.winnr('$')
  while i <= last_winnr do
    if M.is_window_usable(i) then
      return i
    end
    i = i + 1
  end
  return -1
end

function M.get_max_width_winnr()
  local result = -1
  local max_width = 0
  local last_winnr = vim.fn.winnr('$')

  for i = 1, last_winnr do
    local winid = vim.fn.win_getid(i)
    -- 忽略浮窗
    if vim.api.nvim_win_get_config(winid).relative ~= '' then
      goto continue
    end
    local cur_width = vim.fn.winwidth(i)
    if cur_width > max_width then
      max_width = cur_width
      result = i
    end
    ::continue::
  end

  return result
end

---@param split? boolean defaut true, split a new window
---@return integer
function M.pick_window_for_node_open(split)
  local prev_winnr = vim.fn.winnr('#')
  if M.is_window_usable(prev_winnr) then
    return vim.fn.win_getid(prev_winnr)
  end
  local winnr = M.get_first_usable_winnr()
  if winnr > 0 then
    return vim.fn.win_getid(winnr)
  end
  if split == false then
    return -1
  end

  -- 跳到最大宽度的窗口以准备分割
  winnr = M.get_max_width_winnr()
  if winnr > 0 then
    vim.api.nvim_set_current_win(vim.fn.win_getid(winnr))
  end

  local bak = vim.o.splitright
  vim.o.splitright = true
  vim.cmd('vnew')
  vim.o.splitright = bak
  return vim.api.nvim_get_current_win()
end

return M
