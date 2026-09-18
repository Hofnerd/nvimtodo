local M = {}

local box = require('nvimtodo.box')

function M.setup(opts)
  box.show_box("Test123")
  print("My plugin is loaded")
  print(opts)
end

return M
