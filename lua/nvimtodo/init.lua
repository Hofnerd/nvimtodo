local M = {}

-- getting the box drawing module
local box = require('nvimtodo.box')

-- Create the filenames for the local and global todo lists
local gfile = ""
local lfile = ""

-- Setup function
function M.setup(opts)
  -- Get the default directories for local and global todo
  local data_dir = vim.fn.stdpath("data")
  local proj_root = vim.fs.root(0, { ".git", "Makefile" })

  -- Set the filenames. either use the opts
  gfile = opts.global_fn or vim.fn.join({ data_dir, "todo.md" }, '/')
  lfile = opts.local_fn or vim.fn.join({ proj_root, "todo.md" }, '/')

  local strs = { gfile, lfile }

  local stat, _ = vim.loop.fs_stat(gfile)
  local io = require("io")
  if stat then
    local file = io.open(gfile, "r")
    local content = ""
    if file then
      content = file:read("*a")
    end
    local lines = vim.fn.split(content, "\n")
    for _, value in ipairs(lines) do
      table.insert(strs, value)
    end
  else
    local file = io.open(gfile, "w")
    if file then
      file:write("-- new TODO file")
      file:close()
    end
  end
  box.show_box(strs, {})
end

return M
