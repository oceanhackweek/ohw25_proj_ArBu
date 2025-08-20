
# Insert path code of OneArgo-R toolbox
path_code = "~/shared-public/OHW25/ArBu_proj_shared/OneArgo-R/"

# Load the functions and libraries--------------------------------

setwd(path_code)
func.sources = list.files(path_code,pattern="*.R")
func.sources = func.sources[which(func.sources %in% c('Tutorial.R',
                                                      "oneargo_r_license.R")==F)]

if(length(grep("Rproj",func.sources))!=0){
  func.sources = func.sources[-grep("Rproj",func.sources)]
}
invisible(sapply(paste0(func.sources),source,.GlobalEnv))

aux.func.sources = list.files(paste0(path_code,"/auxil"),pattern="*.R")
invisible(sapply(paste0(path_code,"/auxil/",aux.func.sources),source,.GlobalEnv))

# Initialize Argo dataset ----------------------------

initialize_argo() # Take some minutes to download the global Index (need multiple Gb of RAM to do this)


# Set limits near Gulf of Mexico from a given hurricane time
lat_lim=c(15, 30)
lon_lim=c(-98, -80)

#Hurricane Milton: 
# hurricane_name = 'Milton'
# start_date="2021-9-01"
# end_date="2021-11-01"

#Insert info for additional hurricanes: 
hurricane_name = 'Ida'
start_date="2021-08-15"
end_date="2021-09-30"


# Select profiles based on those limits with specified sensor (I chose oxygen since most BGC floats have this sensor)

GoM_data= select_profiles ( lon_lim, 
                            lat_lim, 
                            start_date,
                            end_date,
                            sensor=c('DOXY'), # this selects only floats with oxygen sensors
                            outside="none" #  All floats that cross into the time/space limits
)  # are identified from the Sprof index. The optional 

# 'outside' argument allows the user to specify
# whether to retain profiles from those floats that
# lie outside the space limits ('space'), time
# limits ('time'), both time and space limits 
# ('both'), or to exclude all profiles that fall 
# outside the limits ('none'). The default is 'none'

# Display the number of matching floats and profiles
print(paste('# of matching profiles:',sum(lengths(GoM_data$float_profs))))

print(paste('# of matching floats:',length(GoM_data$float_ids)))

# Load the data for the matching float with format of data frame
data_GoM_df= load_float_data( float_ids= GoM_data$float_ids, # specify WMO number
                              float_profs=GoM_data$float_profs, # specify selected profiles
                              variables="ALL", # load all the variables
                              format="dataframe" # specify format;  
)

# Bind the datasets
all_data<-unique(data_GoM_df[,which(colnames(data_GoM_df) %in% c("LATITUDE","LONGITUDE","WMOID"))]) #reduce the dataset

# Set lat and lon limits
lon_lim = range(all_data$LONGITUDE,na.rm=T)
lat_lim = range(all_data$LATITUDE,na.rm=T)

#zoom out so you can see more land
#latlim = c(lat_lim[1]-2, lat_lim[2]+2)
#lonlim = c(lon_lim[1]-2, lon_lim[2]+2)
latlim = c(lat_lim[1]-5, lat_lim[2]+5)
lonlim = c(lon_lim[1]-5, lon_lim[2]+5)
#convert lon to -180 to +180 scale
#lonlim <- ifelse(lonlim > 180, lonlim - 360, lonlim)

lon_range <- c(lonlim[1], lonlim[2])
lat_range <- c(latlim[1], latlim[2])

# get the land map
world = map_data("world")

float_map = ggplot(all_data, mapping=aes(x=LONGITUDE, y=LATITUDE)) +
  theme_bw() +
  geom_polygon(data=world, aes(x=long, y=lat, group=group),
               fill="#dddddd") +
  geom_path(aes(group=WMOID, col=WMOID)) +
  geom_point(aes(group=WMOID, col=WMOID)) +
  coord_cartesian(xlim=lonlim, ylim=latlim) +
  theme(axis.title.x = element_text(size=20),
        axis.text.x = element_text(size=20),
        axis.title.y = element_text(size=20),
        axis.text.y = element_text(size=20) ) +
  labs(x =expression (Longitude~"("~"°"~E~")"),
       y =expression (Latitude~"("~"°"~N~")"),
       title = paste0("Float Profiles During Hurricane ",hurricane_name)) +
  theme(legend.text = element_text(size =20))+
  theme(legend.title=element_blank())+
  theme(plot.title = element_text(size = 20))
float_map

ggsave(paste0("~/shared-public/OHW25/ArBu_proj_shared/floats/trajectory_images/",hurricane_name,"_float_trajectory_map.jpg", float_map, width = 30, height = 24, units = "cm", dpi = 400)


