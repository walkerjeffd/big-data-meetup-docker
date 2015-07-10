library(dplyr)
library(ggplot2)
library(lubridate)

df <- read.delim('/data/androscoggin.txt', skip=27, col.names = c('Agency', 'StationID', 'Date', 'Flow', 'Flag'))

df <- mutate(df, Date=ymd(Date))

head(df)

ggplot(df, aes(Date, Flow)) +
  geom_line()

ggplot(df, aes(Flow)) +
  geom_histogram()
