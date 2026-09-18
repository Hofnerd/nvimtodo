local BOXAPI = {}

function BOXAPI.show_box(lines, opts)
  opts = opts or {}
  local width = opts.width or 60
  local height = opts.height or 15

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
    zindex = 50,
  })

  -- Close with <Esc>
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  return win
end

return BOXAPI

-- Usage:
-- show_box({"line 1", "line 2", "line 3"})
