local M = {}

-- getting the box drawing module
local box = require('nvimtodo.box')

-- Create the filenames for the local and global todo lists
local gfile = ""
local lfile = ""
M.todolist = { global_todos = {}, local_todos = {} }


local function process_rawfile(content)
  local ret = {}
  local lines = vim.fn.split(content, "\n")
  for _, value in ipairs(lines) do
    if string.find(value, "- %[") then
      table.insert(ret, value)
    end
  end
  return ret
end

function M.DisplayLists()
  -- Figure out how i want to display both lists
end

function M.DisplayGlobalList()
  local list = {}
  for _, value in ipairs(M.todolist.global_todos) do
    table.insert(list, value)
  end

  box.show_box(list, {})
end

function M.DisplayLocalList()
  local list = {}
  for _, value in ipairs(M.todolist.local_todos) do
    table.insert(list, value)
  end

  box.show_box(list, {})
end

-- Setup function
function M.setup(opts)
  local io = require("io")

  -- Get the default directories for local and global todo
  local data_dir = vim.fn.stdpath("data")
  local proj_root = vim.fs.root(0, { ".git", "Makefile" })

  -- Set the filenames. either use the opts
  gfile = opts.global_fn or vim.fn.join({ data_dir, "todo.md" }, '/')
  lfile = opts.local_fn or vim.fn.join({ proj_root, "todo.md" }, '/')

  -- Check if the global file exists. if it does read in the file, else open a new todo file
  local stat, _ = vim.loop.fs_stat(gfile)
  local file = nil

  if stat then
    -- Open the file, grab the content.
    file = io.open(gfile, "r")
    local content = ""
    if file then
      content = file:read("*a")
      file:close()
    end

    -- process the contents of the file
    local todos = process_rawfile(content)
    for _, value in ipairs(todos) do
      table.insert(M.todolist.global_todos, value)
    end
  else
    file = io.open(gfile, "w")
    if file then
      file:write("-- new TODO file")
      file:close()
    end
  end
  -- Check if the local file exists. if it does read in the file
  stat, _ = vim.loop.fs_stat(lfile)
  file = nil

  if stat then
    -- Open the file, grab the content.
    file = io.open(lfile, "r")
    local content = ""
    if file then
      content = file:read("*a")
      file:close()
    end

    -- process the contents of the file
    local todos = process_rawfile(content)
    for _, value in ipairs(todos) do
      table.insert(M.todolist.local_todos, value)
    end
  end


  vim.api.nvim_create_user_command("TodoDisplayLists", function(_)
    M.DisplayLists()
  end, {
    range = false,
    nargs = 0,
    desc = "Show both Global and Local TODO lists"
  })

  vim.api.nvim_create_user_command("TodoDisplayGlobal", function(_)
    M.DisplayGlobalList()
  end, {
    range = false,
    nargs = 0,
    desc = "Show Global TODO list"
  })

  vim.api.nvim_create_user_command("TodoDisplayLocal", function(_)
    M.DisplayLocalList()
  end, {
    range = false,
    nargs = 0,
    desc = "Show Local TODO list"
  })
end

return M
