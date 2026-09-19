local M = {}

local box = require('nvimtodo.box')

function M.setup(opts)
  box.show_box({ "Test123", "test123" }, {})
  print("My plugin is loaded test")
  --print(opts)
end

return M
