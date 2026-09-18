# Developing a Neovim Plugin: A Practical Guide

This guide walks through the anatomy of a real Neovim plugin, using **nvimtodo** — a small todo-list plugin — as the running example. Every section shows the pattern you'd use for any plugin; swap the todo-list specifics for your own feature.

The final artifact: `:NvimTodo add`, `:NvimTodo list`, `:NvimTodo done` commands, a buffer-scoped keymap, persisted state in `stdpath('data')`, and a test suite.

---

## 1. Plugin Directory Layout

Neovim follows a conventional directory layout. A plugin repo looks like this:

```
nvimtodo/
├── plugin/
│   └── nvimtodo.lua          # Vimscript/Lua bootstrap (sourced by Neovim at startup)
├── lua/
│   └── nvimtodo/
│       ├── init.lua           # main module: setup(), public API
│       ├── state.lua          # internal: persistence, data model
│       └── window.lua         # internal: UI (dedicated buffer / float)
├── ftdetect/
│   └── nvimtodo.vim          # sets filetype for nvimtodo buffers
├── syntax/
│   └── nvimtodo.vim          # syntax highlighting for the todo buffer
├── doc/
│   └── nvimtodo.txt          # Vimdoc help (generated or hand-written)
├── tests/
│   ├── .github/               # CI config (optional)
│   └── test.lua               # plenary.nvim tests
├── .gitignore
├── README.md
└── Makefile                   # optional: test, lint, pack targets
```

What goes where:

| Directory | Purpose |
|---|---|
| `plugin/` | **Entry points.** Sourced automatically by Neovim at startup. Keep it tiny — just lazy-load wiring. |
| `lua/` | Your actual plugin code, organized as Lua modules. `lua/nvimtodo/init.lua` is the module root. |
| `ftdetect/` | Files that set `&filetype` when a buffer matching a pattern is opened. |
| `syntax/` | Syntax files that define highlighting rules for your filetype. |
| `doc/` | Vimdoc-format help (`:help nvimtodo` reads `doc/nvimtodo.txt`). |
| `tests/` | Test files, typically using `plenary.nvim` or `luacheck`. |

Two rules of thumb:

1. **`plugin/` is for discovery, not logic.** Everything substantive lives in `lua/`.
2. **`lua/` mirrors your module namespace.** `lua/nvimtodo/state.lua` is `require('nvimtodo.state')`.

---

## 2. Entry Points

Neovim discovers plugins by sourcing files in `plugin/` during startup. For a Lua-first plugin, you want a **lazy-load pattern**: the `plugin/` file registers an `autoload` hook so your Lua code only loads when the user actually uses the plugin.

### The bootstrap: `plugin/nvimtodo.lua`

```lua
-- plugin/nvimtodo.lua
-- Sourced by Neovim at startup. Keep this as small as possible.

-- Only load the module on first use (VimEnter or first command).
vim.api.nvim_create_autocmd('VimEnter', {
  pattern = '*',
  callback = function()
    -- Lazy-load: require() the module only now.
    require('nvimtodo').setup(vim.g.nvimtodo or {})
  end,
  once = true,
})

-- Register commands lazily so :NvimTodo works even before VimEnter fires
-- (e.g. in a headless script). The command body defers to the module.
vim.api.nvim_create_user_command('NvimTodo', function(cmd)
  require('nvimtodo').handle_command(cmd.fargs, cmd.usages)
end, {
  nargs = '+',
  complete = 'custom:v:lua.require("nvimtodo").complete',
  subcommands = { 'add', 'list', 'done', 'setup' },
})
```

### The module root: `lua/nvimtodo/init.lua`

This is the file users `require()`. It exposes `setup()`, the command dispatcher, and any other public API.

```lua
-- lua/nvimtodo/init.lua
local M = {}

-- (full implementation in section 3)
return M
```

### Why two files?

- `plugin/nvimtodo.lua` is **sourced by Neovim** (it's in the `plugin/` directory, which Neovim auto-sources). It's the "wiring" that makes `:NvimTodo` available.
- `lua/nvimtodo/init.lua` is **required by your code** (and by users). It's the actual implementation.

The lazy-load pattern means: Neovim sources the tiny bootstrap at startup, but your 500-line module only loads when the user runs `:NvimTodo` or `VimEnter` fires. This keeps startup fast.

> [!NOTE]
> In `lazy.nvim` / `packer.nvim` managed installs, the plugin manager often handles the lazy-load wiring for you. But shipping a `plugin/` bootstrap makes the plugin work with `vimpack` and manual installs too.

---

## 3. Defining a Lua Module

A Neovim Lua module is just a Lua file that returns a table. The convention is:

```lua
local M = {}
-- ... functions ...
return M
```

### `lua/nvimtodo/init.lua` — the full module

```lua
-- lua/nvimtodo/init.lua
local M = {}

local defaults = {
  data_dir = vim.fn.stdpath('data') .. '/nvimtodo',
  data_file = 'todos.json',
  open_on_start = false,
}

M.config = {}

---@param opts? table
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', defaults, opts or {})
end

---@param text string
function M.add(text)
  local state = require('nvimtodo.state')
  state.add(text)
  vim.notify('Added: ' .. text)
end

---@param done boolean
function M.list(done)
  local state = require('nvimtodo.state')
  local todos = state.list(done)
  local lines = {}
  for _, t in ipairs(todos) do
    local mark = t.done and '[x]' or '[ ]'
    table.insert(lines, string.format('%s %s', mark, t.text))
  end
  if #lines == 0 then
    vim.notify('No todos.')
    return
  end
  -- Show in a dedicated buffer (see section 8)
  require('nvimtodo.window').show(lines)
end

---@param index number
function M.done(index)
  local state = require('nvimtodo.state')
  state.mark_done(index)
  vim.notify('Marked done.')
end

---@param args string[]
function M.handle_command(args)
  local sub = args[1]
  if sub == 'add' then
    M.add(table.concat(args, ' ', 2))
  elseif sub == 'list' then
    M.list(args[2] == 'done')
  elseif sub == 'done' then
    M.done(tonumber(args[2]) or 1)
  else
    vim.notify('Unknown subcommand: ' .. tostring(sub))
  end
end

---@return string[]
function M.complete(lead)
  local subs = { 'add', 'list', 'done', 'setup' }
  local matches = {}
  for _, s in ipairs(subs) do
    if s:sub(1, #lead) == lead then
      table.insert(matches, s)
    end
  end
  return matches
end

return M
```

### How `require()` works

`require('nvimtodo.state')` searches for `nvimtodo/state.lua` in every directory on `vim.o.rtp` (runtimepath) that contains a `lua/` subdirectory. The dot in the module name maps to a path separator:

```
require('nvimtodo.state')  →  <rtp>/lua/nvimtodo/state.lua
require('nvimtodo')        →  <rtp>/lua/nvimtodo/init.lua
```

The function `require()` returns the table that the file `return`s. Neovim caches modules: after the first `require()`, subsequent calls return the cached table without re-executing the file. This is why `local M = {}` at the top of the file is safe — it runs once.

> [!TIP]
> Use `local M = {}` even in files that only have internal helpers. It makes the module's public API explicit and keeps the `return M` convention uniform.

---

## 4. Configuration

The standard pattern for plugin configuration:

1. Define a `defaults` table with every option and its default value.
2. In `setup()`, merge user options into defaults with `vim.tbl_deep_extend`.
3. Store the result on the module for other functions to read.

```lua
-- lua/nvimtodo/init.lua (excerpt)

local defaults = {
  data_dir = vim.fn.stdpath('data') .. '/nvimtodo',
  data_file = 'todos.json',
  open_on_start = false,
  max_items = 100,
}

M.config = {}

---@param opts? table  User-supplied options.
function M.setup(opts)
  -- 'force' overwrites defaults with user values.
  -- 'keep' would preserve defaults on conflict.
  M.config = vim.tbl_deep_extend('force', defaults, opts or {})
end
```

The user calls it in their `init.lua`:

```lua
-- user's ~/.config/nvim/init.lua
require('nvimtodo').setup({
  data_file = 'my_todos.json',   -- override the default
  open_on_start = true,
})
```

### Why `vim.tbl_deep_extend`?

It recursively merges nested tables. If your defaults have a nested structure:

```lua
local defaults = {
  window = {
    position = 'bottom',
    height = 10,
  },
}
```

and the user passes `{ window = { position = 'top' } }`, the result is:

```lua
{ window = { position = 'top', height = 10 } }
```

`'force'` means user values win on conflict. Use `'keep'` if you want defaults to win.

> [!IMPORTANT]
> Always call `setup()` with `opts or {}` — if the user calls `require('nvimtodo').setup()` with no argument, `opts` is `nil`, and `vim.tbl_deep_extend` will error on a nil table.

---

## 5. User Commands

Neovim's `vim.api.nvim_create_user_command` registers a `:Command` that the user can type. The key fields:

| Field | Meaning |
|---|---|
| `name` | The command name (no `:`). |
| `command` | A function receiving a `cmd` table with `.fargs` (string args), `.bang`, `.user`, `.nargs`, etc. |
| `nargs` | `-1` (any), `0` (none), `1` (one), `?` (optional), `+` (one or more). |
| `subcommands` | Enables `:NvimTodo add` style subcommands. |
| `complete` | Custom completion function. |

```lua
-- Registered in plugin/nvimtodo.lua (the bootstrap)
vim.api.nvim_create_user_command('NvimTodo', function(cmd)
  require('nvimtodo').handle_command(cmd.fargs, cmd.usages)
end, {
  nargs = '+',
  subcommands = { 'add', 'list', 'done' },
  complete = 'custom:v:lua.require("nvimtodo").complete',
})
```

This gives the user:

```vim
:NvimTodo add Buy groceries
:NvimTodo list
:NvimTodo list done
:NvimTodo done 1
```

The `cmd.fargs` table contains the raw arguments as strings: `{'add', 'Buy', 'groceries'}`. Your `handle_command` dispatches on the first arg.

> [!TIP]
> For subcommands, use the `subcommands` field rather than parsing `cmd.fargs[1]` inside the command function. Neovim will auto-complete subcommands and show an error for unknown ones.

---

## 6. Keymaps

`vim.keymap.set` binds a key to a function or command. The first argument is the **mode**: `'n'` (normal), `'i'` (insert), `'v'` (visual), `'c'` (command-line), or a comma-separated list like `'nv'`.

### Buffer-scoped vs global

```lua
-- Global: works in every buffer
vim.keymap.set('n', '<leader>t', function()
  vim.cmd('NvimTodo list')
end, { noremap = true, silent = true, desc = 'Open todo list' })

-- Buffer-scoped: only in nvimtodo buffers
-- (set from within a buffer's autocmd or setup)
local buf = vim.api.nvim_get_current_buf()
vim.keymap.set('n', '<leader>a', function()
  local text = vim.fn.input('Add todo: ')
  if text ~= '' then
    vim.cmd('NvimTodo add ' .. vim.fn.shellescape(text))
  end
end, { buffer = buf, noremap = true, silent = true, desc = 'Quick-add todo' })
```

| Option | Effect |
|---|---|
| `{ buffer = buf }` | Keymap only active in buffer `buf`. |
| `{ noremap = true }` | Don't remap if the user already has this key. |
| `{ silent = true }` | Suppress `:echo` output. |
| `{ desc = '...' }` | Shown in `:help key-notation` and `:verbose noremap`. |

### When to set buffer-scoped keymaps

In a `BufEnter` or `BufRead` autocmd for your filetype:

```lua
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*.todo',
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    vim.keymap.set('n', '<CR>', function()
      -- toggle done in the todo buffer
    end, { buffer = buf })
  end,
})
```

This ensures the keymap is only created when the user actually opens a todo buffer.

---

## 7. Autocommands

Neovim's autocommand system lets you react to events. Two directions matter for a plugin:

### Listening to built-in events

```lua
-- lua/nvimtodo/init.lua
local State = require('nvimtodo.state')

---@param opts? table
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', defaults, opts or {})

  if M.config.open_on_start then
    vim.api.nvim_create_autocmd('VimEnter', {
      pattern = '*',
      callback = function()
        M.list(false)
      end,
      once = true,
    })
  end
end
```

Common events you'll listen to:

| Event | When it fires |
|---|---|
| `VimEnter` | After Neovim has fully started. |
| `BufEnter` | When a buffer is displayed. |
| `BufRead` | When a file is read into a buffer. |
| `TextChanged` | When the buffer content changes. |
| `CursorHold` | When the cursor is idle (for lazy UI updates). |

### Firing custom `User` events

Plugins should fire `User` events so other plugins (or the user's config) can react:

```lua
-- lua/nvimtodo/init.lua
local State = require('nvimtodo.state')

function M.add(text)
  State.add(text)
  -- Fire a User event: :autocmd User NvimTodoAdd
  vim.cmd('autocmd User NvimTodoAdd')
end
```

The user (or another plugin) can then listen:

```lua
-- In the user's init.lua
vim.api.nvim_create_autocmd('User', {
  pattern = 'NvimTodoAdd',
  callback = function()
    vim.notify('A todo was added!')
  end,
})
```

> [!NOTE]
> `vim.cmd('autocmd User NvimTodoAdd')` is the classic way to fire a User event. In Neovim 0.10+, `vim.api.nvim_exec_autocmd` is the API equivalent:
>
> ```lua
> vim.api.nvim_exec_autocmd('User', 'NvimTodoAdd', {})
> ```
>
> Both work; the `vim.cmd` form is more widely recognized.

---

## 8. Text Properties / UI

A todo-list plugin needs a place to show the list. Two common approaches:

### Dedicated buffer

Create a scratch buffer with a unique name and set its properties:

```lua
-- lua/nvimtodo/window.lua
local M = {}

function M.show(lines)
  -- Reuse an existing nvimtodo buffer if one is open
  local buf = M._buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf({
      listed = false,       -- won't appear in :ls
      buftype = 'nofile',   -- not backed by a file
      bufhidden = 'wipe',   -- delete when hidden
      modifiable = true,
    })
    M._buf = buf
  end

  -- Set the lines
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set filetype and syntax
  vim.api.nvim_buf_set_name(buf, '[NvimTodo]')
  vim.bo[buf].filetype = 'nvimtodo'

  -- Show it in a vertical split
  local win = vim.api.nvim_open_win(buf, false, {
    split = 'vertical',
    relative = 'editor',
  })

  vim.api.nvim_set_current_win(win)
end

return M
```

The `ftdetect/nvimtodo.vim` file then sets the filetype:

```vim
" ftdetect/nvimtodo.vim
if expand('%:t') == '[NvimTodo]'
  setf nvimtodo
endif
```

And `syntax/nvimtodo.vim` provides highlighting:

```vim
" syntax/nvimtodo.vim
syn match TodoDone     '^\[x\]'
syn match TodoPending '^\[ \]'
syn match TodoText     '^\[.\] .*'
hi link TodoDone     Comment
hi link TodoPending  Special
hi link TodoText     Normal
```

### Floating window

For a more transient UI (e.g. a quick-add popup), use `nvim_open_win`:

```lua
local rows = vim.o.lines
local cols = vim.o.columns

local win = vim.api.nvim_open_win(vim.api.nvim_create_buf({
  bufhidden = 'wipe',
}), false, {
  relative = 'editor',
  border = 'singleline',
  width = math.floor(cols * 0.5),
  height = math.floor(rows * 0.4),
  row = math.floor(rows * 0.3),
  col = math.floor(cols * 0.25),
})

-- Use insert mode for quick input
vim.cmd('startinsert')
```

Choose **dedicated buffer** for a persistent todo list; **floating window** for transient popups.

---

## 9. State Persistence

Store data under `vim.fn.stdpath('data')` — this is the per-user data directory (e.g. `~/.local/share/nvim` on Linux, `~/Library/Application Support/nvim` on macOS).

```lua
-- lua/nvimtodo/state.lua
local M = {}

local data_dir
local data_file

local function ensure_dir()
  if not vim.fn.isdirectory(data_dir) then
    vim.fn.mkdir(data_dir, 'p')  -- recursive
  end
end

local function load()
  if vim.fn.filereadable(data_file) == 0 then
    return {}
  end
  local f = assert(io.open(data_file, 'r'))
  local content = f:read('a')
  f:close()
  if content == '' then
    return {}
  end
  return vim.json.decode(content)
end

local function save(todos)
  ensure_dir()
  local f = assert(io.open(data_file, 'w'))
  f:write(vim.json.encode(todos))
  f:close()
end

function M.init(config)
  data_dir = config.data_dir
  data_file = config.data_dir .. '/' .. config.data_file
end

function M.add(text)
  local todos = load()
  table.insert(todos, { text = text, done = false, created = os.date('%Y-%m-%dT%H:%M:%S') })
  save(todos)
end

function M.list(only_done)
  local todos = load()
  if not only_done then
    return todos
  end
  local out = {}
  for _, t in ipairs(todos) do
    if t.done then table.insert(out, t) end
  end
  return out
end

function M.mark_done(index)
  local todos = load()
  if todos[index] then
    todos[index].done = true
    save(todos)
  end
end

return M
```

The JSON file looks like:

```json
[
  { "text": "Buy groceries", "done": false, "created": "2025-06-01T10:30:00" },
  { "text": "Ship report",   "done": true,  "created": "2025-06-01T09:00:00" }
]
```

> [!IMPORTANT]
> Use `io.open` / `io.write` for file I/O, not `vim.fn.writefile` — the latter writes a *list of lines* and mangles JSON. `vim.json.encode` / `vim.json.decode` handle the serialization.

---

## 10. Testing

Use **`plenary.nvim`** (a test framework) and **`plenary.nvim`'s `nvim` test runner**. Install it as a dev dependency:

```lua
-- .github/workflows/test.yml (or a Makefile target)
-- plenary.nvim is a dev-only dependency, not a runtime dep.
```

In your `lazy.json` / `lazy-lock.json`:

```lua
-- dev dependencies (in lazy.nvim config)
{ 'luapeople/plenary.nvim',      tag = 'v0.1.6' },
{ 'nvim-lua/plenary.nvim',       tag = 'v0.1.6' },
```

A minimal test file:

```lua
-- tests/test.lua
local assert = require('luassert')  -- bundled with plenary
local pending = require('plenary.test')

pending.test('nvimtodo.add', function()
  -- Arrange
  require('nvimtodo').setup({
    data_dir = vim.fn.tempname(),
    data_file = 'test.json',
  })
  require('nvimtodo.state').init(require('nvimtodo').config)

  -- Act
  require('nvimtodo').add('Test todo')

  -- Assert
  local todos = require('nvimtodo.state').list(false)
  assert.equals(1, #todos)
  assert.equals('Test todo', todos[1].text)
  assert.falsy(todos[1].done)
end)

pending.test('nvimtodo.mark_done', function()
  require('nvimtodo').setup({
    data_dir = vim.fn.tempname(),
    data_file = 'test.json',
  })
  require('nvimtodo.state').init(require('nvimtodo').config)
  require('nvimtodo').add('To be done')

  require('nvimtodo').done(1)

  local todos = require('nvimtodo.state').list(false)
  assert.truthy(todos[1].done)
end)
```

Run with:

```bash
# From the repo root
nvim --headless -c "PlenaryBustedFile tests/test.lua" -c "qa!"
```

Or in CI:

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nvimdev/neotest-github-action@v1
        with:
          nvim-version: 'latest'
          test-command: |
            nvim --headless -c "PlenaryBustedFile tests/test.lua" -c "qa!"
```

> [!TIP]
> Use `vim.fn.tempname()` in tests so each test run gets a fresh data directory. Never let tests write to the user's real `stdpath('data')`.

---

## 11. Packaging / Distribution

### `.gitignore`

```gitignore
# Test artifacts
tests/.plenary/
*.swp
*.swo

# Build artifacts (if you use make/lua)
lua/*.luajit
*.o
*.so

# IDE
.vscode/
.idea/
```

### `README.md` — minimal

```markdown
# nvimtodo

A minimal todo-list plugin for Neovim.

## Requirements

- Neovim >= 0.10

## Installation

### lazy.nvim

```lua
{ 'yourname/nvimtodo',
  config = true,          -- auto-calls setup()
  opts = {
    open_on_start = true,
  },
}
```

### vimpack (manual)

```bash
git clone https://github.com/yourname/nvimtodo.git \
  ~/.local/share/nvim/site/pack/plugins/start/nvimtodo
```

## Usage

```vim
:NvimTodo add Buy groceries
:NvimTodo list
:NvimTodo list done
:NvimTodo done 1
```

## Configuration

```lua
require('nvimtodo').setup({
  data_file = 'todos.json',
  open_on_start = false,
})
```

## Keymaps

| Key | Action |
|---|---|
| `<leader>t` | Open todo list |

## License

MIT
```

### `lazy.nvim` install

Users who use `lazy.nvim` add to their `lazy-lock.json` or `init.lua`:

```lua
-- ~/.config/nvim/lazy-lock.json (managed by lazy.nvim)
{
  "nvimtodo": { "commit": "abc1234" }
}
```

Or in `init.lua`:

```lua
require('lazy').setup({
  { 'yourname/nvimtodo',
    config = true,       -- calls require('nvimtodo').setup() with opts below
    opts = {
      open_on_start = true,
    },
  },
})
```

`lazy.nvim` will clone the repo, and because `plugin/nvimtodo.lua` exists, the bootstrap is sourced. The `config = true` flag tells lazy.nvim to call `setup()` with the `opts` table.

### `vimpack` (manual) install

```bash
# Install to a pack path
git clone https://github.com/yourname/nvimtodo.git \
  ~/.local/share/nvim/site/pack/plugins/start/nvimtodo

# Neovim auto-detects it at startup (plugin/ is in the rtp)
```

No `:packadd` needed — Neovim's `pack` option auto-loads from `~/.local/share/nvim/site/pack/`.

### Tagging a release

```bash
git tag -a v0.1.0 -m "Initial release"
git push --tags
```

Users pin to a tag in their `lazy-lock.json`:

```json
{ "nvimtodo": { "commit": "abc1234" } }
```

or use the `branch = 'main'` / `tag = 'v0.1.0'` fields in their lazy.nvim spec.

---

## Summary

| Concern | Where | Key API |
|---|---|---|
| Discovery | `plugin/nvimtodo.lua` | Auto-sourced by Neovim |
| Module | `lua/nvimtodo/init.lua` | `require('nvimtodo')` |
| Config | `M.setup()` | `vim.tbl_deep_extend` |
| Commands | `:NvimTodo` | `nvim_create_user_command` |
| Keymaps | `<leader>t` | `vim.keymap.set` |
| Events | `VimEnter`, `User` | `nvim_create_autocmd`, `nvim_exec_autocmd` |
| UI | Scratch buffer or float | `nvim_create_buf`, `nvim_open_win` |
| State | `stdpath('data')/nvimtodo/` | `io.open` + `vim.json.encode/decode` |
| Tests | `tests/test.lua` | `plenary.nvim` |
| Distribution | Git repo + tag | `lazy.nvim` / `vimpack` |

The pattern is the same for any plugin: a tiny `plugin/` bootstrap for discovery, a `lua/` module tree for logic, `setup()` for configuration, and standard Neovim APIs for commands, keymaps, events, buffers, and persistence. Swap the todo-list specifics for your own feature and the skeleton holds.
