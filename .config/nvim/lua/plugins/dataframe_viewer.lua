return {
  "dataframe-viewer",
  dir = vim.fn.stdpath("config") .. "/lua/dataframe_viewer",
  config = function()
    require("dataframe_viewer").setup()
  end,
}