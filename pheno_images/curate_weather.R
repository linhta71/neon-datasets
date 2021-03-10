###########Read in libraries###########
library(daymetr)
library(dplyr)
library(ggplot2)

###########Download weather data###########
download.file("https://www.neonscience.org/sites/default/files/NEON_Field_Site_Metadata_20201204.csv", 
              "pheno_images/neon_sites.csv")

efi_sites <- read.csv("pheno_images/neon_sites.csv") %>% 
  select(field_site_id, field_latitude, field_longitude) %>% 
  filter(field_site_id %in% c("HARV", "BART", "SCBI", "STEI", "UKFS", "GRSM", "DELA", "CLBJ"))

all_daymet <- c()
for(site in 1:nrow(efi_sites)){
  raw_daymet <- download_daymet(site = efi_sites$field_site_id[site], 
                                lat = efi_sites$field_latitude[site], 
                                lon = efi_sites$field_longitude[site], 
                                start = 2016, 
                                end = 2020, 
                                internal = TRUE)
  df_daymet <- as.data.frame(raw_daymet$data) %>% 
    mutate(site = raw_daymet$site)
  all_daymet <- bind_rows(df_daymet, all_daymet)
}

# get api key here: https://www.ncdc.noaa.gov/cdo-web/token
library(rnoaa)

all_stations <- ghcnd_stations()
close_stations <- all_stations %>% 
  filter(latitude > min(efi_sites$field_latitude) & 
           latitude < max(efi_sites$field_latitude) &
           longitude > min(efi_sites$field_longitude) & 
           longitude < max(efi_sites$field_longitude))
site <- 1
num <- 0.07
single_close_station <- all_stations %>% 
  filter(latitude > efi_sites$field_latitude[site] - num & 
           latitude < efi_sites$field_latitude[site] + num &
           longitude > efi_sites$field_longitude[site] - num & 
           longitude < efi_sites$field_longitude[site] + num)

efi_ghcnd <- all_stations %>% 
  filter(name %in% c("BARTLETT", "HARVARD FOREST", 
                     "FRONT ROYAL 3.1 ESE", "RHINELANDER ONEIDA AP", 
                     "KU-FIELD STN", "GATLINBURG 2 SW", 
                     "DEMOPOLIS LOCK 4", "FORESTBURG 5 S")) %>% 
  group_by(name) %>% 
  slice_tail(n = 1)


map_background <- map_data("state") 

ggplot() +
  geom_polygon(data = map_background, aes(x = long, y = lat, group = group), 
               fill = "white", color = "black") + 
  geom_point(data = efi_sites, aes(x = field_longitude, y = field_latitude), 
             color = "blue") +
  geom_point(data = efi_ghcnd, aes(x = longitude, y = latitude), 
             color = "red", shape = 4) +
  labs(x = "", y = "") +
  theme_classic()


one_site_data <- ncdc(datasetid = "GHCND", stationid = "GHCND:USC00270390", 
                      startdate = "2018-01-01", enddate = "2018-12-01")

ncdc_stations(datasetid='GHCND', locationid='GHCND:USC00270390', 
              stationid='GHCND:USC00084289')


###########Clean up weather data###########
clean_daymet <- all_daymet %>% 
  mutate(origin_year = year - 1, 
         origin_date = paste0(origin_year, "-12-31"), 
         date = as.Date(yday, origin = origin_date)) %>% 
  select(-year, -yday, -origin_year, -origin_date)

###########Join weather data to GCC data###########
pheno_images <- read.csv("pheno_images/targets_gcc.csv") %>% 
  mutate(time = as.Date(time))

gcc_weather <- left_join(pheno_images, clean_daymet, 
                         by = c("siteID" = "site", "time" = "date")) %>% 
  rename(daylength = dayl..s., 
         precipitation = prcp..mm.day., 
         radiation = srad..W.m.2., 
         snow_water_equiv = swe..kg.m.2., 
         max_temp = tmax..deg.c., 
         min_temp = tmin..deg.c., 
         vapor_pressure = vp..Pa.)

write.csv(gcc_weather, "pheno_images/gcc_weather.csv", row.names = FALSE)
