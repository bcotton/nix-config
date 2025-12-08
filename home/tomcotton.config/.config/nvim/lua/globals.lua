-- leader key is spacebar
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Enable filetype detection, plugins, and indent
vim.cmd('filetype on')
vim.cmd('filetype plugin on')
vim.cmd('filetype indent on')

-- Enable syntax highlighting
vim.cmd('syntax on')

-- Set line numbers with relative numbering
vim.opt.number = true
vim.opt.relativenumber = true

-- Highlight cursor line underneath the cursor horizontally.
vim.opt.cursorline = true

-- Highlight cursor line underneath the cursor vertically.
vim.opt.cursorcolumn = true

-- Set shift width to 4 spaces.
vim.opt.shiftwidth = 4

-- Set tab width to 4 columns.
vim.opt.tabstop = 4

vim.opt.termguicolors = true
vim.cmd([[
  hi Cursor guibg=white
]])

-- Use space characters instead of tabs.
vim.opt.expandtab = true

-- Do not save backup files.
vim.opt.backup = false

-- Do not let cursor scroll below or above N number of lines when scrolling.
vim.opt.scrolloff = 20
-- scrolloff now set by smart-scrolloff-nvim

-- Do not wrap lines. Allow long lines to extend as far as the line goes.
vim.opt.wrap = false

-- While searching though a file incrementally highlight matching characters as you type.
vim.opt.incsearch = true

-- Ignore capital letters during search.
vim.opt.ignorecase = true

-- Override the ignorecase option if searching for capital letters.
-- This will allow you to search specifically for capital letters.
vim.opt.smartcase = true

-- Show partial command you type in the last line of the screen.
vim.opt.showcmd = true

-- Show the mode you are on the last line.
vim.opt.showmode = true

-- Show matching words during a search.
vim.opt.showmatch = true

-- Use highlighting when doing a search.
vim.opt.hlsearch = true

-- Set the commands to save in history default number is 20.
vim.opt.history = 1000

-- Enable auto completion menu after pressing TAB.
vim.opt.wildmenu = true

-- Make wildmenu behave like similar to Bash completion.
vim.opt.wildmode = 'list:longest'

-- There are certain files that we would never want to edit with Vim.
-- Wildmenu will ignore files with these extensions.
vim.opt.wildignore = '*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx'

-- Use system clipboard
vim.opt.clipboard:append('unnamedplus')

