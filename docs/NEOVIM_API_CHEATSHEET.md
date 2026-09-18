# Neovim API Cheatsheet

> Reference sheet for plugin developers. Not a tutorial — keep this open in another tab.
> Snippets are Lua unless noted. Every snippet is 1–5 lines.

---

## 1. `vim.api` — the stable C-API surface

The documented, versioned API. Anything in `vim.api` is guaranteed stable across Neovim releases.

### Buffers

```lua
vim.api.nvim_create_buf({ scratch = true, listed = false })  -- new empty buffer
vim.api.nvim_get_current_buf()                              -- current buffer handle
vim.api.nvim_set_current_buf(buf)                           -- switch buffer
vim.api.nvim_buf_get_lines(buf, 0, -1, false)               -- all lines
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a", "b" }) -- replace all lines
vim.api.nvim_buf_get_var(buf, "my_key")                     -- buffer-local var (b:)
vim.api.nvim_buf_set_var(buf, "my_key", value)              -- set b:my_key
```

```lua
vim.api.nvim_create_namespace("nvimtodo")                   -- namespaced id
vim.api.nvim_get_namespaces()                               -- all live namespaces
```

### Windows

```lua
vim.api.nvim_open_win(buf, false, { relative = "editor", width = 60 })  -- open a window
vim.api.nvim_get_current_win()                                  -- current window handle
vim.api.nvim_set_current_win(win)                              -- switch window
vim.api.nvim_win_get_position(win)                             -- {row, col, h, w}
vim.api.nvim_win_set_config(win, { relative = "editor", col = 2 })
vim.api.nvim_win_get_buf(win)                                 -- buffer shown in window
vim.api.nvim_win_delete(win)                                  -- close window
```

### Commands

```lua
vim.api.nvim_create_user_command("Todo", handler, { nargs = 1 })
vim.api.nvim_create_user_command("Todo", handler, {
  nargs = 1,
  bang = true,        -- handler receives bang
  range = 1,          -- handler receives line1, line2
  complete = "custom",
})
vim.api.nvim_create_user_command("Todo.Done", handler)  -- subcommand
```

### Autocommands

```lua
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.md",
  callback = function() end,
})
vim.api.nvim_exec_autocmd("User", "MyPluginReady")  -- fire a User event
vim.api.nvim_create_autocmd("User", {
  pattern = "MyPluginReady",
  callback = function() end,
})
```

### Keymaps

```lua
vim.api.nvim_set_keymap("n", "<leader>t", ":Todo<cr>", { noremap = true })
vim.api.nvim_buf_set_keymap(buf, "n", "<leader>t", ":Todo<cr>", { noremap = true })
```

### Lines & Cursor

```lua
vim.api.nvim_get_current_line()                     -- current line as string
vim.api.nvim_set_current_line("new text")           -- replace current line
vim.api.nvim_get_current_line()                     -- (same, shown for symmetry)
```

### Mode & Input

```lua
vim.api.nvim_get_mode()                            -- { mode, blocking }
vim.api.nvim_input("i")                           -- feed keys, type into buffer
vim.api.nvim_feedkeys("o", "m", false)             -- feed keys with mode flags
```

### Variables & Options

```lua
vim.api.nvim_get_var("my_global")                  -- g:my_global
vim.api.nvim_set_var("my_global", value)
vim.api.nvim_get_option("number")                 -- get option value
vim.api.nvim_set_option("number", true)           -- set option
```

### Runtime & Info

```lua
vim.api.nvim_get_runtime_dir()                    -- runtime path
vim.api.nvim_get_api_info()                      -- version, channel, features
```

---

## 2. `vim.fn` — Vimscript function bridge

Access Vimscript functions from Lua. Grouped by category.

### File I/O

```lua
vim.fn.fileread("path/to/file")                   -- read file into Lua string
vim.fn.filewrite("path/to/file", "contents")     -- write string to file
vim.fn.expand("<cfile>")                        -- expand <cfile>, <sfile>, etc.
vim.fn.stdpath("data")                          -- stdpath: data, config, state, cache
vim.fn.tempname()                               -- unique temp file path
vim.fn.mkdir("dir/sub", true)                   -- mkdir -p
vim.fn.delete("dir", "rf")                     -- rm -rf
vim.fn.rename("old", "new")                     -- rename file/dir
```

### UI / Dialog

```lua
vim.fn.input("Prompt: ")                       -- prompt for user input
vim.fn.confirm("msg", "&Yes", "&No")           -- modal confirm dialog
vim.fn.dialog("msg", "&OK")                    -- modal dialog
```

### Timers

```lua
local t = vim.fn.timer_start(function() end, 1000)  -- 1s repeating
vim.fn.timer_pause(t)
vim.fn.timer_stop(t)
```

### Jobs & Channels

```lua
vim.fn.jobstart({"echo", "hello"}, { on_exit = function() end })
vim.fn.chan_open({"ncat", "localhost", "8080"})
vim.fn.termopen({"nvim", "file.txt"})
```

### Lines & Positions

```lua
vim.fn.getline(1, 5)                           -- lines 1..5
vim.fn.setline(1, "new")                       -- set line 1
vim.fn.line(".")                              -- current line number
vim.fn.col(".")                                -- current col
```

### Search & Highlight

```lua
vim.fn.search("pattern", "n")                 -- search, return line
vim.fn.match("hello", "h")                    -- regex match
vim.fn.matchadd("hi", { group = "ErrorMsg" }) -- add match, returns id
vim.fn.matchdelete(id)
vim.fn.matchdelete_all()
```

### JSON

```lua
vim.fn.json_encode({ a = 1, b = 2 })         -- Lua table → JSON string
vim.fn.json_decode('{"a":1}')                -- JSON string → Lua table
```

---

## 3. `vim.tbl` / `vim.iter` / `vim.pairs` — utility tables

### `vim.tbl`

```lua
vim.tbl_deep_extend(strategy, t, ...)          -- deep-merge tables
vim.tbl_merge(a, b)                            -- shallow merge
vim.tbl_isempty(t)                            -- #t == 0
vim.tbl_clone(t)                              -- deep copy
vim.tbl_contains(t, v)                       -- linear search
vim.tbl_add(t, v)                             -- append
vim.tbl_pop(t)                                -- remove last, return it
vim.tbl_remove(t, i)                         -- remove at index i
vim.tbl_get(t, k, default)                   -- safe get with default
vim.tbl_get_by(t, k)                         -- get or nil
vim.tbl_get_by_key(t, k)                     -- get by key
vim.tbl_get_by_key_and_value(t, k, v)       -- get if key AND value match
```

### `vim.iter`

```lua
vim.iter.from(1, 5)                           -- 1,2,3,4,5
vim.iter.filter(it, function(x) return x > 2 end)
vim.iter.map(it, function(x) return x * 2 end)
vim.iter.take(it, 3)                         -- first 3 elements
vim.iter.drop(it, 2)                         -- skip first 2
vim.iter.take_while(it, function(x) return x < 10 end)
vim.iter.drop_while(it, function(x) return x < 5 end)
vim.iter.reverse(it)
vim.iter.chain(it1, it2)                     -- concatenate iterators
vim.iter.concat(it, sep)                     -- join into string
vim.iter.to_list(it)                         -- collect into array
vim.iter.to_string(it)                       -- join into string
vim.iter.to_array(it)                        -- same as to_list
vim.iter.to_table(it)                        -- collect into table
vim.iter.to_set(it)                         -- unique values
vim.iter.to_dict(it, function(x) return x end)  -- key→value
vim.iter.to_pairs(it)                        -- pairs
vim.iter.to_kv(it)                           -- key-value pairs
vim.iter.to_kv_pairs(it)                     -- array of {k,v}
vim.iter.to_kv_pairs_by_key(it, k)           -- filter pairs by key
vim.iter.to_kv_pairs_by_value(it, v)         -- filter pairs by value
vim.iter.to_kv_pairs_by_key_and_value(it, k, v)
```

### `vim.pairs`

```lua
vim.pairs({ a = 1, b = 2 })                  -- iterate key-value pairs
```

---

## 4. Autocommands & Events

### Firing a User event

```lua
vim.api.nvim_exec_autocmd("User", "MyPluginReady")
```

### Listening to built-in events

| Event | When it fires |
|---|---|
| `VimEnter` | After startup, before first buffer is read |
| `BufEnter` | When a buffer is displayed in a window |
| `BufNewFile` | When a new file is opened (no prior buffer) |
| `BufReadPost` | After a file is read into a buffer |
| `InsertEnter` | Entering insert mode |
| `InsertLeave` | Leaving insert mode |
| `CursorHold` | Cursor idle for `updatetime` ms |
| `TextChanged` | Text changed in normal mode |
| `TextChangedI` | Text changed in insert mode |
| `ColorScheme` | After `:colorscheme` or `:hi` |
| `FileType` | After file type is detected |
| `Syntax` | After syntax highlighting is set |
| `BufWinEnter` | Buffer is displayed in a window |
| `BufWinLeave` | Buffer is no longer displayed |
| `WinEnter` | Entering a window |
| `WinLeave` | Leaving a window |
| `TabEnter` | Entering a tabpage |
| `TabLeave` | Leaving a tabpage |
| `CmdlineChanged` | Command line changed |
| `InsertCharPre` | Before a character is inserted |
| `InsertCharPost` | After a character is inserted |
| `TextYankPost` | After a yank operation |
| `FuncPre` | Before a Vimscript function is called |
| `FuncPost` | After a Vimscript function is called |
| `SourcePre` | Before a file is sourced |
| `SourcePost` | After a file is sourced |
| `SessionLoadPost` | After `:source session.vim` |

### Registration snippet

```lua
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.md",
  callback = function() end,
})
```

---

## 5. Windows & Layout

The 5–6 most-used for plugin UI:

```lua
vim.api.nvim_open_win(buf, false, { relative = "editor", width = 60 })
vim.api.nvim_get_current_win()
vim.api.nvim_set_current_win(win)
vim.api.nvim_get_current_buf()
vim.api.nvim_set_current_buf(buf)
```

### Full set (less common)

```lua
vim.api.nvim_get_current_tabpage()
vim.api.nvim_set_current_tabpage(tab)
vim.api.nvim_get_tabpage(tab)
vim.api.nvim_set_tabpage(tab)
vim.api.nvim_get_tabpage_line(tab)
vim.api.nvim_set_tabpage_line(tab, line)
vim.api.nvim_get_tabpage_col(tab)
vim.api.nvim_set_tabpage_col(tab, col)
vim.api.nvim_get_tabpage_buf(tab)
vim.api.nvim_set_tabpage_buf(tab, buf)
vim.api.nvim_get_tabpage_name(tab)
vim.api.nvim_set_tabpage_name(tab, name)
vim.api.nvim_get_tabpage_title(tab)
vim.api.nvim_set_tabpage_title(tab, title)
```

---

## 6. Timers & Async

### `vim.uv` (Luv bindings)

```lua
local uv = vim.uv
local timer = uv.new_timer()
timer:start(1000, 0, function()
  timer:stop()
  print("fired")
end)

local check = uv.new_check(function() end)  -- runs every loop
local idle = uv.new_idle(function() end)    -- runs when no other work
```

### `vim.defer_fn`

```lua
vim.defer_fn(function()
  print("after 500ms")
end, 500)
```

### `vim.schedule`

```lua
vim.schedule(function()
  -- runs on next main-loop iteration
end)
```

### `vim.schedule_wrap`

```lua
local wrapped = vim.schedule_wrap(function()
  -- runs on next main-loop iteration
end)
wrapped()
```

### Minimal async HTTP (uv.new_tcp)

```lua
local uv = vim.uv
local conn = uv.new_tcp()
conn:connect("127.0.0.1:8080")
conn:write("GET / HTTP/1.0\r\n\r\n")
conn:read_start(function(err, data)
  if data then print(data) end
  conn:close()
end)
```

---

## 7. Health Checks

Define `lua/nvimtodo/health.lua`:

```lua
local M = {}

function M.check()
  vim.cmd("checkhealth nvimtodo")
end

return M
```

What `:checkhealth nvimtodo` expects:

- `lua/nvimtodo/health.lua` exists
- Exports a `check()` function
- `check()` prints status to `:messages`
- `:checkhealth nvimtodo` runs without error

---

## 8. LSP / Treesitter Hooks

### LSP

```lua
vim.lsp.on_attach(function(client, bufnr)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufnr)
end)

vim.lsp.start({
  name = "my_lsp",
  cmd = { "my_lsp_server" },
  root_markers = { ".git" },
})

client.request("textDocument/diagnostic", { uri = "file.txt" })
client.on("notification", function(method, params) end)
```

### Treesitter

```lua
local parser = vim.treesitter.get_parser(
  vim.api.nvim_get_current_buf(),
  "lua",
  nil,
  { highlight = true }
)

vim.treesitter.highlight(
  vim.api.nvim_get_current_buf(),
  "lua"
)
```

---

## 9. Keymap & Command Registration

### Keymap — global vs buffer

```lua
vim.api.nvim_set_keymap("n", "<leader>t", ":Todo<cr>", { noremap = true })
vim.api.nvim_buf_set_keymap(buf, "n", "<leader>t", ":Todo<cr>", { noremap = true })
```

### User command — with bang, nargs, range, complete

```lua
vim.api.nvim_create_user_command("Todo", function(opts)
  -- opts.bang, opts.args, opts.line1, opts.line2
end, {
  nargs = 1,
  bang = true,
  range = 1,
  complete = "custom",
})
```

### Subcommands

```lua
vim.api.nvim_create_user_command("Todo.Done", handler)
vim.api.nvim_create_user_command("Todo.List", handler)
```

---

## 10. Notifications & Messaging

```lua
vim.api.nvim_notify("msg", vim.log.levels.INFO)
vim.api.nvim_notify("error", vim.log.levels.ERROR)
vim.api.nvim_notify("debug", vim.log.levels.DEBUG)
vim.api.nvim_notify("trace", vim.log.levels.TRACE)
vim.api.nvim_notify("warn", vim.log.levels.WARN)

vim.api.nvim_echo({ "hello" }, 1, {})  -- echo to cmdline
vim.api.nvim_get_mode()              -- { mode, blocking }
vim.api.nvim_input("i")             -- feed keys
vim.api.nvim_feedkeys("o", "m", false)  -- feed keys with mode flags
```

---

## 11. State & Options

### `g:` and `b:` variables

```lua
vim.api.nvim_get_var("my_global")                -- g:my_global
vim.api.nvim_set_var("my_global", value)
vim.api.nvim_buf_get_var(buf, "my_buf_var")     -- b:my_buf_var
vim.api.nvim_buf_set_var(buf, "my_buf_var", value)
```

### `w:` and `b:` option scoping

```lua
vim.api.nvim_get_option("number")              -- global
vim.api.nvim_set_option("number", true)
vim.api.nvim_buf_get_option(buf, "number")     -- buffer-local
vim.api.nvim_buf_set_option(buf, "number", true)
```

### `stdpath` for data/config/state/cache

```lua
vim.fn.stdpath("data")       -- ~/.local/share/nvim
vim.fn.stdpath("config")    -- ~/.config/nvim
vim.fn.stdpath("state")     -- ~/.local/state/nvim
vim.fn.stdpath("cache")     -- ~/.cache/nvim
```

---

## 12. Quick Reference Table

| Task | API call | One-liner |
|---|---|---|
| Create buffer | `vim.api.nvim_create_buf` | New empty buffer |
| Open window | `vim.api.nvim_open_win` | Open a window |
| Get current window | `vim.api.nvim_get_current_win` | Current window |
| Set current window | `vim.api.nvim_set_current_win` | Switch window |
| Get current buffer | `vim.api.nvim_get_current_buf` | Current buffer |
| Set current buffer | `vim.api.nvim_set_current_buf` | Switch buffer |
| Get current line | `vim.api.nvim_get_current_line` | Current line |
| Set current line | `vim.api.nvim_set_current_line` | Replace line |
| Get mode | `vim.api.nvim_get_mode` | Current mode |
| Feed keys | `vim.api.nvim_feedkeys` | Feed keys |
| Input | `vim.api.nvim_input` | Type into buffer |
| Get variable | `vim.api.nvim_get_var` | Get g: var |
| Set variable | `vim.api.nvim_set_var` | Set g: var |
| Get option | `vim.api.nvim_get_option` | Get option |
| Set option | `vim.api.nvim_set_option` | Set option |
| Get runtime dir | `vim.api.nvim_get_runtime_dir` | Runtime path |
| Get API info | `vim.api.nvim_get_api_info` | Version, features |
| Create user command | `vim.api.nvim_create_user_command` | Register command |
| Create autocmd | `vim.api.nvim_create_autocmd` | Register event |
| Fire User event | `vim.api.nvim_exec_autocmd` | Fire event |
| Set keymap | `vim.api.nvim_set_keymap` | Bind key |
| Notify | `vim.api.nvim_notify` | Show message |
| Echo | `vim.api.nvim_echo` | Echo to cmdline |
| Read file | `vim.fn.fileread` | Read file |
| Write file | `vim.fn.filewrite` | Write file |
| Expand | `vim.fn.expand` | Expand <cfile> |
| Std path | `vim.fn.stdpath` | Data/config/state/cache |
| Temp name | `vim.fn.tempname` | Unique temp path |
| Mkdir | `vim.fn.mkdir` | mkdir -p |
| Delete | `vim.fn.delete` | rm -rf |
| Rename | `vim.fn.rename` | Rename file |
| System | `vim.fn.system` | Run shell command |
| Get line | `vim.fn.getline` | Get line |
| Set line | `vim.fn.setline` | Set line |
| Line | `vim.fn.line` | Current line |
| Col | `vim.fn.col` | Current col |
| Search | `vim.fn.search` | Search pattern |
| Match | `vim.fn.match` | Regex match |
| Match add | `vim.fn.matchadd` | Add match |
| Match delete | `vim.fn.matchdelete` | Remove match |
| Timer start | `vim.fn.timer_start` | Start timer |
| Timer stop | `vim.fn.timer_stop` | Stop timer |
| Job start | `vim.fn.jobstart` | Start job |
| Chan open | `vim.fn.chan_open` | Open channel |
| Term open | `vim.fn.termopen` | Open terminal |
| JSON encode | `vim.fn.json_encode` | Table → JSON |
| JSON decode | `vim.fn.json_decode` | JSON → table |
| Deep extend | `vim.tbl_deep_extend` | Deep merge |
| Merge | `vim.tbl_merge` | Shallow merge |
| Is empty | `vim.tbl_isempty` | Check empty |
| Clone | `vim.tbl_clone` | Deep copy |
| Contains | `vim.tbl_contains` | Linear search |
| Add | `vim.tbl_add` | Append |
| Pop | `vim.tbl_pop` | Remove last |
| Remove | `vim.tbl_remove` | Remove at index |
| Get | `vim.tbl_get` | Safe get |
| Get by | `vim.tbl_get_by` | Get or nil |
| Get by key | `vim.tbl_get_by_key` | Get by key |
| Get by key+value | `vim.tbl_get_by_key_and_value` | Get if match |
| From | `vim.iter.from` | Range iterator |
| Filter | `vim.iter.filter` | Filter iterator |
| Map | `vim.iter.map` | Map iterator |
| Take | `vim.iter.take` | First N |
| Drop | `vim.iter.drop` | Skip N |
| Take while | `vim.iter.take_while` | Take while |
| Drop while | `vim.iter.drop_while` | Drop while |
| Reverse | `vim.iter.reverse` | Reverse iterator |
| Chain | `vim.iter.chain` | Concatenate |
| Concat | `vim.iter.concat` | Join string |
| To list | `vim.iter.to_list` | Collect array |
| To string | `vim.iter.to_string` | Join string |
| To array | `vim.iter.to_array` | Collect array |
| To table | `vim.iter.to_table` | Collect table |
| To set | `vim.iter.to_set` | Unique values |
| To dict | `vim.iter.to_dict` | Key→value |
| To pairs | `vim.iter.to_pairs` | Pairs |
| To kv | `vim.iter.to_kv` | Key-value |
| To kv pairs | `vim.iter.to_kv_pairs` | Array of {k,v} |
| To kv by key | `vim.iter.to_kv_pairs_by_key` | Filter by key |
| To kv by value | `vim.iter.to_kv_pairs_by_value` | Filter by value |
| To kv by key+value | `vim.iter.to_kv_pairs_by_key_and_value` | Filter by both |
| Pairs | `vim.pairs` | Iterate pairs |
| Defer fn | `vim.defer_fn` | Delayed fn |
| Schedule | `vim.schedule` | Next loop |
| Schedule wrap | `vim.schedule_wrap` | Wrap for next loop |
| New timer | `vim.uv.new_timer` | Luv timer |
| New check | `vim.uv.new_check` | Luv check |
| New idle | `vim.uv.new_idle` | Luv idle |
| LSP on attach | `vim.lsp.on_attach` | LSP attach hook |
| LSP start | `vim.lsp.start` | Start LSP server |
| LSP request | `client.request` | Send request |
| LSP on | `client.on` | Handle notification |
| TS query | `vim.treesitter.query` | TS query |
| TS parser | `vim.treesitter.get_parser` | Get parser |
| TS highlight | `vim.treesitter.highlight` | Highlight buffer |
