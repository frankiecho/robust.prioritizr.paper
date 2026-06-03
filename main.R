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

source(here::here("data_prep.R"))
source(here::here("analysis.R"))

# Number of species for the main results
num_species <- 50

# Main results: 50 species
output <- solve_planning_problem(num_species = 50, replicate = 1)

full_prob <- prob_list[[length(prob_list)]]

# Handle a prioritizr solution where there could be NULL due to infeasibility
# full_prob is a problem with all uncertain scenarios, which needs to be specified to
# ensure the historic baseline scenario is evaluated against this problem too
handle_soln <- function(res, full_prob) {
  if (is.null(res$soln)) {
    return(res)
  }

  if (class(res$soln) == "PackedSpatRaster") {
    res$soln <- terra::unwrap(res$soln)
  }

  area_r <- as.numeric(global(
    cellSize(res$soln, unit = "km"),
    'mean',
    na.rm = TRUE
  ))

  res$area_total <- as.numeric(terra::global(res$soln, "sum", na.rm = TRUE)) *
    area_r
  res$area_new_pa <- as.numeric(terra::global(
    res$soln - pa,
    "sum",
    na.rm = TRUE
  )) *
    area_r

  res$area_ext_pa <- as.numeric(terra::global(
    pa,
    "sum",
    na.rm = TRUE
  )) *
    area_r
  res$rep <- prioritizr::eval_feature_representation_summary(
    full_prob,
    res$soln
  )
  res$cost_total <- prioritizr::eval_cost_summary(full_prob, res$soln)
  res$cost_new_pa <- prioritizr::eval_cost_summary(full_prob, res$soln - pa)
  res$cost_ext_pa <- prioritizr::eval_cost_summary(full_prob, pa)
  return(res)
}

# Plots ---------------
# Color scheme of plots
color_scheme <- c(
  "#CC79A7",
  "#009E73",
  "#D55E00",
  "#0072B2",
  "#E69F00",
  "#56B4E9"
)

problem_names <- c(
  "A. Non-robust: Assume historic baseline",
  "B. Fully Robust",
  "C. Partially Robust: Chance Constraints",
  "D. Partially Robust: Conditional Value-at-Risk Constraints"
)

scenario_names <- data.frame(
  scenario = c("historic_baseline", "ssp126", "ssp245", "ssp370", "ssp585"),
  scenario_fullname = c(
    "Historic",
    "SSP1-RCP2.6",
    "SSP2-RCP4.5",
    "SSP3-RCP7.0",
    "SSP5-RCP8.5"
  )
)

# Function to plot a planning solution
plot_planning_soln <- function(soln) {
  if (is.null(soln)) {
    return(ggplot() + labs(title = "No solution (infeasible or solver error)") + theme_void())
  }
  soln <- terra::ifel(soln == 1, 2, soln)
  soln <- terra::ifel(pa == 1, 1, soln)
  levels(soln) <- data.frame(
    id = c(0, 1, 2),
    cover = c("Not Current PA", "Current PA", "New PA")
  )

  plt <- ggplot() +
    geom_spatraster(data = soln, na.rm = TRUE) +
    geom_sf(data = study_area, fill = NA, show.legend = TRUE) +
    scale_fill_manual(
      '',
      values = c("#F0E442", "#009E73", "#D55E00"),
      na.value = "transparent",
      na.translate = FALSE,
      drop = FALSE
    ) +
    theme_void() +
    theme(legend.position = 'bottom')
  return(plt)
}

# 1. Prioritization maps
for (i in seq_along(output)) {
  cat(sprintf("Scenario %d (%s): soln is %s, solve_time = %.2f s\n",
    i, problem_names[i],
    if (is.null(output[[i]]$soln)) "NULL" else "OK",
    as.numeric(output[[i]]$solve_time, units = "secs")
  ))
}
maps <- map(output, \(x) terra::unwrap(x$soln))

p1_map <- map(maps, plot_planning_soln) |>
  imap(\(x, i) x + labs(subtitle = str_wrap(problem_names[i], width = 40))) |>
  wrap_plots() +
  plot_layout(guides = 'collect', nrow = 2) &
  theme(legend.position = 'bottom')

plots_dir <- here::here("plots")
dir.create(plots_dir, showWarnings = FALSE, recursive = TRUE)

ggsave(
  file.path(plots_dir, "p1_map.png"),
  p1_map,
  width = 2000,
  height = 2000,
  units = 'px',
  dpi = 300
)

# 2. Species representation targets across climate scenarios
species_to_plot <- "Neophema_chrysogaster"

output_clean <- map(
  output,
  handle_soln,
  full_prob = full_prob
) |>
  map(function(x) {
    if (is.null(x$rep)) return(x)
    x$rep <- left_join(
      x$rep,
      species_details,
      by = join_by('feature' == 'name')
    )
    return(x)
  })

names(output_clean) <- problem_names

species_rep <- map(output_clean, "rep") |>
  bind_rows(.id = 'problem')

selected_species_rep <- species_rep |>
  filter(species == species_to_plot) |>
  left_join(scenario_names)

species_target <- max(selected_species_rep$target)

cell_size <- global(
  cellSize(output_clean[[1]]$soln, unit = 'km'),
  mean,
  na.rm = TRUE
) |>
  as.numeric()

selected_species_rep_minmax <- selected_species_rep |>
  group_by(problem) |>
  summarise(
    min = min(absolute_held),
    max = max(absolute_held)
  )

p2a_species_rep <- ggplot(
  selected_species_rep,
  aes(
    x = absolute_held * cell_size,
    y = problem
  )
) +
  geom_segment(
    data = selected_species_rep_minmax,
    aes(
      x = min * cell_size,
      xend = max * cell_size,
      y = problem,
      yend = problem
    ),
    linewidth = 3,
    color = 'gray80'
  ) +
  geom_vline(
    xintercept = species_target * cell_size,
    linetype = 2
  ) +
  annotate(
    "rect",
    xmin = -1e10,
    xmax = species_target * cell_size,
    ymin = 0,
    ymax = 5,
    alpha = .1,
    fill = "gray50"
  ) +
  annotate(
    "text",
    label = "Target not met",
    y = 4.75,
    x = species_target * cell_size / 2
  ) +
  annotate(
    "text",
    label = "Target met",
    y = 4.75,
    x = species_target * cell_size * 1.5
  ) +
  geom_jitter(
    size = 3,
    width = 0,
    height = 0.25,
    aes(color = scenario_fullname, shape = as.character(timestep))
  ) +
  theme_bw() +
  scale_y_discrete(
    "",
    limits = rev,
    labels = function(x) {
      stringr::str_wrap(x, width = 20)
    }
  ) +
  scale_color_manual(values = rev(color_scheme)[1:5]) +
  coord_cartesian(xlim = c(0, NA)) +
  labs(
    subtitle = "Protected Area Representation of the Orange-bellied Parrot",
    x = "Representation (sq. km)",
    y = "",
    shape = "Time Step",
    color = "Scenario"
  ) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank()
  )

# P2b. Protected area size
area_ext_pa <- map_dbl(output_clean, "area_ext_pa") |>
  stack() |>
  rename(problem = ind, area = values)

area_new_pa <- map_dbl(output_clean, "area_new_pa") |>
  stack() |>
  rename(problem = ind, area = values)

area_total <- list("Current PA" = area_ext_pa, "New PA" = area_new_pa) |>
  bind_rows(.id = 'Protected Area')

p2b_area_new_pa <- ggplot(
  area_total,
  aes(x = area, y = problem, fill = `Protected Area`)
) +
  geom_bar(
    stat = "identity",
    color = 'black',
    position = position_stack(reverse = TRUE)
  ) +
  theme_bw() +
  scale_y_discrete(
    "",
    limits = rev,
    labels = function(x) {
      stringr::str_wrap(x, width = 20)
    }
  ) +
  coord_cartesian(xlim = c(0, NA)) +
  scale_fill_manual(
    values = c("Current PA" = "#009E73", "New PA" = "#D55E00")
  ) +
  labs(
    subtitle = "Size of the additional\nprotected area",
    x = "Area (sq. km)",
    y = "",
    fill = ""
  ) +
  coord_cartesian(
    xlim = c(0, (max(area_new_pa$area) + max(area_ext_pa$area)) * 1.1),
    ylim = c(0, 5),
    expand = FALSE
  ) +
  theme(
    panel.grid = element_blank()
  )

# P2c. Protected area cost metric (summed)
cost_new_pa <- map(output_clean, "cost_new_pa") |>
  map(\(x) as.numeric(x[1, 2])) |>
  stack() |>
  rename(problem = ind, cost = values)

cost_ext_pa <- map(output_clean, "cost_ext_pa") |>
  map(\(x) as.numeric(x[1, 2])) |>
  stack() |>
  rename(problem = ind, cost = values)

cost_total <- list("Current PA" = cost_ext_pa, "New PA" = cost_new_pa) |>
  bind_rows(.id = 'Protected Area')

p2c_cost <- ggplot(
  cost_total,
  aes(x = cost, y = problem, fill = `Protected Area`)
) +
  geom_bar(
    stat = "identity",
    color = 'black',
    position = position_stack(reverse = TRUE)
  ) +
  theme_bw() +
  scale_y_discrete(
    "",
    limits = rev,
    labels = function(x) {
      stringr::str_wrap(x, width = 20)
    }
  ) +
  labs(
    subtitle = "Cost",
    x = "Cost metric",
    y = "",
    fill = ""
  ) +
  scale_fill_manual(
    values = c("Current PA" = "#009E73", "New PA" = "#D55E00")
  ) +
  scale_x_continuous(
    labels = scales::label_number(scale_cut = scales::cut_short_scale())
  ) +
  coord_cartesian(
    xlim = c(0, (max(cost_ext_pa$cost) + max(cost_new_pa$cost)) * 1.1),
    ylim = c(0, 5),
    expand = FALSE
  ) +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank()
  )

# P2d. Computational solve times (seconds)
solve_times <- map(output_clean, "solve_time") |>
  map(as.numeric) |>
  stack() |>
  rename(problem = ind, solve_time = values)

p2d_solve_time <- ggplot(solve_times, aes(x = solve_time, y = problem)) +
  geom_bar(stat = "identity", fill = 'gray80', color = 'black') +
  theme_bw() +
  scale_y_discrete(
    "",
    limits = rev,
    labels = function(x) {
      stringr::str_wrap(x, width = 20)
    }
  ) +
  labs(
    subtitle = "Solve time (Gurobi solver)",
    x = "Seconds",
    y = "",
    shape = "Time Step",
    color = "Scenario"
  ) +
  coord_cartesian(
    xlim = c(0, max(solve_times$solve_time) * 1.1),
    ylim = c(0, 5),
    expand = FALSE
  ) +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank()
  )


layout_design <- "
AAA
BCD
"
p2_comb <- p2a_species_rep +
  p2b_area_new_pa +
  p2c_cost +
  p2d_solve_time +
  plot_layout(guides = 'collect', design = layout_design) +
  plot_annotation(tag_level = "A")

ggsave(
  file.path(plots_dir, "p2_comb.png"),
  p2_comb,
  width = 3000,
  height = 2000,
  dpi = 300,
  scale = 1,
  units = 'px'
)


# Write a table showing the constraint matrix size
names(prob_list) <- problem_names
matrix_sizes <- map(prob_list, \(x) data.frame(l = dim(compile(x)$A()))) |>
  bind_cols()
colnames(matrix_sizes) <- problem_names
matrix_sizes <- t(matrix_sizes)
colnames(matrix_sizes) <- c("rows", "cols")
