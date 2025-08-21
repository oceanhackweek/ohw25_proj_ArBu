import pandas as pd

# original CSV path
ibtracs_path = "/home/jovyan/shared-public/OHW25/ArBu_proj_shared/ibtracs/ibtracs.ALL.list.v04r01.csv"

# loading
ibtracs = pd.read_csv(ibtracs_path, header=0, low_memory=False)
ibtracs.columns = ibtracs.columns.str.strip().str.upper()
ibtracs['SEASON'] = pd.to_numeric(ibtracs['SEASON'], errors='coerce')
ibtracs['LAT'] = pd.to_numeric(ibtracs['LAT'], errors='coerce')
ibtracs['LON'] = pd.to_numeric(ibtracs['LON'], errors='coerce')
ibtracs['ISO_TIME'] = pd.to_datetime(ibtracs['ISO_TIME'], format='%Y-%m-%d %H:%M:%S', errors='coerce')

# 2023 data filtering
ibtracs_2023 = ibtracs[ibtracs['SEASON'] == 2023].dropna(subset=['LAT', 'LON'])

# save
ibtracs_2023.to_csv("ibtracs_2023_cleaned.csv", index=False)
print("2023 ibtracs data saved.")
