return {
  {
    "jpalardy/vim-slime",
    init = function()
      vim.g.slime_target = "tmux"
      vim.g.slime_default_config = {
        socket_name = "default",
        target_pane = "1.2",
      }
      vim.g.slime_python_ipython = 1
    end,
    config = function()
      vim.keymap.set("n", "<leader>cc", function()
        vim.fn["slime#send"]("clear\n")
        vim.cmd("SlimeSend")
      end, { desc = "Clear REPL and send" })
      
      local function setup_tmux_panes_and_send()
        -- Get current pane count and info
        local pane_list = vim.fn.system("tmux list-panes -t 1 -F '#{pane_index}' 2>/dev/null")
        local pane_count = 0
        for _ in pane_list:gmatch("[^\r\n]+") do
          pane_count = pane_count + 1
        end
        
        if pane_count < 2 then
          -- No second pane exists, create vertical split
          vim.fn.system("tmux split-window -t 1.1 -h")
          vim.fn.system("tmux send-keys -t 1.2 'python3' Enter")
          -- Update target to new pane
          vim.g.slime_default_config.target_pane = "1.2"
        elseif pane_count == 2 then
          -- Pane 1.2 exists (opencode), split it vertically
          vim.fn.system("tmux split-window -t 1.2 -v")
          vim.fn.system("tmux send-keys -t 1.2 'python3' Enter")
          -- Now: 1.1=nvim, 1.2=new python (top-right), 1.3=opencode (bottom-right)
          vim.g.slime_default_config.target_pane = "1.2"
        end
        
        -- Clear and send to the python pane
        vim.fn["slime#send"]("clear\n")
        local line = vim.api.nvim_get_current_line()
        vim.fn["slime#send"](line .. "\n")
      end
      
      local function clear_and_send_line()
        vim.fn["slime#send"]("clear\n")
        local line = vim.api.nvim_get_current_line()
        vim.fn["slime#send"](line .. "\n")
      end
      
      -- Alt+Enter: Setup tmux panes and send current line
      vim.keymap.set("n", "<M-CR>", setup_tmux_panes_and_send, { desc = "Setup panes and send current line" })
      vim.keymap.set("i", "<M-CR>", setup_tmux_panes_and_send, { desc = "Setup panes and send current line" })
      
      -- Temporary: Keep leader r as backup
      vim.keymap.set("n", "<leader>r", clear_and_send_line, { desc = "Clear REPL and send current line" })
      vim.keymap.set("i", "<leader>r", clear_and_send_line, { desc = "Clear REPL and send current line" })
    end,
  },
}
