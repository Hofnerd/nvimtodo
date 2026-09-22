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

function M.AddGlobalTodo(todo)
  for _, value in ipairs(todo) do
    local str = vim.fn.join({ "- [ ] ", value }, "")
    table.insert(M.todolist.global_todos, str)
  end
end

function M.AddLocalTodo(todo)
  for _, value in ipairs(todo) do
    local str = vim.fn.join({ "- [ ] ", value }, "")
    table.insert(M.todolist.local_todos, str)
  end
end

function M.SaveGlobalTodos()
  local content = vim.fn.join(M.todolist.global_todos, "\n")
  local io = require("io")
  local file = io.open(gfile, "w")
  if file then
    file:write(content)
    file:close()
  end
end

function M.SaveLocalTodos()
  local content = vim.fn.join(M.todolist.local_todos, "\n")
  local io = require("io")
  local file = io.open(lfile, "w")
  if file then
    file:write(content)
    file:close()
  end
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

function M.DisplayProjectTodos()
  -- figure out how i want to display project todos
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


  -- Setup user commands
  vim.api.nvim_create_user_command("TodoDisplayLists", function(_)
    M.DisplayLists()
  end, {
    desc = "Show both Global and Local TODO lists"
  })

  vim.api.nvim_create_user_command("TodoDisplayGlobal", function(_)
    M.DisplayGlobalList()
  end, {
    desc = "Show Global TODO list"
  })

  vim.api.nvim_create_user_command("TodoDisplayLocal", function(_)
    M.DisplayLocalList()
  end, {
    desc = "Show Local TODO list"
  })

  vim.api.nvim_create_user_command("TodoDisplayProject", function(_)
    M.DisplayProjectTodos()
  end, {
    desc = "Show Local TODO list"
  })

  vim.api.nvim_create_user_command("TodoSaveTodoLists", function(_)
    M.SaveLocalTodos()
    M.SaveGlobalTodos()
  end, {
    desc = "Save both Global and local TODO lists"
  })

  vim.api.nvim_create_user_command("TodoSaveGlobal", function(_)
    M.SaveGlobalTodos()
  end, {
    desc = "Save Global TODO list"
  })

  vim.api.nvim_create_user_command("TodoSaveLocal", function(_)
    M.SaveLocalTodos()
  end, {
    desc = "Save Local TODO list"
  })

  vim.api.nvim_create_user_command("TodoAddLocal", function(args)
    M.AddGlobalTodo(args)
  end, {
    nargs = "*",
    desc = "Add list of todos to Global TODO list"
  })

  vim.api.nvim_create_user_command("TodoAddLocal", function(args)
    M.AddLocalTodo(args)
  end, {
    nargs = "*",
    desc = "Add list of todos to the Local TODO list"
  })
end

return M
