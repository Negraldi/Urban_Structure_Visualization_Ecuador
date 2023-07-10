# Set parameters from command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Verify if all arguments are present
if(length(args) != 6) {
    stop("Not all arguments are present. Please provide: city_name, canton_code, pixels_per_degree, continent_file, metro_area_file, functions_script_path.")
}

city_name <- args[1]
canton_code <- args[2]
pixels_per_degree <- as.integer(args[3])
continent_file <- args[4]
metro_area_file <- args[5]
functions_script_path <- args[6]

source(functions_script_path)

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
