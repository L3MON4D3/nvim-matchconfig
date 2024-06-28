# nvim-matchconfig

The goal of this neovim-plugin is to make project-dependent settings as simple
as possible.  

## Introduction
The core of this plugin is the `Matchconfig`. It contains a `Matcher`, which
determines whether the `Matchconfig` matches a buffer, and a `Config`, which
is made up out of different `Options`, each of which can be applied to a buffer.  
All `Matchconfig`s are loaded from one file, by default `configs.lua` in the
`stdpath("config")`-directory (the filename can be modified in `setup()`).  
The following call would register a new `Matchconfig` which matches all buffers
with filetype `python`, and uses the `run_buf`-option to print a message upon
loading the config to the buffer.
```lua
matchconfig.match(matchers.filetype("python"), {{
    run_buf = function()
        print("Hello from nvim-matchconfig")
    end
}})
```
There are several matchers, including one that invokes a lua-callback, so
there is lots of flexibility in matching configurations to buffers.  
The second part of a `Matchconfig` is the `Config`. It will receive the table
containing the `run_buf`-key, and construct all enabled options from it.  
Options can be added or disabled in `setup()`. This includes those shipped in
`matchconfig`, but also ones you may define yourself, which means that there is
a great amount of flexibility in what kind of changes `nvim-matchconfig` can do
to your buffer.  
Since multiple `Matchconfig`s can match a buffer, it may be desired to impose
some kind of ordering (for example, to overwrite a keymap set by another
`Matchconfig` without disabling it entirely). We support this via two functions,
`:after` and `:before`:
```lua
local h1 = matchconfig.match(matchers.filetype("python"), {{
    run_buf = function()
        print("Hello 1")
    end
}})

local h2 = matchconfig.match(matchers.filetype("python"), {{
    run_buf = function()
        print("Hello 2")
    end
}})

local h3 = matchconfig.match(matchers.filetype("python"), {{
    run_buf = function()
        print("Hello 3")
    end
}})

h1:before(h2)
h3:after(h2)
```
In this case, upon opening a python-file, the messages will be in the desired
order (1 -> 2 -> 3).  

One last important feature of `nvim-matchconfig` is its hot-reload capability:
if the file that defines the `Matchconfig`s is written, all active `Config`s are
undone (if they are set up correctly), the new `Matchconfig`s are loaded and
applied to all open buffers.

## Getting Started
0. Make sure you're running Neovim version 0.10+.
1. Install using your favorite package-manager.
   Optionally follow a specific version (we adhere to semantic versioning) by
   providing a tag.
2. Query your config-path via `:lua =vim.fn.stdpath("config")` and create the
   file `config.lua`, and start adding configs. For a quick check that
   everything works correctly, try the following:
   ```lua
   local matchconfig = require("matchconfig")
   local matchers = matchconfig.matchers

   matchconfig.match(matchers.filetype("python"), {{
       run_buf = function()
           print("Hello from nvim-matchconfig")
       end
   }})
   ```
   You should now see the short message upon opening a python-file.

There are multiple types of matchers:
* path
* directory
* pattern
* filetype
* generic
The first three look at the filename of the buffer, and match if the path is
exactly the same, the filename is somewhere below the specified directory, or
if the lua-pattern matches the filename.  
`filetype` matches if the buffer has the specified filetype, and `generic` takes
a lua-callback and is passed information on the buffer, and then decides whether
the buffer matches.
* Flexibly match configurations to a buffer as it's opened.  
  We natively support
  * Path
  * Directory
  * Pattern
  * Filetype
  * Combinations of those (ie. directory `/a/b` and filetype `markdown`) And
    also generic functions that return whether they match some given buffer, for
    customizability.
* `matchonfig` supports hot reload (eg. when the configuration is updated, the
  configurations of all open buffers will be re-derived from it), and if
  `matchconfig` knows about the various changes done by the current
  configuration of a buffer (for example when keybindings or user-commands are
  setup using our wrappers around them), these can be undone as part of that
  reload, so that old settings don't survive.
* To make hot reload really comfortable, all configurations applying to some
  buffer can be listed and jumped to via
  [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
* The order in which the various configurations that match some buffer are
  applied can be controlled, which enables overwriting of general settings with
  more granular ones.

## How-To
```lua
require("matchconfig").setup({ fname = "<absolute path to config-file>" })
```
