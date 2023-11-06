return {
  -- Add the community repository of plugin specifications
  "AstroNvim/astrocommunity",
  -- example of importing a plugin, comment out to use it or add your own
  -- available plugins can be found at https://github.com/AstroNvim/astrocommunity

  -- { import = "astrocommunity.colorscheme.catppuccin" },
  -- { import = "astrocommunity.completion.copilot-lua-cmp" },
     { 
       import = "astrocommunity.markdown-and-latex.vimtex",
       config = function()
         vim.g.tex_flavor = 'latex'
         vim.g.vimtex_view_method = 'zathura'
         vim.g.vimtex_quickfix_mode = 0
         vim.o.conceallevel = 1
         vim.g.tex_conceal = 'abdmg'
       end
     },
}
