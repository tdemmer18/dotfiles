return {
  "saghen/blink.nvim",
  build = "cargo build --release", -- for delimiters
  keys = {
    -- chartoggle
    {
      "<C-;>",
      function()
        require("blink.chartoggle").toggle_char_eol(";")
      end,
      mode = { "n", "v" },
      desc = "Toggle ; at eol",
    },
    {
      ",",
      function()
        require("blink.chartoggle").toggle_char_eol(",")
      end,
      mode = { "n", "v" },
      desc = "Toggle , at eol",
    },

    -- tree
    { "<C-e>", "<cmd>BlinkTree reveal<cr>", desc = "Reveal current file in tree" },
    { "<leader>E", "<cmd>BlinkTree toggle<cr>", desc = "Reveal current file in tree" },
    { "<leader>e", "<cmd>BlinkTree toggle<cr>", desc = "Toggle file tree" },
    { "<leader>ec", "<cmd>BlinkTree close<cr>", desc = "Close file tree" },
  },
  -- all modules handle lazy loading internally
  lazy = false,
  opts = {
    chartoggle = { enabled = true },
    tree = { enabled = true },
  },
}
