# conn-manager.nvim
A ssh connections manager for neovim.

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

## Usage
Run `:ConnManager` in neovim, and press `a` to start. Press `?` for keymaps help.

## Commands
`:ConnManager [open|close|toggle]`

## Default Configuration
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
  on_window_open = nil,   -- params: (winid)
  on_buffer_create = nil, -- params: (bufnr)
  node = {
    window_picker = nil,  -- window_picker for builtin node open, params: (node)
    on_open = nil,        -- params: (node, fallback, opts)
    icons = {
      arrow_closed = ' ',
      arrow_open = ' ',
      closed_folder = ' ',
      opened_folder = ' ',
      terminal_conn = ' ',
    },
  },
  help = {
    cursorline = true,
    sort_by = 'key',
    winhl = 'NormalFloat:Normal',
    window_config = {
      relative = 'editor',
      border = 'single',
      row = 1,
      col = 0,
      style = 'minimal',
      noautocmd = true,
    },
  },
  filter = {
    prefix = '[FILTER]: ',
  },
  save = {
    on_read = nil,  -- read hook, signature: (text) -> string
    -- write hook, signature: (text) -> string|nil
    -- return nil will bypass builtin file writing logic, so you must write file yourself.
    on_write = nil,
  }
}
```

## Default Keymaps
Read `setup_keymaps` function in `lua/conn-manager/init.lua` for detail.
You can press `?` to open keymaps help window in `ConnManager` buffer.

## Example Configuration
<details><summary>lua/plugins/conn-manager.lua</summary>

```lua
local function on_node_open(node, fallback, opts) ---@diagnostic disable-line
  local empty = require('utils').empty
  if not opts or empty(opts.open_with) then
    fallback()
    return
  end
  if opts.open_with == 'tab' then
    require('conn-manager').open_in_tab()
    vim.api.nvim_set_option_value('winfixbuf', true, { win = 0 })
    vim.t.title = node.config.display_name
    return
  end
  local title = node.config.display_name
  -- dump args to execute
  local args = { 'ssh' }
  if node.config.port then
    vim.list_extend(args, { '-p', tostring(node.config.port) })
  end
  if not empty(node.config.username) then
    vim.list_extend(args, { '-l', node.config.username })
  end
  if not empty(node.config.private_key_file) then
    vim.list_extend(args, { '-i', vim.fn.expand(node.config.private_key_file) })
  end
  table.insert(args, node.config.computer_name)
  local prefix
  if opts.open_with == 'kitty' then
    prefix = { 'open', '-n', '-a', 'kitty', '--args', '--title', title }
  else
    prefix = { 'open', '-n', '-a', 'alacritty', '--args', '--title', title, '-e' }
  end
  args = vim.list_extend(prefix, args)
  vim.system(args, { stdout = false, stderr = false, detach = true })
end

local function window_picker(node)
  local winid = require('conn-manager.window').pick_window_for_node_open(false)
  if winid == 0 then
    vim.cmd.tabnew()
    vim.api.nvim_set_option_value('winfixbuf', true, { win = 0 })
    vim.t.title = node.config.display_name
    return vim.api.nvim_get_current_win()
  end
  return winid
end

return {
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
        vim.api.nvim_set_option_value('statusline', '─', { win = win })
        vim.api.nvim_set_option_value('fillchars', vim.o.fillchars .. ',eob: ', { win = win })
        vim.api.nvim_set_option_value('winfixbuf', true, { win = win })
      end,
      node = {
        on_open = on_node_open,
        window_picker = window_picker,
      },
      on_buffer_create = function(bufnr)
        vim.keymap.set(
          'n',
          't',
          function() require('conn-manager').open({ open_with = 'tab' }) end,
          { buffer = bufnr, desc = 'Open in Tab' }
        )
        -- if you need menu support, install `https://github.com/nvzone/menu`,
        -- and read `Menu Support` section
        vim.keymap.set(
          'n',
          '.',
          function() require('menu').open('conn-manager', { mouse = false, border = false }) end,
          { buffer = bufnr, desc = 'Menu' }
        )
      end,
      save = {
        on_read = function(text) return text end,
        on_write = function(text)
          if not vim.fn.executable('jq') then
            return text
          end
          vim.system({ 'jq' }, {
            stdin = text,
          }, function(obj)
            if obj.code ~= 0 then
              vim.api.nvim_err_writeln(string.format('jq exit %d: %s', obj.code, obj.stderr))
              return
            end
            local fname = require('conn-manager.config').config.config_file
            local temp = fname .. '.tmp'
            local file = io.open(temp, 'w')
            if file then
              file:write(obj.stdout)
              file:close()
              os.rename(temp, fname)
            end
          end)
        end,
      },
    })
  end,
}
```

</details>

## Menu Support
Install `https://github.com/nvzone/menu` and add this configuration.
<details><summary>lua/menus/conn-manager.lua</summary>

```lua
return {
  {
    name = '  Open with nvim terminal',
    cmd = function() require('conn-manager').open({ open_with = '' }) end,
    rtxt = 'on',
  },
  {
    name = '  Open with nvim terminal in new tab',
    cmd = function() require('conn-manager').open({ open_with = 'tab' }) end,
    rtxt = 'ot',
  },
  {
    name = '  Open with Alacritty.app',
    cmd = function() require('conn-manager').open({ open_with = 'alacritty' }) end,
    rtxt = 'oa',
  },
  {
    name = '  Open with Kitty.app',
    cmd = function() require('conn-manager').open({ open_with = 'kitty' }) end,
    rtxt = 'ok',
  },
  { name = 'separator' },

  {
    name = '  Add node',
    cmd = require('conn-manager').add_node,
    rtxt = 'a',
  },
  {
    name = '  Add folder',
    cmd = require('conn-manager').add_folder,
    rtxt = 'A',
  },
  { name = 'separator' },

  {
    name = '  Edit node',
    cmd = require('conn-manager').modify,
    rtxt = 'r',
  },
  {
    name = '  Remove node',
    cmd = require('conn-manager').remove,
    rtxt = 'D',
  },
  { name = 'separator' },

  {
    name = '  Cut',
    cmd = require('conn-manager').cut_node,
    rtxt = 'x',
  },
  {
    name = '  Copy',
    cmd = require('conn-manager').copy_node,
    rtxt = 'c',
  },
  {
    name = '  Paste',
    cmd = function() require('conn-manager').paste_node() end,
    rtxt = 'p',
  },
  {
    name = '  Paste before node',
    cmd = function() require('conn-manager').paste_node(true) end,
    rtxt = 'p',
  },
}
```
</details>

## Attention
The password is stored in plain text in neovim, and the security needs to be ensured by yourself.

The connections config file saves sensitive information including passwords in plain text,
do not upload this file to the public domain.

If you need to encrypt your connections config file, please use the `on_read` and `on_write` options,
refer `Example Configuration` section for example.
