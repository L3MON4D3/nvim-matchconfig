# Matchconfig

The goal of this neovim-plugin is to make project-dependent settings as simple
as possible.  

## Features
* Flexibly match configurations to a buffer as it's loaded.  
  We natively support
  * Path
  * Directory
  * Pattern
* Act on matching buffers only (don't pollute global keybindings if undesired)
* Quickly change a buffer's options by jumping to one of the effective
  configurations (needs [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim))
