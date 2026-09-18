-- plugin/nvimtodo.lua
-- This file is sourced as Vimscript by Neovim at startup.
-- It does NOT require the plugin eagerly — it just marks us as loaded.

-- Prevent double-loading (standard guard for plugins)
if g:loaded_nvimtodo == v:false then
  let g:loaded_nvimtodo = 1

  -- Optionally register a lazy-load hook here, e.g. via
  -- vim.api.nvim_create_autocmd or vim.schedule. The actual
  -- require('nvimtodo') happens when the user first calls setup().
end
