# generate_reference.R
#
# Produces the .rds baselines consumed by the testthat suite. The canonical
# R/ code (moon_deterministic + moon_psa) is the single source of truth — no
# legacy scripts are sourced and no paper figures are baked in.
#
# Run ONCE from the moon/ directory whenever the canonical engine changes:
#
#   setwd("path/to/moon")
#   source("tests/reference/generate_reference.R")
#
# Coverage:
#   * Deterministic per sex (female / male / both): cohort_trace_det.rds +
#     anchors.rds (cum inc cost OW/OB1/OB2/total, YLL OB1+OB2, OW@45 prev).
#   * PSA: female base + SA1 (OB2 elim) + SA2 (OB1+OB2 elim), n_iter=1000,
#     seed=123 — produces le_psa.rds, cum_costs_psa.rds, prevalence_at_ages.rds,
#     sa1_sa2.rds.
#   * PSA: male base only — produces cum_costs_psa.rds for the male PSA anchor
#     in test_moon_psa_anchors.R.
#
# Total runtime: roughly 4-5 minutes (4 PSA runs of 1000 iterations each).

stopifnot("Run from moon/ directory" = file.exists(file.path("R", "engine.R")))

src <- function(f) source(file.path("R", f))
src("utils-engine.R")
src("engine.R")
src("moon-params.R")
src("utils-data.R")
src("params-norway.R")
src("check-params.R")
src("moon-deterministic.R")
src("moon-deterministic-methods.R")
src("moon-deterministic-extractors.R")
src("moon-sample-params.R")
src("moon-psa.R")
src("moon-psa-methods.R")

grDevices::pdf(file = NULL)
on.exit(try(grDevices::dev.off(), silent = TRUE), add = TRUE)


# ==============================================================================
# Helpers — per-sex deterministic reference + scalar anchors.
# ==============================================================================

# Build the 99×6 trace matrix (proportions, columns N_always/N_prev/OW/OB1/OB2/D)
# from a moon_deterministic() result.
.trace_matrix <- function(res, cohort_n) {
  states <- c(
    N_always = "N_always", N_prev = "N_prev",
    OW       = "OW",       OB1    = "OB1",
    OB2      = "OB2",      D      = "dead"
  )
  ages <- sort(unique(res$trace$age))
  vapply(states, function(s) {
    rows <- res$trace[res$trace$state == s, ]
    rows <- rows[order(rows$age), ]
    rows$n / cohort_n
  }, numeric(length(ages)))
}

# Per-capita cumulative undiscounted incremental cost vs NW, by state.
# Mirrors helper-fixtures.R:.calc_inc_cost (engine-direct), expressed off the
# wrapper's tidy data frames so we don't depend on cost_matrix exposure.
.det_inc_cost_per_state <- function(res, cohort_n) {
  m <- merge(res$trace, res$costs, by = c("age", "sex", "state"), all.x = TRUE)
  m$c_per <- ifelse(m$n > 0 & !is.na(m$cost), m$cost / m$n, 0)
  c_NW <- m$c_per[m$state == "N_always"]
  names(c_NW) <- as.character(m$age[m$state == "N_always"])
  m$c_NW <- c_NW[as.character(m$age)]
  vapply(c("OW", "OB1", "OB2"), function(s) {
    rows <- m[m$state == s, ]
    sum(rows$n * (rows$c_per - rows$c_NW)) / cohort_n
  }, numeric(1))
}

# Generate deterministic reference for one sex.
#
# Deterministic anchors are testthat fixtures (small, shipped with the
# package). PSA references live under tests/reference/{sex}/psa/ — these
# are heavy and .Rbuildignored. Keep the two output trees in sync with
# the test files that read them (test_engine_anchors.R,
# test_moon_deterministic.R, test_moon_psa_anchors.R).
.gen_det <- function(sex_long) {
  cat(sprintf("Generating deterministic reference for sex='%s'...\n", sex_long))
  ref_dir <- file.path("tests", "testthat", "fixtures", sex_long, "deterministic")
  dir.create(ref_dir, recursive = TRUE, showWarnings = FALSE)

  p   <- moon_params_norway(sex_long)
  res <- moon_deterministic(p)
  cn  <- unname(p$cohort_n)

  trace_mat <- .trace_matrix(res, cn)
  saveRDS(trace_mat, file.path(ref_dir, "cohort_trace_det.rds"))

  inc_per_state <- .det_inc_cost_per_state(res, cn)

  # YLL: SA2 (eliminate OB1+OB2) — zero OW->OB1, redistribute OB1+OB2 mass into OW.
  ip <- p$init_prev
  ov_sa2 <- list(
    set_zero  = "OW_OB1",
    init_prev = c(NW  = unname(ip["NW"]),
                  OW  = unname(ip["OW"] + ip["OB1"] + ip["OB2"]),
                  OB1 = 0, OB2 = 0)
  )
  res_sa2 <- moon_deterministic(p, tp_overrides = ov_sa2)
  LE_base <- sum(res    $trace$n[res    $trace$state != "dead"]) / cn
  LE_sa2  <- sum(res_sa2$trace$n[res_sa2$trace$state != "dead"]) / cn
  yll_obboth <- LE_sa2 - LE_base

  # OW@45 prevalence among alive
  age45 <- res$trace[res$trace$age == 45, ]
  alive45 <- sum(age45$n[age45$state != "dead"])
  prev_ow_age45 <- unname(age45$n[age45$state == "OW"] / alive45)

  anchors <- list(
    inc_cost_undisc = list(
      OW    = unname(inc_per_state["OW"]),
      OB1   = unname(inc_per_state["OB1"]),
      OB2   = unname(inc_per_state["OB2"]),
      total = unname(sum(inc_per_state))
    ),
    yll_obboth_undisc = yll_obboth,
    prev_ow_age45     = prev_ow_age45
  )
  saveRDS(anchors, file.path(ref_dir, "anchors.rds"))

  list(p = p, res = res, anchors = anchors)
}


# ==============================================================================
# 1. DETERMINISTIC — three sexes
# ==============================================================================

det <- list(
  female = .gen_det("female"),
  male   = .gen_det("male"),
  both   = .gen_det("both")
)
cat("Saved: cohort_trace_det.rds + anchors.rds for female / male / both\n")


# ==============================================================================
# 2. PSA — female base
# ==============================================================================

cat("\nRunning female base PSA (n_iter = 1000, seed = 123)...\n")
spec_F <- moon_params_norway("female", uncertainty = TRUE)
psa_F  <- moon_psa(spec_F, n_iter = 1000, seed = 123,
                    store_traces   = "none",
                    correlate_hr   = TRUE,
                    correlate_cost = TRUE)

# Helper: build mean / sd / p025 / p975 by state from per_iter
.cost_summary <- function(per_iter, suffix) {
  states <- c("OW", "OB1", "OB2", "total")
  do.call(rbind, lapply(states, function(s) {
    metric <- paste0("cum_inc_cost_", s, "_", suffix)
    v <- per_iter$value[per_iter$metric == metric]
    data.frame(
      state = s,
      mean  = mean(v),
      sd    = stats::sd(v),
      p025  = unname(stats::quantile(v, 0.025)),
      p975  = unname(stats::quantile(v, 0.975)),
      row.names = NULL
    )
  }))
}

# 2a. LE — years lived from age 2
le_vec <- psa_F$per_iter$value[psa_F$per_iter$metric == "LE"]
le_psa <- data.frame(
  mean = mean(le_vec),
  p025 = unname(stats::quantile(le_vec, 0.025)),
  p975 = unname(stats::quantile(le_vec, 0.975))
)
saveRDS(le_psa, file.path("tests", "reference", "female", "psa", "le_psa.rds"))
cat("Saved: female/psa/le_psa.rds\n")

# 2b. Cumulative incremental costs
cum_costs_psa_F <- list(
  undiscounted    = .cost_summary(psa_F$per_iter, "undisc"),
  discounted_4pct = .cost_summary(psa_F$per_iter, "disc")
)
saveRDS(cum_costs_psa_F,
        file.path("tests", "reference", "female", "psa", "cum_costs_psa.rds"))
cat("Saved: female/psa/cum_costs_psa.rds\n")

# 2c. Prevalence at age 45, by state
prev_F <- do.call(rbind, lapply(c("OW", "OB1", "OB2"), function(s) {
  metric <- paste0("prev_", s, "_age45")
  v <- psa_F$per_iter$value[psa_F$per_iter$metric == metric]
  data.frame(
    age   = 45,
    state = s,
    mean  = mean(v),
    p025  = unname(stats::quantile(v, 0.025)),
    p975  = unname(stats::quantile(v, 0.975)),
    row.names = NULL
  )
}))
saveRDS(prev_F,
        file.path("tests", "reference", "female", "psa", "prevalence_at_ages.rds"))
cat("Saved: female/psa/prevalence_at_ages.rds\n")


# ==============================================================================
# 3. SA1 + SA2 PSA (female only) — YLL from OB2 / OB1+OB2 elimination
# ==============================================================================

ip_F <- det$female$p$init_prev
ov_obboth <- list(
  set_zero  = "OW_OB1",
  init_prev = c(NW  = unname(ip_F["NW"]),
                OW  = unname(ip_F["OW"] + ip_F["OB1"] + ip_F["OB2"]),
                OB1 = 0, OB2 = 0)
)
ov_ob2 <- list(
  set_zero  = "OB1_OB2",
  init_prev = c(NW  = unname(ip_F["NW"]),
                OW  = unname(ip_F["OW"]),
                OB1 = unname(ip_F["OB1"] + ip_F["OB2"]),
                OB2 = 0)
)

cat("Running female SA1 PSA (eliminate OB2)...\n")
psa_sa1 <- moon_psa(spec_F, n_iter = 1000, seed = 123,
                     store_traces   = "none",
                     correlate_hr   = TRUE,
                     correlate_cost = TRUE,
                     tp_overrides   = ov_ob2)

cat("Running female SA2 PSA (eliminate OB1+OB2)...\n")
psa_sa2 <- moon_psa(spec_F, n_iter = 1000, seed = 123,
                     store_traces   = "none",
                     correlate_hr   = TRUE,
                     correlate_cost = TRUE,
                     tp_overrides   = ov_obboth)

le_base   <- psa_F  $per_iter$value[psa_F  $per_iter$metric == "LE"]
le_sa1    <- psa_sa1$per_iter$value[psa_sa1$per_iter$metric == "LE"]
le_sa2    <- psa_sa2$per_iter$value[psa_sa2$per_iter$metric == "LE"]
yll_ob2    <- le_sa1 - le_base
yll_obboth <- le_sa2 - le_base

sa1_sa2 <- list(
  yll = data.frame(
    attributable_to = c("OB2", "OB1_and_OB2"),
    mean  = c(mean(yll_ob2),                              mean(yll_obboth)),
    p025  = c(unname(stats::quantile(yll_ob2,    0.025)), unname(stats::quantile(yll_obboth, 0.025))),
    p975  = c(unname(stats::quantile(yll_ob2,    0.975)), unname(stats::quantile(yll_obboth, 0.975))),
    row.names = NULL
  )
)
saveRDS(sa1_sa2,
        file.path("tests", "reference", "female", "scenarios", "sa1_sa2.rds"))
cat("Saved: female/scenarios/sa1_sa2.rds\n")


# ==============================================================================
# 4. PSA — male base (only cum_costs_psa for the male PSA anchor)
# ==============================================================================

cat("\nRunning male base PSA (n_iter = 1000, seed = 123)...\n")
spec_M <- moon_params_norway("male", uncertainty = TRUE)
psa_M  <- moon_psa(spec_M, n_iter = 1000, seed = 123,
                    store_traces   = "none",
                    correlate_hr   = TRUE,
                    correlate_cost = TRUE)
cum_costs_psa_M <- list(
  undiscounted    = .cost_summary(psa_M$per_iter, "undisc"),
  discounted_4pct = .cost_summary(psa_M$per_iter, "disc")
)
saveRDS(cum_costs_psa_M,
        file.path("tests", "reference", "male", "psa", "cum_costs_psa.rds"))
cat("Saved: male/psa/cum_costs_psa.rds\n")


# ==============================================================================
# 5. HUMAN-READABLE SUMMARY (CSV for code review / sanity checking)
# ==============================================================================

scalar_row <- function(sex, anchor) {
  data.frame(
    sex      = sex,
    metric   = c("cum_cost_OW", "cum_cost_OB1", "cum_cost_OB2", "cum_cost_total",
                 "yll_obboth", "prev_ow_age45"),
    value    = c(anchor$inc_cost_undisc$OW,
                 anchor$inc_cost_undisc$OB1,
                 anchor$inc_cost_undisc$OB2,
                 anchor$inc_cost_undisc$total,
                 anchor$yll_obboth_undisc,
                 anchor$prev_ow_age45),
    stringsAsFactors = FALSE
  )
}
det_rows <- do.call(rbind, lapply(c("female", "male", "both"), function(s) {
  scalar_row(s, det[[s]]$anchors)
}))

psa_rows <- data.frame(
  sex    = c("female", "female", "female",
             "female", "female", "female"),
  metric = c("psa_le_mean", "psa_le_p025", "psa_le_p975",
             "psa_yll_obboth_mean", "psa_yll_obboth_p025", "psa_yll_obboth_p975"),
  value  = c(le_psa$mean, le_psa$p025, le_psa$p975,
             sa1_sa2$yll$mean[2], sa1_sa2$yll$p025[2], sa1_sa2$yll$p975[2]),
  stringsAsFactors = FALSE
)

write.csv(rbind(det_rows, psa_rows),
          file.path("tests", "reference", "scalars_readable.csv"),
          row.names = FALSE)
cat("Saved: tests/reference/scalars_readable.csv\n")


# ==============================================================================
# 6. METADATA (provenance record)
# ==============================================================================

pkg_version <- function(p) {
  tryCatch(as.character(utils::packageVersion(p)),
           error = function(e) "not installed")
}
meta_list <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
  r_version    = R.version.string,
  source       = "canonical R/ code (moon_deterministic + moon_psa)",
  psa_seed     = 123L,
  n_iter       = 1000L,
  sexes        = c("female", "male", "both"),
  git_hash     = tryCatch(
    system("git rev-parse HEAD", intern = TRUE, ignore.stderr = TRUE),
    error = function(e) "unknown"
  ),
  packages = list(
    flexsurv = pkg_version("flexsurv"),
    MASS     = pkg_version("MASS")
  )
)

if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(meta_list,
                       file.path("tests", "reference", "metadata.json"),
                       pretty = TRUE, auto_unbox = TRUE)
  cat("Saved: metadata.json\n")
} else {
  saveRDS(meta_list, file.path("tests", "reference", "metadata.rds"))
  cat("Saved: metadata.rds  (install jsonlite for .json format)\n")
}

cat("\n=== Reference outputs generated successfully ===\n")
cat("Location:", normalizePath(file.path("tests", "reference")), "\n")
