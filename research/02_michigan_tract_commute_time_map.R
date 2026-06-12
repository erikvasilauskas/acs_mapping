# Michigan weighted average commute time map by tract
# ACS 5-year table B08303: Travel Time to Work

pkgs <- c(
    "tidycensus",
    "tigris",
    "dplyr",
    "ggplot2",
    "htmlwidgets",
    "leaflet",
    "sf",
    "scales"
)

invisible(lapply(pkgs, library, character.only = TRUE))

source("research/R/commute_time_helpers.R")

options(
    scipen = 999,
    tigris_use_cache = TRUE,
    tigris_class = "sf"
)

if (!dir.exists("research/outputs")) {
    dir.create("research/outputs", recursive = TRUE)
}

acs_year <- 2024
acs_survey <- "acs5"
analysis_state <- "MI"
analysis_geography <- "tract"
target_crs <- 3078

commute_tract <- get_acs(
    geography = analysis_geography,
    table = "B08303",
    state = analysis_state,
    year = acs_year,
    survey = acs_survey,
    output = "wide",
    geometry = TRUE,
    show_call = TRUE
) %>%
    add_commute_time_metrics() %>%
    st_transform(target_crs)

michigan_counties <- counties(
    state = analysis_state,
    cb = TRUE,
    year = acs_year
) %>%
    st_transform(target_crs)

kalamazoo_county <- michigan_counties %>%
    filter(NAME == "Kalamazoo")

commute_map <- make_michigan_commute_map(
    commute_sf = commute_tract,
    michigan_counties = michigan_counties,
    kalamazoo_county = kalamazoo_county,
    geography_label = "Tract",
    acs_year = acs_year
)

if (interactive()) {
    print(commute_map)
}

ggsave(
    filename = "research/outputs/michigan_tract_avg_commute_time_2024.png",
    plot = commute_map,
    width = 8,
    height = 7,
    dpi = 300,
    bg = "white"
)

interactive_commute_map <- make_michigan_commute_interactive_map(
    commute_sf = commute_tract,
    michigan_counties = michigan_counties,
    kalamazoo_county = kalamazoo_county,
    geography_label = "Tract"
)

save_interactive_commute_map(
    interactive_map = interactive_commute_map,
    html_file = "research/outputs/michigan_tract_avg_commute_time_2024.html"
)

write_commute_outputs(
    commute_sf = commute_tract,
    output_prefix = "research/outputs/michigan_tract_avg_commute_time_2024",
    reliability_count_name = "tracts"
)
