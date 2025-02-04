---@class ntui.StaticText
---@field type string
---@field label string
---@field hl_group string
---@field indent integer 0
---@field priv any private data
local StaticText = {}
StaticText.__index = StaticText

---@param label string
---@param hl_group string
function StaticText.new(label, hl_group)
  local self = setmetatable({}, StaticText)
  self.type = 'StaticText'
  self.label = label
  self.hl_group = hl_group
  self.indent = 0
  self.priv = nil
  return self
end

---@return table a list of {text, hl_group}
function StaticText:render()
  local chunks = {}
  if self.indent > 0 then
    table.insert(chunks, { string.rep(' ', self.indent) })
  end
  table.insert(chunks, { self.label, self.hl_group })
  return chunks
end

return {
  new = StaticText.new,
}
