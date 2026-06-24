# test_moon_psa_anchors.R
#
# Slow PSA tests. All 1000-iteration runs; skipped by default — enable with:
#
#   Sys.setenv(MOON_RUN_SLOW_TESTS = "1")
#   testthat::test_dir("tests/testthat")
#
# Every numeric assertion anchors on tests/reference/{sex}/psa/*.rds (or
# scenarios/sa1_sa2.rds), regenerated from the same canonical PSA call below
# — so the comparison is bit-level (1e-10) and a deviation flags an
# unintended sampler/engine change.
#
# Helpers (.find_moon_root) come from helper-fixtures.R.

skip_if(
  Sys.getenv("MOON_RUN_SLOW_TESTS") != "1",
  "Skipping slow PSA anchor tests. Set MOON_RUN_SLOW_TESTS=1 to enable."
)

.test_data_dir   <- file.path(.find_moon_root(), "inst", "extdata")
.psa_ref_female  <- file.path(.find_moon_root(), "tests", "reference",
                               "female", "psa")
.scen_ref_female <- file.path(.find_moon_root(), "tests", "reference",
                               "female", "scenarios")


# ==============================================================================
# Run the female PSA once and reuse across tests in this file. Same
# (n_iter, seed, correlate_*) as the call inside generate_reference.R so the
# .rds comparisons below are bit-identical.
# ==============================================================================

cat("Running female PSA (n_iter = 1000, seed = 123, correlate_hr = TRUE)...\n")
.spec_F <- moon_params_norway("female", uncertainty = TRUE,
                               data_dir = .test_data_dir)
.psa_F  <- moon_psa(.spec_F, n_iter = 1000, seed = 123,
                     store_traces = "none",
                     correlate_hr = TRUE, correlate_cost = TRUE)


# Helper: pick metric mean / lower / upper from $summary
.get_summary <- function(psa, metric, sex = "female") {
  rows <- psa$summary[psa$summary$metric == metric & psa$summary$sex == sex, ]
  list(mean = rows$mean, lower = rows$lower95, upper = rows$upper95,
       sd = rows$sd)
}


# ==============================================================================
# Headline anchor: mean cumulative undiscounted incremental cost (female)
# converges (within ±2%) on the deterministic point estimate. The
# deterministic point itself is regression-anchored in test_engine_anchors.R,
# so this captures the PSA-mean / point-estimate relationship.
# ==============================================================================

test_that("PSA mean inc cost (female, undisc) converges to deterministic anchor", {
  s   <- .get_summary(.psa_F, "cum_inc_cost_total_undisc")
  ref <- readRDS(testthat::test_path("fixtures", "female",
                                      "deterministic", "anchors.rds"))
  expect_lt(abs(s$mean - ref$inc_cost_undisc$total) / ref$inc_cost_undisc$total, 0.02)
})


# ==============================================================================
# Cross-check vs canonical PSA reference (cum_costs_psa.rds). The reference
# is generated from the same canonical PSA call below — bit-identity is the
# correct expectation. Catches accidental engine drift between regenerations.
# ==============================================================================

test_that("PSA cum cost summary matches reference (bit-level)", {
  ref_path <- file.path(.psa_ref_female, "cum_costs_psa.rds")
  skip_if_not(file.exists(ref_path), "cum_costs_psa.rds not found")
  ref <- readRDS(ref_path)$undiscounted

  for (state in c("OW", "OB1", "OB2", "total")) {
    metric <- if (state == "total") "cum_inc_cost_total_undisc"
              else                  paste0("cum_inc_cost_", state, "_undisc")
    s <- .get_summary(.psa_F, metric)
    expected <- ref[ref$state == state, ]
    expect_equal(s$mean,  expected$mean,  tolerance = 1e-10, label = paste("mean",  metric))
    expect_equal(s$lower, expected$p025,  tolerance = 1e-10, label = paste("lower", metric))
    expect_equal(s$upper, expected$p975,  tolerance = 1e-10, label = paste("upper", metric))
  }
})

test_that("PSA discounted cum cost summary matches reference (bit-level)", {
  ref_path <- file.path(.psa_ref_female, "cum_costs_psa.rds")
  skip_if_not(file.exists(ref_path), "cum_costs_psa.rds not found")
  ref <- readRDS(ref_path)$discounted_4pct

  for (state in c("OW", "OB1", "OB2", "total")) {
    metric <- if (state == "total") "cum_inc_cost_total_disc"
              else                  paste0("cum_inc_cost_", state, "_disc")
    s <- .get_summary(.psa_F, metric)
    expected <- ref[ref$state == state, ]
    expect_equal(s$mean,  expected$mean,  tolerance = 1e-10, label = paste("mean",  metric))
    expect_equal(s$lower, expected$p025,  tolerance = 1e-10, label = paste("lower", metric))
    expect_equal(s$upper, expected$p975,  tolerance = 1e-10, label = paste("upper", metric))
  }
})


# ==============================================================================
# Cross-check LE against the (canonical) reference at bit level. LE is years
# lived from age 2 — same convention as the per_iter $value column.
# ==============================================================================

test_that("PSA LE matches reference (bit-level)", {
  ref_path <- file.path(.psa_ref_female, "le_psa.rds")
  skip_if_not(file.exists(ref_path), "le_psa.rds not found")
  ref <- readRDS(ref_path)
  s <- .get_summary(.psa_F, "LE")

  expect_equal(s$mean,  ref$mean,  tolerance = 1e-10)
  expect_equal(s$lower, ref$p025, tolerance = 1e-10)
  expect_equal(s$upper, ref$p975, tolerance = 1e-10)
})


# ==============================================================================
# YLL via SA2 (eliminate OB1+OB2): compute base LE - SA2 LE iteration-by-
# iteration and aggregate. Bit-level vs sa1_sa2.rds (same PSA call as
# generate_reference.R).
# ==============================================================================

test_that("PSA YLL (OB1+OB2 elimination, female) matches reference (bit-level)", {
  ip <- .spec_F$init_prev
  ov <- list(
    set_zero  = "OW_OB1",
    init_prev = c(NW = unname(ip["NW"]),
                   OW = unname(ip["OW"] + ip["OB1"] + ip["OB2"]),
                   OB1 = 0, OB2 = 0)
  )
  cat("Running SA2 PSA (n_iter = 1000, seed = 123)...\n")
  psa_sa2 <- moon_psa(.spec_F, n_iter = 1000, seed = 123,
                       store_traces = "none",
                       correlate_hr = TRUE, correlate_cost = TRUE,
                       tp_overrides = ov)

  le_base <- .psa_F$per_iter$value[.psa_F$per_iter$metric == "LE"]
  le_sa2  <- psa_sa2$per_iter$value[psa_sa2$per_iter$metric == "LE"]
  yll <- le_sa2 - le_base   # SA2 LE > base LE by construction (no OB1/OB2)

  yll_mean <- mean(yll)
  yll_lo   <- unname(stats::quantile(yll, 0.025))
  yll_hi   <- unname(stats::quantile(yll, 0.975))

  ref_path <- file.path(.scen_ref_female, "sa1_sa2.rds")
  skip_if_not(file.exists(ref_path), "sa1_sa2.rds not found")
  ref_yll  <- readRDS(ref_path)$yll
  expected <- ref_yll[ref_yll$attributable_to == "OB1_and_OB2", ]

  expect_equal(yll_mean, expected$mean, tolerance = 1e-10)
  expect_equal(yll_lo,   expected$p025, tolerance = 1e-10)
  expect_equal(yll_hi,   expected$p975, tolerance = 1e-10)
})


# ==============================================================================
# correlate_hr toggle sanity. NOTE: the IMPLEMENTATION_PLAN §9.2 originally
# claimed `correlate_hr = FALSE` produces a wider band — that's
# mathematically backwards. Shared z makes all 9 HRs perfectly correlated
# within a sim, so the variance contributions add as a SQUARED SUM:
#   Var(Y_shared) ≈ (Σ_i α_i · log_se_i)²   (equality if Y is linear)
# Independent z draws give:
#   Var(Y_indep)  ≈ Σ_i (α_i · log_se_i)²   (sum of squares)
# By Cauchy-Schwarz (a + b)² > a² + b² for positive components, so shared z
# (correlate_hr = TRUE) gives WIDER bands. This is what the legacy
# hr_psa_correlated = TRUE setting was after — to make the sensitivity
# analysis explicitly conservative. Plan §9.2 wording corrected after this
# test landed.
# ==============================================================================

test_that("correlate_hr = TRUE strictly widens the CI vs FALSE", {
  cat("Running female PSA with correlate_hr = FALSE (n_iter = 1000)...\n")
  psa_indep <- moon_psa(.spec_F, n_iter = 1000, seed = 123,
                         store_traces = "none",
                         correlate_hr = FALSE, correlate_cost = TRUE)

  s_corr  <- .get_summary(.psa_F, "cum_inc_cost_total_undisc")
  s_indep <- .get_summary(psa_indep, "cum_inc_cost_total_undisc")

  width_corr  <- s_corr$upper  - s_corr$lower
  width_indep <- s_indep$upper - s_indep$lower

  expect_gt(width_corr, width_indep)

  # Means should still be in the same neighbourhood (HR symmetry).
  expect_lt(abs(s_indep$mean - s_corr$mean) / s_corr$mean, 0.02)
})


# ==============================================================================
# Prevalence at age 45 cross-check (prevalence_at_ages.rds). Picks the OW
# state at age 45 — the canonical "stabilises around 45%" anchor.
# ==============================================================================

test_that("PSA OW prevalence at age 45 matches reference (bit-level)", {
  ref_path <- file.path(.psa_ref_female, "prevalence_at_ages.rds")
  skip_if_not(file.exists(ref_path), "prevalence_at_ages.rds not found")
  ref     <- readRDS(ref_path)
  ref_ow45 <- ref[ref$age == 45 & ref$state == "OW", ]

  s <- .get_summary(.psa_F, "prev_OW_age45")
  expect_equal(s$mean,  ref_ow45$mean, tolerance = 1e-10)
  expect_equal(s$lower, ref_ow45$p025, tolerance = 1e-10)
  expect_equal(s$upper, ref_ow45$p975, tolerance = 1e-10)
})


# ==============================================================================
# Male PSA — bit-level vs male/psa/cum_costs_psa.rds (same call as
# generate_reference.R; correlate_hr = correlate_cost = TRUE).
# ==============================================================================

test_that("PSA cum cost summary (male, undisc) matches reference (bit-level)", {
  ref_path <- file.path(.find_moon_root(), "tests", "reference",
                        "male", "psa", "cum_costs_psa.rds")
  skip_if_not(file.exists(ref_path), "male/psa/cum_costs_psa.rds not found")
  ref <- readRDS(ref_path)$undiscounted

  cat("Running male PSA (n_iter = 1000, seed = 123)...\n")
  spec_M <- moon_params_norway("male", uncertainty = TRUE,
                                data_dir = .test_data_dir)
  psa_M <- moon_psa(spec_M, n_iter = 1000, seed = 123,
                     store_traces   = "none",
                     correlate_hr   = TRUE,
                     correlate_cost = TRUE)

  for (state in c("OW", "OB1", "OB2", "total")) {
    metric <- if (state == "total") "cum_inc_cost_total_undisc"
              else                  paste0("cum_inc_cost_", state, "_undisc")
    s <- .get_summary(psa_M, metric, sex = "male")
    expected <- ref[ref$state == state, ]
    expect_equal(s$mean,  expected$mean, tolerance = 1e-10, label = paste("mean",  metric))
    expect_equal(s$lower, expected$p025, tolerance = 1e-10, label = paste("lower", metric))
    expect_equal(s$upper, expected$p975, tolerance = 1e-10, label = paste("upper", metric))
  }
})


# ==============================================================================
# §9.3 step 8/9 anchor: per_iter has n_iter * n_metrics * n_sex unique rows
# even at full PSA size.
# ==============================================================================

test_that("§9.3 anchor: per_iter rows = n_iter * n_metrics * n_sex (n=1000)", {
  uniq <- nrow(unique(.psa_F$per_iter[, c("iter", "metric", "sex")]))
  expect_equal(uniq, 1000 * 12 * 1)
})
