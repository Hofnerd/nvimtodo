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

  local strs = {}

  local stat, err = vim.loop.fs_stat(gfile)
  if type(stat) == "string" then
    table.insert(strs, stat)
  else
    table.insert(strs, err)
  end

  stat, err = vim.loop.fs_stat(lfile)
  if type(stat) == "string" then
    table.insert(strs, stat)
  else
    table.insert(strs, err)
  end


  table.insert(strs, "Test123")
  table.insert(strs, "test123")
  table.insert(strs, "- [ ] test123")
  table.insert(strs, gfile)
  table.insert(strs, lfile)

  box.show_box(strs, {})
end

return M
