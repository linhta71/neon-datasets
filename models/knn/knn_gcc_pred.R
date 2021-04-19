# take in data
library(tidyverse)
library(anomalize)
library(caret)
library(MuMIn)
library(rpart)
library(rpart.plot)
library(tidyverse)
gcc <- read.csv("C:/Users/Lynn/OneDrive - University of Arizona/Desktop/Genom project/gcc_weather.csv")
view(gcc)


#add logistic regression
gcc_log <-  gcc %>% mutate_if(is.character, as.factor)
gcc_log$gcc_90[is.na(gcc_log$gcc_90)] = 0
gcc_log <- gcc_log%>% select(-time)

#split into 70-30
split_index <- createDataPartition(gcc_log$gcc_90, p = .7, list = F, times = 5)
head(split_index, 10)

 
# create a table to store test error and fold.
error_df<-data.frame(matrix(ncol = 2, nrow = ncol(split_index)))
colnames(error_df) <- c('test_error_log','fold')
error_df

# CV
for ( i in 1:nrow(error_df)) {
  training <- gcc_log[split_index[,i],]
  features_test <- gcc_log[-split_index[,i], !(names(gcc_log) %in% c("gcc_90"))]
  target_test <- gcc_log$gcc_90[-split_index[,i]]
  preprocess_object <- preProcess(training,method = c('center', 'scale', 'knnImpute'))
  
  # Logistc regression
  log_train <- suppressWarnings(glm(gcc_90 ~ ., family = 'binomial', data = training))
  log_preds <- predict(log_train, newdata = features_test, type = 'response')
  log_preds[is.na(log_preds)] = 0
  error_log  <- mean((target_test - log_preds)^2)
  error_df[i,'test_error_log'] <- error_log
  error_df[i,'fold'] <- i
}
error_df

# write to _csv
log <- suppressWarnings(glm(gcc_90 ~ ., family = 'binomial', data = gcc_log))
features_test <- gcc_log[, !(names(gcc_log) %in% c("gcc_90"))]
preds <- predict(log, newdata = features_test, type = 'response')
gcc$Preds.Log <- preds

write.csv(gcc,"C:/Users/Lynn/OneDrive - University of Arizona/Desktop/Genom project/gcc_weather_log_preds_added.csv", row.names = FALSE)

