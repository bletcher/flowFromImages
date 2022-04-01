library(lubridate)
library(ggplot2)
source('./R/getData.R')

d <- getEnvData()
d$dateLub <- as_date(d$date)
write.csv(d, file = './data/sawmillFlow.csv')


ggplot(d, aes(dateLub, flow)) + geom_point()
