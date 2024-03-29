library(dplR)
library(RPostgres)
library(getPass)
library(readr)
library(tidyverse)
library(igraph)
library(RCy3)
library(pals)

set.seed(666)

#drv <- dbDriver("PostgreSQL")
con <- dbConnect(RPostgres::Postgres(),    
                 host = "localhost",   
                 port = 5432,   
                 dbname = "romhout",   
                 user = "postgres",   
                 password=getPass::getPass() )

network_prefix <- "g_series_"
network_prefix2 <- "g_seriestrees_"
network_prefix_m <- "g_means_"
ships <- c("BAYO", "DMN1", "DMN4", "DRUS", "POM2", "POM3", "POM4", "WOE1", "WOS7", "WS3", "WS4", "ZWB1","ZWS1","ZWS2","ZWS4","ZWS6")
sampletrees <- dbGetQuery(con, "select \"MonsterCode\" as sample, \"BoomID\" as boomid from boom")

samplesWOSZWS <- dbGetQuery(con, read_file("queries/SampleShips.sql"))
#ship_parts <- sort(unlist(read.csv("data/Ship_terms.csv")))
ship_parts <- read.csv("data/Ship_terms.csv")
timbershapes <- c("7","9","10", "11", "13", "14", "15", "16", "17", "19")
# set ship parts
for (l in ship_parts$Nederlands){
  # DutchNames
  samplesWOSZWS$onderdeel[str_detect(samplesWOSZWS$monster_jaarringpat, l)] <- l
  # translation to English
  samplesWOSZWS$ship_part[str_detect(samplesWOSZWS$monster_jaarringpat, l)] <- ship_parts$English[ship_parts$Nederlands==l]
}
ship_parts_list <- sort(unlist(ship_parts$English))
samplesWOSZWS$onderdeel[is.na(samplesWOSZWS$onderdeel)] <- "onbekend"
samplesWOSZWS$ship_part[is.na(samplesWOSZWS$onderdeel)] <- "unknown"
# remove stamcode-options. Retain lowest number and remove letters
samplesWOSZWS$stamcode <- gsub("/.*|-.*", "", samplesWOSZWS$stamcode)
samplesWOSZWS$stamcode <- gsub("[^0-9]", "", samplesWOSZWS$stamcode)

# start Cytoscape (check Batch-file after update Cytoscape)
system("Cytoscape.bat")
source("CytoscapeStyles.R")
#load data and create networks with only measurements (and multiple measurements of trees)

netw_stats <- data.frame(network=character(), ship=character(), type=numeric(), 
                         no_comp=numeric(), no_nodes = numeric(), no_edges = numeric(),
                         clust_coef = numeric(), avg_degree = numeric(), max_radius = numeric())

# create folder for export images from networks (or clear, since Cytoscape would ask for each overwrite)
if (dir.exists("export/cytoscape_image")) {
  unlink("export/cytoscape_image/*", recursive = TRUE)
} else {
  dir.create("export/cytoscape_image")
}

for (n in 1:4) {
  assign(paste0("series_network_data_", n), dbGetQuery(con, read_file(paste0("queries/Network_Series_", n, "_without_treecurves.sql"))))
  assign(paste0("series_network_data_", n), get(paste0("series_network_data_", n)) %>%  group_by(Series_A, Series_B) %>%  filter(sum_sims == max(sum_sims)))
  assign(paste0(network_prefix,n), graph.data.frame(get(paste0("series_network_data_", n)), directed=FALSE))
  assign(paste0(network_prefix,n), igraph::simplify(get(paste0(network_prefix,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, n)),paste0("Series_network_type_",n), collection = paste0("Series_network_type_",n))
  loadTableData(sampletrees,data.key.column = "sample")
  setVisualStyle("GreyNodesLabel")
  exportImage(paste0("export/cytoscape_image/Network_series_type_",n,".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_series_type_",n,".png"),type = "PNG", resolution=600, zoom=500)
  analyzeNetwork()
  no_comp <- components(get(paste0(network_prefix,n)))$no
  no_nodes <- gorder(get(paste0(paste0(network_prefix,n))))
  no_edges <- gsize(get(paste0(network_prefix,n)))
  clust_coef <- transitivity(get(paste0(network_prefix,n)), type="average")
  avg_degree <- mean(degree(get(paste0(network_prefix,n))))
  max_radius <- max(eccentricity(get(paste0(network_prefix,n)))) # diameter of the network
  netw_stats <- rbind(netw_stats, data.frame(network="series", ship="all_series", type=n, 
                                             no_comp=no_comp, no_nodes = no_nodes, no_edges = no_edges,
                                             clust_coef = clust_coef, avg_degree = avg_degree, max_radius = max_radius))
  for (s in ships){
    # network of material from ship
    copyVisualStyle("WhiteNodesLabel", paste0("ship_", s, "_trees_type_", n))
    assign(paste0("ship_", s ,"_network_data_", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, nchar(s))==s, str_sub(Series_B, 1, nchar(s))==s))
    if (dim(get(paste0("ship_", s ,"_network_data_", n)))[1] == 0) { 
      rm(list = paste0("ship_", s ,"_network_data_", n))
      next }
    assign(paste0(network_prefix, "ship_", s, "_" ,n), graph.data.frame(get(paste0("ship_", s ,"_network_data_", n)), directed=FALSE))
    assign(paste0(network_prefix, "ship_", s, "_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_", s, "_" ,n)), edge.attr.comb = "first"))
    createNetworkFromIgraph(get(paste0(network_prefix, "ship_", s, "_" ,n)),paste0("Network_series_ship_", s, "_type_" ,n), collection = paste0("Series_network_type_",n), style.name = paste0("ship_", s, "_trees_type_", n))
    layoutNetwork(layout.name="kamada-kawai")
    setVisualStyle(paste0("ship_", s, "_trees_type_", n))
    try(loadTableData(sampletrees,data.key.column = "sample"))
    treelist <- sort(unlist(na.omit(unique(getTableColumns("node", "boomid")))))
    setNodeColorMapping(table.column = 'boomid', table.column.values = treelist , colors = polychrome(length(treelist)), mapping.type = "d", style.name = paste0("ship_", s, "_trees_type_", n))
    setVisualStyle(paste0("ship_", s, "_trees_type_", n))
    exportImage(paste0("export/cytoscape_image/Network_series_ship_", s, "_type_" ,n, "_trees.svg"),type = "SVG")
    exportImage(paste0("export/cytoscape_image/Network_series_ship_", s, "_type_" ,n, "_trees.png"),type = "PNG", resolution=600, zoom=500)
    # for WOS7 en ZWS ships: create style for parts in ship
    if (s %in% c("WOS7", "ZWB1","ZWS2","ZWS4","ZWS6")){
      # style based on part in the ship
      copyVisualStyle("WhiteNodesLabel", paste0("ship_", s, "_parts_type_", n))
      setVisualStyle(paste0("ship_", s, "_parts_type_", n))
      try(loadTableData(samplesWOSZWS,data.key.column = "monstercode"))
      #setNodeColorMapping(table.column = 'onderdeel', table.column.values = ship_parts , colors = polychrome(length(ship_parts)), mapping.type = "d", style.name = paste0("ship_", s, "_parts_type_", n))
      setNodeColorMapping(table.column = 'ship_part', table.column.values = ship_parts_list , colors = polychrome(length(ship_parts_list)), mapping.type = "d", style.name = paste0("ship_", s, "_parts_type_", n))
      exportImage(paste0("export/cytoscape_image/Network_series_ship_", s, "_type_" ,n, "_shipparts.svg"),type = "SVG")
      exportImage(paste0("export/cytoscape_image/Network_series_ship_", s, "_type_" ,n, "_shipparts.png"),type = "PNG", resolution=600, zoom=500)
      # visual style based on stamcode (timber shape)
      copyVisualStyle("WhiteNodesLabel", paste0("ship_", s, "_timbershape_type_", n))
      setVisualStyle(paste0("ship_", s, "_timbershape_type_", n))
      setNodeColorMapping(table.column = 'stamcode', table.column.values = timbershapes , colors = polychrome(length(timbershapes)), mapping.type = "d", style.name = paste0("ship_", s, "_timbershape_type_", n))
      exportImage(paste0("export/cytoscape_image/Network_series_ship_", s, "_type_" ,n, "_timbershapes.svg"),type = "SVG")
      exportImage(paste0("export/cytoscape_image/Network_series_ship_", s, "_type_" ,n, "_timbershapes.png"),type = "PNG", resolution=600, zoom=500)
    }
    if (getNodeCount() >= 4) {analyzeNetwork()}
    setVisualStyle(paste0("ship_", s, "_trees_type_", n))
    # get network_stats
    no_comp <- components(get(paste0(network_prefix, "ship_", s, "_" ,n)))$no
    no_nodes <- gorder(get(paste0(paste0(network_prefix, "ship_", s, "_" ,n))))
    no_edges <- gsize(get(paste0(network_prefix, "ship_", s, "_" ,n)))
    clust_coef <- transitivity(get(paste0(network_prefix, "ship_", s, "_" ,n)), type="average")
    avg_degree <- mean(degree(get(paste0(network_prefix, "ship_", s, "_" ,n))))
    max_radius <- max(eccentricity(get(paste0(network_prefix, "ship_", s, "_" ,n))))
    netw_stats <- rbind(netw_stats, data.frame(network="series", ship=s, type=n, 
                                               no_comp=no_comp, no_nodes = no_nodes, no_edges = no_edges,
                                               clust_coef = clust_coef, avg_degree = avg_degree, max_radius = max_radius))
    # network with other sites
    assign(paste0("ship_", s ,"_network_data_neighbours_", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, nchar(s))==s))
    assign(paste0(network_prefix, "ship_", s, "_neighbours_" ,n), graph.data.frame(get(paste0("ship_", s ,"_network_data_neighbours_", n)), directed=FALSE))
    assign(paste0(network_prefix, "ship_", s, "_neighbours_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_", s, "_neighbours_" ,n)), edge.attr.comb = "first"))
    createNetworkFromIgraph(get(paste0(network_prefix, "ship_", s, "_neighbours_" ,n)),paste0("Network_series_ship_", s, "_neighbours_type_" ,n), collection = paste0("Series_network_type_",n))
    layoutNetwork(layout.name="kamada-kawai")
    setVisualStyle("GreyNodesLabel")
    if (getNodeCount() >= 4) {analyzeNetwork()}
  }
  # combined WOS7 / ZWS6 network (all measurements)
  WOSZWS6 <- c("WOS7", "ZWS6")
  assign(paste0("ship_WOS7_ZWS6_network_data_", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, 4) %in% WOSZWS6, str_sub(Series_B, 1, 4) %in% WOSZWS6))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n), graph.data.frame(get(paste0("ship_WOS7_ZWS6_network_data_", n)), directed=FALSE))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n)),paste0("Network_series_ship_WOS7_ZWS6_type_" ,n), collection = paste0("Series_network_type_",n), style.name = "GreyNodesLabel")
  setVisualStyle("GreyNodesLabel")
  layoutNetwork(layout.name="kamada-kawai")
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, ".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, ".png"),type = "PNG", resolution=600, zoom=500)
  # trees 
  loadTableData(sampletrees,data.key.column = "sample")
  copyVisualStyle("WhiteNodesLabel", paste0("ship_WOS7_ZWS6_trees_type_", n))
  setVisualStyle(paste0("ship_WOS7_ZWS6_trees_type_", n))
  treelist <- sort(unlist(na.omit(unique(getTableColumns("node", "boomid")))))
  setNodeColorMapping(table.column = 'boomid', table.column.values = treelist, colors = polychrome(length(treelist)), mapping.type = "d", style.name = paste0("ship_WOS7_ZWS6_trees_type_", n))
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, "_trees.svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, "_trees.png"),type = "PNG", resolution=600, zoom=500)
  if (getNodeCount() >= 4) {analyzeNetwork()}
  copyVisualStyle("WhiteNodesLabel", paste0("ship_WOS7_ZWS6_parts_type_", n))
  setVisualStyle(paste0("ship_WOS7_ZWS6_parts_type_", n))
  try(loadTableData(samplesWOSZWS,data.key.column = "monstercode"))
  # ship parts
  #setNodeColorMapping(table.column = 'onderdeel', table.column.values = ship_parts , colors = polychrome(length(ship_parts)), mapping.type = "d", style.name = paste0("ship_WOS7_ZWS6_parts_type_", n))
  setNodeColorMapping(table.column = 'ship_part', table.column.values = ship_parts_list , colors = polychrome(length(ship_parts_list)), mapping.type = "d", style.name = paste0("ship_WOS7_ZWS6_parts_type_", n))
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, "_shipparts.svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, "_shipparts.png"),type = "PNG", resolution=600, zoom=500)
  # timber shapes
  copyVisualStyle("WhiteNodesLabel", paste0("ship_WOS7_ZWS6_timbershape_type_", n))
  setNodeColorMapping(table.column = 'stamcode', table.column.values = timbershapes , colors = polychrome(length(timbershapes)), mapping.type = "d", style.name = paste0("ship_WOS7_ZWS6_timbershape_type_", n))
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, "_timbershapes.svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_series_ship_WOS7_ZWS6_type_" ,n, "_timbershapes.png"),type = "PNG", resolution=600, zoom=500)
  # combined WOS7 / ZWS6 network with other sites
  assign(paste0("ship_WOS7_ZWS6_network_data_neighbours_", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, 4) %in% WOSZWS6))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n), graph.data.frame(get(paste0("ship_WOS7_ZWS6_network_data_neighbours_", n)), directed=FALSE))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n)),paste0("Network_series_ship_WOS7_ZWS6_neighbours_type_" ,n), collection = paste0("Series_network_type_",n))
  layoutNetwork(layout.name="kamada-kawai")
  setVisualStyle("GreyNodesLabel")
  if (getNodeCount() >= 4) {analyzeNetwork()}
}

closeSession(save.before.closing = TRUE, filename = "export/Ships_series.cys")
commandQuit() # close Cytoscape to empty memory it retains from the running session 
# start Cytoscape again (check Batch-file after update Cytoscape)
system("Cytoscape.bat")
source("CytoscapeStyles.R")

#load data and create networks with trees and only one curve per tree
for (n in 1:4) {
  assign(paste0("seriestrees_network_data_", n), dbGetQuery(con, read_file(paste0("queries/Network_Series_", n, ".sql"))))
  assign(paste0("seriestrees_network_data_", n), get(paste0("seriestrees_network_data_", n)) %>%  group_by(Series_A, Series_B) %>%  filter(sum_sims == max(sum_sims)))
  assign(paste0(network_prefix2,n), graph.data.frame(get(paste0("seriestrees_network_data_", n)), directed=FALSE))
  assign(paste0(network_prefix2,n), igraph::simplify(get(paste0(network_prefix2,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix2, n)),paste0("Trees_network_type_",n), collection = paste0("Trees_network_type_",n))
  setVisualStyle("GreyNodesLabel")
  layoutNetwork(layout.name="kamada-kawai")
  exportImage(paste0("export/cytoscape_image/Network_trees_type_",n,".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_trees_type_",n,".png"),type = "PNG", resolution=600, zoom=500)
  # colour nodes based on ship
  copyVisualStyle("WhiteNodesLabel", paste0("ship_colour_type_", n))
  setVisualStyle(paste0("ship_colour_type_", n))
  ship_names <- data.frame(name = getTableColumns("node","name"), ship = str_sub(unlist(getTableColumns("node","name")),1,4), row.names = NULL)
  loadTableData(ship_names,data.key.column = "name")
  setNodeColorMapping(table.column = 'ship', table.column.values = ships, colors = polychrome(length(ships)), mapping.type = "d", style.name = paste0("ship_colour_type_", n))
  exportImage(paste0("export/cytoscape_image/Network_trees_ship_color_type_" ,n, ".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_trees_ship_color_type_" ,n, ".png"),type = "PNG", resolution=600, zoom=500)
  
  analyzeNetwork()
  no_comp <- components(get(paste0(network_prefix2,n)))$no
  no_nodes <- gorder(get(paste0(paste0(network_prefix2,n))))
  no_edges <- gsize(get(paste0(network_prefix2,n)))
  clust_coef <- transitivity(get(paste0(network_prefix2,n)), type="average")
  avg_degree <- mean(degree(get(paste0(network_prefix2,n))))
  max_radius <- max(eccentricity(get(paste0(network_prefix2,n))))
  netw_stats <- rbind(netw_stats, data.frame(network="trees", ship="all_trees", type=n, 
                                             no_comp=no_comp, no_nodes = no_nodes, no_edges = no_edges,
                                             clust_coef = clust_coef, avg_degree = avg_degree, max_radius = max_radius))
  for (s in ships){
    # network of material form ship
    assign(paste0("ship_", s ,"_network_data_", n), get(paste0("seriestrees_network_data_", n)) %>% filter(str_sub(Series_A, 1, nchar(s))==s, str_sub(Series_B, 1, nchar(s))==s))
    if (dim(get(paste0("ship_", s ,"_network_data_", n)))[1] == 0) { 
      paste0("ship_", s ,"_network_data_", n)
      next }
    assign(paste0(network_prefix2, "ship_", s, "_" ,n), graph.data.frame(get(paste0("ship_", s ,"_network_data_", n)), directed=FALSE))
    assign(paste0(network_prefix2, "ship_", s, "_" ,n), igraph::simplify(get(paste0(network_prefix2, "ship_", s, "_" ,n)), edge.attr.comb = "first"))
    createNetworkFromIgraph(get(paste0(network_prefix2, "ship_", s, "_" ,n)),paste0("Trees_series_ship_", s, "_type_" ,n), collection = paste0("Trees_network_type_",n))
    setVisualStyle("GreyNodesLabel")
    layoutNetwork(layout.name="kamada-kawai")
    if (getNodeCount() >= 4) {analyzeNetwork()}
    exportImage(paste0("export/cytoscape_image/Network_trees_ship_", s, "_type_" ,n, ".svg"),type = "SVG")
    exportImage(paste0("export/cytoscape_image/Network_trees_ship_", s, "_type_" ,n, ".png"),type = "PNG", resolution=600, zoom=500)
    # get network_stats
    no_comp <- components(get(paste0(network_prefix2, "ship_", s, "_" ,n)))$no
    no_nodes <- gorder(get(paste0(paste0(network_prefix2, "ship_", s, "_" ,n))))
    no_edges <- gsize(get(paste0(network_prefix2, "ship_", s, "_" ,n)))
    clust_coef <- transitivity(get(paste0(network_prefix2, "ship_", s, "_" ,n)), type="average")
    avg_degree <- mean(degree(get(paste0(network_prefix2, "ship_", s, "_" ,n))))
    max_radius <- max(eccentricity(get(paste0(network_prefix2, "ship_", s, "_" ,n))))
    netw_stats <- rbind(netw_stats, data.frame(network="trees", ship=s, type=n, 
                                               no_comp=no_comp, no_nodes = no_nodes, no_edges = no_edges,
                                               clust_coef = clust_coef, avg_degree = avg_degree, max_radius = max_radius))
    
    # network with other sites
    assign(paste0("ship_", s ,"_network_data_neighbours_", n), get(paste0("seriestrees_network_data_", n)) %>% filter(str_sub(Series_A, 1, nchar(s))==s))
    assign(paste0(network_prefix2, "ship_", s, "_neighbours_" ,n), graph.data.frame(get(paste0("ship_", s ,"_network_data_neighbours_", n)), directed=FALSE))
    assign(paste0(network_prefix2, "ship_", s, "_neighbours_" ,n), igraph::simplify(get(paste0(network_prefix2, "ship_", s, "_neighbours_" ,n)), edge.attr.comb = "first"))
    createNetworkFromIgraph(get(paste0(network_prefix2, "ship_", s, "_neighbours_" ,n)),paste0("Network_trees_ship_", s, "_neighbours_type_" ,n), collection = paste0("Trees_network_type_",n))
    setVisualStyle("GreyNodesLabel")
    layoutNetwork(layout.name="kamada-kawai")
    if (getNodeCount() >= 4) {analyzeNetwork()}
  }
  # combined network of all ships (all measurements)
  assign(paste0("ship_combined_network_data_trees", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, 4) %in% ships, str_sub(Series_B, 1, 4) %in% ships))
  assign(paste0(network_prefix, "ship_combined_" ,n), graph.data.frame(get(paste0("ship_combined_network_data_trees", n)), directed=FALSE))
  assign(paste0(network_prefix, "ship_combined_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_combined_" ,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, "ship_combined_" ,n)),paste0("Network_trees_ship_combined_type_" ,n), collection = paste0("Trees_network_type_",n), style.name = paste0("ship_combined_type_", n))
  layoutNetwork(layout.name="kamada-kawai")
  analyzeNetwork()
  # colour nodes based on ship
  copyVisualStyle("WhiteNodesLabel", paste0("ship_combined_type_", n))
  setVisualStyle(paste0("ship_combined_type_", n))
  ship_names <- data.frame(name = getTableColumns("node","name"), ship = str_sub(unlist(getTableColumns("node","name")),1,4), row.names = NULL)
  loadTableData(ship_names,data.key.column = "name")
  setNodeColorMapping(table.column = 'ship', table.column.values = ships, colors = polychrome(length(ships)), mapping.type = "d", style.name = paste0("ship_combined_type_", n))
  exportImage(paste0("export/cytoscape_image/Network_trees_all_ships_type_" ,n, ".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_trees_all_ships_type_" ,n, ".png"),type = "PNG", resolution=600, zoom=500)
  # combined network of all ships with other sites
  assign(paste0("ship_combined_network_data_trees_neighbours_", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, 4) %in% ships))
  assign(paste0(network_prefix, "ship_combined_neighbours_" ,n), graph.data.frame(get(paste0("ship_combined_network_data_trees_neighbours_", n)), directed=FALSE))
  assign(paste0(network_prefix, "ship_combined_neighbours_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_combined_neighbours_" ,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, "ship_combined_neighbours_" ,n)),paste0("Network_trees_ship_combined_neighbours_type_" ,n), collection = paste0("Trees_network_type_",n))
  layoutNetwork(layout.name="kamada-kawai")
  setVisualStyle("GreyNodesLabel")
  no_comp <- components(get(paste0(network_prefix,n)))$no
  no_nodes <- gorder(get(paste0(paste0(network_prefix,n))))
  no_edges <- gsize(get(paste0(network_prefix,n)))
  clust_coef <- transitivity(get(paste0(network_prefix,n)), type="average")
  avg_degree <- mean(degree(get(paste0(network_prefix,n))))
  max_radius <- max(eccentricity(get(paste0(network_prefix,n))))
  netw_stats <- rbind(netw_stats, data.frame(network="trees", ship="all_ships", type=n, 
                                             no_comp=no_comp, no_nodes = no_nodes, no_edges = no_edges,
                                             clust_coef = clust_coef, avg_degree = avg_degree, max_radius = max_radius))
  
  analyzeNetwork()
  # colour nodes based on ship
  copyVisualStyle("WhiteNodesLabel", paste0("ship_combined_neighbour_type_", n))
  ship_names <- data.frame(name = getTableColumns("node","name"), ship = str_sub(unlist(getTableColumns("node","name")),1,4), row.names = NULL)
  loadTableData(ship_names,data.key.column = "name")
  setNodeColorMapping(table.column = 'ship', table.column.values = ships, colors = polychrome(length(ships)), mapping.type = "d", style.name = paste0("ship_combined_neighbour_type_", n))
  setVisualStyle(paste0("ship_combined_neighbour_type_", n))
  
  # combined WOS7 / ZWS6 network (all trees)
  WOSZWS6 <- c("WOS7", "ZWS6")
  assign(paste0("ship_WOS7_ZWS6_network_data_trees", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, 4) %in% WOSZWS6, str_sub(Series_B, 1, 4) %in% WOSZWS6))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n), graph.data.frame(get(paste0("ship_WOS7_ZWS6_network_data_trees", n)), directed=FALSE))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, "ship_WOS7_ZWS6_" ,n)),paste0("Network_trees_ship_WOS7_ZWS6_type_" ,n), collection = paste0("Trees_network_type_",n), style.name = paste0("ship_WOS7_ZWS6_type_", n))
  setVisualStyle("GreyNodesLabel")
  layoutNetwork(layout.name="kamada-kawai")
  exportImage(paste0("export/cytoscape_image/Network_trees_WOS7_ZWS6_type_" ,n, ".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_trees_WOS7_ZWS6_type_" ,n, ".png"),type = "PNG", resolution=600, zoom=500)
  analyzeNetwork()
  # combined WOS7 / ZWS6 network with other sites
  assign(paste0("ship_WOS7_ZWS6_network_data_trees_neighbours_", n), get(paste0("series_network_data_", n)) %>% filter(str_sub(Series_A, 1, 4) %in% WOSZWS6))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n), graph.data.frame(get(paste0("ship_WOS7_ZWS6_network_data_trees_neighbours_", n)), directed=FALSE))
  assign(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n), igraph::simplify(get(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix, "ship_WOS7_ZWS6_neighbours_" ,n)),paste0("Network_trees_ship_WOS7_ZWS6_neighbours_type_" ,n), collection = paste0("Trees_network_type_",n))
  setVisualStyle("GreyNodesLabel")
  layoutNetwork(layout.name="kamada-kawai")
  analyzeNetwork()
}

closeSession(save.before.closing = TRUE, filename = "export/Ships_trees.cys")
commandQuit() # close Cytoscape to empty memory 
# start Cytoscape again (check Batch-file after update Cytoscape)
system("Cytoscape.bat")
source("CytoscapeStyles.R")

# Networks of sitechronologies

for (n in 1:4) {
  assign(paste0("means_network_data_", n), dbGetQuery(con, read_file(paste0("queries/Network_means_", n, ".sql"))))
  assign(paste0("means_network_data_", n), get(paste0("means_network_data_", n)) %>%  group_by(Mean_A, Mean_B) %>%  filter(sum_sims == max(sum_sims)))
  assign(paste0(network_prefix_m,n), graph.data.frame(get(paste0("means_network_data_", n)), directed=FALSE))
  assign(paste0(network_prefix_m,n), igraph::simplify(get(paste0(network_prefix_m,n)), edge.attr.comb = "first"))
  createNetworkFromIgraph(get(paste0(network_prefix_m, n)),paste0("means_network_type_",n), collection = paste0("Means_network_type_",n))
  layoutNetwork(layout.name="kamada-kawai")
  analyzeNetwork()
  # colour nodes based on ship
  copyVisualStyle("WhiteNodesLabel", paste0("ship_means_type_", n))
  site_names <- data.frame(name = getTableColumns("node","name"), site = str_split_fixed(unlist(getTableColumns("node","name")), "_", 2)[,1], row.names = NULL)
  loadTableData(site_names,data.key.column = "name")
  setNodeColorMapping(table.column = 'site', table.column.values = ships, colors = polychrome(length(ships)), mapping.type = "d", style.name = paste0("ship_means_type_", n))
  setVisualStyle(paste0("ship_means_type_", n))
  write_graph(get(paste0(network_prefix_m,n)), paste0("export/",network_prefix_m,n,".graphml"), format = "graphml")
  write_graph(get(paste0(network_prefix_m,n)), paste0("export/",network_prefix_m,n,".ncol"), format = "ncol")
  exportImage(paste0("export/cytoscape_image/Network_means_type_",n,".svg"),type = "SVG")
  exportImage(paste0("export/cytoscape_image/Network_means_type_",n,".png"),type = "PNG", resolution=600, zoom=500)
  # get network_stats
  no_comp <- components(get(paste0(network_prefix_m,n)))$no
  no_nodes <- gorder(get(paste0(paste0(network_prefix_m,n))))
  no_edges <- gsize(get(paste0(network_prefix_m,n)))
  clust_coef <- transitivity(get(paste0(network_prefix_m,n)), type="average")
  avg_degree <- mean(degree(get(paste0(network_prefix_m,n))))
  max_radius <- max(eccentricity(get(paste0(network_prefix_m,n))))
  netw_stats <- rbind(netw_stats, data.frame(network="means", ship="all_means", type=n, 
                                             no_comp=no_comp, no_nodes = no_nodes, no_edges = no_edges,
                                             clust_coef = clust_coef, avg_degree = avg_degree, max_radius = max_radius))
  
}

closeSession(save.before.closing = TRUE, filename = "export/Means_ships.cys")
commandQuit() # close Cytoscape to empty memory 

write.csv2(netw_stats, "export/netw_stats.csv", row.names = FALSE)

save.image(file = "Barges_Networks.RData")


dbDisconnect(con)

