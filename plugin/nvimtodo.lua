vim.api.nvim_create_autocmd('VimEnter', {
  pattern = "*",
  callback = function()
    require('nvimtodo').setup(vim.g.nvimtodo or {})
  end,
  once = true,
})
