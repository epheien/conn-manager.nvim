local Config = require('conn-manager.config')
local Types = require('conn-manager.types')

local M = {}

local clip_hl = {
  copy = 'ConnManagerCopyHL',
  cut = 'ConnManagerCutHL',
}

---@class Node
---@field parent Node
---@field children Node[]
---@field expanded boolean
---@field expandable boolean
---@field data any private data
---@field config ConnectionConfig
---@field jobs integer[] 打开的终端实例 job_id
---@field clip string 'cut' or 'copy'
local Node = {}
Node.__index = Node
M.Node = Node

---@param expandable? boolean
---@return Node
function Node.new(expandable)
  local self = setmetatable({}, Node)
  self.parent = nil
  self.children = {}
  self.expanded = false
  self.expandable = expandable and true or false
  self.data = nil
  self.config = Types.ConnectionConfig.new()
  self.jobs = {}
  self.clip = ''
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

function Node:__tostring()
  return self.config and self.config.display_name or string.format('table: %p', self)
end

-- 添加子节点
---@param child Node
---@param pos? integer
function Node:add_child(child, pos)
  child.parent = self
  if pos then
    table.insert(self.children, pos, child)
  else
    table.insert(self.children, child)
  end
end

--- 如果是目录则直接 add_child, 否则就添加到叶子节点的后面
---@param node Node
function Node:add_child_or_sibling(node)
  if self.expanded then
    self:add_child(node)
    return
  end
  for idx, child in ipairs(self.parent.children) do
    if child == self then
      self.parent:add_child(node, idx + 1)
    end
  end
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

-- 浅 clone, children 不会管
function Node:clone()
  local clone_node = Node.new(self.expandable)
  clone_node.config = vim.deepcopy(self.config)
  return clone_node
end

---render node and it's children
---@param indent? integer
---@param lines? string[]
---@param line_to_node? table[]
---@param filter? function
---@return string[]|table[]
---@return table[]
function Node:deep_render(indent, lines, line_to_node, filter)
  indent = indent or 0
  lines = lines or {}
  line_to_node = line_to_node or {}
  local child_render_count = 0
  -- filter leaf node
  if filter and not self.expandable and not filter(self) then
    goto out
  end
  table.insert(lines, self:render(indent))
  table.insert(line_to_node, self)
  if not filter and not self.expanded then
    goto out
  end
  for _, child in ipairs(self.children) do
    local prev = #lines
    child:deep_render(indent + 1, lines, line_to_node, filter)
    child_render_count = child_render_count + #lines - prev
  end
  -- 如果子节点全部被过滤了, 那么这个目录也不再显示
  if self.expandable and child_render_count == 0 and filter then
    table.remove(lines, #lines)
    table.remove(line_to_node, #line_to_node)
  end
  ::out::
  return lines, line_to_node
end

---@param indent integer
---@return string|table[]
function Node:render(indent)
  local indent_text = string.rep('  ', indent or 0)
  local icons = Config.config.node.icons
  local prefix = self.expandable and (self.expanded and icons.arrow_open or icons.arrow_closed)
    or '  '
  local icon = self.expandable and (self.expanded and icons.opened_folder or icons.closed_folder)
    or icons.terminal_conn
  local label = tostring(self)
  if false then
    return string.format('%s%s %s', indent_text, prefix, label)
  else
    local hl_group = self.expandable and 'ConnManagerFolder' or nil
    local msgs = {
      { indent_text },
      { prefix, hl_group },
      { icon, hl_group },
      { label, clip_hl[self.clip] or hl_group },
    }
    if #self.jobs > 0 then
      table.insert(msgs, { string.format(' [%d]', tostring(#self.jobs)), 'Special' })
    end
    --print(vim.inspect(msgs), vim.inspect(self.jobs), #self.jobs)
    return msgs
  end
end

function M.new_node_from_conn(conn)
  local node = Node.new(#(conn.children or {}) > 0 or conn.config.type == 'folder')
  node.config = vim.tbl_extend('force', Types.ConnectionConfig.new(), conn.config)
  for _, child in ipairs(conn.children or {}) do
    node:add_child(M.new_node_from_conn(child))
  end
  return node
end

---载入配置, 返回连接树
---@param fname string
---@return Node
function M.load_config(fname)
  local config = {}
  if vim.uv.fs_stat(fname) then ---@diagnostic disable-line
    config = M.read_config(fname)
  end
  local root = Node.new(true)
  root.expanded = true -- root 无条件展开
  for _, conn in ipairs(config.connections or {}) do
    root:add_child(M.new_node_from_conn(conn))
  end
  return root
end

function M.new_conn_from_node(node)
  local conn = {}
  conn.config = node.config
  conn.children = {}
  for _, child in ipairs(node.children or {}) do
    table.insert(conn.children, M.new_conn_from_node(child))
  end
  return conn
end

function M.read_config(fname)
  local file = io.open(fname, 'r')
  assert(file, 'failed to load config from ' .. fname)
  local text = file:read('*a')
  if Config.config.save.on_read then
    text = Config.config.save.on_read(text)
  end
  local config = vim.json.decode(text)
  return config
end

return M
