local buffer = require('conn-manager.buffer')
local M = {}

M.ns_id = vim.api.nvim_create_namespace('ntui.Dialog')

---@class ntui.Dialog
---@field title string
---@field components any[]
---@field lnum_to_object table
---@field lnum_offset integer
---@field priv any
local Dialog = {}
Dialog.__index = Dialog

function Dialog.new(title)
  local self = setmetatable({}, Dialog)
  self.title = title
  self.components = {}
  self.lnum_to_object = {}
  self.lnum_offset = 0
  self.priv = nil
  return self
end

---@param ... ntui.SingleText[]
function Dialog:add_component(...)
  for _, object in ipairs({ ... }) do
    table.insert(self.components, object)
  end
end

function Dialog:render(bufnr)
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
  local renders = {}
  local lnum_to_object = {}
  for _, object in ipairs(self.components) do
    table.insert(renders, object:render())
    table.insert(lnum_to_object, object)
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '' }) -- 清空缓冲区
  buffer.echo_chunks_list_to_buffer(M.ns_id, bufnr, renders)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  self.lnum_to_object = lnum_to_object
  return lnum_to_object
end

function Dialog:get_object()
  local lnum = vim.api.nvim_win_get_cursor(self.winid)[1]
  return self.lnum_to_object[lnum + self.lnum_offset]
end

function Dialog:on_click()
  if not self.winid then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(self.winid)[1]
  local object = self.lnum_to_object[lnum]
  if object.type ~= 'SingleText' then
    return
  end
  vim.ui.input({
    prompt = vim.trim(object.label) .. ': ',
    default = object.value,
  }, function(input)
    if not input or object.value == input then
      return
    end
    object.value = input
    self:refresh()
  end)
end

function Dialog:refresh()
  local pos = vim.api.nvim_win_get_cursor(self.winid)
  self:render(self.bufnr)
  pos[1] = math.min(vim.api.nvim_buf_line_count(self.bufnr), pos[1])
  vim.api.nvim_win_set_cursor(self.winid, pos)
end

function Dialog:open_win(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)
  self.bufnr = bufnr
  self:render(bufnr)
  local width = math.min(vim.o.columns, 100)
  local col = math.floor((vim.o.columns - width) / 2)
  self.winid = vim.api.nvim_open_win(
    bufnr,
    true,
    vim.tbl_deep_extend('force', {
      relative = 'editor',
      row = math.floor((vim.o.lines - 2) / 4),
      col = col,
      width = width,
      height = math.floor(vim.o.lines / 2),
      border = 'single',
      title = string.format(' %s ', self.title),
      title_pos = 'center',
    }, opts.window_config or {})
  )
  vim.api.nvim_set_option_value('winhl', 'NormalFloat:Normal', { win = self.winid })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.keymap.set('n', 'q', '<C-w>q', { buffer = bufnr, remap = false })
  vim.keymap.set('n', '<CR>', function() self:on_click() end, { buffer = bufnr, remap = false })
  vim.keymap.set('n', '<2-LeftMouse>', '<CR>', { buffer = bufnr, remap = true })
  vim.keymap.set('n', 'i', '<CR>', { buffer = bufnr, remap = true })
  vim.keymap.set('n', 'I', '<CR>', { buffer = bufnr, remap = true })
  vim.keymap.set('n', 'a', '<CR>', { buffer = bufnr, remap = true })
  vim.keymap.set('n', 'A', '<CR>', { buffer = bufnr, remap = true })
  vim.keymap.set('n', '<2-LeftRelease>', '<NOP>', { buffer = bufnr, remap = false })
  vim.keymap.set('n', '<C-w>s', '<C-s>', { buffer = bufnr, remap = true })
  vim.keymap.set('n', '<C-s>', function()
    if opts.on_save then
      if opts.on_save(self) then
        vim.api.nvim_win_close(self.winid, false)
      end
    end
  end, { buffer = bufnr })
end

M.new = Dialog.new

return M
