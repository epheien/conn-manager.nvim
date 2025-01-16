local M = {}

---@param bufnr integer
---@param tree Node
---@return Node[]
function M.render(bufnr, tree)
  local lines, line_to_node = tree:render(-1)
  -- root 节点需要特殊处理显示效果
  if #lines > 0 then
    lines[1] = 'Connections'
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return line_to_node
end

return M
