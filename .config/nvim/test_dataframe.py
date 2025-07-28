import pandas as pd
import numpy as np

# Create sample dataframes for testing
df = pd.DataFrame({
    'Name': ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'],
    'Age': [25, 30, 35, 28, 32],
    'City': ['New York', 'London', 'Tokyo', 'Paris', 'Berlin'],
    'Salary': [50000, 60000, 75000, 55000, 68000],
    'Department': ['Engineering', 'Marketing', 'Engineering', 'Sales', 'Marketing']
})

# Test lines - place cursor on any of these and press <leader>dv
df
df.head()
df.describe()
df[df['Age'] > 30]
df.groupby('Department')['Salary'].mean()