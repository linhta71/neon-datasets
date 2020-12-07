###########Read in libraries###########
library(neonstore)
library(dplyr)
library(tidyr)
library(rgbif)
library(ggplot2)

###########Download data###########
download_loc <- paste0(neon_dir(), "/")
cover_product_id <- "DP1.10058.001"

if(!dir.exists(paste0(download_loc, cover_product_id))){
  neon_download(product = cover_product_id, type = "expanded")
}

###########Clean up data###########
all_sites_df <- neon_read(table = "div_1m2Data-basic", 
                                 product = cover_product_id, 
                                 start_date = "2013-03-01", end_date = "2020-01-30")

curated_df <- all_sites_df %>% 
  select(uid, siteID, decimalLatitude, decimalLongitude,
         plotID, subplotID, endDate, scientificName, taxonRank,
         percentCover) %>% 
  filter(!is.na(scientificName), 
         taxonRank == "species", 
         decimalLongitude > -140, 
         decimalLatitude > 25 & decimalLatitude < 50) %>% 
  select(-taxonRank) %>% 
  unite(sitename, c("siteID", "plotID", "subplotID"), sep = "_") %>% 
  rename(lat = decimalLatitude, 
         lon = decimalLongitude, 
         date = endDate, 
         species = scientificName, 
         canopy_cover = percentCover) %>% 
  relocate(species, lat, lon, sitename, date, canopy_cover)

###########QA/QC data###########
# individual percent cover records
range(curated_df$canopy_cover, na.rm = TRUE) 

# percent cover records per subplot
curated_df %>% 
  group_by(sitename, date) %>% 
  summarise(total_percent_cover = sum(canopy_cover))

# species distributions compared against GBIF source
species_ordered <- curated_df %>% 
  group_by(species) %>% 
  summarize(count = n()) %>% 
  arrange(desc(count))

gbif_occs <- c()
for (species in species_ordered$species[1:10]) {
  species_occs <- occ_search(scientificName = species, 
                             country = "US", 
                             limit = 1000)$data
  species_occs <- species_occs %>% 
    select(scientificName, decimalLatitude, decimalLongitude)
  gbif_occs <- rbind(gbif_occs, species_occs)
}

gbif_occs_clean <- gbif_occs %>% 
  rename(species = scientificName, 
         lat = decimalLatitude, 
         lon = decimalLongitude) %>% 
  filter(species %in% species_ordered$species[1:10]) %>% 
  mutate(source = "gbif")

neon_occs <- curated_df %>% 
  select(species, lon, lat) %>% 
  filter(species %in% unique(gbif_occs_clean$species)) %>% 
  mutate(source = "neon")

occs <- rbind(gbif_occs_clean, neon_occs)

ggplot() +
  geom_polygon(data = map_data("state"), aes(x = long, y = lat, group = group), 
               fill = "white", color = "black") +
  geom_point(data = occs, aes(x = lon, y = lat, color = source)) +
  scale_color_manual(values = c("grey", "red")) +
  facet_wrap(~species)

# check locations
locations <- c(paste(curated_df$lon, curated_df$lat))
head(sort(table(locations)))

###########Save data###########
write.csv(curated_df, file = "plant_cover/plant_cover.csv", row.names = FALSE)
