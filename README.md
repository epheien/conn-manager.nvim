# conn-manager.nvim
ssh connections manager for nvim

## Screenshot
<img width="1022" alt="Image" src="https://github.com/user-attachments/assets/41c9c586-390d-4cb4-8d0b-6954e0eece2c" />

## Setup
Example setup for lazy.nvim
```lua
{
  'epheien/conn-manager.nvim',
  cmd = 'ConnManager',
  config = function()
    require('conn-manager').setup({
      config_file = vim.fs.joinpath(vim.fn.stdpath('config') --[[@as string]], 'conn-manager.json'),
      window_config = {
        width = 36,
        split = 'left',
        vertical = true,
        win = -1,
      },
      on_window_open = function(win)
        vim.api.nvim_set_option_value('fillchars', vim.o.fillchars .. ',eob: ', { win = win })
      end,
    })
  end,
}
```

## Default configuration
```lua
{
  config_file = vim.fs.joinpath(vim.fn.stdpath('config') --[[@as string]], 'conn-manager.json'),
  keymaps = true, -- add default keymaps
  window_config = {
    width = 30,
    split = 'left',
    vertical = true,
    win = -1,
  },
  on_window_open = nil,
  on_buffer_create = nil,
  node = {
    window_picker = nil, -- window_picker for builtin node open, function(node) end
    on_open = nil, -- (node, fallback, opts)
    icons = {
      arrow_closed = ' ',
      arrow_open = ' ',
      closed_folder = ' ',
      opened_folder = ' ',
      terminal_conn = ' ',
    },
  },
}
```

## Default keymaps
```lua
local bufnr = 0
vim.keymap.set('n', '<CR>', M.open, { buffer = bufnr })
vim.keymap.set('n', '<2-LeftRelease>', '<CR>', { remap = true, silent = true, buffer = bufnr })
vim.keymap.set('n', '<2-LeftMouse>', '<Nop>', { silent = true, buffer = bufnr })
vim.keymap.set('n', 'i', M.inspect, { buffer = bufnr })
vim.keymap.set('n', '<C-t>', M.open_in_tab, { buffer = bufnr })
vim.keymap.set('n', 'R', M.refresh, { buffer = bufnr })
vim.keymap.set('n', 'a', M.add_node, { buffer = bufnr })
vim.keymap.set('n', 'A', M.add_folder, { buffer = bufnr })
vim.keymap.set('n', 'D', M.remove, { buffer = bufnr })
vim.keymap.set('n', 'r', M.modify, { buffer = bufnr })
vim.keymap.set('n', 'p', M.goto_parent, { buffer = bufnr })
vim.keymap.set('n', 'x', M.cut_node, { buffer = bufnr })
vim.keymap.set('n', 'c', M.copy_node, { buffer = bufnr, nowait = true })
vim.keymap.set('n', 'P', function() M.paste_node(true) end, { buffer = bufnr })
vim.keymap.set('n', 'gp', function() M.paste_node(false) end, { buffer = bufnr })
```
