###########Read in libraries###########
library(neonstore)
library(dplyr)
library(tidyr)

###########Download data###########
download_loc <- paste0(neon_dir(), "/")
cover_product_id <- "DP1.10058.001"

if(!dir.exists(paste0(download_loc, cover_product_id))){
  neon_download(product = cover_product_id, type = "expanded")
}

###########Clean up data###########
single_site_date_df <- neon_read(table = "div_1m2Data-basic", 
                                 product = cover_product_id, site = "SJER", 
                                 start_date = "2019-04-01", end_date = "2019-04-30")

curated_df <- single_site_date_df %>% 
  select(uid, siteID, decimalLatitude, decimalLongitude,
         plotID, subplotID, endDate, scientificName, taxonRank,
         percentCover) %>% 
  filter(!is.na(scientificName), 
         taxonRank == "species") %>% 
  select(-taxonRank) %>% 
  unite(sitename, c("siteID", "plotID", "subplotID"), sep = "_") %>% 
  rename(lat = decimalLatitude, 
         lon = decimalLongitude, 
         date = endDate, 
         species = scientificName, 
         canopy_cover = percentCover) %>% 
  relocate(species, lat, lon, sitename, date, canopy_cover)

###########Save data###########
write.csv(curated_df, file = "plant_cover/plant_cover.csv", row.names = FALSE)
