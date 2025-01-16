local Config = require('conn-manager.config')
local Node = require('conn-manager.node')
local Render = require('conn-manager.render')
local Window = require('conn-manager.window')

local M = {}

-- 叶子节点 open hook
---comment
---@param node Node
local function on_node_open(node)
  -- @提取需要运行的命令
  local args = { 'ssh' }
  if node.config.port then
    table.insert(args, '-p' .. tostring(node.config.port))
  end
  if node.config.username then
    table.insert(args, '-l' .. node.config.username)
  end
  table.insert(args, node.config.computer_name)

  -- @跳到准备渲染的窗口
  local win = Window.pick_window_for_node_open()
  vim.api.nvim_set_current_win(win)

  ---生成闭包
  ---@param state table { done = false }
  ---@return function
  local function make_callback(state)
    return function(job_id, data, event) ---@diagnostic disable-line: unused-local
      if state.done or not node.config.password then
        return
      end
      local text = table.concat(data)
      if vim.regex([['s password: $]]):match_str(text) then
        if node.config.password and node.config.password ~= '' then
          vim.fn.chansend(job_id, node.config.password .. '\n')
          state.done = true
        end
      end
      state.match_count = (state.match_count or 0) + #data
      if state.match_count >= 100 then
        state.done = true
        vim.api.nvim_echo({
          {
            string.format('%s can not detect login prompt, abort detecting', node),
            'WarningMsg',
          },
        }, true, {})
      end
    end
  end

  -- @开始执行命令
  local jobid = vim.fn.termopen(args, {
    on_stdout = make_callback({ done = false }),
    on_exit = function(job_id, exit_code, event) ---@diagnostic disable-line: unused-local
      --print(node.jobs, job_id, event, exit_code)
      node.jobs = node.jobs - 1
    end,
  })
  node.jobs = node.jobs + 1
  vim.cmd.startinsert()

  --print(jobid, vim.inspect(args))
  return jobid
end

M.config = {}
---@type Node
M.tree = nil
---@type Node[]
M.line_to_node = {}
---@type integer
M.window = -1

local function setup_keymaps(bufnr)
  vim.keymap.set('n', '<CR>', function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local node = M.line_to_node[lnum]
    if not node.parent then
      return
    end
    if node.expandable then
      node.expanded = not node.expanded
      M.refresh()
    else
      if type(M.config.node.on_open) == 'function' then
        M.config.node.on_open(node)
      else
        --print(node.config.display_name, node.config.computer_name, node.config.port)
        on_node_open(node)
      end
    end
  end, { buffer = bufnr or true })

  vim.keymap.set(
    'n',
    '<2-LeftMouse>',
    '<CR>',
    { remap = true, silent = true, buffer = bufnr or true }
  )

  vim.keymap.set('n', 'i', function()
    local node = M.line_to_node[vim.api.nvim_win_get_cursor(0)[1]]
    if node.expandable then
      vim.notify('this is a folder')
    else
      vim.notify(node.config.description or 'no description')
    end
  end, { buffer = bufnr or true })
end

local function setup_buffer(buffer)
  setup_keymaps(buffer)
  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = buffer,
    callback = function() M.window = -1 end,
  })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buffer })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buffer })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buffer })
  vim.api.nvim_set_option_value('undolevels', 100, { buf = buffer })
  vim.api.nvim_set_option_value('buflisted', false, { buf = buffer })
  vim.api.nvim_set_option_value('filetype', 'status_table', { buf = buffer })
  vim.api.nvim_set_option_value('filetype', 'ConnManager', { buf = buffer })
  if type(M.config.on_buffer_create) == 'function' then
    M.config.on_buffer_create(buffer)
  end
end

local function setup_window(win)
  vim.api.nvim_set_option_value('wrap', false, { win = win })
  vim.api.nvim_set_option_value('colorcolumn', '', { win = win })
  vim.api.nvim_set_option_value('list', false, { win = win })
  vim.api.nvim_set_option_value('cursorline', true, { win = win })
  vim.api.nvim_set_option_value('winfixwidth', true, { win = win })
  vim.api.nvim_set_option_value('number', false, { win = win })
  vim.api.nvim_set_option_value('winfixbuf', true, { win = win })
  if type(M.config.on_window_open) == 'function' then
    M.config.on_window_open(M.window)
  end
end

function M.open(focus)
  if vim.api.nvim_win_is_valid(M.window) then
    if vim.api.nvim_get_current_win() ~= M.window then
      vim.api.nvim_set_current_win(M.window)
    end
    return M.window
  end

  local buffer = vim.api.nvim_create_buf(false, true)
  setup_buffer(buffer)
  local line_to_node = Render.render(buffer, M.tree)
  M.line_to_node = line_to_node

  M.window = vim.api.nvim_open_win(buffer, focus, M.config.window_config)
  setup_window(M.window)
  return M.window
end

function M.refresh()
  if not vim.api.nvim_win_is_valid(M.window) then
    return
  end
  M.line_to_node = Render.render(vim.api.nvim_win_get_buf(M.window), M.tree)
end

function M.setup(opts)
  opts = opts or {}
  M.config = Config.setup(opts)
  local ok, tree = pcall(Node.load_config, M.config.config_path)
  if not ok then
    vim.notify(tree .. ', conn-manager will be disabled', vim.log.levels.ERROR)
    return
  end
  M.tree = tree

  vim.api.nvim_create_user_command('ConnManagerOpen', function() M.open() end, { nargs = 0 })
end

return M
