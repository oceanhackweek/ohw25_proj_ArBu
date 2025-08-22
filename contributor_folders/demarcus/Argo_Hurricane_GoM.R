# Introduction -----
# ###
#
# Jennifer McWhorter & Marin Cornec (7/2/2024)
# 
# This demo shows how to handle the OneArgo toolbox and its basics functions.
# 
# The exercise aims to:
#   
# 1) Set the toolbox
# 2) Select Oxygen data from four floats in the Gulf of Mexico
# 3) Extract those data from the GDAC under a dataframe
# 4) Plot the floats trajectories
# 5) Plot the flags of oxygen quality-controlled data
# 6) Plot the vertical profiles of oxygen from the selected floats
# 
# https://github.com/NOAA-PMEL/OneArgo-R/

# BEFORE YOU START !!
# Fill the path directory to the folder for the OneArgo toolbox at line 43
#
# ###
# 1) Prepare the worsket ----
# ###

#Remove previous files from R before running the scripts below 
cat("\014")
rm(list = ls())

#Load (and install, if necessary) libraries
for (i in c("dplyr","ggplot2","lubridate","gridExtra","tidyverse","ggeffects")) {
  if (!require(i, character.only = TRUE)) {
    install.packages(i, dependencies = TRUE)
    library(i, character.only = TRUE)
  }
}

# ###
# 2) Initialize the Toolbox ----
# ###  

# Set the working directory 
path_code = "~/shared-public/OHW25/ArBu_proj_shared/OneArgo-R/"
setwd(path_code)

# Code below references the OneArgo toolbox functions
func.sources = list.files(path_code,pattern="*.R")
func.sources = func.sources[which(func.sources %in% c('Tutorial.R',"oneargo_r_license.R")==F)] 

if(length(grep("Rproj",func.sources))!=0){
  func.sources = func.sources[-grep("Rproj",func.sources)]
}

invisible(sapply(paste0(func.sources),source,.GlobalEnv))

aux.func.sources = list.files(paste0(path_code,"/auxil"),pattern="*.R")
invisible(sapply(paste0(path_code,"/auxil/",aux.func.sources),source,.GlobalEnv))

# This function defines standard settings and paths and creates Index and 
# Profiles folders in your current path.  
# It also downloads the Sprof index file from the GDAC to your Index folder. 
# The Sprof index is referenced when downloading and subsetting float data 
# based on user specified criteria in other functions.
initialize_argo() 

# ###
# 3) Read in data from the DAC using the toolbox -----
# ###

# Select profiles based on time and geographical limits with specified sensor

# This example uses the Gulf of Mexico pilot array, with oxygen measurements 
# variable DOXY), deployed in 2021.
# The "mode" option indicates the type of data mode to be extracted:
# ‘R’: raw mode 
# ‘A’: adjusted  
# ‘D’: delayed-mode 
# ‘RAD’: all modes (raw, delayed mode, adjusted).

# This function will return the selection of floats WMO and profiles numbers.

# For the variable selection, make sure to use the appropriated name of the 
# available parameters:
# PRES, PSAL, TEMP, DOXY, BBP, BBP470, BBP532, BBP700, TURBIDITY, CP, CP660, 
# CHLA, CDOM, NITRATE, BISULFIDE, PH_IN_SITU_TOTAL, DOWN_IRRADIANCE, 
# DOWN_IRRADIANCE380, DOWN_IRRADIANCE412,DOWN_IRRADIANCE443, DOWN_IRRADIANCE490, 
# DOWN_IRRADIANCE555, DOWN_IRRADIANCE670, UP_RADIANCE, UP_RADIANCE412, 
# UP_RADIANCE443, UP_RADIANCE490, UP_RADIANCE555, DOWNWELLING_PAR, DOXY2, DOXY3
#
# For the geographical selection, you can use:
#   - a box (lon_lim=c(min longitude, max longitude); 
#     lat_lim=c(min latitude, max latitude)
#   - a polygon selection (lon_lim= vector a longitude values, 
#      lat_lim = vector of corresponding latitude values)
#              
# For an overview of the available floats/parameters, we also recommend using 
# either monitoring tools:
#   - https://maps.biogeochemical-argo.com/bgcargo/ 
#   - https://fleetmonitoring.euro-argo.eu/dashboard?Status=Active 
GoM_BGC = select_profiles(lon_lim = c(-96, -80),
                          lat_lim = c(17, 29),
                          start_date='2021-10-01',
                          end_date='2100-04-22',
                          sensor=c('DOXY'),
                          mode = 'RAD')

# Load the floats data

# This function will download and extract the data for the selection of floats 
# WMO and profiles
float_data = load_float_data(float_ids=GoM_BGC$float_ids,
                             float_profs=GoM_BGC$float_profs)

# Extract the DOXY profiles and create a dataframe with the data
# 
# This function converts the original list format of the data to a dataframe format.
# 
# A selection of flags measurements need to be specified (qc_flags).
# 
# 1 = good data
# 2 = probably good data
# 3 = probably bad data
# 4 = bad data
# 5 = value changed
# 6 = not attributed
# 7 = not attributed
# 8 = interpolated data
# 9 = no data
# QC 1,2,5,8 are the safer to use
#
# The 'raw' option defines which data mode should be used for the chosen 
# variable: 
# raw = ‘yes_strict’, raw data only. raw = ‘no’, adjusted data only. 
# raw = ‘yes’, raw data when adjusted data are not available. 
# raw = ‘no_strict’, skip the float if not all the variables are adjusted.
# 
# The "type" option defines how detailed will be output be: 
# 'cleaned' : output will contain only the data with the requested QC (default) 
# 'detailed': output will contain all the original data and additional 
# columns with the corresponding QC.
#
# The "mode" option, when set to TRUE (default) will add a column displaying 
# the data mode of the corresponding variable. 
# (R = "Real Time", A= "Adjusted, D= "Delayed")
float_data_qc = extract_qc_df(float_data$Data,
                              variables = c('DOXY','TEMP','PSAL'),
                              qc_flags = c(1:9),
                              raw='yes', 
                              format='dataframe',
                              type='detailed', 
                              mode = T)

# Remove lines with no data (NA) in the dataframe
float_data_qc_na<-unique(na.omit(float_data_qc)) 

# Clean up the WMOID
#Remove the f from the number (f4903625 to 4903624)
float_data_qc_na$float_num<-substr(float_data_qc_na$WMOID,2,8) 

# Print the WMO of the floats available in the dataframe
unique(float_data_qc_na$float_num)

# Locate the max and min time for the data
max(float_data_qc_na$TIME) # 2025-08-21
min(float_data_qc_na$TIME) # 2021-10-03

# Extract times for before, during and after hurricane Idalia 
which(float_data_qc_na$TIME > "2023-08-01" & float_data_qc_na$TIME < "2023-9-10") 
which(float_data_qc_na$TIME == "2023-08-19")
which(float_data_qc_na$TIME == "2023-08-29")
which(float_data_qc_na$TIME == "2023-09-10")

# Set new varibles for plots for before, during and after 
during_float<-float_data_qc_na[16340:16409,]
before_float<-float_data_qc_na[16270:16339,]
after_float<-float_data_qc_na[17263:17325,]

# 4) Plot the float trajectories -----
# ###

# Set up base map
mapWorld <- borders("world", colour="gray40", fill="gray40") # create a layer of borders

# Set map limits
lons = c(-96, -80)
lats = c(17, 29)

# Plot map of the float locations before hurricane 
before_map <- ggplot(data=before_float,
                aes(x=LONGITUDE, 
                    y=LATITUDE, 
                    color = float_num, 
                    group=float_num))+
  geom_path() +
  geom_point(size = 3) +
  coord_cartesian(xlim = lons, ylim = lats) +
  ylab("Lat (deg. N)")+
  xlab("Lon (deg. E)")+
  ggtitle("Float Before Hurricane ") +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15),
        aspect.ratio = 1)+
  mapWorld
before_map

# Plot map of the float locations during hurricane 
during_map <- ggplot(data=during_float,
                     aes(x=LONGITUDE, 
                         y=LATITUDE, 
                         color = float_num, 
                         group=float_num))+
  geom_path() +
  geom_point(size = 3) +
  coord_cartesian(xlim = lons, ylim = lats) +
  ylab("Lat (deg. N)")+
  xlab("Lon (deg. E)")+
  ggtitle("Float During Hurricane") +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15),
        aspect.ratio = 1)+
  mapWorld
during_map


# Plot map of the float locations during after
after_map <- ggplot(data=after_float,
                     aes(x=LONGITUDE, 
                         y=LATITUDE, 
                         color = float_num, 
                         group=float_num))+
  geom_path() +
  geom_point(size = 3) +
  coord_cartesian(xlim = lons, ylim = lats) +
  ylab("Lat (deg. N)")+
  xlab("Lon (deg. E)")+
  ggtitle("Float After Hurricane") +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15),
        aspect.ratio = 1)+
  mapWorld
after_map

track_plots <- before_map+during_map+after_map
track_plots

# Parameters 
before_float_o2 <- ggplot(data=before_float, aes( x = DOXY, 
                                      y = PRES, 
                                      color = float_num, 
                                      group = CYCLE_NUMBER),
             orientation = "y") + facet_wrap(~float_num) +
  geom_path(linewidth = .1) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1)+ 
  labs(colour="WMO")+
  scale_y_reverse(limits=c(500,5)) +
  scale_x_continuous(position = "top") +
  labs(
    x = expression(paste("Oxygen [", mu, "mol kg"^"-1","]")),
    y = "Pressure [dbar]"
  )

before_float_o2

before_plot

# ###
# 6) Plot profiles ----- 
# ###

# Oxygen profiles 
p1 <- ggplot(data=Float_jul_aug, aes( x = DOXY, 
                                         y = PRES, 
                                         color = float_num, 
                                         group = CYCLE_NUMBER),
             orientation = "y") + facet_wrap(~float_num) +
  geom_path(linewidth = .1) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1)+ 
  labs(colour="WMO")+
  scale_y_reverse(limits=c(500,5)) +
  scale_x_continuous(position = "top") +
  labs(
    x = expression(paste("Oxygen [", mu, "mol kg"^"-1","]")),
    y = "Pressure [dbar]"
  )

p1



# plot before, during, after (Temp + Salinity)
# Temp 

arg_temp<-ggplot() + 
  facet_wrap(~float_num) +
  geom_path(data = before_float, 
            aes(x = TEMP, y = PRES, group = CYCLE_NUMBER),
            color = "blue", linewidth = 0.2) +
  geom_path(data = during_float, 
            aes(x = TEMP, y = PRES, group = CYCLE_NUMBER),
            color = "red", linewidth = 0.2) +
  geom_path(data = after_float, 
            aes(x = TEMP, y = PRES, group = CYCLE_NUMBER),
            color = "purple", linewidth = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1) +
  scale_y_reverse(limits = c(1000, 0)) +
  scale_x_continuous(position = "top") +
  labs(
    x = expression(paste("Temperature [°C]")),
    y = "Pressure [dbar]"
  )
arg_temp
# Salinity 
arg_sal<-ggplot() + 
  facet_wrap(~float_num) +
  geom_path(data = before_float, 
            aes(x = PSAL, y = PRES, group = CYCLE_NUMBER),
            color = "blue", linewidth = 0.2) +
  geom_path(data = during_float, 
            aes(x = PSAL, y = PRES, group = CYCLE_NUMBER),
            color = "red", linewidth = 0.2) +
  geom_path(data = after_float, 
            aes(x = PSAL, y = PRES, group = CYCLE_NUMBER),
            color = "purple", linewidth = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1) +
  scale_y_reverse(limits = c(1000, 0)) +
  scale_x_continuous(position = "top") +
  labs(
    x = expression(paste("Salinity [g/kg]")),
    y = "Pressure [dbar]"
  )
arg_temp

# DENS
arg_den<-ggplot() + 
  facet_wrap(~float_num) +
  geom_path(data = before_float, 
            aes(x = den, y = PRES, group = CYCLE_NUMBER),
            color = "blue", linewidth = 0.2) +
  geom_path(data = during_float, 
            aes(x = den, y = PRES, group = CYCLE_NUMBER),
            color = "red", linewidth = 0.2) +
  geom_path(data = after_float, 
            aes(x = den, y = PRES, group = CYCLE_NUMBER),
            color = "purple", linewidth = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1) +
  scale_y_reverse(limits = c(1000, 0)) +
  scale_x_continuous(position = "top") +
  labs(
    x = expression(paste("Density [kg/m3]")),
    y = "Pressure [dbar]"
  )
arg_den

# Oxygen
arg_o2<-ggplot() + 
  facet_wrap(~float_num) +
  geom_path(data = before_float, 
            aes(x = DOXY, y = PRES, group = CYCLE_NUMBER),
            color = "blue", linewidth = 0.2) +
  geom_path(data = during_float, 
            aes(x = DOXY, y = PRES, group = CYCLE_NUMBER),
            color = "red", linewidth = 0.2) +
  geom_path(data = after_float, 
            aes(x = DOXY, y = PRES, group = CYCLE_NUMBER),
            color = "purple", linewidth = 0.2) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1) +
  scale_y_reverse(limits = c(1000, 0)) +
  scale_x_continuous(position = "top") +
  labs(x = expression(paste("Oxygen [mol/kg]")),
    y = "Pressure [dbar]") 

library(patchwork)

plots_profiles <- arg_temp+arg_sal+arg_o2+ arg_den
plots_profiles

install.packages("gsw")
library("gsw")

# Stratification 
before_float_N2<-gsw_Nsquared(before_float$PSAL,before_float$TEMP, before_float$PRES, before_float$LATITUDE)
after_float_N2<-gsw_Nsquared(after_float$PSAL,after_float$TEMP, after_float$PRES, after_float$LATITUDE)
during_float_N2<-gsw_Nsquared(during_float$PSAL,during_float$TEMP, during_float$PRES, during_float$LATITUDE)


N2 <- ggplot(data=before_float_N2, aes( x = DOXY, 
                                      y = PRES, 
                                      color = float_num, 
                                      group = CYCLE_NUMBER),
             orientation = "y") + facet_wrap(~float_num) +
  geom_path(linewidth = .1) +
  theme_bw() +
  theme(axis.text.x = element_text(size = 15), 
        axis.title.x = element_text(size = 15), 
        axis.text.y = element_text(size = 15), 
        axis.title.y = element_text(size = 15), 
        legend.text  = element_text(size = 15), 
        legend.title = element_text(size = 15), 
        aspect.ratio=1)+ 
  labs(colour="WMO")+
  scale_y_reverse(limits=c(500,5)) +
  scale_x_continuous(position = "top") +
  labs(
    x = expression(paste("Oxygen [", mu, "mol kg"^"-1","]")),
    y = "Pressure [dbar]"
  )

p1



# Convert plot to a savable object
g <- arrangeGrob(p1)

# ggsave("X:/YOUR/PATH/plot.png", g, width=12, height=8)
#
# END
