local BOXAPI = {}

-- local resize_timer = nil
--
-- local function on_resize(win)
--   if resize_timer then
--     resize_timer:stop()
--   else
--   end
--   resize_timer = vim.uv.new_timer()
--   resize_timer:start(50, 0, function()
--     resize_timer:stop()
--     resize_timer:close()
--
--   end)
-- end

function BOXAPI.show_box(lines, opts)
  opts = opts or {}

  local cur_buf = vim.api.nvim_get_current_win()
  local width = opts.width or math.floor((vim.api.nvim_win_get_width(cur_buf) * 0.8) + 0.5)
  local height = opts.height or math.floor((vim.api.nvim_win_get_height(cur_buf) * 0.8) + 0.5)

  local buf = vim.api.nvim_create_buf(nil, {
    buftype = 'nofile',
    bufhidden = 'wipe',
  })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "Hello!" })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    border = opts.border or "rounded",
    style = "minimal",
    title = "To Do List:",
    title_pos = "center",
    zindex = 50,
  })
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:Normal')
  vim.api.nvim_command('setlocal ft=markdown')

  --   local winresize = vim.api.nvim_create_autocmd("WinResized", {
  --     pattern = "*",
  --     callback = on_resize(win),
  --   })

  -- Close with <Esc>
  vim.keymap.set("n", "<Esc>", function()
    --    vim.api.nvim_del_autocmd(winresize)
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  return win
end

return BOXAPI
