local Config = require('conn-manager.config')
local Node = require('conn-manager.node')
local Render = require('conn-manager.render')
local Window = require('conn-manager.window')
local Utils = require('conn-manager.utils')

local M = {}

M.filter_pattern = ''
M.filter_regex = nil

local empty = Utils.empty
local function notify_error(msg) vim.notify(msg, vim.log.levels.ERROR) end
local function notify(msg) vim.notify(msg, vim.log.levels.INFO) end

-- 叶子节点 open hook
---@param node Node|nil
local function on_node_open(node, window_picker)
  if not node or node.expandable then
    return
  end
  -- @提取需要运行的命令
  local args = { 'ssh' }
  if node.config.port then
    vim.list_extend(args, { '-p', tostring(node.config.port) })
  end
  if not empty(node.config.username) then
    vim.list_extend(args, { '-l', node.config.username })
  end
  if not empty(node.config.private_key_file) then
    vim.list_extend(args, { '-i', Utils.expand_user(node.config.private_key_file) })
  end
  table.insert(args, node.config.computer_name)

  --notify(vim.inspect(args))

  -- @跳到准备渲染的窗口
  local win = type(window_picker) == 'function' and window_picker(node)
    or Window.pick_window_for_node_open()
  vim.api.nvim_set_current_win(win)

  ---生成闭包
  ---@param state table { done = false }
  ---@return function
  local function make_callback(state)
    return function(job_id, data, event) ---@diagnostic disable-line: unused-local
      if state.done or empty(node.config.password) then
        return
      end
      local text = table.concat(data)
      if vim.regex([['s password: $]]):match_str(text) then
        vim.fn.chansend(job_id, node.config.password .. '\n')
        state.done = true
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
      for i, id in ipairs(node.jobs) do
        if id == job_id then
          table.remove(node.jobs, i)
          break
        end
      end
      M.refresh_node(node)
    end,
  })
  table.insert(node.jobs, jobid)
  --vim.cmd.startinsert()

  --print(jobid, vim.inspect(args))
  return jobid
end

M.config = {}
---@type Node
M.tree = nil
---@type Node[]
M.line_to_node = {}
---@type integer
M.bufnr = -1
---@type integer[]
M.windows = {}
-- kind 'cut'|'copy'
M.clipboard = { kind = 'cut', node = nil }
-- namespace
M.ns_id = vim.api.nvim_create_namespace('conn-manager')

---@param current_tabpage boolean|nil
---@return integer
local function get_win(current_tabpage)
  if vim.t.conn_manager and vim.t.conn_manager.winid and vim.t.conn_manager.winid > -1 then
    return vim.t.conn_manager.winid or -1
  end
  return current_tabpage and -1 or (M.windows[1] or -1)
end

---@return integer 0 means invalid
local function get_lnum()
  local ok, pos = pcall(vim.api.nvim_win_get_cursor, get_win())
  return ok and pos[1] or 0
end

---@return Node|nil
local function get_node() return M.line_to_node[get_lnum()] end

function M.open(opts)
  local lnum = get_lnum()
  local node = get_node()
  if not node or not node.parent or lnum <= 0 then
    return
  end
  if node.expandable then
    node.expanded = not node.expanded
    M.refresh('expand')
  else
    local fallback = function() on_node_open(node, Config.config.node.window_picker) end
    if type(M.config.node.on_open) == 'function' then
      M.config.node.on_open(node, fallback, opts)
    else
      --print(node.config.display_name, node.config.computer_name, node.config.port)
      fallback()
    end
    M.refresh_node(node)
  end
end

function M.inspect()
  local node = get_node()
  if node then
    notify(node:inspect())
  end
end

local function setup_keymaps(bufnr)
  bufnr = bufnr or 0
  local opts = function(desc, o)
    return vim.tbl_deep_extend('force', {
      desc = desc,
      buffer = bufnr,
    }, o or {})
  end
  vim.keymap.set('n', '<CR>', M.open, opts('Open'))
  -- 使用 LeftRelease 触发, 可避免双击连接 ssh 后, 在终端退出插入模式的问题
  vim.keymap.set('n', '<2-LeftRelease>', '<CR>', opts('Open', { remap = true, silent = true }))
  vim.keymap.set('n', '<2-LeftMouse>', '<Nop>', opts('<Nop>', { silent = true }))
  vim.keymap.set('n', 'i', M.inspect, opts('Inspect'))
  vim.keymap.set('n', '<C-t>', M.open_in_tab, opts('Open in Tab'))
  vim.keymap.set('n', 'R', M.refresh, opts('Refresh'))
  vim.keymap.set('n', 'a', M.add_node, opts('Add Node'))
  vim.keymap.set('n', 'A', M.add_folder, opts('Add Folder'))
  vim.keymap.set('n', 'D', M.remove, opts('Remove'))
  vim.keymap.set('n', 'r', M.modify, opts('Modify'))
  vim.keymap.set('n', 'p', M.goto_parent, opts('Goto Parent'))
  vim.keymap.set('n', 'x', M.cut_node, opts('Cut'))
  vim.keymap.set('n', 'c', M.copy_node, opts('Copy'))
  vim.keymap.set('n', 'P', function() M.paste_node(true) end, opts('Paste before Cursor'))
  vim.keymap.set('n', 'gp', function() M.paste_node(false) end, opts('Paste after Cursor'))
  vim.keymap.set('n', 'f', M.live_filter, opts('Live Filter: Start'))
  vim.keymap.set('n', 'F', M.live_filter_clear, opts('Live Filter: Clear'))
  vim.keymap.set('n', '?', require('conn-manager.help').toggle, opts('Help'))
end

local function setup_buffer(buffer)
  if Config.config.keymaps then
    setup_keymaps(buffer)
  end
  vim.api.nvim_create_autocmd('WinClosed', {
    buffer = buffer,
    callback = function()
      local win = get_win()
      for i, w in ipairs(M.windows) do
        if w == win then
          table.remove(M.windows, i)
          local _, tabnr = pcall(vim.api.nvim_win_get_tabpage, w)
          local ok, state = pcall(vim.api.nvim_tabpage_get_var, tabnr, 'conn_manager')
          if ok then
            state.winid = -1
            vim.api.nvim_tabpage_set_var(tabnr, 'conn_manager', state)
          end
          break
        end
      end
    end,
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
    M.config.on_window_open(win)
  end
end

function M.conn_manager_open(focus)
  local win = get_win(true)
  if vim.api.nvim_win_is_valid(win) then
    if vim.api.nvim_get_current_win() ~= win then
      vim.api.nvim_set_current_win(win)
    end
    return win
  end

  local bufnr = M.bufnr
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    setup_buffer(bufnr)
    local line_to_node = Render.render(M.ns_id, bufnr, M.tree)
    M.line_to_node = line_to_node
    M.bufnr = bufnr
  end

  win = vim.api.nvim_open_win(bufnr, focus, M.config.window_config)
  setup_window(win)
  -- window 实例绑定 tabpage
  local state = vim.t.conn_manager or {}
  state.winid = win
  vim.t.conn_manager = state
  table.insert(M.windows, win)
  return win
end

function M.conn_manager_close()
  local win = get_win(true)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, false)
  end
end

-- TODO: increment
---@param event? string
---@param force? boolean true 表示强制刷新全部
function M.refresh(event, force) ---@diagnostic disable-line
  local win = get_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(win)
  local pos = vim.api.nvim_win_get_cursor(win)
  M.line_to_node = Render.render(M.ns_id, bufnr, M.tree, {
    filter = not empty(M.filter_pattern) and function(node)
      if empty(M.filter_pattern) or type(M.filter_pattern) ~= 'string' then
        return true
      end
      return (M.filter_regex:match_str(node.config.display_name))
    end or nil,
    root_line = not empty(M.filter_pattern) and {
      { Config.config.filter.prefix, 'ConnManagerLiveFilterPrefix' },
      { M.filter_pattern, 'ConnManagerLiveFilterValue' },
    } or nil,
  })
  if pos[1] > vim.api.nvim_buf_line_count(bufnr) then
    pos[1] = vim.api.nvim_buf_line_count(bufnr)
  end
  vim.api.nvim_win_set_cursor(win, pos)
end

function M.refresh_node(node)
  if not node then
    return
  end

  local lnum = 0
  if get_node() == node then
    lnum = get_lnum() -- 快速路径
  else
    for ln = 1, #M.line_to_node do
      if M.line_to_node[ln] == node then
        lnum = ln
        break
      end
    end
    if lnum == 0 then
      return
    end
  end

  local win = get_win()
  local msgs = node:render(node:get_depth() - 1)
  local bufnr = vim.api.nvim_win_get_buf(win)
  local pos = vim.api.nvim_win_get_cursor(win)
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, lnum - 1, lnum)
  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { '' })
  require('conn-manager.buffer').echo_to_buffer(M.ns_id, bufnr, lnum, msgs)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_win_set_cursor(win, pos)
end

function M.open_in_tab()
  local node = get_node()
  on_node_open(node, function() vim.cmd('tabnew') end)
  M.refresh_node(node)
end

function M.setup(opts)
  opts = opts or {}
  M.config = Config.setup(opts)
  local ok, tree = pcall(Node.load_config, M.config.config_file)
  if not ok then
    notify_error(tree .. ', conn-manager will be disabled')
    return
  end
  M.tree = tree

  require('conn-manager.highlights').setup()

  vim.api.nvim_create_user_command(
    'ConnManagerOpen',
    function() M.conn_manager_open() end,
    { nargs = 0 }
  )
  vim.api.nvim_create_user_command(
    'ConnManagerClose',
    function() M.conn_manager_close() end,
    { nargs = 0 }
  )
end

function M.remove()
  local node = get_node()
  if not node or not node.parent then
    return
  end
  local choice =
    vim.fn.confirm(string.format('Delete %s?', node.config.display_name), '&Yes\n&No', 2)
  if choice == 1 then
    node.parent:remove_child(node)
    M.refresh('remove')
    M.save_config()
  end
end

local function buffer_save_action(node, post_func)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')
  local config = loadstring(content)()
  if not config or type(config) ~= 'table' then
    notify_error('failed to parse content')
    return
  end
  if empty(config.display_name) then
    notify_error('display_name cannot be empty')
    return
  end
  if empty(config.computer_name) then
    notify_error('computer_name cannot be empty')
    return
  end
  if type(post_func) == 'function' then
    post_func(node, config)
  end
  vim.api.nvim_win_close(winid, false)
end

function M.add_folder()
  local node = get_node()
  if not node then
    return
  end
  local name = vim.fn.input('Folder name')
  if empty(name) then
    return
  end
  local new_node = Node.Node.new(true)
  new_node.config = vim.tbl_extend('force', {}, {
    display_name = name,
    ['type'] = 'folder',
  })
  node:add_child_or_sibling(new_node)
  M.refresh('add')
  M.save_config()
end

function M.add_node()
  local node = get_node()
  if not node then
    return
  end
  local bufnr, _ = Utils.create_scratch_floatwin('conn-manager add connection')
  local template = [[
-- press <C-s> or <C-w>s to save
return {
  display_name = '',
  description = '',
  computer_name = '', -- aka. hostname, also can be IP
  port = 22,
  username = '',
  password = '',
  private_key_file = '',
}]]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(template, '\n', {}))
  vim.api.nvim_set_option_value('filetype', 'lua', { buf = bufnr })

  vim.keymap.set('n', '<C-s>', function()
    buffer_save_action(node, function(n, config)
      config['type'] = 'terminal'
      local new_node = Node.new_node_from_conn({ config = config })
      n:add_child_or_sibling(new_node)
      M.refresh('add')
      M.save_config()
    end)
  end, { buffer = bufnr })
  vim.keymap.set('n', '<C-w>s', '<C-s>', { buffer = bufnr, remap = true, silent = true })
end

function M.modify()
  local node = get_node()
  if not node then
    return
  end
  if node.expandable then
    local name = vim.fn.input({
      prompt = 'Rename to',
      default = node.config.display_name,
    })
    if not empty(name) then
      node.config.display_name = name
      M.refresh_node(node)
      M.save_config()
    end
    return
  end

  local bufnr, _ = Utils.create_scratch_floatwin('conn-manager modify connection')
  local template = 'return ' .. vim.inspect(node.config)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(template, '\n', {}))
  vim.api.nvim_set_option_value('filetype', 'lua', { buf = bufnr })

  vim.keymap.set('n', '<C-s>', function()
    buffer_save_action(node, function(n, config)
      n.config = config
      M.refresh_node(node)
      M.save_config()
    end)
  end, { buffer = bufnr })
  vim.keymap.set('n', '<C-w>s', '<C-s>', { buffer = bufnr, remap = true, silent = true })
end

function M.save_config()
  local conn = Node.new_conn_from_node(M.tree)
  local config = {
    connections = conn.children,
  }
  local content = vim.json.encode(config)
  if Config.config.save.on_write then
    content = Config.config.save.on_write(content)
  end
  if not content then
    return
  end
  local temp = Config.config.config_file .. '.tmp'
  local file = io.open(temp, 'w')
  if not file then
    notify_error('[conn-manager] failed to write config')
    return
  end
  if file then
    file:write(content)
    file:close()
    local ok, err = os.rename(temp, Config.config.config_file)
    if not ok then
      notify_error('[conn-manager] failed to save config: ' .. tostring(err))
    end
  end
end

function M.goto_parent()
  local node = get_node()
  if not node or not node.parent then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  for i = lnum - 1, 1, -1 do
    if M.line_to_node[i] == node.parent then
      vim.cmd([[normal! m']])
      vim.api.nvim_win_set_cursor(0, { i, 0 })
    end
  end
end

local function clear_clipboard()
  if M.clipboard.node then
    local clip_node = M.clipboard.node
    clip_node.clip = ''
    M.clipboard.node = nil
    M.clipboard.kind = ''
    M.refresh_node(clip_node)
  end
end

function M.cut_node()
  local node = get_node()
  if not node or not node.parent then
    return
  end
  local clip_node = M.clipboard.node
  local clip_kind = M.clipboard.kind
  clear_clipboard()
  if clip_node == node and clip_kind == 'cut' then
    notify(string.format('%s removed from clipboard', node))
  else
    M.clipboard = { kind = 'cut', node = node }
    node.clip = M.clipboard.kind
    notify(string.format('%s cut to clipboard', node))
  end
  M.refresh_node(node)
end

function M.copy_node()
  local node = get_node()
  if not node or not node.parent then
    return
  end
  if node.expandable then
    notify_error('folder node cannot be copied')
    return
  end
  local clip_node = M.clipboard.node
  local clip_kind = M.clipboard.kind
  clear_clipboard()
  if clip_node == node and clip_kind == 'copy' then
    notify(string.format('%s removed from clipboard', node))
  else
    M.clipboard = { kind = 'copy', node = node }
    node.clip = M.clipboard.kind
    notify(string.format('%s copy to clipboard', node))
  end
  M.refresh_node(node)
end

function M.paste_node(before)
  local clip_kind = M.clipboard.kind
  local clip_node = M.clipboard.node
  if not clip_node or not clip_node.parent then
    return
  end
  local node = get_node()
  if not node then
    return
  end
  if clip_kind == 'cut' and clip_node == node then
    return
  end
  if node.expandable then
    if clip_kind == 'cut' then
      clip_node.parent:remove_child(clip_node)
      clear_clipboard()
    end
    node:add_child(clip_kind == 'cut' and clip_node or clip_node:clone())
  else
    if clip_kind == 'cut' then
      clip_node.parent:remove_child(clip_node)
      clear_clipboard()
    end
    for idx, child in ipairs(node.parent.children) do
      if child == node then
        node.parent:add_child(
          clip_kind == 'cut' and clip_node or clip_node:clone(),
          before and idx or idx + 1
        )
        break
      end
    end
  end
  M.refresh('paste')
  M.save_config()
end

function M.live_filter_clear()
  require('conn-manager.filter').live_filter_clear()
  M.filter_pattern = ''
  M.filter_regex = nil
  M.refresh()
end

function M.live_filter()
  require('conn-manager.filter').live_filter_open(function(input)
    M.filter_pattern = input
    M.filter_regex = vim.regex(M.filter_pattern)
    M.refresh()
  end)
end

return M
