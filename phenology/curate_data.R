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
                              product = cover_product_id)

pheno_records <- status_intensity %>% 
  select(uid, plotID, date, individualID, phenophaseName, phenophaseStatus, 
         phenophaseIntensityDefinition, phenophaseIntensity) %>% 
  filter(phenophaseName == "Open flowers",  
         phenophaseIntensity == "50-74%") %>% 
  rename(uid_pheno = uid)

sites <- c("ABBY", "BARR", "BART", "BLAN", "BONA", "CLBJ", "CPER", "DCFS", "DEJU", "DELA", 
           "DSNY", "GRSM", "GUAN", "HARV", "HEAL", "JERC", "JORN", "KONA", "KONZ", "LAJA", 
           "LENO", "MLBS", "MOAB", "NIWO", "NOGP", "OAES", "ONAQ", "ORNL", "OSBS", "PUUM", 
           "RMNP", "SCBI", "SERC", "SJER", "SOAP", "SRER", "STEI", "STER", "TALL", "TEAK", 
           "TOOL", "TREE", "UKFS", "UNDE", "WOOD", "WREF", "YELL")

per_individual <- c()
for (site in sites) {
  per_ind_by_site <- neon_read(table = "phe_perindividual-basic", 
                               product = cover_product_id, 
                               site = site)
  per_ind_by_site <- select(per_ind_by_site, uid, decimalLatitude, 
                            decimalLongitude, individualID, scientificName, siteID)
  per_individual <- rbind(per_ind_by_site, per_individual)
}

# TODO: figure out why some individualIDs have multiple species
checking_duplicates <- per_individual %>% 
  group_by(individualID) %>% 
  summarise(id_occurrences = n_distinct(scientificName), 
            lon_occurrences = n_distinct(decimalLongitude), 
            lat_occurrences = n_distinct(decimalLatitude)) %>% 
  filter(id_occurrences > 1 | lat_occurrences > 1 | lon_occurrences > 1)

individual_records <- per_individual %>% 
  group_by(individualID) %>% 
  slice(1) %>% 
  ungroup() %>% 
  rename(uid_ind = uid)

combined <- left_join(pheno_records, individual_records, by = "individualID") %>% 
  tidyr::separate(date, c("year", "month", "day"), sep = "-", remove = FALSE) %>% 
  group_by(individualID, year) %>% 
  arrange(date) %>% 
  slice(1) %>% 
  ungroup() %>% 
  select(individualID, scientificName, decimalLatitude, decimalLongitude, plotID, 
         date, uid_pheno, uid_ind) %>% 
  rename(species = scientificName, lat = decimalLatitude, lon = decimalLongitude, 
         sitename = plotID, first_flower_date = date)

###########Subset data###########
species_list1 <- readLines("phenology/NPN_species_subset1_notes.csv")

species_list2 <- read.csv("phenology/NPN_species_subset2.csv", header = FALSE)
species_list2 <- tidyr::unite(species_list2, genus_species, V1:V2, sep = " ")
species_list2 <- species_list2[,1]

species_list_comp <- c(species_list1, species_list2)

combined_subset <- combined %>% 
  filter(grepl(paste(species_list_comp, collapse = "|"), species))

###########Add weather data###########
pheno_sites <- combined_subset %>% 
  tidyr::separate(sitename, c("Site", "Transect"), sep = "_") %>% 
  select(Site) %>% 
  summarize(unique(Site))
pheno_sites <- as.vector(pheno_sites$`unique(Site)`)

precip_product_id <- "DP1.00006.001"
if(!dir.exists(paste0(download_loc, precip_product_id))){
  neon_download(product = precip_product_id, type = "expanded")
}

precip <- neon_read(table = "SECPRE_30min-expanded", 
                    product = precip_product_id, 
                    site = pheno_sites[pheno_sites != "SRER"])

mean_daily_precip <- precip %>% 
  filter(!is.na(secPrecipBulk)) %>% 
  tidyr::separate(startDateTime, c("startDate", "startTime"), sep = " ") %>% 
  group_by(siteID, startDate) %>% 
  summarize(count = n(), daily_precip = sum(secPrecipBulk)) %>% 
  filter(count == 48) %>% 
  mutate(year = substr(startDate, 1, 4)) %>% 
  group_by(siteID, year) %>% 
  summarize(count = n(), mean_daily_precip = mean(daily_precip)) %>% 
  filter(count %in% c(364, 365, 366)) %>% 
  select(-count)

combined_subset <- combined_subset %>% 
  mutate(site = substr(sitename, 1, 4), 
         year = substr(first_flower_date, 1, 4))

combined_subset <- left_join(combined_subset, mean_daily_precip, 
                                    by = c("site" = "siteID", "year" = "year"))

###########Save data###########
write.csv(combined_subset, file = "phenology/phenology.csv", row.names = FALSE)
