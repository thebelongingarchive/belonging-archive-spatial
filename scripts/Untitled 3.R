required_packages <- c("data.table", "dplyr", "fixest", "quantreg")
missing_packages <- required_packages[!required_packages %in% rownames(installed.packages())]

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}
library(data.table)
library(dplyr)
library(fixest)
library(quantreg)
choose_csv <- function(label) {
  message("\nChoose: ", label)
  path <- file.choose()
  message("Loaded from: ", path)
  data.table::fread(path)
}

choose_optional_csv <- function(label) {
  message("\nOPTIONAL: ", label)
  message("Cancel the file chooser to skip this section.")
  path <- tryCatch(file.choose(), error = function(e) NA_character_)
  if (is.na(path) || !nzchar(path)) return(NULL)
  message("Loaded from: ", path)
  data.table::fread(path)
}

normalize_zip <- function(x) {
  x <- gsub("[^0-9]", "", as.character(x))
  sprintf("%05d", as.integer(x))
}

require_columns <- function(data, columns, object_name) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0) {
    stop(
      object_name, " is missing required columns: ",
      paste(missing, collapse = ", ")
    )
  }
}

safe_lm <- function(formula, data, label) {
  message("\nRunning: ", label)
  fit <- tryCatch(
    lm(formula, data = data),
    error = function(e) {
      warning(label, " failed: ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(fit)) print(summary(fit))
  fit
}

safe_feols <- function(formula, data, label, vcov_formula = NULL) {
  message("\nRunning: ", label)
  fit <- tryCatch(
    {
      if (is.null(vcov_formula)) {
        fixest::feols(formula, data = data)
      } else {
        fixest::feols(formula, data = data, vcov = vcov_formula)
      }
    },
    error = function(e) {
      warning(label, " failed: ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(fit)) print(summary(fit))
  fit
}

safe_rq <- function(formula, tau, data, label) {
  message("\nRunning: ", label)
  fit <- tryCatch(
    quantreg::rq(formula, tau = tau, data = data),
    error = function(e) {
      warning(label, " failed: ", conditionMessage(e))
      NULL
    }
  )
  if (!is.null(fit)) print(summary(fit, se = "nid"))
  fit
}

haversine_km <- function(lat1, lon1, lat2, lon2) {
  radius_km <- 6371.0088
  to_rad <- pi / 180
  phi1 <- lat1 * to_rad
  phi2 <- lat2 * to_rad
  delta_phi <- (lat2 - lat1) * to_rad
  delta_lambda <- (lon2 - lon1) * to_rad

  a <- sin(delta_phi / 2)^2 +
    cos(phi1) * cos(phi2) * sin(delta_lambda / 2)^2

  2 * radius_km * atan2(sqrt(a), sqrt(1 - a))
}

tract_df <- choose_csv(
  "brooklyn_harlem_urban_econ_tract_clean.csv"
)

brooklyn_digital <- choose_csv(
  "brooklyn_meta_digital_independent.csv"
)

brooklyn_social <- choose_csv(
  "brooklyn_social_capital_clean.csv"
)

combined_dyads_raw <- choose_csv(
  "combined_brooklyn_harlem_merged_modeling_data.csv"
)

harlem_digital <- choose_csv(
  "harlem_meta_digital_independent.csv"
)

master_network_raw <- choose_csv(
  "master_digital_networks_with_urban_econ.csv"
)

harlem_social <- choose_csv(
  "harlem_social_capital_clean.csv"
)
require_columns(
  tract_df,
  c(
    "tract", "study_region", "mean_commute_time",
    "short_commute_share", "job_density_2013",
    "jobs_within_5mi", "highpay_jobs_5mi",
    "pop_density_2010", "rent_2bed_2015", "med_income_2016"
  ),
  "tract_df"
)

require_columns(
  brooklyn_digital,
  c("user_region", "friend_region", "scaled_sci"),
  "brooklyn_digital"
)

require_columns(
  harlem_digital,
  c("user_region", "friend_region", "scaled_sci"),
  "harlem_digital"
)

require_columns(
  brooklyn_social,
  c("zip", "pop2018", "ec_zip", "nbhd_bias_zip"),
  "brooklyn_social"
)

require_columns(
  harlem_social,
  c("zip", "pop2018", "ec_zip", "nbhd_bias_zip"),
  "harlem_social"
)

require_columns(
  combined_dyads_raw,
  c("user_region", "friend_region", "scaled_sci"),
  "combined_dyads_raw"
)

require_columns(
  master_network_raw,
  c(
    "user_region", "friend_region", "scaled_sci", "origin_region",
    "avg_commute_time", "short_commute_pct", "avg_job_density",
    "jobs_within_5mi", "highpay_jobs_5mi", "rent_2bed_2015",
    "med_income_2016"
  ),
  "master_network_raw"
)

tract_df <- tract_df %>%
  mutate(
    tract = as.character(tract),
    study_region = factor(study_region)
  )

brooklyn_digital <- brooklyn_digital %>%
  mutate(
    user_region = normalize_zip(user_region),
    friend_region = normalize_zip(friend_region),
    scaled_sci = as.numeric(scaled_sci),
    origin_area = "Brooklyn"
  )

harlem_digital <- harlem_digital %>%
  mutate(
    user_region = normalize_zip(user_region),
    friend_region = normalize_zip(friend_region),
    scaled_sci = as.numeric(scaled_sci),
    origin_area = "Harlem"
  )

brooklyn_social <- brooklyn_social %>%
  mutate(
    zip = normalize_zip(zip),
    area = "Brooklyn"
  )

harlem_social <- harlem_social %>%
  mutate(
    zip = normalize_zip(zip),
    area = "Harlem"
  )

social_all <- bind_rows(brooklyn_social, harlem_social) %>%
  distinct(zip, .keep_all = TRUE)

harlem_zips <- harlem_social$zip
brooklyn_zips <- brooklyn_social$zip
study_zips <- social_all$zip

combined_dyads_raw <- combined_dyads_raw %>%
  mutate(
    user_region = normalize_zip(user_region),
    friend_region = normalize_zip(friend_region),
    scaled_sci = as.numeric(scaled_sci)
  )

master_network_raw <- master_network_raw %>%
  mutate(
    user_region = normalize_zip(user_region),
    friend_region = normalize_zip(friend_region),
    scaled_sci = as.numeric(scaled_sci),
    origin_region = factor(origin_region)
  )
message("\n===== TRACT DESCRIPTIVE STATISTICS =====")
print(
  tract_df %>%
    group_by(study_region) %>%
    summarise(
      n_tracts = n(),
      mean_income = mean(med_income_2016, na.rm = TRUE),
      median_income = median(med_income_2016, na.rm = TRUE),
      mean_commute = mean(mean_commute_time, na.rm = TRUE),
      mean_job_density = mean(job_density_2013, na.rm = TRUE),
      mean_highpay_jobs_5mi = mean(highpay_jobs_5mi, na.rm = TRUE),
      mean_rent = mean(rent_2bed_2015, na.rm = TRUE),
      .groups = "drop"
    )
)

message("\n===== ZIP-LEVEL SOCIAL CAPITAL SUMMARY =====")
print(
  social_all %>%
    group_by(area) %>%
    summarise(
      n_zips = n(),
      mean_ec = mean(ec_zip, na.rm = TRUE),
      median_ec = median(ec_zip, na.rm = TRUE),
      mean_neighborhood_bias = mean(nbhd_bias_zip, na.rm = TRUE),
      median_neighborhood_bias = median(nbhd_bias_zip, na.rm = TRUE),
      mean_population = mean(pop2018, na.rm = TRUE),
      .groups = "drop"
    )
)

message("\n===== SOCIAL CAPITAL CORRELATIONS BY AREA =====")
for (area_name in unique(social_all$area)) {
  message("\nArea: ", area_name)
  area_data <- social_all %>%
    filter(area == area_name) %>%
    select(ec_zip, nbhd_bias_zip, pop2018)
  print(cor(area_data, use = "pairwise.complete.obs"))
}
tract_model_income <- safe_lm(
  log1p(med_income_2016) ~
    mean_commute_time +
    log1p(job_density_2013) +
    log1p(highpay_jobs_5mi) +
    log1p(rent_2bed_2015) +
    study_region,
  tract_df,
  "Tract model 1: median income"
)

tract_model_commute <- safe_lm(
  mean_commute_time ~
    log1p(job_density_2013) +
    log1p(jobs_within_5mi) +
    log1p(pop_density_2010) +
    study_region,
  tract_df,
  "Tract model 2: commute burden"
)

tract_model_job_access <- safe_lm(
  log1p(highpay_jobs_5mi) ~
    mean_commute_time +
    log1p(pop_density_2010) +
    log1p(med_income_2016) +
    study_region,
  tract_df,
  "Tract model 3: access to high-paying jobs"
)

tract_q25 <- safe_rq(
  med_income_2016 ~
    mean_commute_time +
    log1p(job_density_2013) +
    log1p(highpay_jobs_5mi) +
    study_region,
  0.25,
  tract_df,
  "Quantile regression: 25th income percentile"
)

tract_q50 <- safe_rq(
  med_income_2016 ~
    mean_commute_time +
    log1p(job_density_2013) +
    log1p(highpay_jobs_5mi) +
    study_region,
  0.50,
  tract_df,
  "Quantile regression: median income"
)

tract_q75 <- safe_rq(
  med_income_2016 ~
    mean_commute_time +
    log1p(job_density_2013) +
    log1p(highpay_jobs_5mi) +
    study_region,
  0.75,
  tract_df,
  "Quantile regression: 75th income percentile"
)
origin_social <- social_all %>%
  transmute(
    user_region = zip,
    origin_area = area,
    origin_ec = ec_zip,
    origin_bias = nbhd_bias_zip,
    origin_population = pop2018,
    origin_clustering = clustering_zip,
    origin_support_ratio = support_ratio_zip,
    origin_volunteering = volunteering_rate_zip,
    origin_civic_orgs = civic_organizations_zip
  )

destination_social <- social_all %>%
  transmute(
    friend_region = zip,
    destination_area = area,
    destination_ec = ec_zip,
    destination_bias = nbhd_bias_zip,
    destination_population = pop2018,
    destination_clustering = clustering_zip,
    destination_support_ratio = support_ratio_zip,
    destination_volunteering = volunteering_rate_zip,
    destination_civic_orgs = civic_organizations_zip
  )

combined_dyads <- combined_dyads_raw %>%
  select(user_region, friend_region, scaled_sci) %>%
  left_join(origin_social, by = "user_region") %>%
  left_join(destination_social, by = "friend_region") %>%
  mutate(
    log_sci = log1p(scaled_sci),
    origin_area = factor(origin_area, levels = c("Brooklyn", "Harlem")),
    destination_area = factor(destination_area, levels = c("Brooklyn", "Harlem")),
    tie_type = case_when(
      origin_area == "Brooklyn" & destination_area == "Brooklyn" ~ "Brooklyn-Brooklyn",
      origin_area == "Brooklyn" & destination_area == "Harlem" ~ "Brooklyn-Harlem",
      origin_area == "Harlem" & destination_area == "Brooklyn" ~ "Harlem-Brooklyn",
      origin_area == "Harlem" & destination_area == "Harlem" ~ "Harlem-Harlem",
      TRUE ~ NA_character_
    ),
    tie_type = factor(tie_type)
  ) %>%
  filter(!is.na(log_sci), !is.na(origin_area), !is.na(destination_area))

message("\n===== DYADIC DATA CHECK =====")
print(combined_dyads %>% count(origin_area, destination_area))

message("\n===== RAW DYADIC CORRELATIONS =====")
print(
  combined_dyads %>%
    select(
      log_sci,
      origin_ec,
      destination_ec,
      origin_bias,
      destination_bias,
      origin_population,
      destination_population
    ) %>%
    cor(use = "pairwise.complete.obs")
)
network_model_1 <- safe_feols(
  log_sci ~ origin_area,
  combined_dyads,
  "Network model 1: origin-area comparison",
  ~ user_region + friend_region
)

# Model 2: destination social-capital conditions
network_model_2 <- safe_feols(
  log_sci ~
    destination_ec +
    destination_bias +
    log1p(destination_population) +
    origin_area,
  combined_dyads,
  "Network model 2: destination social capital",
  ~ user_region + friend_region
)
network_model_3 <- safe_feols(
  log_sci ~
    origin_ec +
    destination_ec +
    origin_bias +
    destination_bias +
    log1p(origin_population) +
    log1p(destination_population),
  combined_dyads,
  "Network model 3: origin and destination social capital",
  ~ user_region + friend_region
)

network_model_4 <- safe_feols(
  log_sci ~
    origin_area * destination_ec +
    origin_area * destination_bias +
    log1p(origin_population) +
    log1p(destination_population),
  combined_dyads,
  "Network model 4: Harlem/Brooklyn interactions",
  ~ user_region + friend_region
)

network_model_5 <- safe_feols(
  log_sci ~ tie_type,
  combined_dyads,
  "Network model 5: tie-type comparison",
  ~ user_region + friend_region
)
network_model_6 <- safe_feols(
  log_sci ~
    origin_ec + destination_ec +
    origin_bias + destination_bias +
    origin_clustering + destination_clustering +
    origin_support_ratio + destination_support_ratio +
    origin_volunteering + destination_volunteering +
    log1p(origin_civic_orgs) + log1p(destination_civic_orgs) +
    log1p(origin_population) + log1p(destination_population),
  combined_dyads,
  "Network model 6: expanded social-capital model",
  ~ user_region + friend_region
)
full_digital <- bind_rows(brooklyn_digital, harlem_digital) %>%
  mutate(
    log_sci = log1p(scaled_sci),
    origin_area = factor(origin_area, levels = c("Brooklyn", "Harlem")),
    destination_area = case_when(
      friend_region %in% brooklyn_zips ~ "Brooklyn",
      friend_region %in% harlem_zips ~ "Harlem",
      TRUE ~ "External"
    ),
    destination_area = factor(
      destination_area,
      levels = c("External", "Brooklyn", "Harlem")
    )
  ) %>%
  left_join(origin_social, by = c("user_region" = "user_region"), suffix = c("", "_social"))
if ("origin_area_social" %in% names(full_digital)) {
  full_digital <- full_digital %>%
    mutate(origin_area = coalesce(as.character(origin_area), origin_area_social)) %>%
    select(-origin_area_social) %>%
    mutate(origin_area = factor(origin_area, levels = c("Brooklyn", "Harlem")))
}

full_network_model_1 <- safe_feols(
  log_sci ~ origin_area + destination_area,
  full_digital,
  "Full network model 1: origin and broad destination area",
  ~ user_region + friend_region
)

full_network_model_2 <- safe_feols(
  log_sci ~
    origin_area * destination_area +
    origin_ec +
    origin_bias +
    log1p(origin_population),
  full_digital,
  "Full network model 2: area interactions plus origin conditions",
  ~ user_region + friend_region
)

master_network <- master_network_raw %>%
  mutate(
    log_sci = log1p(scaled_sci),
    origin_region = factor(origin_region)
  ) %>%
  left_join(origin_social, by = "user_region")

master_model_1 <- safe_feols(
  log_sci ~
    origin_region +
    avg_commute_time +
    short_commute_pct +
    log1p(avg_job_density) +
    log1p(jobs_within_5mi) +
    log1p(highpay_jobs_5mi) +
    log1p(rent_2bed_2015) +
    log1p(med_income_2016),
  master_network,
  "Master model 1: urban economic origin conditions",
  ~ user_region + friend_region
)

master_model_2 <- safe_feols(
  log_sci ~
    origin_region * origin_ec +
    origin_region * origin_bias +
    avg_commute_time +
    log1p(avg_job_density) +
    log1p(highpay_jobs_5mi) +
    log1p(rent_2bed_2015) +
    log1p(med_income_2016),
  master_network,
  "Master model 2: social capital and urban-economic interactions",
  ~ user_region + friend_region
)
centroids <- choose_optional_csv(
  "a ZIP centroid CSV for the gravity model"
)

if (!is.null(centroids)) {
  if ("zipcode" %in% names(centroids) && !"zip" %in% names(centroids)) {
    setnames(centroids, "zipcode", "zip")
  }
  if ("lat" %in% names(centroids) && !"latitude" %in% names(centroids)) {
    setnames(centroids, "lat", "latitude")
  }
  if ("lon" %in% names(centroids) && !"longitude" %in% names(centroids)) {
    setnames(centroids, "lon", "longitude")
  }
  if ("lng" %in% names(centroids) && !"longitude" %in% names(centroids)) {
    setnames(centroids, "lng", "longitude")
  }

  require_columns(
    centroids,
    c("zip", "latitude", "longitude"),
    "centroids"
  )

  centroids <- centroids %>%
    transmute(
      zip = normalize_zip(zip),
      latitude = as.numeric(latitude),
      longitude = as.numeric(longitude)
    ) %>%
    distinct(zip, .keep_all = TRUE)

  origin_centroids <- centroids %>%
    rename(
      user_region = zip,
      origin_latitude = latitude,
      origin_longitude = longitude
    )

  destination_centroids <- centroids %>%
    rename(
      friend_region = zip,
      destination_latitude = latitude,
      destination_longitude = longitude
    )

  gravity_data <- combined_dyads %>%
    left_join(origin_centroids, by = "user_region") %>%
    left_join(destination_centroids, by = "friend_region") %>%
    mutate(
      distance_km = haversine_km(
        origin_latitude,
        origin_longitude,
        destination_latitude,
        destination_longitude
      )
    ) %>%
    filter(is.finite(distance_km))

  gravity_model <- safe_feols(
    log_sci ~
      log1p(distance_km) +
      log1p(origin_population) +
      log1p(destination_population) +
      origin_ec +
      destination_ec +
      origin_bias +
      destination_bias,
    gravity_data,
    "Gravity model: distance-adjusted digital connectedness",
    ~ user_region + friend_region
  )
} else {
  message("\nGravity model skipped because no centroid file was selected.")
  gravity_model <- NULL
}
message("\n===== SELECTED NETWORK MODEL TABLE =====")
network_models_to_show <- Filter(
  Negate(is.null),
  list(
    "Origin area" = network_model_1,
    "Destination capital" = network_model_2,
    "Origin + destination" = network_model_3,
    "Area interactions" = network_model_4,
    "Tie type" = network_model_5
  )
)

if (length(network_models_to_show) > 0) {
  print(fixest::etable(network_models_to_show))
}

message("\nTract-model summaries were printed when each lm model ran.")
output_folder <- file.path(getwd(), "harlem_brooklyn_model_outputs")
dir.create(output_folder, showWarnings = FALSE, recursive = TRUE)

saveRDS(
  list(
    tract_model_income = tract_model_income,
    tract_model_commute = tract_model_commute,
    tract_model_job_access = tract_model_job_access,
    tract_q25 = tract_q25,
    tract_q50 = tract_q50,
    tract_q75 = tract_q75,
    network_model_1 = network_model_1,
    network_model_2 = network_model_2,
    network_model_3 = network_model_3,
    network_model_4 = network_model_4,
    network_model_5 = network_model_5,
    network_model_6 = network_model_6,
    full_network_model_1 = full_network_model_1,
    full_network_model_2 = full_network_model_2,
    master_model_1 = master_model_1,
    master_model_2 = master_model_2,
    gravity_model = gravity_model
  ),
  file.path(output_folder, "all_models.rds")
)

fwrite(
  as.data.table(combined_dyads),
  file.path(output_folder, "clean_combined_dyads.csv")
)

fwrite(
  as.data.table(
    social_all %>%
      select(zip, area, pop2018, ec_zip, nbhd_bias_zip)
  ),
  file.path(output_folder, "social_capital_core_variables.csv")
)

capture.output(
  sessionInfo(),
  file = file.path(output_folder, "session_info.txt")
)

message("\nAnalysis complete.")
message("Outputs saved to: ", normalizePath(output_folder))
