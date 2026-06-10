# ACS Mapping Demonstration
# Setup File

# Purpose: 
# - Install required packages 
# - Load workshop libraries 
# - Configure Census API access
# - Test your connection

# 1. Uncomment and run if packages are not installed

#install.packages(c("tidycensus",
#                   "censusapi",
#                   "tigris",
#                   "tidyverse",
#                   "sf",
#                   "mapview",
#                   "leaflet",
#                   "patchwork",
#                   "scales"))

# 2. Load your libraries

# For Census data
library(tidycensus)   # ACS, Decennial 
library(censusapi)    # All other Census datasets
# For Census shapefiles
library(tigris)
# For working with the data and visualization, tidyverse packages
library(dplyr)
library(tidyr)
library(ggplot2)
# Spatial data support
library(sf)
# For interactive maps
library(mapview)
library(leaflet)
# For map/visual formatting and composition
library(patchwork)
# For number formatting helpers
library(scales)

# 3. Census API Key setup (run one time only)

# If you do not already have a Census API key
# Request one here:
# https://api.census.gov/data/key_signup.html

# Replace "YOUR_KEY_HERE" with your personal API key
# and run this line ONE TIME ONLY.

#tidycensus::census_api_key("INSERT YOUR KEY HERE", install = TRUE, overwrite = TRUE)

# After successfully running it once:
# 1. Comment the line back out
# 2. Restart your R session if needed
# 3. Remove your key from the code before sharing.
# 4. Your key is now stored in the .Renviron file for future sessions

# Example:
#tidycensus::census_api_key("abc123examplekey", install = TRUE, overwrite = TRUE)


# 4. Test your API connection

# Run this section to confirm your API key works 

acs_test <- get_acs(geography = "state", 
                    variables = "B19013_001", 
                    year = 2024,
                    show_call = TRUE) 

head(acs_test) 

# If data appears, setup is complete!