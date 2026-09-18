local M = {}

require('nvimtodo.box')

function M.setup(opts)
  print("My plugin is loaded")
  print(opts)
end

return M
