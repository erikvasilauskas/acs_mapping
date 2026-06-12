# Shared helpers for ACS B08303 commute-time analysis.

commute_midpoints <- c(
    "B08303_002E" = 2.5,   # Less than 5 minutes
    "B08303_003E" = 7,     # 5 to 9 minutes
    "B08303_004E" = 12,    # 10 to 14 minutes
    "B08303_005E" = 17,    # 15 to 19 minutes
    "B08303_006E" = 22,    # 20 to 24 minutes
    "B08303_007E" = 27,    # 25 to 29 minutes
    "B08303_008E" = 32,    # 30 to 34 minutes
    "B08303_009E" = 37,    # 35 to 39 minutes
    "B08303_010E" = 42,    # 40 to 44 minutes
    "B08303_011E" = 52.5,  # 45 to 59 minutes
    "B08303_012E" = 75,    # 60 to 89 minutes
    "B08303_013E" = 95     # 90 or more minutes
)

census_blues <- c(
    "#D5E1EF",
    "#A9C3DF",
    "#7DA5CF",
    "#4F84BA",
    "#205493",
    "#0E3B6F",
    "#062644"
)

add_commute_time_metrics <- function(acs_data) {
    commute_estimate_cols <- names(commute_midpoints)
    commute_moe_cols <- sub("E$", "M", commute_estimate_cols)

    acs_data %>%
        mutate(
            total_workers = B08303_001E,
            total_workers_moe_90 = B08303_001M,
            weighted_commute_numerator =
                rowSums(as.matrix(pick(all_of(commute_estimate_cols))) *
                            matrix(commute_midpoints,
                                   nrow = n(),
                                   ncol = length(commute_midpoints),
                                   byrow = TRUE),
                        na.rm = TRUE),
            weighted_commute_numerator_moe_90 =
                sqrt(rowSums((as.matrix(pick(all_of(commute_moe_cols))) *
                                  matrix(commute_midpoints,
                                         nrow = n(),
                                         ncol = length(commute_midpoints),
                                         byrow = TRUE))^2,
                             na.rm = TRUE)),
            avg_commute_minutes = if_else(
                total_workers > 0,
                weighted_commute_numerator / total_workers,
                NA_real_
            ),
            total_workers_se = total_workers_moe_90 / 1.645,
            weighted_commute_numerator_se = weighted_commute_numerator_moe_90 / 1.645,
            avg_commute_se = if_else(
                total_workers > 0,
                sqrt(weighted_commute_numerator_se^2 +
                         avg_commute_minutes^2 * total_workers_se^2) / total_workers,
                NA_real_
            ),
            avg_commute_moe_90 = avg_commute_se * 1.645,
            avg_commute_rse = avg_commute_se / avg_commute_minutes,
            reliability = case_when(
                is.na(avg_commute_rse) ~ NA_character_,
                avg_commute_rse < 0.12 ~ "High reliability",
                avg_commute_rse < 0.30 ~ "Moderate reliability",
                TRUE ~ "Low reliability"
            )
        )
}

make_michigan_commute_map <- function(commute_sf,
                                      michigan_counties,
                                      kalamazoo_county,
                                      geography_label,
                                      acs_year) {
    ggplot() +
        geom_sf(
            data = commute_sf,
            aes(fill = avg_commute_minutes),
            color = NA
        ) +
        geom_sf(
            data = michigan_counties,
            fill = NA,
            color = "white",
            linewidth = 0.08,
            alpha = 0.8
        ) +
        geom_sf(
            data = kalamazoo_county,
            fill = NA,
            color = "darkred",
            linewidth = 0.7
        ) +
        scale_fill_gradientn(
            colors = census_blues,
            name = "Average minutes",
            labels = label_number(accuracy = 1),
            na.value = "grey90"
        ) +
        labs(
            title = paste("Weighted Average Commute Time by Michigan Census", geography_label),
            subtitle = "Kalamazoo County outlined in red",
            caption = paste0(
                "Source: American Community Survey 5-year Estimates ",
                acs_year,
                ", table B08303. 90+ minute bin coded as 95 minutes."
            )
        ) +
        coord_sf(expand = FALSE) +
        theme_void() +
        theme(
            plot.title = element_text(hjust = 0.5, face = "bold", margin = margin(b = 5)),
            plot.title.position = "panel",
            plot.subtitle = element_text(hjust = 0.5, margin = margin(b = 4)),
            legend.position = "bottom",
            legend.direction = "horizontal",
            legend.title = element_text(size = 9, face = "bold"),
            legend.text = element_text(size = 8),
            plot.margin = margin(t = 5, r = 5, b = 5, l = 5)
        ) +
        guides(
            fill = guide_colorbar(
                title.position = "top",
                barwidth = 14,
                barheight = 0.6
            )
        )
}

make_michigan_commute_interactive_map <- function(commute_sf,
                                                  michigan_counties,
                                                  kalamazoo_county,
                                                  geography_label) {
    format_number <- function(x, accuracy = 1) {
        ifelse(
            is.na(x),
            "Not available",
            scales::number(x, accuracy = accuracy, big.mark = ",")
        )
    }

    commute_popup <- commute_sf %>%
        st_transform(4326) %>%
        mutate(
            avg_commute_minutes_label = format_number(avg_commute_minutes, 0.1),
            avg_commute_moe_90_label = format_number(avg_commute_moe_90, 0.1),
            avg_commute_rse_label = ifelse(
                is.na(avg_commute_rse),
                "Not available",
                scales::percent(avg_commute_rse, accuracy = 0.1)
            ),
            total_workers_label = format_number(total_workers, 1),
            total_workers_moe_90_label = format_number(total_workers_moe_90, 1),
            reliability_label = ifelse(is.na(reliability), "Not available", reliability),
            hover_label = paste0(
                NAME,
                "\nAverage commute: ",
                avg_commute_minutes_label,
                " minutes"
            ),
            popup_html = paste0(
                "<strong>", NAME, "</strong>",
                "<table>",
                "<tr><td>GEOID</td><td>", GEOID, "</td></tr>",
                "<tr><td>Average commute</td><td>", avg_commute_minutes_label, " minutes</td></tr>",
                "<tr><td>Average commute MOE 90%</td><td>", avg_commute_moe_90_label, " minutes</td></tr>",
                "<tr><td>Relative standard error</td><td>", avg_commute_rse_label, "</td></tr>",
                "<tr><td>Reliability</td><td>", reliability_label, "</td></tr>",
                "<tr><td>Total workers</td><td>", total_workers_label, "</td></tr>",
                "<tr><td>Total workers MOE 90%</td><td>", total_workers_moe_90_label, "</td></tr>",
                "</table>"
            )
        ) %>%
        select(
            GEOID,
            NAME,
            avg_commute_minutes,
            hover_label,
            popup_html
        )

    county_lines <- michigan_counties %>%
        st_transform(4326) %>%
        st_boundary()

    kalamazoo_line <- kalamazoo_county %>%
        st_transform(4326) %>%
        st_boundary()

    commute_palette <- leaflet::colorNumeric(
        palette = census_blues,
        domain = commute_popup$avg_commute_minutes,
        na.color = "grey90"
    )

    leaflet::leaflet(commute_popup) %>%
        leaflet::addProviderTiles(
            leaflet::providers$CartoDB.Positron,
            group = "Basemap"
        ) %>%
        leaflet::addPolygons(
            layerId = ~GEOID,
            group = paste("Average commute minutes by", tolower(geography_label)),
            fillColor = ~commute_palette(avg_commute_minutes),
            fillOpacity = 0.75,
            color = "#ffffff",
            weight = 0.2,
            opacity = 0.45,
            popup = ~popup_html,
            popupOptions = leaflet::popupOptions(
                maxWidth = 360,
                closeButton = TRUE
            ),
            label = ~hover_label,
            labelOptions = leaflet::labelOptions(
                direction = "auto",
                textsize = "12px"
            ),
            options = leaflet::pathOptions(interactive = TRUE),
            highlightOptions = leaflet::highlightOptions(
                weight = 2,
                color = "#111111",
                fillOpacity = 0.9,
                bringToFront = TRUE
            )
        ) %>%
        leaflet::addPolylines(
            data = county_lines,
            group = "County boundaries",
            color = "#ffffff",
            weight = 1,
            opacity = 0.8,
            options = leaflet::pathOptions(interactive = FALSE)
        ) %>%
        leaflet::addPolylines(
            data = kalamazoo_line,
            group = "Kalamazoo County",
            color = "darkred",
            weight = 4,
            opacity = 1,
            options = leaflet::pathOptions(interactive = FALSE)
        ) %>%
        leaflet::addLegend(
            pal = commute_palette,
            values = ~avg_commute_minutes,
            title = "Average minutes",
            position = "bottomright"
        ) %>%
        leaflet::addLayersControl(
            overlayGroups = c("County boundaries", "Kalamazoo County"),
            options = leaflet::layersControlOptions(collapsed = FALSE)
        )
}

save_interactive_commute_map <- function(interactive_map, html_file) {
    htmlwidgets::saveWidget(
        interactive_map,
        file = html_file,
        selfcontained = FALSE
    )
}

write_commute_outputs <- function(commute_sf,
                                  output_prefix,
                                  reliability_count_name) {
    commute_sf %>%
        st_drop_geometry() %>%
        select(
            GEOID,
            NAME,
            total_workers,
            total_workers_moe_90,
            avg_commute_minutes,
            avg_commute_se,
            avg_commute_moe_90,
            avg_commute_rse,
            reliability
        ) %>%
        arrange(desc(avg_commute_minutes)) %>%
        write.csv(
            file = paste0(output_prefix, ".csv"),
            row.names = FALSE
        )

    commute_sf %>%
        st_drop_geometry() %>%
        count(reliability, name = reliability_count_name) %>%
        mutate(share = .data[[reliability_count_name]] / sum(.data[[reliability_count_name]])) %>%
        write.csv(
            file = sub("_avg_commute_time_", "_commute_reliability_", paste0(output_prefix, ".csv")),
            row.names = FALSE
        )
}
