# Install only the packages needed by the webinar examples that are missing
# from the active R library paths.

find_project_root <- function(start = getwd()) {
    current <- normalizePath(start, winslash = "/", mustWork = TRUE)

    repeat {
        if (length(list.files(current, pattern = "\\.Rproj$")) > 0) {
            return(current)
        }

        parent <- dirname(current)
        if (identical(parent, current)) {
            stop("Could not find an .Rproj file above ", start, call. = FALSE)
        }

        current <- parent
    }
}

project_root <- find_project_root()
r_minor <- strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1]
project_lib <- file.path(project_root, "r-library", paste0("R-", R.version$major, ".", r_minor))

if (!dir.exists(project_lib)) {
    dir.create(project_lib, recursive = TRUE, showWarnings = FALSE)
}

.libPaths(unique(c(normalizePath(project_lib, winslash = "/", mustWork = FALSE), .libPaths())))

required_packages <- c(
    "tidycensus",
    "censusapi",
    "tigris",
    "tidyverse",
    "sf",
    "mapview",
    "leaflet",
    "patchwork",
    "scales",
    "rmarkdown",
    "knitr"
)

missing_packages <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) == 0) {
    message("All required packages are already available.")
} else {
    message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
    install.packages(
        missing_packages,
        lib = project_lib,
        repos = "https://cloud.r-project.org",
        dependencies = c("Depends", "Imports", "LinkingTo")
    )
}

package_status <- data.frame(
    package = required_packages,
    available = vapply(required_packages, requireNamespace, logical(1), quietly = TRUE),
    row.names = NULL
)

print(package_status)
