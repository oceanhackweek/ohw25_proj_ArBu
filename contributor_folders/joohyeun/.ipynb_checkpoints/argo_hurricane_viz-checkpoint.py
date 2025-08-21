import pandas as pd
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from argopy import DataFetcher
from geopy.distance import geodesic
from datetime import timedelta

# 1. Load IBTrACS CSV
print("Loading IBTrACS CSV file...")
ibtracs_path = "/home/jovyan/shared-public/OHW25/ArBu_proj_shared/ibtracs/ibtracs.ALL.list.v04r01.csv"
ibtracs = pd.read_csv(ibtracs_path, header=0, low_memory=False)

ibtracs['SEASON'] = pd.to_numeric(ibtracs['SEASON'], errors='coerce')
ibtracs['LAT'] = pd.to_numeric(ibtracs['LAT'], errors='coerce')
ibtracs['LON'] = pd.to_numeric(ibtracs['LON'], errors='coerce')
ibtracs['ISO_TIME'] = pd.to_datetime(ibtracs['ISO_TIME'], format='%Y-%m-%d %H:%M:%S', errors='coerce')

ibtracs_2023 = ibtracs[ibtracs['SEASON'] == 2023].dropna(subset=['LAT', 'LON'])


# 2. Clean column names
ibtracs.columns = ibtracs.columns.str.strip().str.upper()

# 3. Parse datetime and filter for 2023 season
print("Parsing datetime and filtering for 2023 season...")

storm_count = ibtracs_2023['NAME'].nunique()
print(f"Total storms found for 2023: {storm_count}")

# 4. Group by storm name
print("Grouping storm data by name...")
storms = ibtracs_2023.groupby('NAME')

# 5. Loop through each storm
for idx, (name, group) in enumerate(storms, start=1):
    print(f"\n[{idx}/{storm_count}] Processing storm: {name}")
    group = group.sort_values('ISO_TIME')
    lats = group['LAT'].values
    lons = group['LON'].values
    times = group['ISO_TIME'].values

    print("Calculating bounding box and time window...")
    lat_min, lat_max = lats.min() - 1, lats.max() + 1
    lon_min, lon_max = lons.min() - 1, lons.max() + 1
    time_start = pd.Timestamp(times.min()) - timedelta(days=1)
    time_end = pd.Timestamp(times.max()) + timedelta(days=1)
    print(f"   → Lat range: {lat_min:.2f} to {lat_max:.2f}")
    print(f"   → Lon range: {lon_min:.2f} to {lon_max:.2f}")
    print(f"   → Time window: {time_start.date()} to {time_end.date()}")

    print("Fetching Argo profiles from Argopy...")
    try:
        ds = DataFetcher().region([lon_min, lon_max, lat_min, lat_max, 0, 2000, str(time_start.date()), str(time_end.date())]).to_xarray()

        if 'LATITUDE' in ds and 'LONGITUDE' in ds:
            profile_count = len(ds['LATITUDE'])
            print(f"Argo profiles retrieved: {profile_count}")
        else:
            print(f"No LATITUDE/LONGITUDE found in Argo dataset for {name}")
            continue
    except Exception as e:
        print(f"Skipping {name} due to Argo fetch error: {e}")
        continue

    print("Generating map visualization...")
    plt.figure(figsize=(10, 6))
    ax = plt.axes(projection=ccrs.PlateCarree())
    ax.set_extent([lon_min - 5, lon_max + 5, lat_min - 5, lat_max + 5])
    ax.add_feature(cfeature.COASTLINE)
    ax.add_feature(cfeature.BORDERS)
    ax.gridlines(draw_labels=True)

    # Plot hurricane path
    ax.plot(lons, lats, 'r-', label=f"{name} path")
    ax.scatter(lons, lats, color='red', s=10)

    # Plot Argo profiles
    ax.scatter(ds['LONGITUDE'], ds['LATITUDE'], color='blue', s=10, label='Argo profiles')

    plt.title(f"{name} (2023) Hurricane Path & Argo Profiles")
    plt.legend()
    output_file = f"hurricane_argo_{name.lower().replace(' ', '_')}.png"
    plt.savefig(output_file)
    plt.close()
    print(f"Map saved to: {output_file}")
