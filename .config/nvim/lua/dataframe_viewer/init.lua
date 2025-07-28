local M = {}

local function create_floating_window()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " DataFrame Viewer ",
    title_pos = "center"
  })
  
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "filetype", "dataframe")
  
  return buf, win
end

local function get_python_code_from_line()
  local line = vim.api.nvim_get_current_line()
  local trimmed = line:match("^%s*(.-)%s*$")
  
  if trimmed:match("^#") then
    return nil
  end
  
  if trimmed:match("df") or trimmed:match("DataFrame") or trimmed:match("%.head") or 
     trimmed:match("%.tail") or trimmed:match("%.describe") or trimmed:match("%.info") then
    return trimmed
  end
  
  return nil
end

local function execute_python_and_get_dataframe(code)
  
  local python_script = [[
import sys
import json
import traceback
import os

try:
    import pandas as pd
    import numpy as np
    
    print("DEBUG: Libraries imported", file=sys.stderr)
    
    # Execute any Python files in current directory to load variables
    exec_globals = {'pd': pd, 'np': np, 'DataFrame': pd.DataFrame, 'Series': pd.Series}
    
    # Try to execute the current file to get the same context
    current_file = ']] .. vim.fn.expand('%:p') .. [['
    if current_file.endswith('.py') and os.path.exists(current_file):
        print(f"DEBUG: Executing current file: {current_file}", file=sys.stderr)
        try:
            with open(current_file, 'r') as f:
                file_content = f.read()
            exec(file_content, exec_globals)
            print("DEBUG: Current file executed successfully", file=sys.stderr)
        except Exception as e:
            print(f"DEBUG: Error executing file: {e}", file=sys.stderr)
    else:
        print("DEBUG: No Python file context, using sample data", file=sys.stderr)
        # Fallback to sample data
        df = pd.DataFrame({
            'Name': ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'],
            'Age': [25, 30, 35, 28, 32],
            'City': ['New York', 'London', 'Tokyo', 'Paris', 'Berlin'],
            'Salary': [50000, 60000, 75000, 55000, 68000],
            'Department': ['Engineering', 'Marketing', 'Engineering', 'Sales', 'Marketing']
        })
        exec_globals['df'] = df
    
    code_to_eval = ]] .. string.format("%q", code) .. [[
    
    print("DEBUG: About to evaluate: " + code_to_eval, file=sys.stderr)
    result = eval(code_to_eval, exec_globals)
    print("DEBUG: Evaluation complete", file=sys.stderr)
    
    # Handle different result types
    if isinstance(result, pd.DataFrame):
        pass  # Already a DataFrame
    elif isinstance(result, pd.Series):
        result = result.to_frame()
        if result.columns[0] == 0:  # Unnamed series
            result.columns = ['Value']
    else:
        print(json.dumps({"error": "Result is not a DataFrame or Series, got: " + str(type(result))}))
        sys.exit(1)
    
    print("DEBUG: Converting to JSON", file=sys.stderr)
    
    # Convert DataFrame to JSON with metadata
    df_info = {
        "shape": list(result.shape),
        "columns": result.columns.tolist(),
        "dtypes": {str(k): str(v) for k, v in result.dtypes.items()},
        "data": result.head(100).to_dict('records'),
        "index": result.head(100).index.tolist()
    }
    
    print(json.dumps(df_info))
    
except ImportError as e:
    print(json.dumps({"error": "Missing required library: " + str(e)}))
    sys.exit(1)
except Exception as e:
    error_info = {
        "error": str(e),
        "traceback": traceback.format_exc()
    }
    print(json.dumps(error_info))
    sys.exit(1)
]]
  
  local temp_file = vim.fn.tempname() .. ".py"
  
  local file = io.open(temp_file, "w")
  if not file then
    return nil, "Could not create temporary file"
  end
  
  file:write(python_script)
  file:close()
  
  local result = vim.fn.system("python3 " .. temp_file)
  
  vim.fn.delete(temp_file)
  
  if result == "" then
    return nil, "Python script produced no output"
  end
  
  -- Extract JSON from output (filter out debug messages)
  local json_line = nil
  for line in result:gmatch("[^\r\n]+") do
    if line:match("^{.*}$") then
      json_line = line
      break
    end
  end
  
  if not json_line then
    return nil, "No JSON found in Python output: " .. result
  end
  

  
  local success, data = pcall(vim.fn.json_decode, json_line)
  if not success then
    return nil, "Failed to parse JSON: " .. json_line
  end
  
  if data.error then
    return nil, data.error
  end
  
  return data, nil
end

local function format_dataframe_display(df_data, sort_col, sort_desc, filter_text)
  local lines = {}
  local columns = df_data.columns
  local data = df_data.data
  
  -- Apply filtering
  local filtered_data = {}
  if filter_text and filter_text ~= "" then
    for _, row in ipairs(data) do
      local match = false
      for _, value in pairs(row) do
        if tostring(value):lower():find(filter_text:lower()) then
          match = true
          break
        end
      end
      if match then
        table.insert(filtered_data, row)
      end
    end
  else
    filtered_data = data
  end
  
  -- Apply sorting
  if sort_col and sort_col ~= "" then
    table.sort(filtered_data, function(a, b)
      local val_a = a[sort_col]
      local val_b = b[sort_col]
      
      if type(val_a) == "number" and type(val_b) == "number" then
        return sort_desc and val_a > val_b or val_a < val_b
      else
        return sort_desc and tostring(val_a) > tostring(val_b) or tostring(val_a) < tostring(val_b)
      end
    end)
  end
  
  -- Header
  table.insert(lines, string.format("DataFrame Shape: %dx%d | Showing: %d rows", 
    df_data.shape[1], df_data.shape[2], #filtered_data))
  table.insert(lines, "")
  
  -- Controls
  table.insert(lines, "Controls: s=sort, f=filter, r=refresh, q=quit")
  if sort_col then
    table.insert(lines, string.format("Sorted by: %s (%s)", sort_col, sort_desc and "desc" or "asc"))
  end
  if filter_text and filter_text ~= "" then
    table.insert(lines, string.format("Filter: '%s'", filter_text))
  end
  table.insert(lines, string.rep("─", 80))
  
  -- Column headers
  local header = ""
  local col_widths = {}
  for _, col in ipairs(columns) do
    local width = math.max(15, string.len(col))
    col_widths[col] = width
    header = header .. string.format("%-" .. width .. "s │ ", col)
  end
  table.insert(lines, header)
  table.insert(lines, string.rep("─", 80))
  
  -- Data rows
  for i, row in ipairs(filtered_data) do
    if i > 50 then  -- Limit display to 50 rows
      table.insert(lines, "... (showing first 50 rows)")
      break
    end
    
    local line = ""
    for _, col in ipairs(columns) do
      local value = row[col]
      if value == nil then
        value = "NaN"
      elseif type(value) == "number" then
        value = string.format("%.3f", value)
      else
        value = tostring(value)
      end
      
      if string.len(value) > col_widths[col] - 1 then
        value = string.sub(value, 1, col_widths[col] - 4) .. "..."
      end
      
      line = line .. string.format("%-" .. col_widths[col] .. "s │ ", value)
    end
    table.insert(lines, line)
  end
  
  return lines
end

local current_df_data = nil
local current_sort_col = nil
local current_sort_desc = false
local current_filter = ""

local function refresh_display(buf)
  if not current_df_data then return end
  
  local lines = format_dataframe_display(current_df_data, current_sort_col, current_sort_desc, current_filter)
  
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function setup_keymaps(buf, win)
  local opts = { buffer = buf, silent = true }
  
  -- Quit
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  
  -- Sort
  vim.keymap.set("n", "s", function()
    if not current_df_data then return end
    
    vim.ui.select(current_df_data.columns, {
      prompt = "Sort by column:",
    }, function(choice)
      if choice then
        if current_sort_col == choice then
          current_sort_desc = not current_sort_desc
        else
          current_sort_col = choice
          current_sort_desc = false
        end
        refresh_display(buf)
      end
    end)
  end, opts)
  
  -- Filter
  vim.keymap.set("n", "f", function()
    vim.ui.input({
      prompt = "Filter text: ",
      default = current_filter,
    }, function(input)
      if input ~= nil then
        current_filter = input
        refresh_display(buf)
      end
    end)
  end, opts)
  
  -- Refresh
  vim.keymap.set("n", "r", function()
    refresh_display(buf)
  end, opts)
end

function M.view_dataframe()
  local success, result = pcall(function()
    local code = get_python_code_from_line()
    
    if not code then
      vim.notify("No dataframe code detected on current line", vim.log.levels.WARN)
      return
    end
    
    vim.notify("Executing: " .. code, vim.log.levels.INFO)
    
    local df_data, error = execute_python_and_get_dataframe(code)
    
    if error then
      vim.notify("Error: " .. error, vim.log.levels.ERROR)
      return
    end
    
    current_df_data = df_data
    current_sort_col = nil
    current_sort_desc = false
    current_filter = ""
    
    local buf, win = create_floating_window()
    setup_keymaps(buf, win)
    refresh_display(buf)
  end)
  
  if not success then
    vim.notify("Plugin error: " .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.setup()
  -- Set up the command and keymap
  vim.api.nvim_create_user_command("DataFrameView", M.view_dataframe, {})
  vim.keymap.set("n", "<leader>dv", M.view_dataframe, { desc = "View DataFrame" })
end

return M