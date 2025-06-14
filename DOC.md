# Overview
`nvim-matchconfig` is designed to make project-specific settings as comfortable
as possible. This includes matching to buffers based on arbitrary criteria
(filename or directory match some pattern, or specific files are present),
merging multiple matching configurations, and easy editing via jump-to-config
and hot reload on edit.

# Primitives
This section will describe the primitives used by `nvim-matchconfig`, and their
various responsibilities. This is rather technical, and if it's your first time
reading this, consider skipping it and coming back to it as things are
referenced later on.

## Matchconfig
The core of this plugin is the `Matchconfig`. It associates a `Config`, which
is a set of changes applicable to a buffer or neovim-session, with a `Matcher`,
which determines whether the `Matchconfig` matches some buffer (one example of a
`Matcher` is the `PatternMatcher`, which checks whether the filename of a buffer
matches some pattern).

```lua
mc.register(matchers.pattern(".*.config/nvim/.*"), c{
    run_buf = function()
        print("Hello from nvim-matchconfig")
    end
})
```
This would print "Hello from nvim-matchconfig" whenever a buffer whose name
matches the pattern `.*.config/nvim/.*` is loaded.

## Config
This primitive is not very interesting, it merely groups all enabled `Option`s
together and spreads out various operations onto all of them.

## Option
The modifications a `Config` applies to a buffer are split up into multiple
`Option`s. Every `Option` can define what happens when it is applied to a
buffer, how to undo it, and how to merge two instances with each other. This
means that it is possible to customize the merge-behaviour per-option, which
gives great flexibility.

```lua
mc.register(matchers.pattern(".*.config/nvim/.*"), c{
    run_buf = function()
        print("Hello from run_buf 1")
    end,
    run_buf_named = {
        hello = function()
            print("Hello from named function 1")
        end
    }
})

mc.register(matchers.pattern(".*init.lua"), c{
    run_buf = function()
        print("Hello from run_buf 2")
    end,
    run_buf_named = {
        hello = function()
            print("Hello from named function 2")
        end
    }
})
```
When merging multiple `run_buf` options, all passed functions will be executed
while `run_buf_named` only runs the highest-priority function of any given name.

So, with the example above, opening the file `$HOME/.config/nvim/init.lua` would
print both "Hello from run_buf 1" and "Hello from run_buf 2", but only one of
"Hello from named function 1" and "Hello from named function 2".


## Matcher
Every matcher is essentially a function which, given the handle to a buffer,
returns whether the buffer matches. Currently there are a few matchers built-in,
but it is easy to add more.


## Ordering

Since more than one `Matchconfig` can match a buffer, it may be desirable to
impose some kind of ordering (for example, to overwrite a keymap set by another
`Matchconfig` without disabling it entirely). We support this via two functions,
`after` and `before`:
```lua
local h1 = mc.register(matchers.filetype("python"), c{
    run_buf = function()
        print("Hello 1")
    end
})

local h2 = mc.register(matchers.filetype("python"), c{
    run_buf = function()
        print("Hello 2")
    end
})

local h3 = mc.register(matchers.filetype("python"), c{
    run_buf = function()
        print("Hello 3")
    end
})

h1:before(h2)
h3:after(h2)
```
In this case, upon opening a python-file, the messages will be in the order 1 ->
2 -> 3.  
The ordering can be thought of as introducing barriers into the execution of the
merged options. While this is ultimately up to the specific options,
theoretically they can be implemented s.t. _all_ options of some `Matchconfig`
are executed before any option of another `Matchconfig`, e.g.
```lua
local h1 = mc.register(matchers.filetype("python"), c{
    run_buf = function()
        print("Hello buf 1")
    end,
    run_session = function()
        print("Hello session 1")
    end
})

local h2 = mc.register(matchers.filetype("python"), c{
    run_buf = function()
        print("Hello buf 2")
    end,
    run_session = function()
        print("Hello session 2")
    end
})
h1:before(h2)
```
Even though there are 2 different options at play here, this will print both the
`*1`-messages before any of the `*2`-messages.

## Blacklisting

Besides ordering `Matchconfig`s, it's also possible to prevent their
execution. Higher-priority `Matchconfig`s can disable (`:blacklist`) another
`Matchconfig`:
```lua
local h1 = mc.register(matchers.dir("/home/user/dirA"), c{
    run_buf = function()
        print("Hello 1")
    end
})

local h2 = mc.register(matchers.dir("/home/user/dirA/subdirB"), c{
    run_buf = function()
        print("Hello 2")
    end
})
local h3 = mc.register(matchers.filetype("python"), c{})
-- blacklist implies `after`.
h2:blacklist(h1)
```
This will print `Hello1` when opening e.g. `dirA/file.lua`, `Hello1` and `Hello2`
when opening `dirA/subdirB/file.lua`, and only `Hello2` when opening
`dirA/subdirB/file.py`.
Beside `blacklist`, there is also `unblacklist` (which also implies an
`after`-ordering), and `blacklist_by` and `unblacklist_by`, which both imply a
`before`-ordering.


# Usage

By default (without a manual call to `setup`), `nvim-matchconfig` only has the
`Option` `run_buf` enabled, and will load the file located at
`vim.fn.stdpath("config")/config.lua`.

Perform a quick sanity-check by putting these contents

```lua
local mc = require("matchconfig")
local c = mc.config
local matchers = mc.matchers

mc.register(matchers.filetype("python"), c{
	run_buf = function()
		print("Hello from nvim-matchconfig")
	end
})
```
into `vim.fn.stdpath("config")/config.lua`. Opening a python file should print
the short message.

To enable more options, pass them to `setup`, e.g.
```lua
mc.setup({
	options = {
		require("matchconfig.options.bufvar"),
		require("matchconfig.options.run_buf"),
		require("matchconfig.options.run_buf_named"),
		require("matchconfig.options.run_session"),
		require("matchconfig.options.bufopt"),
		require("matchconfig.options.lsp"),
	}
})
```
While this example only shows options defined in `matchconfig`, this list can
also include custom options.

# Options for matchconfig.setup

# Different options

# API

# Tips
* use abbreviations for the various matchers
  ```lua
  local mft = matchers.filetype
  local mpattern = matchers.pattern
  local mfile = matchers.file
  local mdir = matchers.dir
  ```
* add usercommands for quickly jumping to active matchconfigs and the
  config-file:
  ```lua
  vim.api.nvim_create_user_command("C", require("matchconfig").pick_current, {})
  vim.api.nvim_create_user_command("CO", ":e " .. vim.uv.fs_realpath(require("matchconfig").get_configfile()), {})
  ```

# Appendix

* Local variables used in this document:
  ```lua
  local mc = require("matchconfig")
  local c = mc.config
  local matchers = mc.matchers
  ```
