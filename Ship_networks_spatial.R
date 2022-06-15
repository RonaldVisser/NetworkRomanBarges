library(sf)
library(tidyverse)
library(RPostgres)
library(getPass)

set.seed(666)

#drv <- dbDriver("PostgreSQL")
con <- dbConnect(RPostgres::Postgres(),    
                 host = "localhost",   
                 port = 5432,   
                 dbname = "romhout",   
                 user = "postgres",   
                 password=getPass::getPass() )

#ship_chronologies <- c("DMN1_Q1", "DMN1_Q1", "DMN1_Q3", "POM3_Q1", "POM4_Q1", "WOS7_Q1", "WOS7_Q2","ZWS4_Q1","ZWS6_Q1", "ZWS6_Q2")

ships <- c("BAYO", "DMN1", "DMN4", "DRUS", "POM2", "POM3", "POM4", "WOE1", "WOS7", "WS3", "WS4", "ZWB1","ZWS1","ZWS2","ZWS4","ZWS6")
sitechronos <- dbGetQuery(con, "Select * from site_chrono_info")
site_names <- data.frame(name = sitechronos$SiteChrono, site = str_split_fixed(unlist(sitechronos$SiteChrono), "_", 2)[,1], row.names = NULL)
ship_chronos <- site_names %>% filter(site %in% ships) %>% select(name)

gpkg_name <- "export/barges.gpkg"

for (n in 1:4) {
  assign(paste0("means_network_data_", n), st_read(con, query=read_file(paste0("queries/Network_means_", n, "_spatial.sql"))))
  assign(paste0("means_network_data_", n), get(paste0("means_network_data_", n)) %>%  group_by(Mean_A, Mean_B) %>%  filter(sum_sims == max(sum_sims))) 
  assign(paste0("ship_network_data_", n), inner_join(get(paste0("means_network_data_", n)), ship_chronos, by=c("Mean_A" = "name")))
  st_write(get(paste0("ship_network_data_", n)), dsn = gpkg_name, layer = paste0("ship_network_data_", n))
}  

 


  