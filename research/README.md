# Original Research Workspace

This folder is a separate workspace for original ACS analysis using the webinar
repository as a template.

## Current Starting Point

`01_michigan_block_group_commute_time_map.R` builds a Michigan block-group map
of weighted average commute time using ACS table `B08303`, Travel Time to Work.

`02_michigan_tract_commute_time_map.R` reproduces the same analysis at tract
level for a more reliable research map and writes an interactive HTML map.

`01_michigan_commute_time_map.R` remains as a backward-compatible wrapper for
the original block-group script.

Verified Census API choices:

- Dataset: 2024 ACS 5-year estimates, currently the most recent ACS 5-year
  dataset available through `tidycensus`.
- Geography: block group is available for `B08303` and is finer than tract or
  county; tract output is also produced because block-group estimates are often
  noisy.
- Scope: Michigan statewide map, with Kalamazoo County outlined for reference.

The weighted average is calculated from ACS travel-time bins. The final open
ended `90 or more minutes` bin is coded as 95 minutes, matching the demo-style
approach in this repository.

## Uncertainty Notes

ACS does not report the number of survey responses behind each block group or
tract estimate in these tables. It reports estimates and 90 percent margins of
error.

The commute script converts ACS MOEs to standard errors with `SE = MOE / 1.645`
and adds approximate standard-error diagnostics for the derived weighted average
commute time. The derived-average uncertainty is an approximation because it
does not include the full covariance structure among ACS table cells.

## Interactive Output

The tract script writes `michigan_tract_avg_commute_time_2024.html` plus a
matching `michigan_tract_avg_commute_time_2024_files/` dependency folder. The
HTML is not self-contained because self-contained `htmlwidgets` output requires
Pandoc to inline JavaScript and CSS dependencies into a single file.
