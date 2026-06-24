# test_moon_deterministic.R
#
# Step 5 — verify the moon_deterministic() wrapper produces a well-formed
# moon_deterministic object whose underlying engine output reproduces the same anchors
# as the engine-direct anchors in test_engine_anchors.R.
#
# Helpers (.find_moon_root, .calc_*, .run_base, .run_sa2) are auto-loaded
# from helper-fixtures.R.

.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")


# Per-capita cumulative incremental cost vs NW, computed from the wrapper's
# `costs` + `trace` data frames. Mirrors .calc_inc_cost (which works on the
# engine output directly): for each age, recover c_state from cost / n, then
# sum n * (c_state - c_NW) over OW/OB1/OB2 and divide by cohort_n.
#
# We can't get inc cost from `costs` alone because cost = occ * cn * c_state
# is "total euros spent in state" — to compare states we need per-capita
# per-cycle costs, which the wrapper doesn't store directly. The relation
# c_state = cost / n holds whenever n > 0 (n = occ * cn). The NW baseline is
# read from N_always rows; N_prev would give the same value (both draw from
# cost_df$state == "NW").
.df_inc_cost_per_capita <- function(result) {
  trace <- result$trace
  costs <- result$costs
  cn    <- unname(result$params$cohort_n)

  m <- merge(trace, costs, by = c("age", "sex", "state"), all.x = TRUE)
  m$c_per <- ifelse(m$n > 0 & !is.na(m$cost), m$cost / m$n, 0)

  c_NW_age <- m$c_per[m$state == "N_always"]
  names(c_NW_age) <- as.character(m$age[m$state == "N_always"])
  m$c_NW <- c_NW_age[as.character(m$age)]

  obesity <- m$state %in% c("OW", "OB1", "OB2")
  sum(m$n[obesity] * (m$c_per[obesity] - m$c_NW[obesity])) / cn
}


# ==============================================================================
# §9.3 structural anchor: result inherits "moon_deterministic" with the documented top-
# level names.
# ==============================================================================

test_that("result is a moon_deterministic with the documented layout", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  expect_s3_class(res, "moon_deterministic")
  expect_setequal(names(res), c("trace", "costs", "params", "meta"))

  expect_s3_class(res$trace, "data.frame")
  expect_setequal(names(res$trace), c("age", "sex", "state", "n"))

  expect_s3_class(res$costs, "data.frame")
  expect_setequal(names(res$costs), c("age", "sex", "state", "cost", "cost_disc"))

  expect_setequal(names(res$meta),
                  c("moon_version", "run_time", "duration_sec", "cycle_length",
                    "horizon", "discount_rate", "tp_overrides", "seed", "iter"))
})


# ==============================================================================
# Trace shape: 6 external states (engine's full state space exposed:
# N_always, N_prev, OW, OB1, OB2, dead), 99 ages, rows-per-age sum to
# cohort_n head-counts.
# ==============================================================================

test_that("trace has 99 ages * 6 states and per-age head-counts sum to cohort_n", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  expect_equal(nrow(res$trace), 99 * 6)
  expect_setequal(unique(res$trace$state),
                  c("N_always", "N_prev", "OW", "OB1", "OB2", "dead"))
  expect_setequal(unique(res$trace$age), 2:100)
  expect_equal(unique(res$trace$sex), "female")

  per_age <- aggregate(n ~ age, data = res$trace, FUN = sum)
  expect_true(all(abs(per_age$n - unname(p$cohort_n)) < 1e-6))
})


# ==============================================================================
# Costs shape: 5 cost-bearing states (no "dead"; N_always and N_prev each
# carry their own row even though both draw the NW per-capita cost), 99
# ages, undiscounted >= discounted.
# ==============================================================================

test_that("costs has 99 ages * 5 states (no dead) and disc <= undisc", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  expect_equal(nrow(res$costs), 99 * 5)
  expect_setequal(unique(res$costs$state),
                  c("N_always", "N_prev", "OW", "OB1", "OB2"))
  expect_setequal(unique(res$costs$age), 2:100)

  expect_true(all(res$costs$cost      >= 0))
  expect_true(all(res$costs$cost_disc >= 0))
  expect_true(all(res$costs$cost_disc <= res$costs$cost + 1e-9))

  # Cycle 0 (age = start_age = 2) is undiscounted.
  start_rows <- res$costs[res$costs$age == 2, ]
  expect_equal(start_rows$cost_disc, start_rows$cost)
})


# ==============================================================================
# N_always vs N_prev: both NW substates draw the same per-capita cost from
# cost_df, so cost / n must match age-by-age (where both have non-zero
# occupancy). This is the contract that justifies using either state as the
# c_NW baseline in inc-cost calculations.
# ==============================================================================

test_that("N_always and N_prev share the per-capita NW cost", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  m <- merge(res$trace, res$costs, by = c("age", "sex", "state"))
  m$c_per <- ifelse(m$n > 0, m$cost / m$n, NA_real_)

  c_alw <- m$c_per[m$state == "N_always"]
  c_prv <- m$c_per[m$state == "N_prev"]
  ok    <- !is.na(c_alw) & !is.na(c_prv)
  expect_true(all(abs(c_alw[ok] - c_prv[ok]) < 1e-9))
})


# ==============================================================================
# Discount factor: cost_disc / cost = 1/(1+r)^(age - start_age), checked at
# multiple ages and states. (Skip rows where cost == 0 — ages 2-19 are zero.)
# ==============================================================================

test_that("cost_disc / cost = 1/(1+r)^(age - start_age)", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  cd     <- res$costs[res$costs$cost > 0, ]
  ratio  <- cd$cost_disc / cd$cost
  expected <- 1 / (1 + p$discount_rate) ^ (cd$age - p$start_age)
  expect_equal(ratio, expected, tolerance = 1e-12)
})


# ==============================================================================
# Verification anchor: per-capita incremental cost ≈ engine's .calc_inc_cost.
# Tight tolerance — both routes use the same engine, so they must be
# bit-equivalent up to floating-point noise.
# ==============================================================================

test_that("wrapper-derived per-capita inc cost matches engine-direct (female)", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  inc_wrap   <- .df_inc_cost_per_capita(res)
  inc_engine <- .calc_inc_cost(.run_base(p))
  expect_equal(inc_wrap, inc_engine, tolerance = 1e-9)
})

test_that("wrapper-derived per-capita inc cost matches engine-direct (male)", {
  p   <- moon_params_norway("male", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  inc_wrap   <- .df_inc_cost_per_capita(res)
  inc_engine <- .calc_inc_cost(.run_base(p))
  expect_equal(inc_wrap, inc_engine, tolerance = 1e-9)
})

test_that("wrapper-derived per-capita inc cost matches engine-direct (both)", {
  p   <- moon_params_norway("both", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  inc_wrap   <- .df_inc_cost_per_capita(res)
  inc_engine <- .calc_inc_cost(.run_base(p))
  expect_equal(inc_wrap, inc_engine, tolerance = 1e-9)
})


# ==============================================================================
# Anchor pass-through: wrapper-derived per-capita inc cost matches the
# regenerated reference at bit-level for every sex. Mirrors the engine-direct
# anchor in test_engine_anchors.R via the wrapper's cost data frame.
# ==============================================================================

invisible(lapply(c("female", "male", "both"), function(sex_long) {
  test_that(sprintf("wrapper inc cost matches reference anchor (%s)", sex_long), {
    p   <- moon_params_norway(sex_long, data_dir = .test_data_dir)
    res <- moon_deterministic(p)
    inc <- .df_inc_cost_per_capita(res)

    ref <- readRDS(testthat::test_path("fixtures", sex_long,
                                        "deterministic", "anchors.rds"))
    expect_equal(inc, ref$inc_cost_undisc$total, tolerance = 1e-9)
  })
}))


# ==============================================================================
# Trace bit-identity vs the legacy female reference.
# trace$n / cohort_n (per-state, per-age) should equal each reference column
# directly — N_always, N_prev, OW, OB1, OB2 carry through verbatim from the
# engine; D is renamed to "dead".
# ==============================================================================

test_that("trace matches legacy female reference (proportions, 1e-10)", {
  ref_path <- testthat::test_path("fixtures", "female",
                                   "deterministic", "cohort_trace_det.rds")
  skip_if_not(file.exists(ref_path), "reference cohort_trace_det.rds not found")

  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)
  cn  <- unname(p$cohort_n)
  ref <- readRDS(ref_path)

  pivot <- function(state) {
    rows <- res$trace[res$trace$state == state, ]
    rows <- rows[order(rows$age), ]
    unname(rows$n / cn)
  }

  expect_equal(pivot("N_always"), unname(ref[, "N_always"]), tolerance = 1e-10)
  expect_equal(pivot("N_prev"),   unname(ref[, "N_prev"]),   tolerance = 1e-10)
  expect_equal(pivot("OW"),       unname(ref[, "OW"]),       tolerance = 1e-10)
  expect_equal(pivot("OB1"),      unname(ref[, "OB1"]),      tolerance = 1e-10)
  expect_equal(pivot("OB2"),      unname(ref[, "OB2"]),      tolerance = 1e-10)
  expect_equal(pivot("dead"),     unname(ref[, "D"]),        tolerance = 1e-10)
})


# ==============================================================================
# Validation pass-through: a broken `params` errors with a useful message
# from moon_check_params() before any engine work happens.
# ==============================================================================

test_that("invalid params is rejected by the wrapper", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)
  p$discount_rate <- 2
  expect_error(moon_deterministic(p), "discount_rate")
})

test_that("strict = FALSE downgrades to warning and still runs", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)
  # Mutate something benign that fails range but doesn't break the math:
  # corrupt mortality_hr$OW to 0 — engine would happily produce mortality 0
  # for OW. Run completes; check_params warns.
  p$mortality_hr$OW[1] <- 0
  expect_warning(res <- moon_deterministic(p, strict = FALSE),
                 "mortality_hr")
  expect_s3_class(res, "moon_deterministic")
})


# ==============================================================================
# Meta sublist contents: timestamps, version, horizon, tp_overrides slot,
# NA seed/iter for standalone runs.
# ==============================================================================

test_that("meta records horizon, discount, tp_overrides, NA seed/iter", {
  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- moon_deterministic(p)

  expect_equal(unname(res$meta$horizon),
               c(p$start_age, p$max_age))
  expect_equal(res$meta$discount_rate, p$discount_rate)
  expect_null(res$meta$tp_overrides)
  expect_true(is.na(res$meta$seed))
  expect_true(is.na(res$meta$iter))
  expect_equal(res$meta$cycle_length, 1L)
  expect_s3_class(res$meta$run_time, "POSIXct")
  expect_true(is.numeric(res$meta$duration_sec) && res$meta$duration_sec >= 0)
})


# ==============================================================================
# tp_overrides round-trips into meta and changes the trace as expected (SA2:
# zero OW_OB1 + redistribute initial OB1+OB2 mass into OW; OB1 + OB2 occupancy
# should fall to ~0 over the run).
# ==============================================================================

test_that("SA2 tp_overrides flow through and zero out the obesity tail", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)
  ip <- p$init_prev
  ip_sa2 <- c(NW  = unname(ip["NW"]),
              OW  = unname(ip["OW"] + ip["OB1"] + ip["OB2"]),
              OB1 = 0,
              OB2 = 0)
  ov <- list(set_zero = "OW_OB1", init_prev = ip_sa2)
  res <- moon_deterministic(p, tp_overrides = ov)

  expect_equal(res$meta$tp_overrides, ov)

  ob1_total <- sum(res$trace$n[res$trace$state == "OB1"])
  ob2_total <- sum(res$trace$n[res$trace$state == "OB2"])
  expect_lt(ob1_total, 1e-6)
  expect_lt(ob2_total, 1e-6)
})


# ==============================================================================
# Sex label propagates from cohort_n into all trace + costs rows.
# ==============================================================================

test_that("sex label in trace/costs matches names(cohort_n)", {
  for (sx in c("female", "male", "both")) {
    p   <- moon_params_norway(sx, data_dir = .test_data_dir)
    res <- moon_deterministic(p)
    expect_equal(unique(res$trace$sex), sx)
    expect_equal(unique(res$costs$sex), sx)
  }
})


# ==============================================================================
# §9.3 verification anchor expressed verbatim.
# ==============================================================================

test_that("§9.3 anchor: inherits(moon_deterministic(p), 'moon_deterministic')", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)
  expect_true(inherits(moon_deterministic(p), "moon_deterministic"))
})
