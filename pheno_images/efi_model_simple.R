library(dplyr)
library(ggplot2)
library(lubridate)

now <- Sys.Date()
this_month <- month(now)
this_day <- day(now)

end <- now + days(35)
end_month <- month(end)
end_day <- day(end)

middle_month <- ifelse(end_month - this_month == 2, this_month + 1, 0)

file <- 'https://raw.githubusercontent.com/genophenoenvo/neon-datasets/main/pheno_images/targets_gcc.csv'
gcc <- readr::read_csv(file) %>% 
  mutate(month = month(time), year = year(time), day = day(time), doy = yday(time)) %>% 
  filter((month == this_month & day > this_day) | (month == end_month & day <= end_day  ) | (month == middle_month)) %>% 
  filter(!(month == 2 & day == 29))

means <- gcc %>% 
  filter(!is.na(gcc_90) & !is.na(gcc_sd)) %>% 
  group_by(month, day, siteID) %>% 
  summarise(n = n(),
            time =  ymd(paste(2021, sprintf("%02d", month), sprintf("%02d", min(day)), 
                              sep = '-')),
            gcc_sd =  max(gcc_90)/10,
            gcc_90 =  median(gcc_90)) %>% 
  select(time, siteID, gcc_90, gcc_sd) %>% 
  arrange(siteID, time) %>% 
  unique() %>% 
  ungroup()

## create predictions
preds <- means %>% 
  mutate(forecast = 1, data_assimilation = 0, mean = signif(gcc_90, 2), sd = signif(gcc_sd, 1)) %>% 
  select(time, siteID, forecast, data_assimilation, mean, sd) %>% 
  tidyr::pivot_longer(cols = c('mean', 'sd'), names_to = 'statistic', values_to = 'gcc_90')

pred_filename <- paste('phenology', year(now), this_month, this_day, 'PEG.csv', sep = '-')
readr::write_csv(preds, file = pred_filename)

## metadata
## from https://github.com/eco4cast/EFIstandards/blob/master/vignettes/logistic-metadata-example.Rmd

library(EML)
library(emld)
emld::eml_version("eml-2.2.0")


template_eml <- EML::read_eml('https://raw.githubusercontent.com/eco4cast/neon4cast-beetles/c7e76a2585c55f6141e4b51a081edee65b8ea82a/meta/eml.xml')

attributes <- tibble::tribble(
  ~attributeName,     ~attributeDefinition,                          ~unit,                  ~formatString, ~numberType, ~definition,
  "time",              "[dimension]{time}",                          "year",                 "YYYY-MM-DD",  "numberType", NA,
  "siteID",            "[dimension]{depth in reservior}",            "dimensionless",         NA,           "character",  NA,
  "gcc_90",            "[observation]{Predicted GCC}",               "proportion",            NA,           "integer",    NA,
  "gcc_sd",            "[process_error]{observation error}",         "proportion",            NA,           "integer",    NA
) 

attributes
attrList <- set_attributes(attributes, 
                           col_classes = c("Date", "character", "numeric","numeric"))

physical <- set_physical(pred_filename,
                         recordDelimiter='\n')

dataTable <- eml$dataTable(
  entityName = "forecast",  
  entityDescription = "Forecast of GCC",
  physical = physical,
  attributeList = attrList)

me <- list(
  individualName = list(givenName = "David", 
                        surName = "LeBauer"),
  electronicMailAddress = "dlebauer@arizona.edu",
  id = "https://orcid.org/0000-0001-7228-053X")


keywordSet <- list(
  list(
    keywordThesaurus = "EFI controlled vocabulary",
    keyword = list("forecast",
                   "phenology",
                   "timeseries")
  ))

abstract_text <- 'a secret way of predicting gcc'

plant_cover <- readr::read_csv('plant_cover/plant_cover.csv')

neon_sites <- c("HARV", "BART", "SCBI", "STEI", "UKFS", "GRSM", "DELA", "CLBJ")
coverage <- 
  set_coverage(begin = now, 
               end = end,
               geographicDescription = paste(c("NEON Sites:", neon_sites), sep = ' ', collapse = ' '),
               west = min(plant_cover$lon), east = max(plant_cover$lon), 
               north = max(plant_cover$lat), south = min(plant_cover$lat)
)

dataset = eml$dataset(
  title = "PEG phenology prediction",
  creator = me,
  contact = list(references="https://orcid.org/0000-0001-7228-053X"),
  pubDate = Sys.Date(),
  intellectualRights = "http://www.lternet.edu/data/netpolicy.html.",
  abstract =  "A Secret Sauce Prediction",
  dataTable = dataTable,
  keywordSet = keywordSet,
  coverage = coverage
)

forecast_iteration_id = as.numeric(now)
additionalMetadata <- eml$additionalMetadata(
  metadata = list(
    forecast = list(
      ## Basic elements
      timestep = "1 day", ## should be udunits parsable; already in coverage -> temporalCoverage?
      forecast_horizon = "35 days",
      forecast_issue_time = now,
      forecast_iteration_id = forecast_iteration_id,
      forecast_project_id = "PEG",
      metadata_standard_version = "0.3",
      model_description = list(
        forecast_model_id = 'Secret Sauce',
        name = "mean of prev. obs on date + inflated error",
        type = "process-based",
        repository = "https://github.com/genophenoenvo/EFI-phenology"
      ),
      ## MODEL STRUCTURE & UNCERTAINTY CLASSES
      initial_conditions = list(
        # Possible values: absent, present, data_driven, propagates, assimilates
        status = "data_driven",
        # Number of parameters / dimensionality
        complexity = 1  ## [species 1, species 2] per depth
      ),
      drivers = list(
        status = "data_driven"
      ),
      parameters = list(
        status = "present",
        complexity = 1  ## [r, K, alpha] x 2 spp
      ),
      random_effects = list(
        status = "absent"
      ),
      process_error = list(
        status = "absent"
      ),
      obs_error = list(
        status = "absent"
      )
    ) # forecast
  ) # metadata
) # eml$additionalMetadata

my_eml <- eml$eml(dataset = dataset,
                  additionalMetadata = additionalMetadata,
                  packageId = forecast_iteration_id , 
                  system = "datetime"  ## system used to generate packageId
)

eml_validate(my_eml)
write_eml(my_eml, gsub(pattern = 'csv', replacement = 'xml', pred_filename))
