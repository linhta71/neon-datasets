FROM cyversevice/rstudio-verse:3.6.3

RUN R -e "install.packages(c('neonstore', 'daymetr', 'rgbif'), dependencies=TRUE, repos='https://cloud.r-project.org')"
