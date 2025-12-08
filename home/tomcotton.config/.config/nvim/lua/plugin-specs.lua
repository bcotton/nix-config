-- https://github.com/jdhao/nvim-config/blob/main/lua/plugin_specs.lua

local plugin_specs = {
  -- auto-completion engine
  -- { "hrsh7th/cmp-nvim-lsp", lazy = true },
  -- { "hrsh7th/cmp-path", lazy = true },
  -- { "hrsh7th/cmp-buffer", lazy = true },
  -- { "hrsh7th/cmp-omni", lazy = true },
  -- { "hrsh7th/cmp-cmdline", lazy = true },
  -- { "quangnguyen30192/cmp-nvim-ultisnips", lazy = true },
  -- {
  --   "hrsh7th/nvim-cmp",
  --   name = "nvim-cmp",
  --   event = "VeryLazy",
  --   config = function()
  --     require("config.nvim-cmp")
  --   end,
  -- },
  -- {
  --   "neovim/nvim-lspconfig",
  --   config = function()
  --     require("config.lsp")
  --   end,
  -- },
  -- {
  --   "dnlhc/glance.nvim",
  --   config = function()
  --     require("config.glance")
  --   end,
  --   event = "VeryLazy",
  -- },

  -- LSPs https://www.jakmaz.com/blog/nvim-lsp
  -- { -- Mason: installs and manages external tools like LSP servers
  --   'mason-org/mason.nvim',
  --   opts = {},
  -- },
  -- { -- Mason-LSPConfig: tells Mason which servers to install and links them to lspconfig
  --   "mason-org/mason-lspconfig.nvim",
  --   opts = {
  --     ensure_installed = {
  --       "lua_ls",
  --       "pyright",
  --       "ts_ls",
  --       "rust_analyzer",
  --       "clangd"
  --     },
  --   },
  -- },
  -- { -- nvim-lspconfig: connects Neovim to installed LSP servers
  --   "neovim/nvim-lspconfig",
  --   config = function()
  --     require("lspconfig") -- sets up lspconfigs
  --   end
  -- },
  -- {
  --   "nvim-treesitter/nvim-treesitter",
  --   lazy = true,
  --   build = ":TSUpdate",
  --   config = function()
  --     require("config.treesitter")
  --   end,
  -- },

  -- {
  --   "nvim-treesitter/nvim-treesitter-textobjects",
  --   event = "VeryLazy",
  --   branch = "master",
  --   config = function()
  --     require("config.treesitter-textobjects")
  --   end,
  -- },
  { "machakann/vim-swap", event = "VeryLazy" },

  -- {
  --   "nvim-telescope/telescope.nvim",
  --   cmd = "Telescope",
  --   dependencies = {
  --     "nvim-telescope/telescope-symbols.nvim",
  --   },
  -- },
  {
    'romgrk/barbar.nvim',
    dependencies = {
      'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
      'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
    },
    init = function() vim.g.barbar_auto_setup = false end,
    opts = {
      require("config.barbar")
    },
    version = '^1.0.0', -- optional: only update when a new 1.x version is released
  },
  {
    "ibhagwan/fzf-lua",
    config = function()
      require("config.fzf-lua")
    end,
    event = "VeryLazy",
  },
  {
    "lmburns/lf.nvim",
    cmd = "Lf",
    dependencies = { "nvim-lua/plenary.nvim", "akinsho/toggleterm.nvim" },
    opts = {
      winblend = 0,
      highlights = { NormalFloat = { guibg = "NONE" } },
      border = "single",
      escape_quit = false,
    },
    keys = {
      { "<leader>fl", "<cmd>Lf<cr>", desc = "NeoTree" },
    },
  },

  {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function()
      require("config.toggleterm")
    end,
  },

  -- scrolloff_percentage: controls how close the cursor can be to the top or bottom
  --                       of the screen before scrolling begins
  -- {
  --   "tonymajestro/smart-scrolloff.nvim",
  --   opts = {
  --     scrolloff_percentage = 0.25
  --   },
  -- },
  {
    "karb94/neoscroll.nvim",
    opts = {
      duration_multiplier = 0.65
    },
  },

  -- {
  --   "MeanderingProgrammer/render-markdown.nvim",
  --   main = "render-markdown",
  --   opts = {},
  --   ft = { "markdown" },
  -- },
  -- A list of colorscheme plugin you may want to try. Find what suits you.
  -- { "navarasu/onedark.nvim", lazy = true },
  -- { "sainnhe/edge", lazy = true },
  -- { "sainnhe/sonokai", lazy = true },
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    config = function()
      vim.cmd.colorscheme("gruvbox-material")
    end,
  },
  -- { "sainnhe/everforest", lazy = true },
  -- { "EdenEast/nightfox.nvim", lazy = true },
  -- { "catppuccin/nvim", name = "catppuccin", lazy = true },
  -- { "olimorris/onedarkpro.nvim", lazy = true },
  -- { "marko-cerovac/material.nvim", lazy = true },
  -- {
  --   "rockyzhang24/arctic.nvim",
  --   dependencies = { "rktjmp/lush.nvim" },
  --   name = "arctic",
  --   branch = "v2",
  -- },
  -- { "rebelot/kanagawa.nvim", lazy = true },
  -- { "miikanissi/modus-themes.nvim", priority = 1000 },
  -- { "wtfox/jellybeans.nvim", priority = 1000 },
  -- { "projekt0n/github-nvim-theme", name = "github-theme" },
  -- { "e-ink-colorscheme/e-ink.nvim", priority = 1000 },
  -- { "ficcdaf/ashen.nvim", priority = 1000 },
  -- { "savq/melange-nvim", priority = 1000 },
  -- { "Skardyy/makurai-nvim", priority = 1000 },
  -- { "vague2k/vague.nvim", priority = 1000 },
  -- { "webhooked/kanso.nvim", priority = 1000 },
  -- { "zootedb0t/citruszest.nvim", priority = 1000 },

  -- plugins to provide nerdfont icons
  {
    "nvim-mini/mini.icons",
    version = false,
    config = function()
      -- this is the compatibility fix for plugins that only support nvim-web-devicons
      require("mini.icons").mock_nvim_web_devicons()
      require("mini.icons").tweak_lsp_kind()
    end,
    lazy = true,
  },

  {
    "nvim-lualine/lualine.nvim",
    event = "BufRead",
    cond = firenvim_not_active,
    config = function()
      require("config.lualine")
    end,
  },

  -- {
  --   "akinsho/bufferline.nvim",
  --   event = { "BufEnter" },
  --   cond = firenvim_not_active,
  --   config = function()
  --     require("config.bufferline")
  --   end,
  -- },

  -- fancy start screen
  {
    "nvimdev/dashboard-nvim",
    -- cond = firenvim_not_active,
    config = function()
      require("config.dashboard-nvim")
    end,
  },
  -- Highlight URLs inside vim
  { "itchyny/vim-highlighturl", event = "BufReadPost" },

  -- notification plugin
  -- {
  --   "rcarriga/nvim-notify",
  --   event = "VeryLazy",
  --   config = function()
  --     require("config.nvim-notify")
  --   end,
  -- },

  { "nvim-lua/plenary.nvim", lazy = true },

  -- Only install these plugins if ctags are installed on the system
  -- show file tags in vim window
  -- {
  --   "liuchengxu/vista.vim",
  --   enabled = function()
  --     return utils.executable("ctags")
  --   end,
  --   cmd = "Vista",
  -- },

  -- Automatic insertion and deletion of a pair of characters
  -- {
  --   "windwp/nvim-autopairs",
  --   event = "InsertEnter",
  --   config = true,
  -- },

  -- Comment plugin
  {
    "tpope/vim-commentary",
    keys = {
      { "gc", mode = "n" },
      { "gc", mode = "v" },
    },
  },

  -- Multiple cursor plugin like Sublime Text?
  -- 'mg979/vim-visual-multi'

  -- Show undo history visually
  { "simnalamburt/vim-mundo", cmd = { "MundoToggle", "MundoShow" } },

  -- Manage your yank history
  {
    "gbprod/yanky.nvim",
    config = function()
      require("config.yanky")
    end,
    cmd = "YankyRingHistory",
  },

  -- Repeat vim motions
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- Git command inside vim
  {
    "tpope/vim-fugitive",
    event = "User InGitRepo",
    config = function()
      require("config.fugitive")
    end,
  },

  -- {
  --   "mhinz/vim-signify",
  --   config = function()
  --     require("config.signify")
  --   end,
  -- },

  -- Better git log display
  { "rbong/vim-flog", cmd = { "Flog" } },
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("config.git-conflict")
    end,
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen" },
  },

  {
    "rhysd/vim-grammarous",
    enabled = function()
      return vim.g.is_mac
    end,
    ft = { "markdown" },
  },

  { "chrisbra/unicode.vim", keys = { "ga" }, cmd = { "UnicodeSearch" } },

  -- Additional powerful text object for vim, this plugin should be studied
  -- carefully to use its full power
  -- { "wellle/targets.vim", event = "VeryLazy" },

  -- Plugin to manipulate character pairs quickly
  { "machakann/vim-sandwich", event = "VeryLazy" },

  -- Only use these plugin on Windows and Mac and when LaTeX is installed
  {
    "lervag/vimtex",
    -- enabled = function()
    --   return utils.executable("latex")
    -- end,
    ft = { "tex" },
  },
  {
    "preservim/vim-pencil",
    init = function()
      vim.g["pencil#wrapModeDefault"] = "soft"
    end,
  },

  -- Modern matchit implementation
  -- { "andymass/vim-matchup", event = "BufRead" },
  -- { "tpope/vim-scriptease", cmd = { "Scriptnames", "Messages", "Verbose" } },

  -- Asynchronous command execution
  -- { "skywind3000/asyncrun.vim", lazy = true, cmd = { "AsyncRun" } },
  -- { "cespare/vim-toml", ft = { "toml" }, branch = "main" },

  -- Debugger plugin
  -- {
  --   "sakhnik/nvim-gdb",
  --   enabled = function()
  --     return vim.g.is_win or vim.g.is_linux
  --   end,
  --   build = { "bash install.sh" },
  --   lazy = true,
  -- },

  -- Session management plugin
  { "tpope/vim-obsession", cmd = "Obsession" },

  -- showing keybindings
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("config.which-key")
    end,
  },

  -- show and trim trailing whitespaces
  -- { "jdhao/whitespace.nvim", event = "VeryLazy" },
  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    config = function()
      require("config.bqf")
    end,
  },

  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },

  -- {
    -- show hint for code actions, the user can also implement code actions themselves,
    -- see discussion here: https://github.com/neovim/neovim/issues/14869
  --   "kosayoda/nvim-lightbulb",
  --   config = function()
  --     require("config.lightbulb")
  --   end,
  --   event = "LspAttach",
  -- },

  {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = { -- set to setup table
    },
  },
}


---@diagnostic disable-next-line: missing-fields
require("lazy").setup {
  spec = plugin_specs,
  ui = {
    border = "rounded",
    title = "Plugin Manager",
    title_pos = "center",
  },
  rocks = {
    enabled = false,
    hererocks = false,
  },
}
