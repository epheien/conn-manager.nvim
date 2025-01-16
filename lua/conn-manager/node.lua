local Config = require('conn-manager.config')

local M = {}

local Node = {}
Node.__index = Node

---@class Node
---@field parent Node
---@field children Node[]
---@field expanded boolean
---@field expandable boolean
---@field data any private data
---@field config table
---@field jobs integer[] 打开的终端实例 job_id
---@return table
function Node.new(expandable)
  local self = setmetatable({}, Node)
  self.parent = nil
  self.children = {}
  self.expanded = false
  self.expandable = expandable
  self.data = nil
  self.config = {}
  self.jobs = {}
  return self
end

---@return string
function Node:inspect()
  local temp = {}
  for key, val in pairs(self) do
    -- ignore some keys
    if not (key == 'parent' or key == 'children') then
      temp[key] = val
    end
  end
  return vim.inspect(temp)
end

function Node:__tostring() return self.config.display_name or string.format('table: %p', self) end

-- 添加子节点
function Node:add_child(child)
  child.parent = self
  table.insert(self.children, child)
end

-- 移除子节点
function Node:remove_child(child)
  for i, c in ipairs(self.children) do
    if c == child then
      child.parent = nil
      table.remove(self.children, i)
      break
    end
  end
end

-- 获取节点的深度
function Node:get_depth()
  local depth = 0
  local current = self
  while current.parent do
    depth = depth + 1
    current = current.parent
  end
  return depth
end

-- 获取根节点
function Node:get_root()
  local current = self
  while current.parent do
    current = current.parent
  end
  return current
end

---render node and it's children
---@param indent? integer
---@param lines? string[]
---@param line_to_node? table[]
---@return string[]
---@return table[]
function Node:deep_render(indent, lines, line_to_node)
  indent = indent or 0
  lines = lines or {}
  line_to_node = line_to_node or {}
  table.insert(lines, self:render(indent))
  table.insert(line_to_node, self)
  if not self.expanded then
    goto out
  end
  for _, child in ipairs(self.children) do
    child:deep_render(indent + 1, lines, line_to_node)
  end
  ::out::
  return lines, line_to_node
end

---@param indent integer
---@return string|table[]
function Node:render(indent)
  local indent_text = string.rep('  ', indent)
  local icons = Config.config.node.icons
  local prefix = self.expandable and (self.expanded and icons.arrow_open or icons.arrow_closed)
    or '  '
  local icon = self.expandable and (self.expanded and icons.opened_folder or icons.closed_folder)
    or icons.terminal_conn
  local label = tostring(self)
  if false then
    return string.format('%s%s %s', indent_text, prefix, label)
  else
    local hl_group = self.expandable and 'Directory' or nil
    local msgs = { { indent_text }, { prefix, hl_group }, { icon, hl_group }, { label, hl_group } }
    if #self.jobs > 0 then
      table.insert(msgs, { string.format(' [%d]', tostring(#self.jobs)), 'Special' })
    end
    --print(vim.inspect(msgs), vim.inspect(self.jobs), #self.jobs)
    return msgs
  end
end

local function new_node_from_conn(conn)
  local node = Node.new(#(conn.children or {}) > 0)
  --node.expanded = node.expandable and true or false
  node.config = conn.config
  for _, child in ipairs(conn.children or {}) do
    node:add_child(new_node_from_conn(child))
  end
  return node
end

---载入配置, 返回连接树
---@param fname string
---@return Node
function M.load_config(fname)
  local config = M.read_config(fname)
  local root = Node.new(true)
  root.expanded = true -- root 无条件展开
  for _, conn in ipairs(config.connections) do
    root:add_child(new_node_from_conn(conn))
  end
  return root
end

function M.read_config(fname)
  local file = io.open(fname, 'r')
  assert(file, 'failed to load config from ' .. fname)
  local text = file:read('*a')
  local config = vim.json.decode(text)
  return config
end

return M
