# Fretless

## Introduction

My doom-emacs inspired neovim config.
Developed valuing the following attributes:

* DWIM-like consistency
* Focused
* Introspective

## Installation

Like any other nvim config, install nvim version >= 0.9 I'm using 10.0
```bash
git clone https://github.com/ReggieMarr/nvim.git ~/.config/nvim
```

Then run ```:MasonInstallAll``` && ```:Lazy update```
They made need to be run a couple times
## Progress

[-] [TODO](2024-10-20_todo.md) Project management features
    [-] [TODO](2024-10-20_todo.md) Create, switch-to, and discover project sessions
    [-] [TODO](2024-10-20_todo.md) Project window on entry consists of:
        - nvtree on the left
        - `telescope.file_browser` in the middle (with readme preselected)
        - harpoon/tasks on the side
        - possible transient ?
        - jira integration ?
[-] [TODO](2024-10-20_todo.md) Navigation
    [-] [DONE](2024-10-20_todo.md) doom-like evil mode
    [-] [TODO](2024-10-20_todo.md) doom-like fuzzy finding files
    [-] [TODO](2024-10-20_todo.md) DWIM `vertico` vs `dired` (i.e. `telescope.find_files` vs `telescope.file_browser`)
[-] [TODO](2024-10-20_todo.md) Introspection
    [-] [TODO](2024-10-20_todo.md) Find info on arbitrary binds - `Spc-h-k`
    [-] [TODO](2024-10-20_todo.md) Find info on functions - `Spc-h-f`
    [-] [TODO](2024-10-20_todo.md) Get messages in buffers
    [-] [FIXME](2024-10-20_todo.md) Fix `checkhealth`
[-] [TODO](2024-10-20_todo.md) Misc
    [-] [TODO](2024-10-20_todo.md) Fuzzy Execute Commands - `M-x`

## Known issues

### ```:checkhealth which-key ``` errors
For some reason I get this fairly often
```
There were issues reported with your **which-key** mappings.
Use `:checkhealth which-key` to find out more.
```
It seems to just be a nuisance error and ```:checkhealth which-key``` doesn't illumintate anything

## Telescope hides desired results
Results fed into Telescope either aren't sorting properly or something.
Right now when we search something that has a ton of results the closest results appear hidden.

## Resources

- [Emacs inspired config using luarocks](https://github.com/NTBBloodbath/doom-one.nvim)
- [Emacs inspired config using lazy](https://github.com/orhnk/vimacs)
    - This config started as a fork of this but has started to vary greatly
- [Emacs inspired config using lazy](https://github.com/orhnk/vimacs)

### Notes

#### [How to leverage lua for plugin setup](https://www.youtube.com/watch?v=N-RFCfs6rxI)
- `vim.fn.{vim script function}` 
  This is the syntax that allows lua to call vim script *functions*
- `vim.cmd.{vim script command}` 
  This is the syntax that allows lua to call vim script *commands*
- Functions vs Commands
    - Functions: Take in some data and provide data as a response
    - Commands: Take in some arguments and execute some behaviour
- How does `require` work
  If we supply something like `require(lazy)` nvim looks in our runtime path (rtp)
  if that directory exists it will try to run `lua/init.lua`
