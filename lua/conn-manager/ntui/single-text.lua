---@class ntui.SingleText
---@field type string
---@field label string
---@field value any
---@field indent integer 0
---@field priv any private data
local SingleText = {}
SingleText.__index = SingleText

---@param label string
---@param value? any
function SingleText.new(label, value)
  local self = setmetatable({}, SingleText)
  self.type = 'SingleText'
  self.label = label
  self.value = value
  self.indent = 0
  self.priv = nil
  return self
end

---@param include_indent boolean
---@return integer
function SingleText:get_label_display_width(include_indent)
  return (include_indent and self.indent or 0) + vim.api.nvim_strwidth(self.label) + 2
end

---@return table a list of {text, hl_group}
function SingleText:render()
  local chunks = {}
  if self.indent > 0 then
    table.insert(chunks, { string.rep(' ', self.indent) })
  end
  table.insert(chunks, { self.label .. ': ', 'Label' })
  table.insert(chunks, { tostring(self.value) })
  return chunks
end

return {
  new = SingleText.new,
}
