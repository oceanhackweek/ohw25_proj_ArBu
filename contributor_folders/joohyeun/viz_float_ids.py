import pandas as pd
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from argopy import DataFetcher
from datetime import timedelta
import os

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

# Output directory for profile logs
output_dir = "argo_profile_logs"
os.makedirs(output_dir, exist_ok=True)

# Group by storm name
storms = ibtracs_2023.groupby('NAME')

# Process each storm
for idx, (name, group) in enumerate(storms, start=1):
    if name not in ['ADRIAN', 'HILARY', 'IDALIA', 'LIDIA']:
        continue  # Skip storms that are not in the target list
    
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

            required_keys = ['LATITUDE', 'LONGITUDE', 'TIME', 'PLATFORM_NUMBER', 'CYCLE_NUMBER']
            if not all(k in ds for k in required_keys):
                continue

            argo_times = pd.to_datetime(ds['TIME'].values)
            lon_argo = ds['LONGITUDE'].values
            lat_argo = ds['LATITUDE'].values
            platform_ids = ds['PLATFORM_NUMBER'].values
            cycle_numbers = ds['CYCLE_NUMBER'].values

            # Classify profiles
            for lon, lat, time, pid, cycle in zip(lon_argo, lat_argo, argo_times, platform_ids, cycle_numbers):
                pid_str = pid.decode() if isinstance(pid, (bytes, bytearray)) else str(pid)
                label = f"{pid_str}-{cycle}"
                entry = f"{label}, {time.date()}, {lat:.2f}, {lon:.2f}"
                if before_start <= time < before_end:
                    argo_before.append(entry)
                elif during_start <= time <= during_end:
                    argo_during.append(entry)
                elif after_start < time <= after_end:
                    argo_after.append(entry)

        except Exception as e:
            print(f"   Skipping point due to error: {e}")
            continue

    # Save profile info to txt file
    argo_before = sorted(set(argo_before))
    argo_during = sorted(set(argo_during))
    argo_after = sorted(set(argo_after))
    txt_filename = os.path.join(output_dir, f"argo_profiles_{name.lower().replace(' ', '_')}.txt")
    with open(txt_filename, 'w') as f:
        f.write(f"Argo Profiles for Hurricane: {name} (2023)\n\n")
        f.write("[Before]\n")
        f.write("\n".join(argo_before) if argo_before else "None\n")
        f.write("\n\n[During]\n")
        f.write("\n".join(argo_during) if argo_during else "None\n")
        f.write("\n\n[After]\n")
        f.write("\n".join(argo_after) if argo_after else "None\n")
    print(f"   Profile info saved to: {txt_filename}")

    # Visualization (without profile labels)
    print("   Generating map visualization...")
    plt.figure(figsize=(10, 6))
    ax = plt.axes(projection=ccrs.PlateCarree())
    ax.set_extent([lon_min - 5, lon_max + 5, lat_min - 5, lat_max + 5])
    ax.add_feature(cfeature.COASTLINE)
    ax.add_feature(cfeature.BORDERS)
    ax.gridlines(draw_labels=True)

    # Hurricane path
    ax.plot(lons, lats, 'r-', label=f"{name} path")
    ax.scatter(lons, lats, color='red', s=10)

    # Argo profiles (no labels)
    def plot_profiles(profiles, color, label_text):
        if profiles:
            coords = [entry.split(',')[-2:] for entry in profiles]
            lon_p = [float(lon.strip()) for _, lon in coords]
            lat_p = [float(lat.strip()) for lat, _ in coords]
            ax.scatter(lon_p, lat_p, color=color, s=10, label=label_text)

    plot_profiles(argo_before, 'magenta', 'Argo: Before')
    plot_profiles(argo_during, 'lime', 'Argo: During')
    plot_profiles(argo_after, 'blue', 'Argo: After')

    plt.title(f"{name} (2023) – Hurricane Path & Argo Profiles")
    plt.legend()
    output_file = f"combined_argo_hurricane_{name.lower().replace(' ', '_')}.png"
    plt.savefig(output_file)
    plt.close()
    print(f"   Map saved to: {output_file}")
