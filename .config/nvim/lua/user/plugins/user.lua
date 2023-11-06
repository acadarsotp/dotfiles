return {
  -- You can also add new plugins here as well:
  -- Add plugins, the lazy syntax
  -- "andweeb/presence.nvim",
  -- {
  --   "ray-x/lsp_signature.nvim",
  --   event = "BufRead",
  --   config = function()
  --     require("lsp_signature").setup()
  --   end,
  -- },

  {
  	"SirVer/ultisnips",
  	ft = "tex",
  	config = function()
      vim.g.UltiSnipsExpandTrigger = '<tab>'
      vim.g.UltiSnipsJumpForwardTrigger = '<tab>'
      vim.g.UltiSnipsJumpBackwardTrigger = '<s-tab>'
      vim.g.UltiSnipsSnippetDirectories = {"~/.config/nvim/lua/user/plugins/UltiSnips/"}
    end,
  },
}



--vim.g.UltiSnipsSnippetDirectories = ['~/.config/nvim/lua/user/plugins/UltiSnips']                             
