local M = {}

function M.setup()
  vim.api.nvim_set_hl(0, 'ConnManagerFolder', { link = 'Directory', default = true })
  vim.api.nvim_set_hl(0, 'ConnManagerCopyHL', { link = 'Added', default = true })
  vim.api.nvim_set_hl(0, 'ConnManagerCutHL', { link = 'Changed', default = true })
end

return M
