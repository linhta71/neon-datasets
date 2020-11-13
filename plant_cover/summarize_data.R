###########Read in libraries and data###########
library(dplyr)
library(tidyr)
library(knitr)
library(kableExtra)
library(ggplot2)
plant_cover <- read.csv("plant_cover/plant_cover.csv")

###########Generate summary stats###########

# Plots and sites table and counts
sites_plots <- plant_cover %>% 
  separate(sitename, sep = "_", into = c("site", "also_site", "plot", "subplot")) %>% 
  group_by(site) %>% 
  summarise(count = n_distinct(plot)) %>% 
  rename(Site = site, Plots = count)

sites_plots_rows <- seq_len(nrow(sites_plots) %/% 2)
kable(list(sites_plots[sites_plots_rows,1:2],  
           matrix(numeric(), nrow=0, ncol=1),
           sites_plots[-sites_plots_rows, 1:2]), 
      format = "html") %>% 
  kable_styling("striped", full_width = FALSE) %>% 
  save_kable("plant_cover/plots_by_sites.png")

nrow(sites_plots)
sum(sites_plots$Plots)

# Species table and counts

species_counts <- plant_cover %>% 
  group_by(species) %>% 
  summarize(count = n()) %>% 
  arrange(desc(count)) %>% 
  slice(1:20) %>% 
  rename(Species = species, Occurrences = count)
kable(species_counts, format = "html") %>% 
  save_kable("plant_cover/species_records.png")

nrow(plant_cover)
length(unique(plant_cover$species))

# Dates table and counts

range(as.Date(plant_cover$date))
length(unique(as.Date(plant_cover$date)))

###########Visualize data###########

# Map of locations

map_background <- map_data("state") 
         
ggplot() +
  geom_polygon(data = map_background, aes(x = long, y = lat, group = group), 
               fill = "white", color = "black") + 
  geom_point(data = plant_cover, aes(x = lon, y = lat), 
             color = "blue", shape = 4) +
  labs(x = "", y = "") +
  theme_classic()
ggsave("plant_cover/map_locations.png")

# Records by date

dates <- plant_cover %>% 
  select(date) %>% 
  mutate(date = as.Date(date)) %>% 
  group_by(date) %>% 
  summarize(count = n()) %>% 
  rename(Date = date, Records = count)

ggplot() +
  geom_col(data = dates, aes(x = Date, y = Records), color = "black", fill = "black") +
  theme_classic()
ggsave("plant_cover/records_by_date.png")