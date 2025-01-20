# nvim-matchconfig

The goal of this neovim-plugin is to implement project-dependent settings in a
feature-complete and flexible manner.

Relevant features:
* Declaratively define options (not just buffer-local or global
  `vim.opt`-options, but any arbitrary code that changes a buffers state) that
  should be applied to some buffer based on predicates (filename matches some
  pattern, or file is inside some directory), their order (override less
  specific options with more specific ones) and how they are merged when there
  are collisions (for example the last provided value of an option has priority,
  or all values are somehow combined)
* Quickly edit currently-loaded options (jump to options that apply to the
  current buffer, and, upon changing them, discard the old options and load the
  new options)
* The set of options that can be defined for a buffer is not set in stone but
  can be supplanted by user-defined options.

## Example

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
-- Makefile-based projects.
local make_generic = matchconfig.register(extra_matchers.make(), c{
    run_buf = function(args)
        nnoremapsilent_buf("<Space>b", ":!cd " .. args.match_args .. " && make build<Cr>")
    end
})

-- make sure that (arbitrarily) the make-binding supersedes the cmake-binding.
-- So in projects that have both a CMakeLists.txt and a Makefile, <space>b would
-- run `make build`.
cmake_generic:after(make_generic)

-- for filenames that match README.md$ or DOC.md$, register two usercommands,
-- `:Gr` and `:S`, for starting and stopping a grip-server
-- (https://github.com/joeyespo/grip), which can render markdown as it appears
-- on github.
matchconfig.register(matchers.pattern("README.md$") + matchers.pattern("DOC.md$"), c{
    run_buf = function(args)
        usercommand_buf("Gr", function()
            local socket = require("socket")
            local server = socket.bind("*", 0)
            local _, port = server:getsockname()
            server:close()

            io.popen(
                "systemd-run --user -u $(systemd-escape grip_" .. args.file .. ") " ..
                "grip -b " .. args.file .. " " .. port .. " 2> /dev/null")
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

## Getting Started
0. Make sure you're running Neovim version 0.10+.
1. Install `nvim-matchconfig` using your favorite package-manager.
   Optionally follow a specific version (we adhere to semantic versioning) by
   providing a tag.
2. Find your config-directory via `:lua =vim.fn.stdpath("config")` (very, very
   likely this is `~/.config/nvim`) and create the file `config.lua` in it. For
   a quick check that everything works correctly, try the following:
   ```lua
    local matchconfig = require("matchconfig")
    local matchers = matchconfig.matchers
    local c = matchconfig.config

    matchconfig.register(matchers.filetype("python"), c{
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
