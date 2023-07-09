source("UrbanStructureFunctions.R")

# Set parameters
city_name <- "Cuenca"
canton_code <- "0101"
pixels_per_degree <- 17026
continent_file <- "map_of_ecuador/nxprovincias.shp"
metro_area_file <- "map_of_ecuador/INEC_Area_Metro.gpkg"

# Read and transform continent data
continent = continent_file %>%
  read_sf() %>%
  st_union() %>%
  st_transform(., "WGS84")

# Determine bounding box for analysis
bounding_box = metro_area_file %>%
  read_sf() %>%
  st_transform(., "WGS84") %>%
  process_metro_areas(., canton_code) %>%
  st_bbox()

# Prepare bounding box and intersect it with continent
bounding_box = prepare_bounding_box(bounding_box)
continent = st_intersection(continent, bounding_box)

# Retrieve street lines from Open Street Map
streets = get_street_lines(bounding_box)

# Retrieve water and island areas from Open Street Map
island_water_areas = get_island_water_areas(bounding_box)
list2env(island_water_areas, .GlobalEnv)

# Split the streets where they intersect
streets = split_lines(streets)

# Process coordinates
coordinate_data = process_coordinates(streets)
list2env(coordinate_data, .GlobalEnv)


# Saving the plots as PNGs
save_plot_as_png(
      city_name = city_name, 
      coordinates =coordinates,
       points = points,
       bbox = bounding_box, 
       continent=continent, 
       water = water_areas,
       islands =  islands,
       pixels_per_degree = pixels_per_degree)
