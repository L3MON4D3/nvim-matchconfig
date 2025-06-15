# nvim-matchconfig

The goal of this neovim-plugin is to implement project-dependent settings in a
feature-complete and flexible manner.

Relevant features:
* Declaratively define options (not just buffer-local or global
  `vim.opt`-options, but any arbitrary code that changes a buffers state) to
  apply to some buffer based on predicates.  
  For example, set a keybinding for all buffers whose filename matches
  `.*README.md`, or configure a specific lsp for all `python` files in some
  directory.  
  Special care is taken to allow these options to be very minimal (quick to
  create!), unloadable (remove them completely), and have well-defined merging
  behaviour (in case more than one option applies to some buffer).
* Quickly edit currently-loaded options.  
  It is possible to quickly jump to any option that applies to the current
  buffer, edit it, and reload the options for all open buffers.

# Project State
This is definitely very pre-1.0, so best only use it by pinning it to a commit,
so it's excluded when more stable plugins are updated. Whenever a new breaking
change is pushed, it, and a way to adapt to it will be posted to [this
issue](https://github.com/L3MON4D3/nvim-matchconfig/issues/1), so consider
following it.


# Example

The following code shows a few of the basic concepts of matchconfig:

```lua
-- Setup some local variables
local matchconfig = require("matchconfig")
local matchers = matchconfig.matchers
local extra_matchers = require("matchconfig.extras.matchers.projects")

local c = matchconfig.config
local actions = matchconfig.actions

local nnoremapsilent_buf = actions.nnoremapsilent_buf
local usercommand_buf = actions.usercommand_buf

-- For all buffers that belong to a cmake-project, register a keybinding for
-- running `cmake --build build`.
-- A buffer belongs to a cmake project if a `CMakeLists.txt` can be found in any
-- of its parent-directories.
-- Note that ideally, this would be improved by using some repl-plugin for more
-- interactivity.
local cmake_generic = matchconfig.register(extra_matchers.cmake(), c{
    run_buf = function(args)
        -- nnoremapsilent_buf registers a buffer-local keybinding that can be
        -- removed upon reload.
        -- for the cmake-matcher, args.match_args is the directory where the
        -- Makefile resides.
        nnoremapsilent_buf("<Space>b", ":!cd " .. args.match_args .. " && cmake --build build<Cr>")
    end
})

-- this time, register a keybinding on the same key-combo as before, but for
-- Makefile-based projects (again, identified by searching upwards for a
-- `Makefile`)
local make_generic = matchconfig.register(extra_matchers.make(), c{
    run_buf = function(args)
        nnoremapsilent_buf("<Space>b", ":!cd " .. args.match_args .. " && make build<Cr>")
    end
})

-- make sure that (arbitrarily) the cmake-binding supersedes the make-binding.
-- So in projects that have both a CMakeLists.txt and a Makefile, <space>b would
-- run `make build`.
-- Here this is achieved trivially by registering the cmake-keybind after the
-- make-keybind, but this merging behaviour can be completely customized for
-- every option.
cmake_generic:after(make_generic)

-- for filenames that match README.md$ or DOC.md$ (ie. files named
-- `README.md/DOC.md`), register two usercommands, `:Gr` and `:S`, for starting and
-- stopping a grip-server (https://github.com/joeyespo/grip) (it can render
-- markdown as it appears on github, very useful for previewing changes).
matchconfig.register(matchers.pattern("README.md$") + matchers.pattern("DOC.md$"), c{
    run_buf = function(args)
        usercommand_buf("Gr", function()
            io.popen(
                "systemd-run --user -u $(systemd-escape grip_" .. args.file .. ") " ..
                "grip -b " .. args.file .. " 0 2> /dev/null")
        end, {})
        usercommand_buf("S", function()
            io.popen(
                "systemctl --user stop $(systemd-escape grip_" .. args.file .. ")")
        end, {})
    end
})
```

And the short session below shows the hot-reload and editing capabilities of
`nvim-matchconfig` with the config shown above:

https://github.com/user-attachments/assets/260f21ff-f769-4ef2-913d-f39a6407f719

Note the following things:
* `:C` opens a telescope-based picker for all options loaded for the current
  buffer.
* After changing the `Makefile`-matching `run_buf` for the first time, the old
  keybinding is removed and the new one (`make build_debug`) is registered.
  When the `nnoremapsilent_buf` is commented out, no keybinding exists for
  `<space>b`.
* `pick_current` only shows the most up-to-date information and no older,
  no-longer effective options.

# Getting Started
0. Make sure you're running Neovim version 0.10+.
1. Install `nvim-matchconfig` using your favorite package-manager.
   Optionally follow a specific version (we adhere to semantic versioning) by
   providing a tag.
2. Find your config-directory via `:lua =vim.fn.stdpath("config")` (very, very
   likely this is `~/.config/nvim`) and create the file `config.lua` in it. For
   a quick check that everything works correctly, try the following:
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
   You should now see a short message upon opening a python-file.

3. Define your own configs.  Reading the remainder of this README and DOC.md
   should give you some solid ideas on how to use `nvim-matchconfig` and what it
   is capable of.

## Configuring
`nvim-matchconfig` can be configured using a `setup`-function:
```lua
require("matchconfig").setup({
    path = "config.lua",
    options = {
        require("matchconfig.options.run_buf")
        require("matchconfig.options.run_session")
    }
})
```
More information on `setup` and its various keys can be found in
DOC.md in the chapter `API-Setup`.

## Other Resources on `nvim-matchconfig`

The chapter `Tips` in DOC.md has suggestions for a good workflow with
`nvim-matchconfig` as well as mappings and commands that may come in handy.

My dotfiles also contain a pretty large `nvim-matchconfig`-config
[here](https://github.com/L3MON4D3/Dotfiles/blob/main/nvim/configs.lua), with
the setup
[here](https://github.com/L3MON4D3/Dotfiles/blob/main/nvim/lua/plugins/matchconfig.lua)
