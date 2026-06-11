local({
    project_root <- getwd()
    r_minor <- strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1]
    project_lib <- file.path(project_root, "r-library", paste0("R-", R.version$major, ".", r_minor))

    if (!dir.exists(project_lib)) {
        dir.create(project_lib, recursive = TRUE, showWarnings = FALSE)
    }

    .libPaths(unique(c(normalizePath(project_lib, winslash = "/", mustWork = FALSE), .libPaths())))

    options(
        scipen = 999,
        tigris_class = "sf",
        tigris_use_cache = TRUE,
        tigris_cache_dir = file.path(project_root, "tigris-cache")
    )
})
