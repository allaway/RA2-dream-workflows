import pandas as pd

template = pd.read_csv("/test/template.csv")
template.fillna(2)
template.to_csv("/output/predictions.csv",index=False)