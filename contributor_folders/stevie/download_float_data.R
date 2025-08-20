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

