local BOXAPI = {}

function BOXAPI.show_box(lines, opts)
  opts = opts or {}

  local cur_buf = vim.api.nvim_get_current_win()
  local width = opts.width or math.floor((vim.api.nvim_win_get_width(cur_buf) * 0.8) + 0.5)
  local height = opts.height or math.floor((vim.api.nvim_win_get_height(cur_buf) * 0.8) + 0.5)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "Hello!" })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = opts.border or "rounded", -- "single", "double", "rounded", "solid", "shadow"
    style = "minimal",
    title = "To Do List:",
    title_pos = "center",
    zindex = 50,
  })
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:Normal')

  -- Close with <Esc>
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  return win
end

return BOXAPI
