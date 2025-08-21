import pandas as pd
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from argopy import DataFetcher
from datetime import timedelta

# Load and clean IBTrACS CSV
print("Loading IBTrACS CSV file...")
ibtracs_path = "/home/jovyan/shared-public/OHW25/ArBu_proj_shared/ibtracs/ibtracs.ALL.list.v04r01.csv"
ibtracs = pd.read_csv(ibtracs_path, header=0, low_memory=False)

# Standardize and parse columns
ibtracs.columns = ibtracs.columns.str.strip().str.upper()
ibtracs['SEASON'] = pd.to_numeric(ibtracs['SEASON'], errors='coerce')
ibtracs['LAT'] = pd.to_numeric(ibtracs['LAT'], errors='coerce')
ibtracs['LON'] = pd.to_numeric(ibtracs['LON'], errors='coerce')
ibtracs['ISO_TIME'] = pd.to_datetime(ibtracs['ISO_TIME'], format='%Y-%m-%d %H:%M:%S', errors='coerce')

# Filter for 2023 season
ibtracs_2023 = ibtracs[ibtracs['SEASON'] == 2023].dropna(subset=['LAT', 'LON', 'ISO_TIME'])
storm_count = ibtracs_2023['NAME'].nunique()
print(f"Total storms found for 2023: {storm_count}")

# Group by storm name
storms = ibtracs_2023.groupby('NAME')

# Process each storm
for idx, (name, group) in enumerate(storms, start=1):
    print(f"\n[{idx}/{storm_count}] Processing storm: {name}")
    group = group.sort_values('ISO_TIME')

    # Hurricane path coordinates
    lats = group['LAT'].values
    lons = group['LON'].values
    times = pd.to_datetime(group['ISO_TIME'].values)

    # Define overall bounding box and time range
    lat_min, lat_max = lats.min() - 2, lats.max() + 2
    lon_min, lon_max = lons.min() - 2, lons.max() + 2
    time_start = pd.Timestamp(times.min()) - timedelta(days=14)
    time_end = pd.Timestamp(times.max()) + timedelta(days=14)

    # Initialize containers for Argo profiles
    argo_before = []
    argo_during = []
    argo_after = []

    # Loop through each hurricane point
    for point_time, point_lat, point_lon in zip(times, lats, lons):
        point_time = pd.Timestamp(point_time)

        # Define time windows
        before_start = point_time - timedelta(days=14)
        before_end   = point_time - timedelta(days=1)
        during_start = point_time - timedelta(days=1)
        during_end   = point_time + timedelta(days=1)
        after_start  = point_time + timedelta(days=1)
        after_end    = point_time + timedelta(days=14)

        # Define local bounding box
        lat_box_min, lat_box_max = point_lat - 2, point_lat + 2
        lon_box_min, lon_box_max = point_lon - 2, point_lon + 2

        try:
            ds = DataFetcher().region([
                lon_box_min, lon_box_max, lat_box_min, lat_box_max, 0, 2000,
                str(before_start.date()), str(after_end.date())
            ]).to_xarray()

            if 'LATITUDE' not in ds or 'LONGITUDE' not in ds or 'TIME' not in ds:
                continue

            argo_times = pd.to_datetime(ds['TIME'].values)
            lon_argo = ds['LONGITUDE'].values
            lat_argo = ds['LATITUDE'].values

            # Classify profiles
            before_mask = (argo_times >= before_start) & (argo_times < before_end)
            during_mask = (argo_times >= during_start) & (argo_times <= during_end)
            after_mask  = (argo_times > after_start) & (argo_times <= after_end)

            argo_before.extend(zip(lon_argo[before_mask], lat_argo[before_mask]))
            argo_during.extend(zip(lon_argo[during_mask], lat_argo[during_mask]))
            argo_after.extend(zip(lon_argo[after_mask], lat_argo[after_mask]))

        except Exception as e:
            if "erddap.ifremer.fr/erddap/tabledap/ArgoFloats.nc" in str(e):
                continue  # Silently skip known ERDDAP error
            print(f"   Skipping point due to error: {e}")
            continue

    # Visualization
    print("   Generating combined map visualization...")
    plt.figure(figsize=(10, 6))
    ax = plt.axes(projection=ccrs.PlateCarree())
    ax.set_extent([lon_min - 5, lon_max + 5, lat_min - 5, lat_max + 5])
    ax.add_feature(cfeature.COASTLINE)
    ax.add_feature(cfeature.BORDERS)
    ax.gridlines(draw_labels=True)

    # Hurricane path
    ax.plot(lons, lats, 'r-', label=f"{name} path")
    ax.scatter(lons, lats, color='red', s=10)

    # Argo profiles
    if argo_before:
        lon_b, lat_b = zip(*argo_before)
        ax.scatter(lon_b, lat_b, color='magenta', s=10, label='Argo: Before')
    if argo_during:
        lon_d, lat_d = zip(*argo_during)
        ax.scatter(lon_d, lat_d, color='lime', s=10, label='Argo: During')
    if argo_after:
        lon_a, lat_a = zip(*argo_after)
        ax.scatter(lon_a, lat_a, color='blue', s=10, label='Argo: After')

    plt.title(f"{name} (2023) – Hurricane Path & Argo Profiles")
    plt.legend()
    output_file = f"combined_argo_hurricane_{name.lower().replace(' ', '_')}.png"
    plt.savefig(output_file)
    plt.close()
    print(f"   Map saved to: {output_file}")
