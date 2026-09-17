# nvimtodo API Reference

## Overview

The **nvimtodo** project does not currently contain any source code. Its workspace directory (`/workspace/nvimtodo/`) is **empty** — there is no `lua/` tree, no `plugin/` directory, no `init.lua`, no `config.lua`, no README, and no documentation. It appears to be a freshly-initialized (or not-yet-populated) project placeholder.

> [!IMPORTANT]
> This document reflects the actual state of the repository as of 2026-09-17. No API surface, configuration schema, user commands, or events have been implemented yet. The sections below are provided as a structural template to fill in once the plugin code lands.

## Public API Functions

**None.** No Lua module is defined in the project. There is no `lua/nvimtodo/init.lua`, no `lua/nvimtodo/api.lua`, and no `plugin/nvimtodo.lua` entry point. The plugin has not been implemented.

## Configuration Options

**None.** No `config.lua`, `options.lua`, or `defaults.lua` file exists. There is no `M.config` table to document.

## User Commands

**None.** No `:NvimTodo`-style command is registered. No `vim.api.nvim_create_user_command` call exists anywhere in the tree.

## Events / Autocmds Fired by the Plugin

**None.** No `vim.api.nvim_create_autocmd` or `vim.api.nvim_exec_autocmd` call exists in the project.

## Building a Basic Plugin (Planned)

> [!NOTE]
> This section is a **forward-looking template** to be filled in once `nvimtodo` ships its first Lua module. It is not a working example.

### Step 1 — Install the plugin

```vim
vim.cmd("packadd nvimtodo")
```

### Step 2 — Load the API

```lua
local nvimtodo = require("nvimtodo")
```

### Step 3 — Register a command

```lua
vim.api.nvim_create_user_command("MyTodo", function(opts)
  nvimtodo.do_something(opts.args)
end, { nargs = 1 })
```

### Step 4 — Hook an event

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "NvimTodoReady",
  callback = function()
    print("nvimtodo is ready")
  end,
})
```

### Minimal example

```lua
-- mytodo_plugin.lua
local nvimtodo = require("nvimtodo")

vim.api.nvim_create_user_command("MyTodo", function(opts)
  nvimtodo.do_something(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_autocmd("User", {
  pattern = "NvimTodoReady",
  callback = function()
    print("nvimtodo is ready")
  end,
})
```

> [!WARNING]
> The functions and events referenced above (`nvimtodo.do_something`, `NvimTodoReady`) **do not exist**. They are placeholders illustrating the expected shape of a future API.

## See Also

- Project root: `/workspace/nvimtodo/` (empty)
