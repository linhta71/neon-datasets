library(dplyr)
library(ggplot2)
library(lubridate)
options(digits = 10)

# file <- 'https://raw.githubusercontent.com/genophenoenvo/neon-datasets/main/pheno_images/targets_gcc.csv' 
file <- 'targets_gcc.csv'
gcc <- readr::read_csv(file) %>% 
  mutate(month = month(time), year = year(time), day = day(time), doy = yday(time)) %>% 
  filter((month == 2 & day >18) | (month == 3 ))

means <- gcc %>% 
  filter(!is.na(gcc_90) & !is.na(gcc_sd)) %>% 
  group_by(month, day, siteID) %>% 
  summarise(gcc_90 = signif(mean(gcc_90), 3), 
            gcc_sd = signif(mean(gcc_sd), 3),
            n = n()) %>% 
  mutate(time = paste(2021, sprintf("%02d", month), sprintf("%02d", min(day)), 
                      sep = '-')) %>% 
  ungroup() %>% 
  arrange(siteID, time) %>% 
  select(time, siteID, gcc_90, gcc_sd, n)

readr::write_csv(means, file = 'pred_gcc.csv')
ggplot(data = means, aes(ymd(time), gcc_90)) + 
#  geom_smooth(se = FALSE)+
  geom_point(aes(color = n)) +
  geom_errorbar(aes(ymin = gcc_90 - gcc_sd, ymax = gcc_90 + gcc_sd)) +
  facet_wrap(~siteID, ncol = 2) +
  scale_x_date() +
  scale_color_viridis_c()
  
