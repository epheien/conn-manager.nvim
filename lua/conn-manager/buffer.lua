local M = {}

---把 nvim_echo 的参数写到缓冲区的某一行中
---@param ns_id any
---@param bufnr integer
---@param lnum integer
---@param messages table[]
---@param bang? boolean
---@return integer render 的行数
local function echo_to_buffer(ns_id, bufnr, lnum, messages, bang)
  ns_id = ns_id or vim.api.nvim_create_namespace('echo_to_buffer')
  -- 初始化当前行和列的位置
  local row = math.max(lnum - 1, 0)
  local col = 0
  local count = 0

  if #messages == 0 then
    return count
  end
  count = count + 1

  -- 遍历消息列表
  for _, message in ipairs(messages) do
    -- 获取消息的文本和高亮组
    local text = message[1]
    local hl_group = message[2]

    -- 将消息文本写入缓冲区
    local lines = vim.split(text, '\n', { plain = true })
    count = count + #lines - 1
    for i, line in ipairs(lines) do
      vim.api.nvim_buf_set_text(bufnr, row, col, row, col, { line })

      -- 获取写入的文本的长度
      local text_length = #line

      -- 如果指定了高亮组, 则为写入的文本设置 extmark
      if hl_group then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
          end_row = row,
          end_col = col + text_length,
          hl_group = hl_group,
        })
      end

      if i < #lines then
        if #lines > 1 then
          -- 如果不是最后一行, 则移动到下一行的开头
          row = row + 1
          col = 0
          -- 添加新行
          vim.api.nvim_buf_set_lines(bufnr, row + 1, row + 1, false, { '' })
        end
      else
        -- 如果是最后一行, 则更新列的位置,移动到下一个消息的开始位置
        col = col + text_length
      end
    end
  end

  -- 如果设置了 bang, 则将光标移动到消息的开头
  if bang then
    -- NOTE: nvim 的 API 允许渲染不显示的 buffer, 所以操作窗口是不安全的
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  end

  return count
end

---把 nvim_echo 参数的列表全部写到缓冲区
---@param ns_id any
---@param bufnr integer
---@param chunks_list table[][] 每个元素都是 nvim_echo 的第一个参数 chunks
local function echo_chunks_list_to_buffer(ns_id, bufnr, chunks_list, bang)
  local offset = 0
  for lnum, message in ipairs(chunks_list) do
    -- 非首行都要在末尾添加空行
    if lnum ~= 1 then
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { '' })
    end
    local count = echo_to_buffer(ns_id, bufnr, lnum + offset, message, bang)
    offset = offset + count - 1
  end
end

M.echo_to_buffer = echo_to_buffer
M.echo_chunks_list_to_buffer = echo_chunks_list_to_buffer

return M
