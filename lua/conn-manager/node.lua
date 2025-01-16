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
---@field jobs integer 打开的终端实例数量
---@return table
function Node.new(expandable)
  local self = setmetatable({}, Node)
  self.parent = nil
  self.children = {}
  self.expanded = false
  self.expandable = expandable
  self.data = nil
  self.config = {}
  self.jobs = 0
  return self
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
---@param indent integer
---@param lines string[]
---@param line_to_node table[]
---@return string[]
---@return table[]
function Node:render(indent, lines, line_to_node)
  indent = indent or 0
  lines = lines or {}
  line_to_node = line_to_node or {}
  local prefix = string.rep('  ', indent)
  table.insert(
    lines,
    string.format(
      '%s%s %s',
      prefix,
      self.expandable and (self.expanded and '~' or '+') or ' ',
      tostring(self)
    )
  )
  table.insert(line_to_node, self)
  if not self.expanded then
    goto out
  end
  for _, child in ipairs(self.children) do
    child:render(indent + 1, lines, line_to_node)
  end
  ::out::
  return lines, line_to_node
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

-- 示例用法
--local root = Node.new(true)
--root.expanded = true
--local child1 = Node.new(true)
--local child2 = Node.new(true)
--local child3 = Node.new()
--local child4 = Node.new()
--
--root:add_child(child1)
--root:add_child(child2)
--child1:add_child(child3)
--child1:add_child(child4)
--child1.expanded = true
--
--local lines, line_to_node = root:render()
--for _, line in ipairs(lines) do
--  print(line)
--end
--
--for ln, node in ipairs(line_to_node) do
--  print(ln, node, type(node))
--end

return M
