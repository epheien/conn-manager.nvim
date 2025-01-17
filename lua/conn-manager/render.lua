local M = {}

---@param ns_id integer
---@param bufnr integer
---@param tree Node
---@return Node[]
function M.render(ns_id, bufnr, tree)
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  local lines, line_to_node = tree:deep_render(-1)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  if type(lines[1]) == 'string' then
    -- root 节点需要特殊处理显示效果
    lines[1] = 'Connections'
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  else
    -- root 节点需要特殊处理显示效果
    lines[1] = { { 'Connections', 'Title' } }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '' }) -- 清空缓冲区
    require('conn-manager.buffer').echo_chunks_list_to_buffer(ns_id, bufnr, lines)
  end
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  return line_to_node
end

return M
