# devtools::install_github('eco4cast/neon4cast')
# install.packages('readr')
library(neon4cast)
pheno_sites <- c("HARV", "BART", "SCBI", "STEI", "UKFS", "GRSM", "DELA", "CLBJ)"
download_noaa(pheno_sites)
noaa_fc <- stack_noaa()
readr::write_csv(noaa_fc, file = paste0('pheno_images/NOAA_GEFS_35d_', Sys.Date(), '.csv'))
