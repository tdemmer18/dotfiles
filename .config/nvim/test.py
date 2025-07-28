import pandas as pd

df = pd.read_csv("~/Documents/models/goals_for_output.csv")

print(df.head())

df
df.columns


(df.loc[:, ["goals_for feature", "coef"]].query("coef > 0"))


df.coef


df["intercept"]
