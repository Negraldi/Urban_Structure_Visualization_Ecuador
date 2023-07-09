# Install and Import necessary libraries
# List of packages needed
packages <- c("lwgeom", "sf", "osmdata", "dplyr")

# Function to check if packages are installed, install them if not
check_and_install <- function(pkg){
  if (!require(pkg, character.only = TRUE)){
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# Use the function to check and install packages
lapply(packages, check_and_install)


# Use spherical geometry (FALSE)
sf_use_s2(FALSE)

# Function to adjust brightness of colors
adjust_brightness <- function(color_codes, target_brightness) {
  color_codes = t(col2rgb(color_codes))/255  
  base_brightness = (color_codes %*% c(0.2989,0.5870 ,0.1140))[,1]
  color_codes =
    (target_brightness/base_brightness)*(target_brightness<base_brightness)*color_codes +
    ((target_brightness-base_brightness)/(1-base_brightness)+(1-(target_brightness-base_brightness)/(1-base_brightness))*color_codes)*(base_brightness<target_brightness)
  color_codes[color_codes > 1] = 1
  color_codes[color_codes < 0] = 0
  return(rgb(color_codes))
}

# Function to plot map
plot_map <- function(hue, sat=1, target_brightness, x0, y0, x1, y1, bbox, continent, water, island, water_color="#3D4D52", land_color="black", ...) {
  par(mar=c(0,0,0,0), mai=c(0,0,0,0), bg=water_color)
  bbox=st_bbox(bbox)
  plot(bbox[c(1,3)], bbox[c(2,4)], xaxs="i", yaxs="i", axes=FALSE, frame.plot=FALSE, ann=FALSE, asp=1, type="n")
  plot(continent, col=land_color, border="transparent", add=T, xpd = T)
  plot(water, col=water_color, border="transparent", add=T)
  plot(island, col=land_color, border="transparent", add=T)
  color_codes = hsv(h = hue, s = sat, v = 1)
  color_codes = adjust_brightness(color_codes, target_brightness)
  segments(x0, y0, x1, y1, col=color_codes, lty = 1, ...)
}

# Function to process metro areas
process_metro_areas <- function(metro_data, cant_data) {
  
  metro_areas = metro_data$geom %>%
    st_union() %>%
    st_cast(.,"POLYGON") %>%
    st_as_sf()
  
  metro_areas$parr =  
    st_intersects(metro_areas, metro_data) %>%
    lapply(.,function(x) metro_data$DPA_PARROQ[x])
  rm(metro_data)
  
  metro_areas = metro_areas %>%
    filter(sapply(parr,function(x) any(substr(x,1,4) %in% cant_data))) %>%
    slice_max(st_area(x), n = 1) %>%
    .$x
  
  return(metro_areas)
}

# Function to prepare bounding box
prepare_bounding_box <- function(bbox, crs="WGS84") {
  bounding_box = data.frame(x =bbox[c(1,3)], y = bbox[c(2,4)]) %>% 
    st_as_sf(coords = c("x", "y")) %>%
    st_bbox() %>%
    st_as_sfc %>%
    st_set_crs(crs)
  return(bounding_box)
}

# Function to get street lines from OpenStreetMap within a bounding box
get_street_lines <- function(bbox) {
  bbox_coords = st_bbox(bbox)
  
  # Query OSM for highways of various types
  streets = opq(bbox = bbox_coords) %>%
    add_osm_feature(key = 'highway',
                    value=c("residential","living_street","tertiary","primary",
                            "secondary","trunk","primary_link","secondary_link",
                            "tertiary_link","unclassified")) %>%
    osmdata_sf() %>%
    .$osm_lines %>%
    st_make_valid() %>%
    select(highway) %>%
    st_intersection(.,bbox) %>%
    st_make_valid() %>%
    filter(!is.na(highway)) %>%
    filter(as.numeric(st_length(geometry)) != 0)
  
  # Recategorize street types
  streets$highway = factor(streets$highway)
  levels(streets$highway)[levels(streets$highway) %in% c("living_street","residential","unclassified")] = "residential"
  levels(streets$highway)[levels(streets$highway) %in% c("primary","primary_link","trunk")] = "primary"
  levels(streets$highway)[levels(streets$highway) %in% c("secondary_link","secondary")] = "secondary"
  levels(streets$highway)[levels(streets$highway) %in% c("tertiary_link","tertiary")] = "tertiary"
  streets$highway = ordered(streets$highway,c("residential","tertiary","secondary","primary"))
  
  # Assign unique IDs
  streets$id = 1:nrow(streets)
  streets = st_cast(streets,"MULTILINESTRING")
  
  return(streets)
}

# Function to get island and water areas from OpenStreetMap within a bounding box
get_island_water_areas <- function(bbox) {
  bbox_coords = st_bbox(bbox)
  
  # Query OSM for islands, residential areas, and water bodies
  island_water = opq(bbox = bbox_coords) %>%
    add_osm_features(features = list (
      "place" = "island",
      "landuse" = "residential",
      "natural" = "water"
    )
    ) %>%
    osmdata_sf() %>%
    .$osm_polygons %>%
    select(name, place, landuse, natural)  %>%
    st_intersection(., bbox) %>%
    st_make_valid() %>%
    filter(as.numeric(st_area(geometry)) != 0)
  
  # Extract islands and residential areas
  islands = island_water %>%
    filter(place %in% "island" | landuse %in% "residential") %>%
    st_union()
  
  # Extract water bodies
  water = island_water %>%
    filter(natural %in% "water") %>%
    filter(grepl("río|estero|lago|rio", tolower(name))) %>%
    st_union()
  
  return(list(islands = islands, water_areas = water))
}

# Function to split lines at intersections
split_lines <- function(streets) {
  streets = streets %>%
    .$geometry %>%
    st_intersection() %>%
    st_collection_extract(.,"POINT") %>%
    st_cast(.,to="POINT") %>%
    lwgeom::st_split(streets, .) %>%
    st_collection_extract(., type="LINESTRING") 
  return(streets)
}

# Function to process street coordinates
process_coordinates = function(streets) {
  coordinates = st_coordinates(streets)
  coordinates = data.frame(coordinates)
  
  # Convert to integer for precision
  coordinates[,c("X","Y")] = round(coordinates[,c("X","Y")] * 1e7)
  coordinates$X = as.integer(coordinates$X)
  coordinates$Y = as.integer(coordinates$Y)
  
  points = unique(coordinates[,c("X","Y")])
  points$id = 1:nrow(points)
  
  coordinates$ord = 1:nrow(coordinates)
  coordinates = coordinates %>%
    left_join(points, by=c("X"="X", "Y"="Y")) %>%
    rename(id_points=id) %>%
    select(-X, -Y)
  
  coordinates = coordinates %>%
    group_by(L1) %>%
    arrange(ord) %>%
    filter(diff(c(0, id_points)) != 0) %>%
    mutate(id_points1 = id_points, id_points2 = lead(id_points, 1, 0)) %>%
    filter(id_points2 != 0) %>%
    ungroup() %>%
    arrange(L1) %>%
    select(L1, id_points1, id_points2)
  
  coordinates = data.frame(rbind(as.matrix(coordinates), as.matrix(coordinates[,c(1,3:2)])))
  coordinates$highway = streets$highway[coordinates$L1]
  
  coordinates = coordinates %>%
    filter(id_points1 < id_points2) %>%
    group_by(id_points1, id_points2) %>%
    summarise(highway = max(highway)) %>%
    arrange(highway)
  
  coordinates$angle = atan2(y = points[coordinates$id_points1,"Y"]/1e7 - points[coordinates$id_points2,"Y"]/1e7,
                            x = points[coordinates$id_points1,"X"]/1e7 - points[coordinates$id_points2,"X"]/1e7)
  
  coordinates$uang = ((coordinates$angle + pi*(coordinates$angle < 0)) - pi/2*((coordinates$angle + pi*(coordinates$angle < 0)) > (pi/2))) / (pi/2)
  
  list(coordinates=coordinates, points=points)
}

# Function to save plot as PNG
save_plot_as_png = function(city_name, coordinates, points, bbox, continent, water, islands, pixels_per_degree) {
  bbox_coords = st_bbox(bbox)
  
  # Calculate pixel dimensions based on degrees
  pixel_width = round((bbox_coords[3] - bbox_coords[1]) * pixels_per_degree)
  pixel_height = round((bbox_coords[4] - bbox_coords[2]) * pixels_per_degree)
  
  sats=c(1,1,0)
  brightness=cbind(255-c(190,150,117,81),c(190,150,117,81),c(190,150,117,81))
  water_colors=c("#3D4D52","lightblue","lightblue")
  land_colors=c("black","white","white")
  
  
  png(sprintf("%s_%%02d.png", city_name), width = pixel_width, height = pixel_height, res = 300)
  
  for(i in 1:3) {
    plot_map(hue = coordinates$uang,
             sat = sats[i],
             target_brightness = 
               (
                 (coordinates$highway=="residential")*brightness[1,i]+
                   (coordinates$highway=="tertiary")*brightness[2,i]+
                   (coordinates$highway=="secondary")*brightness[3,i]+
                   (coordinates$highway=="primary")*brightness[4,i]
               )/255,
             x0=points[coordinates$id_points1,"X"]/1e7,
             y0=points[coordinates$id_points1,"Y"]/1e7,
             x1=points[coordinates$id_points2 ,"X"]/1e7,
             y1=points[coordinates$id_points2,"Y"]/1e7,
             bbox=bbox,
             continent = continent,
             water =water,
             island=islands,
             water_color =water_colors[i],
             land_color = land_colors[i]
    )
  }
  dev.off()
  
}
