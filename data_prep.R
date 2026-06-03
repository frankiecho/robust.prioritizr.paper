library(here)
library(prioritizr)
library(robust.prioritizr)
library(terra)
library(dplyr)
library(tibble)
library(stringr)
library(ggplot2)
library(tidyr)
library(tidyterra)
library(patchwork)
library(gurobi)
library(purrr)
library(sf)
library(readr)
library(cli)

# Data Preparation ----------------

rp_data_prep <- function(num_species = 50) {
  cli::cli_alert_info(glue::glue("Preparing data for {num_species} species"))

  # Set core list of threatened species that must be included
  # the rest of the list are randomly drawn until we reach "num_species"
  threatened_species <- c(
    "Philoria_frosti",
    "Petrogale_penicillata",
    "Liopholis_guthega",
    "Tympanocryptis_lineata",
    "Lichenostomus_melanops",
    "Gymnobelideus_leadbeateri",
    "Stipiturus_mallee",
    "Burramys_parvus",
    "Pseudophryne_pengilleyi",
    "Neophema_chrysogaster",
    "Pedionomus_torquatus",
    "Anthochaera_phrygia",
    "Pseudomys_fumeus",
    "Miniopterus_schreibersii",
    "Pseudophryne_corroboree",
    "Litoria_spenceri",
    "Mixophyes_balbus",
    "Sarcophilus_harrisii"
  )

  # Download data if not already cached locally
  data_dir <- here::here("data")
  dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

  files_to_download <- c("cost.tif", "pa.tif", "species.tif", "species.csv")
  for (f in files_to_download) {
    dest_path <- file.path(data_dir, f)
    if (!file.exists(dest_path)) {
      cli::cli_alert_info(glue::glue("Downloading {f}..."))
      piggyback::pb_download(
        f,
        dest = data_dir,
        repo = "jeffreyhanson/robust.prioritizr.data",
        tag = "v1.0.0"
      )
    } else {
      cli::cli_alert_success(glue::glue("Using cached {f}"))
    }
  }

  # Import data
  cost <- rast(file.path(data_dir, "cost.tif"))
  pa <- rast(file.path(data_dir, "pa.tif"))
  species <- rast(file.path(data_dir, "species.tif"))
  species_details <- readr::read_csv(file.path(data_dir, "species.csv"))

  study_area <- cost
  values(study_area)[!is.na(values(study_area))] <- 1
  names(study_area) <- "study_area"
  study_area <- as.polygons(study_area, na.rm = TRUE)

  species_details <- species_details |>
    mutate(scenario = str_extract(proj, "ssp[0-9]{3,4}|historic_baseline")) |>
    mutate(timestep = as.numeric(str_extract(proj, "[0-9]{4}")))

  # Data checks
  if (
    !(length(unique(species_details$name)) == length(unique(names(species))))
  ) {
    stop("Number of unique species-scenario-year combinations don't match.")
  }

  if (sum(is.na(match(names(species), species_details$name)) > 0)) {
    stop("Not all species are uniquely identified in the raster layer names.")
  }

  # Find the total area with species presence
  global_sums <- global(species, 'sum', na.rm = TRUE)
  species_details$species_sum <- unname(unlist(global_sums))

  # Relative target - relative to historic baseline
  rt <- 0.3

  conf_level <- 0.75

  ## Set feasible relative targets to ensure that the problem is feasible --------
  species_details <- species_details |>
    group_by(species) |>
    mutate(
      min_achievable_target = min(species_sum),
      historic_abundance = mean(species_sum[scenario == 'historic_baseline']),
      target = min(historic_abundance * rt),
      gap = species_sum - target
    ) |>
    mutate(target = min(target, min_achievable_target)) |>
    filter(min_achievable_target > 0) |>
    mutate(
      scenario_group = paste0(
        if_else(scenario == 'historic_baseline', "h_", ""),
        species
      ),
    )

  # Subset the dataset further to meet the list of species
  species_list_data <- unique(species_details$species)
  final_species_list <- c()

  if (length(species_list_data) > num_species) {
    list_in_threatened_species <- species_list_data[
      species_list_data %in% threatened_species
    ]
    list_not_in_threatened_species <- species_list_data[
      !species_list_data %in% threatened_species
    ]
    final_species_list <- c(
      list_in_threatened_species,
      sample(
        list_not_in_threatened_species,
        num_species - length(threatened_species)
      )
    )
  } else {
    warning(sprintf("total length of species is less than num_species"))
    final_species_list <- species_list_data
  }

  species_details <- species_details |>
    filter(species %in% final_species_list)

  groups <- species_details$scenario_group

  is_historic_baseline <- which(species_details$scenario == 'historic_baseline')

  species_subset <- species[[species_details$id]]

  species_hb <- species_subset[[is_historic_baseline]]

  targets <- species_details |>
    ungroup() |>
    transmute(
      feature = name,
      type = "absolute",
      sense = ">=",
      target = target,
      scenario = scenario
    )

  targets_hb <- targets |>
    filter(scenario == 'historic_baseline') |>
    select(-scenario)

  targets <- targets |>
    select(-scenario)

  list2env(as.list(environment()), envir = .GlobalEnv)
  return()
}
