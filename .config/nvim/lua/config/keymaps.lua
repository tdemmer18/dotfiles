-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--

vim.keymap.set("n", "<S-CR>", function()
  -- Send the current line via Slime
  vim.cmd("SlimeSendCurrentLine")

  -- Move to next non-blank line
  local curr = vim.fn.line(".")
  local total = vim.fn.line("$")

  for lnum = curr + 1, total do
    local line = vim.fn.getline(lnum)
    if line:match("%S") and not line:match("^%s*#") then
      vim.fn.cursor(lnum, 1)
      break
    end
  end
end, { noremap = true, silent = true })

vim.keymap.set("v", "<S-CR>", function()
  vim.cmd("SlimeRegionSend")
end, { noremap = true, silent = true })
