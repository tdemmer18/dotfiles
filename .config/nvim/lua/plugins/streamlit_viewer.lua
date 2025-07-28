return {
  "streamlit-dataframe-viewer",
  dir = vim.fn.stdpath("config") .. "/lua/streamlit_viewer",
  config = function()
    require("streamlit_viewer").setup()
  end,
}