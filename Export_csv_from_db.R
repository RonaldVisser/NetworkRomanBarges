library(RPostgres)
library(getPass)
library(tidyverse)

con <- dbConnect(RPostgres::Postgres(),    
                 host = "localhost",   
                 port = 5432,   
                 dbname = "romhout",   
                 user = "postgres",   
                 password=getPass::getPass() )

for (n in 1:4) {
  assign(paste0("means_network_data_", n), dbGetQuery(con, read_file(paste0("queries/Network_means_", n, ".sql"))))
  assign(paste0("means_network_data_", n), get(paste0("means_network_data_", n)) %>%  group_by(Mean_A, Mean_B) %>%  filter(sum_sims == max(sum_sims)))
  write.csv(get(paste0("means_network_data_", n)), paste0("export/means_network_data_", n, ".csv"),row.names = FALSE)
  assign(paste0("series_network_data_", n), dbGetQuery(con, read_file(paste0("queries/Network_Series_", n, "_without_treecurves.sql"))))
  assign(paste0("series_network_data_", n), get(paste0("series_network_data_", n)) %>%  group_by(Series_A, Series_B) %>%  filter(sum_sims == max(sum_sims)))
  write.csv(get(paste0("series_network_data_", n)), paste0("export/series_network_data_", n, ".csv"),row.names = FALSE)
  assign(paste0("seriestrees_network_data_", n), dbGetQuery(con, read_file(paste0("queries/Network_Series_", n, ".sql"))))
  assign(paste0("seriestrees_network_data_", n), get(paste0("seriestrees_network_data_", n)) %>%  group_by(Series_A, Series_B) %>%  filter(sum_sims == max(sum_sims)))
  write.csv(get(paste0("seriestrees_network_data_", n)), paste0("export/seriestrees_network_data_", n, ".csv"),row.names = FALSE)
}  
