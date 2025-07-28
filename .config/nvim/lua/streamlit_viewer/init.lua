local M = {}

local function get_python_code_from_line()
  local line = vim.api.nvim_get_current_line()
  local trimmed = line:match("^%s*(.-)%s*$")

  if trimmed:match("^#") then
    return nil
  end

  if
    trimmed:match("df")
    or trimmed:match("DataFrame")
    or trimmed:match("%.head")
    or trimmed:match("%.tail")
    or trimmed:match("%.describe")
    or trimmed:match("%.info")
  then
    return trimmed
  end

  return nil
end

local function create_streamlit_app(code)
  local current_file = vim.fn.expand("%:p")
  local app_content = string.format(
    [[
import streamlit as st
import pandas as pd
import numpy as np
import sys
import os

# Set page config
st.set_page_config(
    page_title="Tom's DataFrame Viewer",
    page_icon="📊",
    layout="wide"
)

st.title("📊 Tom's DataFrame Viewer")
st.markdown("---")

try:
    # Execute the current file to get context
    current_file = %q
    if current_file.endswith('.py') and os.path.exists(current_file):
        st.info(f"Loading data from: {os.path.basename(current_file)}")
        
        # Read and execute the file
        with open(current_file, 'r') as f:
            file_content = f.read()
        
        # Create execution context
        exec_globals = {'pd': pd, 'np': np, 'st': st}
        exec(file_content, exec_globals)
        
        # Evaluate the specific code
        code_to_eval = %q
        result = eval(code_to_eval, exec_globals)
        
        # Display the dataframe
        if isinstance(result, pd.DataFrame):
            st.subheader(f"Result of: `{code_to_eval}`")
            
            # Show basic info
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Rows", result.shape[0])
            with col2:
                st.metric("Columns", result.shape[1])
            with col3:
                st.metric("Memory Usage", f"{result.memory_usage(deep=True).sum() / 1024:.1f} KB")
            
            # Show data types
            with st.expander("📋 Column Information"):
                dtype_df = pd.DataFrame({
                    'Column': result.columns,
                    'Data Type': result.dtypes.astype(str),
                    'Non-Null Count': result.count(),
                    'Null Count': result.isnull().sum()
                })
                st.dataframe(dtype_df, use_container_width=True)
            
            # Main dataframe display with filtering
            st.subheader("🔍 Interactive Data Explorer")
            
            # Add filters
            col1, col2 = st.columns([1, 3])
            
            with col1:
                st.markdown("**Filters:**")
                
                # Column selector for filtering
                if len(result.columns) > 0:
                    filter_column = st.selectbox("Filter by column:", ["None"] + list(result.columns))
                    
                    if filter_column != "None":
                        if result[filter_column].dtype in ['object', 'string']:
                            # Text filter for string columns
                            filter_value = st.text_input(f"Filter {filter_column} contains:")
                            if filter_value:
                                result = result[result[filter_column].astype(str).str.contains(filter_value, case=False, na=False)]
                        else:
                            # Numeric filter
                            min_val = float(result[filter_column].min())
                            max_val = float(result[filter_column].max())
                            filter_range = st.slider(
                                f"Filter {filter_column} range:",
                                min_val, max_val, (min_val, max_val)
                            )
                            result = result[
                                (result[filter_column] >= filter_range[0]) & 
                                (result[filter_column] <= filter_range[1])
                            ]
                
                # Sort options
                if len(result.columns) > 0:
                    sort_column = st.selectbox("Sort by column:", ["None"] + list(result.columns))
                    if sort_column != "None":
                        sort_ascending = st.checkbox("Ascending", value=True)
                        result = result.sort_values(sort_column, ascending=sort_ascending)
            
            with col2:
                # Display the filtered/sorted dataframe
                st.dataframe(
                    result, 
                    use_container_width=True,
                    height=600
                )
            
            # Summary statistics
            if result.select_dtypes(include=[np.number]).shape[1] > 0:
                with st.expander("📈 Summary Statistics"):
                    st.dataframe(result.describe(), use_container_width=True)
            
        elif isinstance(result, pd.Series):
            st.subheader(f"Result of: `{code_to_eval}`")
            
            # Convert series to dataframe for display
            series_df = result.to_frame()
            if series_df.columns[0] == 0:
                series_df.columns = ['Value']
            
            col1, col2 = st.columns(2)
            with col1:
                st.metric("Length", len(result))
            with col2:
                st.metric("Data Type", str(result.dtype))
            
            st.dataframe(series_df, use_container_width=True, height=400)
            
            if result.dtype in [np.number, 'int64', 'float64']:
                with st.expander("📈 Series Statistics"):
                    st.dataframe(result.describe().to_frame().T, use_container_width=True)
        
        else:
            st.error(f"Result is not a DataFrame or Series. Got: {type(result)}")
            st.code(str(result))
    
    else:
        st.error("No Python file found or file doesn't exist")
        st.info("Make sure you're in a Python file with dataframe code")

except Exception as e:
    st.error(f"Error executing code: {str(e)}")
    st.code(f"Code that failed: {code_to_eval}")
    
    # Show traceback in expander
    import traceback
    with st.expander("🐛 Error Details"):
        st.code(traceback.format_exc())

# Add refresh button
if st.button("🔄 Refresh Data"):
    st.rerun()
]],
    current_file,
    code
  )

  return app_content
end

local function run_streamlit_viewer(code)
  local app_content = create_streamlit_app(code)

  -- Create temporary streamlit app file
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  local app_file = temp_dir .. "/dataframe_app.py"

  local file = io.open(app_file, "w")
  if not file then
    vim.notify("Could not create Streamlit app file", vim.log.levels.ERROR)
    return
  end

  file:write(app_content)
  file:close()

  -- Run streamlit in the background
  local port = math.random(8501, 8600) -- Random port to avoid conflicts
  local cmd = string.format(
    "cd %s && streamlit run %s --server.port %d --server.headless true --browser.gatherUsageStats false",
    temp_dir,
    app_file,
    port
  )

  vim.notify(string.format("Starting Streamlit on port %d...", port), vim.log.levels.INFO)

  -- Start streamlit in background
  vim.fn.jobstart(cmd, {
    detach = true,
    on_exit = function()
      -- Clean up temp files when streamlit exits
      vim.fn.delete(temp_dir, "rf")
    end,
  })

  -- Wait a moment then open browser
  vim.defer_fn(function()
    local url = string.format("http://localhost:%d", port)
    vim.notify(string.format("Opening %s in browser", url), vim.log.levels.INFO)
    vim.fn.jobstart({ "open", url }, { detach = true })
  end, 2000) -- Wait 2 seconds for streamlit to start
end

function M.view_streamlit()
  local success, result = pcall(function()
    local code = get_python_code_from_line()

    if not code then
      vim.notify("No dataframe code detected on current line", vim.log.levels.WARN)
      return
    end

    vim.notify("Creating Streamlit app for: " .. code, vim.log.levels.INFO)
    run_streamlit_viewer(code)
  end)

  if not success then
    vim.notify("Plugin error: " .. tostring(result), vim.log.levels.ERROR)
  end
end

function M.setup()
  -- Set up the command and keymap
  vim.api.nvim_create_user_command("StreamlitView", M.view_streamlit, {})
  vim.keymap.set("n", "<leader>ds", M.view_streamlit, { desc = "View DataFrame in Streamlit" })
end

return M
