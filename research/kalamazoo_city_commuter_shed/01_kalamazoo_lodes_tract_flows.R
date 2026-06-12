# Kalamazoo city commuter-shed from LEHD LODES origin-destination flows

pkgs <- c(
    "readr",
    "dplyr",
    "sf",
    "tigris",
    "ggplot2",
    "leaflet",
    "htmlwidgets",
    "scales",
    "stringr"
)

invisible(lapply(pkgs, library, character.only = TRUE))

options(
    scipen = 999,
    tigris_use_cache = TRUE,
    tigris_class = "sf"
)

base_dir <- "research/kalamazoo_city_commuter_shed"
raw_dir <- file.path(base_dir, "data", "raw")
output_dir <- file.path(base_dir, "outputs")

dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

state_abbr <- "mi"
state_fips <- "26"
lodes_version <- "LODES8"
lodes_root <- paste0("https://lehd.ces.census.gov/data/lodes/", lodes_version, "/", state_abbr)
od_dir_url <- paste0(lodes_root, "/od/")
xwalk_url <- paste0(lodes_root, "/", state_abbr, "_xwalk.csv.gz")

list_available_lodes_years <- function(od_url, state_abbr) {
    od_html <- readLines(od_url, warn = FALSE)
    pattern <- paste0(state_abbr, "_od_main_JT00_([0-9]{4})\\.csv\\.gz")
    matches <- stringr::str_match(od_html, pattern)[, 2]
    sort(unique(as.integer(stats::na.omit(matches))))
}

lodes_year <- max(list_available_lodes_years(od_dir_url, state_abbr))

od_file_name <- paste0(state_abbr, "_od_main_JT00_", lodes_year, ".csv.gz")
od_url <- paste0(od_dir_url, od_file_name)
od_file <- file.path(raw_dir, od_file_name)
xwalk_file <- file.path(raw_dir, paste0(state_abbr, "_xwalk.csv.gz"))

download_if_needed <- function(url, destfile) {
    if (!file.exists(destfile)) {
        download.file(url, destfile = destfile, mode = "wb", quiet = FALSE)
    }
}

download_if_needed(od_url, od_file)
download_if_needed(xwalk_url, xwalk_file)

message("Using LODES file: ", od_file_name)

xwalk <- readr::read_csv(
    xwalk_file,
    col_types = cols(
        tabblk2020 = col_character(),
        trct = col_character(),
        stplc = col_character(),
        stplcname = col_character(),
        cty = col_character(),
        ctyname = col_character(),
        .default = col_skip()
    )
) %>%
    mutate(
        home_block = tabblk2020,
        work_block = tabblk2020,
        tract_geoid = stringr::str_pad(trct, width = 11, side = "left", pad = "0"),
        place_geoid = stringr::str_pad(stplc, width = 7, side = "left", pad = "0")
    )

kalamazoo_city <- xwalk %>%
    filter(stplcname == "Kalamazoo city, MI") %>%
    distinct(place_geoid, stplcname)

if (nrow(kalamazoo_city) != 1) {
    stop("Expected one Kalamazoo city place in the LODES crosswalk; found ", nrow(kalamazoo_city))
}

kalamazoo_place_geoid <- kalamazoo_city$place_geoid[[1]]

block_lookup <- xwalk %>%
    distinct(
        home_block,
        work_block,
        tract_geoid,
        place_geoid,
        stplcname
    )

od <- readr::read_csv(
    od_file,
    col_types = cols(
        w_geocode = col_character(),
        h_geocode = col_character(),
        S000 = col_double(),
        .default = col_skip()
    )
)

od_tract <- od %>%
    left_join(
        block_lookup %>%
            select(h_geocode = home_block,
                   home_tract_geoid = tract_geoid,
                   home_place_geoid = place_geoid),
        by = "h_geocode"
    ) %>%
    left_join(
        block_lookup %>%
            select(w_geocode = work_block,
                   work_tract_geoid = tract_geoid,
                   work_place_geoid = place_geoid),
        by = "w_geocode"
    )

tract_scores <- od_tract %>%
    group_by(home_tract_geoid) %>%
    summarise(
        resident_jobs = sum(S000, na.rm = TRUE),
        jobs_to_kalamazoo_city = sum(S000[work_place_geoid == kalamazoo_place_geoid], na.rm = TRUE),
        .groups = "drop"
    ) %>%
    full_join(
        od_tract %>%
            group_by(work_tract_geoid) %>%
            summarise(
                workplace_jobs = sum(S000, na.rm = TRUE),
                jobs_from_kalamazoo_city = sum(S000[home_place_geoid == kalamazoo_place_geoid], na.rm = TRUE),
                .groups = "drop"
            ),
        by = c("home_tract_geoid" = "work_tract_geoid")
    ) %>%
    rename(tract_geoid = home_tract_geoid) %>%
    mutate(
        across(
            c(resident_jobs, jobs_to_kalamazoo_city, workplace_jobs, jobs_from_kalamazoo_city),
            ~ tidyr::replace_na(.x, 0)
        ),
        inbound_share_to_kalamazoo = if_else(
            resident_jobs > 0,
            jobs_to_kalamazoo_city / resident_jobs,
            NA_real_
        ),
        outbound_share_from_kalamazoo = if_else(
            workplace_jobs > 0,
            jobs_from_kalamazoo_city / workplace_jobs,
            NA_real_
        ),
        bidirectional_jobs = jobs_to_kalamazoo_city + jobs_from_kalamazoo_city,
        commuter_score = coalesce(inbound_share_to_kalamazoo, 0) +
            coalesce(outbound_share_from_kalamazoo, 0),
        in_kalamazoo_city = tract_geoid %in%
            unique(xwalk$tract_geoid[xwalk$place_geoid == kalamazoo_place_geoid]),
        data_driven_shed = case_when(
            in_kalamazoo_city ~ "Kalamazoo city",
            jobs_to_kalamazoo_city >= 50 | inbound_share_to_kalamazoo >= 0.05 ~ "Inbound shed",
            jobs_from_kalamazoo_city >= 50 | outbound_share_from_kalamazoo >= 0.05 ~ "Outbound shed",
            bidirectional_jobs >= 50 | commuter_score >= 0.05 ~ "Bidirectional tie",
            TRUE ~ "Outside threshold"
        )
    )

tracts_mi <- tigris::tracts(
    state = state_fips,
    year = 2024,
    cb = TRUE
) %>%
    st_transform(3078)

kalamazoo_county <- tigris::counties(
    state = state_fips,
    cb = TRUE,
    year = 2024
) %>%
    filter(NAME == "Kalamazoo") %>%
    st_transform(3078)

kalamazoo_place <- tigris::places(
    state = state_fips,
    cb = TRUE,
    year = 2024
) %>%
    filter(GEOID == kalamazoo_place_geoid) %>%
    st_transform(3078)

tract_map_data <- tracts_mi %>%
    left_join(tract_scores, by = c("GEOID" = "tract_geoid")) %>%
    mutate(
        map_score = if_else(data_driven_shed == "Outside threshold", NA_real_, commuter_score),
        data_driven_shed = tidyr::replace_na(data_driven_shed, "Outside threshold")
    )

analysis_extent <- kalamazoo_place %>%
    st_buffer(dist = units::set_units(45, "mi")) %>%
    st_transform(st_crs(tract_map_data))

tract_map_focus <- tract_map_data %>%
    st_filter(analysis_extent, .predicate = st_intersects)

output_csv <- file.path(output_dir, paste0("kalamazoo_lodes_tract_commuter_shed_", lodes_year, ".csv"))

tract_map_data %>%
    st_drop_geometry() %>%
    select(
        GEOID,
        NAME,
        resident_jobs,
        jobs_to_kalamazoo_city,
        inbound_share_to_kalamazoo,
        workplace_jobs,
        jobs_from_kalamazoo_city,
        outbound_share_from_kalamazoo,
        bidirectional_jobs,
        commuter_score,
        in_kalamazoo_city,
        data_driven_shed
    ) %>%
    arrange(desc(commuter_score), desc(bidirectional_jobs)) %>%
    write.csv(output_csv, row.names = FALSE)

census_blues <- c(
    "#D5E1EF",
    "#A9C3DF",
    "#7DA5CF",
    "#4F84BA",
    "#205493",
    "#0E3B6F",
    "#062644"
)

static_map <- ggplot() +
    geom_sf(
        data = tract_map_focus,
        aes(fill = map_score),
        color = "white",
        linewidth = 0.08
    ) +
    geom_sf(
        data = kalamazoo_county,
        fill = NA,
        color = "grey35",
        linewidth = 0.45
    ) +
    geom_sf(
        data = kalamazoo_place,
        fill = NA,
        color = "darkred",
        linewidth = 0.8
    ) +
    scale_fill_gradientn(
        colors = census_blues,
        name = "Commuter score",
        labels = label_number(accuracy = 0.01),
        na.value = "grey90"
    ) +
    coord_sf(expand = FALSE) +
    labs(
        title = "Kalamazoo City Commuter-Shed by Census Tract",
        subtitle = "LODES home-work flows; Kalamazoo city outlined in red",
        caption = paste0(
            "Source: LEHD LODES ",
            lodes_year,
            ". Commuter score = inbound resident-worker share + outbound workplace-job share."
        )
    ) +
    theme_void() +
    theme(
        plot.title = element_text(hjust = 0.5, face = "bold", margin = margin(b = 5)),
        plot.title.position = "panel",
        plot.subtitle = element_text(hjust = 0.5, margin = margin(b = 4)),
        legend.position = "bottom",
        legend.direction = "horizontal",
        legend.title = element_text(size = 9, face = "bold"),
        legend.text = element_text(size = 8),
        plot.caption = element_text(size = 8, hjust = 0.5),
        plot.margin = margin(t = 5, r = 10, b = 5, l = 10)
    ) +
    guides(
        fill = guide_colorbar(
            title.position = "top",
            barwidth = 14,
            barheight = 0.6
        )
    )

ggsave(
    filename = file.path(output_dir, paste0("kalamazoo_lodes_tract_commuter_shed_", lodes_year, ".png")),
    plot = static_map,
    width = 8,
    height = 7,
    dpi = 300,
    bg = "white"
)

format_number <- function(x, accuracy = 1) {
    ifelse(is.na(x), "Not available", scales::number(x, accuracy = accuracy, big.mark = ","))
}

format_percent <- function(x, accuracy = 0.1) {
    ifelse(is.na(x), "Not available", scales::percent(x, accuracy = accuracy))
}

interactive_data <- tract_map_focus %>%
    st_transform(4326) %>%
    mutate(
        score_label = format_number(commuter_score, 0.01),
        inbound_share_label = format_percent(inbound_share_to_kalamazoo),
        outbound_share_label = format_percent(outbound_share_from_kalamazoo),
        resident_jobs_label = format_number(resident_jobs, 1),
        inbound_jobs_label = format_number(jobs_to_kalamazoo_city, 1),
        workplace_jobs_label = format_number(workplace_jobs, 1),
        outbound_jobs_label = format_number(jobs_from_kalamazoo_city, 1),
        popup_html = paste0(
            "<strong>", NAME, "</strong>",
            "<table>",
            "<tr><td>GEOID</td><td>", GEOID, "</td></tr>",
            "<tr><td>Shed class</td><td>", data_driven_shed, "</td></tr>",
            "<tr><td>Commuter score</td><td>", score_label, "</td></tr>",
            "<tr><td>Resident jobs</td><td>", resident_jobs_label, "</td></tr>",
            "<tr><td>Jobs to Kalamazoo city</td><td>", inbound_jobs_label, "</td></tr>",
            "<tr><td>Inbound share</td><td>", inbound_share_label, "</td></tr>",
            "<tr><td>Workplace jobs</td><td>", workplace_jobs_label, "</td></tr>",
            "<tr><td>Jobs from Kalamazoo city residents</td><td>", outbound_jobs_label, "</td></tr>",
            "<tr><td>Outbound share</td><td>", outbound_share_label, "</td></tr>",
            "</table>"
        ),
        hover_label = paste0(
            NAME,
            "\nCommuter score: ",
            score_label,
            "\nTo Kalamazoo: ",
            inbound_jobs_label,
            " jobs"
        )
    )

score_palette <- leaflet::colorNumeric(
    palette = census_blues,
    domain = interactive_data$map_score,
    na.color = "grey90"
)

interactive_map <- leaflet::leaflet(interactive_data) %>%
    leaflet::addProviderTiles(
        leaflet::providers$CartoDB.Positron,
        group = "Basemap"
    ) %>%
    leaflet::addPolygons(
        layerId = ~GEOID,
        group = "Commuter-shed tracts",
        fillColor = ~score_palette(map_score),
        fillOpacity = 0.75,
        color = "#ffffff",
        weight = 0.4,
        opacity = 0.6,
        popup = ~popup_html,
        label = ~hover_label,
        labelOptions = leaflet::labelOptions(direction = "auto", textsize = "12px"),
        options = leaflet::pathOptions(interactive = TRUE),
        highlightOptions = leaflet::highlightOptions(
            weight = 2,
            color = "#111111",
            fillOpacity = 0.9,
            bringToFront = TRUE
        )
    ) %>%
    leaflet::addPolylines(
        data = st_boundary(st_transform(kalamazoo_county, 4326)),
        group = "Kalamazoo County",
        color = "grey35",
        weight = 2,
        opacity = 1,
        options = leaflet::pathOptions(interactive = FALSE)
    ) %>%
    leaflet::addPolylines(
        data = st_boundary(st_transform(kalamazoo_place, 4326)),
        group = "Kalamazoo city",
        color = "darkred",
        weight = 4,
        opacity = 1,
        options = leaflet::pathOptions(interactive = FALSE)
    ) %>%
    leaflet::addLegend(
        pal = score_palette,
        values = ~map_score,
        title = "Commuter score",
        position = "bottomright"
    ) %>%
    leaflet::addLayersControl(
        overlayGroups = c("Kalamazoo County", "Kalamazoo city"),
        options = leaflet::layersControlOptions(collapsed = FALSE)
    )

htmlwidgets::saveWidget(
    interactive_map,
    file = file.path(output_dir, paste0("kalamazoo_lodes_tract_commuter_shed_", lodes_year, ".html")),
    selfcontained = FALSE
)

message("Wrote: ", output_csv)
