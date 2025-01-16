local M = {}

function M.render(bufnr, tree)
  local lines, line_to_node = tree:render()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return line_to_node
end

return M
