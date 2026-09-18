# Developing a Neovim Plugin: The Basics

This document walks through the fundamentals of writing a Neovim plugin, using
`nvimtodo` — a small todo-list plugin — as the running example. You should
already be comfortable with Lua and using Vim/Neovim.

By the end you'll have a plugin that:

- installs cleanly via any manager
- exposes a `:NvimTodo` command
- shows its todo list in a floating window
- persists todos to disk as JSON
- has a one-line test

---

## 1. Plugin Directory Layout

A Neovim plugin is just a directory (usually a git repo) with a few
conventional subdirectories. Neovim's `:runtimepath` mechanism knows how to
find code inside these locations, so the layout *is* the discovery protocol.

```
nvimtodo/
├── plugin/              # Vimscript entry points (auto-sourced at startup)
│   └── nvimtodo.lua     #   (a .lua file here is sourced as a *script*)
├── lua/                 # Lua modules, require'd by path
│   └── nvimtodo/
│       ├── init.lua      #   main module: require('nvimtodo')
│       ├── state.lua     #   internal module: require('nvimtodo.state')
│       └── view.lua      #   floating-window rendering
├── ftdetect/            # filetype detection (ftplugin-style)
│   └── nvimtodo.vim    #   sets `&filetype` for todo buffers
├── syntax/              # syntax highlighting for the todo buffer
│   └── nvimtodo.vim
├── doc/                 # help files (viewed with :help nvimtodo)
│   └── nvimtodo.txt
├── tests/               # plenary.nvim test files
│   └── test.lua
├── .gitignore
└── README.md
```

**Why `plugin/` and `lua/` are special:**

- **`plugin/`** — Neovim auto-sources every file in `plugin/` on startup
  (unless `:set nocompatible` or the plugin is disabled). This is the
  *bootstrap* layer. You typically put a small file here whose only job is
  to set up lazy-loading and defer the real work to Lua.
- **`lua/`** — added to `require`'s search path. A file at
  `lua/nvimtodo/init.lua` is loaded on first `require('nvimtodo')`.
  Neovim does **not** auto-source this; it's pulled in on demand.
- **`ftdetect/`** — sourced when a buffer is opened; used to set
  `&filetype` so syntax and `ftplugin` files apply.
- **`syntax/`** — loaded when `&filetype` matches the filename.
- **`doc/`** — help pages. `:help nvimtodo` finds `doc/nvimtodo.txt`.

> [!NOTE]
> You don't need all of these. A minimal plugin is just `lua/<name>/init.lua`
> and `plugin/<name>.lua`. The rest is added as the plugin grows.

---

## 2. Entry Points

How does Neovim find your plugin? There are three common mechanisms:

| Mechanism | How it works |
|---|---|
| **`:runtimepath`** | `vim.o.rtp` lists directories; `plugin/` and `lua/` inside each are searched automatically |
| **`packadd`** | `:packadd nvimtodo` loads a local plugin by name (used in dev/test) |
| **lazy.nvim / vimpack** | Managers that `:packadd` your repo and manage its lifecycle |

For a user installing `nvimtodo` via lazy.nvim, the config looks like:

```lua
-- lazy.nvim spec
require('lazy').setup({
  { 'yourname/nvimtodo',
    config = function()
      require('nvimtodo').setup({})
    end,
  },
})
```

vimpack (Neovim's built-in `:packadd`-based manager) just needs the repo URL:

```vim
" vimpack config
packadd nvimtodo
```

### The two classic entry points

**`plugin/nvimtodo.lua`** — the Vimscript bootstrap. Despite the `.lua`
extension, this file is *sourced as Vimscript* by Neovim's startup process.
Its job is to defer everything to Lua:

```lua
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
```

**`lua/nvimtodo/init.lua`** — the real module. This is what
`require('nvimtodo')` resolves to. It's only loaded when someone calls
`require('nvimtodo')` for the first time.

> [!TIP]
> The lazy-loading pattern: `plugin/` does almost nothing (sets a guard,
> maybe registers an autocmd). The heavy work lives in `lua/` and is pulled
> in on first `require()`. This keeps startup fast and avoids loading code
> the user never calls.

---

## 3. Defining a Lua Module

The core of the plugin is `lua/nvimtodo/init.lua`. The convention is:

1. Create a local table `M` (or `local M = {}`).
2. Attach functions to it.
3. `return M` at the bottom.

```lua
-- lua/nvimtodo/init.lua
local M = {}

--- Add a todo item.
---@param text string
function M.add(text)
  -- implementation in state.lua
  local state = require('nvimtodo.state')
  state.add(text)
end

--- List all todos.
function M.list()
  local state = require('nvimtodo.state')
  return state.all()
end

return M
```

**The `require()` convention:**

- `require('nvimtodo')` → looks for `lua/nvimtodo/init.lua` on
  `vim.o.rtp`.
- `require('nvimtodo.state')` → looks for `lua/nvimtodo/state.lua`.
- `require('nvimtodo.view')` → looks for `lua/nvimtodo/view.lua`.

Neovim's `require` is the standard Lua `require`, but with the runtimepath
prepended. If a module is required twice, the second call returns the
cached table — so `M` is a singleton per session.

**Internal modules** (like `state.lua`) follow the same pattern:

```lua
-- lua/nvimtodo/state.lua
local M = {}

local todos = {}

function M.add(text)
  todos[#todos + 1] = { text = text, done = false }
end

function M.all()
  return todos
end

return M
```

---

## 4. Configuration

The standard pattern for a configurable plugin:

1. Define a `defaults` table inside the module.
2. Expose a `setup()` function that merges user config into defaults.
3. The user calls `require('nvimtodo').setup({...})` in their init.

```lua
-- lua/nvimtodo/init.lua (continued)

local defaults = {
  data_dir = vim.fn.stdpath('data') .. '/nvimtodo',
  win_position = 'bottom',   -- 'bottom' | 'top' | 'float'
  win_width = 60,
  win_height = 15,
}

local config = nil  -- set by setup()

--- Configure nvimtodo.
---@param user_config table?
function M.setup(user_config)
  -- Merge user config into defaults (shallow merge)
  config = vim.tbl_deep_extend('force', defaults, user_config or {})

  -- Register user commands (see section 5)
  M._register_commands()

  -- Fire a User event so other plugins can hook in
  vim.api.nvim_exec_autocmd('User', {
    pattern = 'NvimTodoReady',
    data = { config = config },
    desc = 'nvimtodo: configuration complete',
  })
end

--- Get the active config (for internal use).
function M.get_config()
  if not config then
    M.setup({})
  end
  return config
end
```

The user's init file:

```lua
-- user's init.lua
require('nvimtodo').setup({
  win_position = 'float',
  win_width = 50,
})
```

> [!NOTE]
> `vim.tbl_deep_extend('force', defaults, user_config)` does a deep merge:
> user values override defaults, but missing keys are preserved. Use
> `'keep'` mode if you want defaults to win on conflict.

---

## 5. User Commands

Register `:NvimTodo` with `vim.api.nvim_create_user_command`. The command
name is the first argument; the callback receives an `opts` table with
`opts.args` (the raw string after the command) and `opts.count`.

```lua
-- lua/nvimtodo/init.lua (continued)

local api = vim.api

function M._register_commands()
  api.nvim_create_user_command('NvimTodo', function(opts)
    local args = vim.split(opts.args, '%s+', { empty = false })
    local sub = args[1]

    if sub == 'add' then
      local text = table.concat(args, ' ', 2)  -- everything after 'add'
      if text == '' then
        vim.notify('Usage: :NvimTodo add <text>', vim.log.levels.WARN)
        return
      end
      M.add(text)
      vim.notify('Added: ' .. text)

    elseif sub == 'list' then
      local todos = M.list()
      for i, t in ipairs(todos) do
        local mark = t.done and '[x]' or '[ ]'
        print(string.format('%s %s', mark, t.text))
      end

    elseif sub == 'done' then
      local state = require('nvimtodo.state')
      state.mark_done(args[2])  -- mark by index
      vim.notify('Marked done.')

    else
      vim.notify('Unknown subcommand: ' .. (sub or ''), vim.log.levels.WARN)
    end
  end, {
    nargs = '*',   -- accepts 0+ args
    complete = 'custom:v:lua.require("nvimtodo")._complete',
  })
end

-- Simple completion for subcommands
function M._complete(arg, line)
  local subs = { 'add', 'list', 'done' }
  local matches = {}
  for _, s in ipairs(subs) do
    if s:sub(1, #arg) == arg then
      matches[#matches + 1] = s
    end
  end
  return matches
end
```

Usage:

```
:NvimTodo add Buy milk
:NvimTodo list
:NvimTodo done 1
```

---

## 6. Keymaps

Use `vim.keymap.set` to bind keys. The first argument is the mode
(`'n'`, `'i'`, `'v'`, etc.).

```lua
-- lua/nvimtodo/init.lua (continued)

function M._register_keymaps()
  -- Global: open the todo list anywhere
  vim.keymap.set('n', '<leader>t', function()
    require('nvimtodo.view').toggle()
  end, { desc = 'Toggle nvimtodo' })

  -- Buffer-local: only active in a nvimtodo buffer
  -- (set when the todo buffer is opened, see section 8)
  vim.keymap.set('n', 'd', function()
    require('nvimtodo.state').mark_done_at_cursor()
  end, { buffer = 0, desc = 'Mark done' })
end
```

**Global vs. buffer-scoped:**

- `vim.keymap.set('n', 'key', fn)` — global, active in every buffer.
- `vim.keymap.set('n', 'key', fn, { buffer = 0 })` — buffer-local;
  `buffer = 0` means "the current buffer" (the one that was current
  when the keymap was set). Use this for keys that only make sense
  inside the todo list.

> [!TIP]
> Register buffer-local keymaps *after* you create the buffer (see section
> 8), so `buffer = 0` refers to the right buffer.

---

## 7. Autocommands

Neovim's `vim.api.nvim_create_autocmd` works with both built-in events
(`BufEnter`, `VimEnter`, `CursorHold`, …) and custom `User` events.

### (a) Listening for built-in events

```lua
-- lua/nvimtodo/init.lua (continued)

local api = vim.api

function M._register_autocmds()
  -- Show a hint on first buffer entry
  api.nvim_create_autocmd('BufEnter', {
    pattern = '*.txt',  -- or any pattern
    callback = function()
      -- e.g. auto-open todo list on certain filetypes
    end,
  })

  -- Save state when the editor is ready
  api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      local state = require('nvimtodo.state')
      state.load()  -- load from disk
    end,
  })
end
```

### (b) Firing custom `User` events

This lets *other* plugins hook into your lifecycle:

```lua
-- Fire when setup() completes (see section 4)
api.nvim_exec_autocmd('User', {
  pattern = 'NvimTodoReady',
  data = { config = config },
  desc = 'nvimtodo: setup complete',
})

-- Fire when a todo is added
api.nvim_exec_autocmd('User', {
  pattern = 'NvimTodoItemAdded',
  data = { text = text },
  desc = 'nvimtodo: item added',
})
```

Other plugins can then listen:

```lua
-- in another plugin
vim.api.nvim_create_autocmd('User', {
  pattern = 'NvimTodoItemAdded',
  callback = function(args)
    -- args.data.text is the new item
    print('nvimtodo added: ' .. args.data.text)
  end,
})
```

> [!NOTE]
> `nvim_exec_autocmd` (imperative) runs the autocmds *synchronously* and
> returns. Use it for "fire and forget" lifecycle events. For
> buffer-scoped events where you want the autocmd to persist, use
> `nvim_create_autocmd` with `add = true`.

---

## 8. Text Properties / UI

A todo plugin needs somewhere to show its list. Two common approaches:

### Dedicated buffer

Create a scratch buffer and write the todo list into it:

```lua
-- lua/nvimtodo/view.lua
local M = {}

local buf = nil

function M.open()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_set_current_buf(buf)
    return
  end

  buf = vim.api.nvim_create_buf(false, true)  -- scratch, not listed
  vim.api.nvim_buf_set_name(buf, '[nvimtodo]')
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'nvimtodo')

  -- Render initial content
  M.render()

  -- Set up buffer-local keymaps (see section 6)
  vim.api.nvim_set_current_buf(buf)
  local state = require('nvimtodo.state')
  vim.keymap.set('n', 'd', function()
    state.mark_done_at_cursor()
    M.render()
  end, { buffer = buf })
end

function M.render()
  if not buf then return end
  local todos = require('nvimtodo.state').all()
  local lines = {}
  for i, t in ipairs(todos) do
    local mark = t.done and '[x]' or '[ ]'
    lines[#lines + 1] = string.format('%d. %s %s', i, mark, t.text)
  end
  if #lines == 0 then
    lines[1] = '(no todos)'
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

return M
```

### Floating window

For a non-intrusive overlay:

```lua
-- lua/nvimtodo/view.lua (continued)

function M.toggle_float()
  local win = vim.api.nvim_open_win(0, false, {
    relative = 'editor',
    border = 'single',
    style = 'float',
    width = 60,
    height = 15,
    row = 2,
    col = 2,
  })
  vim.api.nvim_set_current_win(win)
  -- Write content into the float window's buffer
  local todos = require('nvimtodo.state').all()
  local lines = {}
  for i, t in ipairs(todos) do
    local mark = t.done and '[x]' or '[ ]'
    lines[#lines + 1] = string.format('%d. %s %s', i, mark, t.text)
  end
  vim.api.nvim_win_set_text(win, lines)
end
```

> [!TIP]
> A dedicated buffer is simpler and integrates with `:b`, `:bd`, and
> window management. A floating window is better for a quick-glance
> overlay. Many todo plugins offer both — a `:NvimTodo` command opens
> the buffer, `<leader>t` toggles the float.

---

## 9. State Persistence

Store todos as JSON in the user's data directory:

```lua
-- lua/nvimtodo/state.lua (continued)

local M = {}

local DATA_DIR = nil
local todos = {}

local function _data_path()
  if not DATA_DIR then
    DATA_DIR = vim.fn.stdpath('data') .. '/nvimtodo'
    vim.fn.mkdir(DATA_DIR, 'p')  -- create dirs recursively
  end
  return DATA_DIR .. '/todos.json'
end

--- Load todos from disk.
function M.load()
  local path = _data_path()
  if vim.fn.filereadable(path) == 1 then
    local ok, data = pcall(vim.fn.jsondecode, vim.fn.readfile(path)[1])
    if ok and type(data) == 'table' then
      todos = data
    end
  end
end

--- Save todos to disk.
function M.save()
  local path = _data_path()
  vim.fn.writefile({ vim.fn.jsonencode(todos) }, path)
end

function M.add(text)
  todos[#todos + 1] = { text = text, done = false }
  M.save()
end

function M.all()
  return todos
end

function M.mark_done_at_cursor()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local idx = line  -- 1-based line number == 1-based index
  if todos[idx] then
    todos[idx].done = true
    M.save()
  end
end

return M
```

> [!NOTE]
> `vim.fn.jsonencode` / `vim.fn.jsondecode` are the built-in JSON
> functions. For more complex needs, `lspkind` or a dedicated JSON
> library works too, but for a todo list the built-ins are sufficient.

---

## 10. Testing

Use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for tests.
A minimal test file:

```lua
-- tests/test.lua
local nvimtodo = require('nvimtodo')

describe('nvimtodo', function()
  before_each(function()
    -- Reset state between tests
    require('nvimtodo.state').clear()
  end)

  it('adds a todo', function()
    nvimtodo.add('test item')
    local todos = nvimtodo.list()
    assert.equal(1, #todos)
    assert.equal('test item', todos[1].text)
    assert.is_false(todos[1].done)
  end)

  it('persists to disk', function()
    nvimtodo.add('persisted')
    local state = require('nvimtodo.state')
    state.save()
    state.load()
    assert.equal(1, #state.all())
  end)
end)
```

Run with:

```sh
nvim --headless -c "PlenaryBustedDirectory tests/ ./tests/" -c "qa!"
```

Or via `:PlenaryBustedFile tests/test.lua` in an interactive session.

---

## 11. Packaging / Distribution

To make the plugin installable, you need:

### `.gitignore`

```gitignore
# Test artifacts
tests/.plenary/
tests/.plenary_home/

# OS/editor noise
.DS_Store
*.swp
*~
```

### `README.md`

A minimal README with install instructions:

````markdown
# nvimtodo

A todo-list plugin for Neovim.

## Install

### lazy.nvim

```lua
require('lazy').setup({
  { 'yourname/nvimtodo',
    config = function()
      require('nvimtodo').setup({})
    end,
  },
})
```

### vimpack

```vim
packadd nvimtodo
```

## Usage

```
:NvimTodo add Buy milk
:NvimTodo list
:NvimTodo done 1
```

## Keymaps

| Key | Action |
|---|---|
| `<leader>t` | Toggle todo list |
| `d` (in todo buffer) | Mark done |
````

### Manager notes

- **lazy.nvim** — just needs the repo URL (`'yourname/nvimtodo'`). It
  `:packadd`s the repo, runs your `config` function, and you're done.
- **vimpack** — `:packadd nvimtodo` loads by name; no config function
  needed (your `setup()` is called by the user in their init).
- **`:runtimepath`** — users can add `~/dev/nvimtodo` to `vim.o.rtp`
  for development. Your `plugin/` and `lua/` directories are picked up
  automatically.

> [!TIP]
> Tag releases (`git tag v0.1.0`) so managers can pin versions. Most
> managers default to the latest tag or `HEAD` if no tags exist.

---

## Putting It All Together

The full `init.lua` for `nvimtodo`:

```lua
-- lua/nvimtodo/init.lua
local M = {}

local defaults = {
  data_dir = vim.fn.stdpath('data') .. '/nvimtodo',
  win_position = 'bottom',
  win_width = 60,
  win_height = 15,
}

local config = nil

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', defaults, user_config or {})
  M._register_commands()
  M._register_keymaps()
  M._register_autocmds()

  vim.api.nvim_exec_autocmd('User', {
    pattern = 'NvimTodoReady',
    data = { config = config },
    desc = 'nvimtodo: setup complete',
  })
end

function M.add(text)
  require('nvimtodo.state').add(text)
end

function M.list()
  return require('nvimtodo.state').all()
end

function M.get_config()
  if not config then M.setup({}) end
  return config
end

function M._register_commands()
  vim.api.nvim_create_user_command('NvimTodo', function(opts)
    local args = vim.split(opts.args, '%s+', { empty = false })
    local sub = args[1]
    if sub == 'add' then
      M.add(table.concat(args, ' ', 2))
    elseif sub == 'list' then
      for i, t in ipairs(M.list()) do
        print(string.format('%s %s', t.done and '[x]' or '[ ]', t.text))
      end
    elseif sub == 'done' then
      require('nvimtodo.state').mark_done_at_cursor()
    end
  end, { nargs = '*' })
end

function M._register_keymaps()
  vim.keymap.set('n', '<leader>t', function()
    require('nvimtodo.view').open()
  end, { desc = 'Toggle nvimtodo' })
end

function M._register_autocmds()
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      require('nvimtodo.state').load()
    end,
  })
end

return M
```

That's the whole plugin. Every section above maps to a real file in the
tree. Add features (editing, filtering, multiple lists) by extending
`state.lua` and `view.lua` — the entry points, config, and command
registration stay the same.
