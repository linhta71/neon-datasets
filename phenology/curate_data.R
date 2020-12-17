###########Read in libraries###########
library(neonstore)
library(dplyr)

###########Download data###########
download_loc <- paste0(neon_dir(), "/")
cover_product_id <- "DP1.10055.001"

if(!dir.exists(paste0(download_loc, cover_product_id))){
  neon_download(product = cover_product_id, type = "expanded")
}

###########Clean up data###########

status_intensity <- neon_read(table = "phe_statusintensity-basic", 
                                    site = "DSNY", 
                                    start_date = "2018-03-01", 
                                    end_date = "2018-12-30")

pheno_records <- status_intensity %>% 
  select(uid, plotID, date, individualID, phenophaseName, phenophaseStatus, 
         phenophaseIntensityDefinition, phenophaseIntensity) %>% 
  filter(phenophaseName == "Open flowers",  
         phenophaseIntensity == "50-74%") %>% 
  rename(uid_pheno = uid)

per_individual <- neon_read(table = "phe_perindividual-basic", 
                            site = "DSNY")

checking_duplicates <- per_individual %>% 
  group_by(individualID) %>% 
  summarise(id_occurrences = n_distinct(scientificName), 
            lon_occurrences = n_distinct(decimalLongitude), 
            lat_occurrences = n_distinct(decimalLatitude)) %>% 
  filter(id_occurrences > 1 | lat_occurrences > 1 | lon_occurrences > 1)

individual_records <- per_individual %>% 
  select(uid, decimalLatitude, decimalLongitude, individualID, scientificName) %>% 
  group_by(individualID) %>% 
  slice(1) %>% 
  ungroup() %>% 
  rename(uid_ind = uid)

combined <- left_join(pheno_records, individual_records, by = "individualID") %>% 
  group_by(individualID) %>% 
  arrange(date) %>% 
  slice(1) %>% 
  ungroup() %>% 
  select(scientificName, decimalLatitude, decimalLongitude, plotID, date, 
         uid_pheno, uid_ind) %>% 
  rename(species = scientificName, lat = decimalLatitude, lon = decimalLongitude, 
         sitename = plotID, first_flower_date = date)

###########Save data###########
write.csv(combined, file = "phenology/phenology.csv", row.names = FALSE)
