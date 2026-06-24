# test_moon_psa.R
#
# Step 8 — moon_sample_params() + moon_psa() + S3 methods. Tests are kept
# small (n_iter = 20-30) so the suite stays fast; the §9.2 anchor checks
# (n_iter = 1000) live in test_psa_scenarios.R behind MOON_RUN_SLOW_TESTS.
#
# Helpers (.find_moon_root) come from helper-fixtures.R.

.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")

.psa_spec <- function(sex = "female") {
  moon_params_norway(sex, uncertainty = TRUE, data_dir = .test_data_dir)
}


# ==============================================================================
# moon_sample_params: shape, schema, validation pass-through
# ==============================================================================

test_that("moon_sample_params returns n plain-value params lists", {
  set.seed(1)
  spec <- .psa_spec()
  draws <- moon_sample_params(spec, n = 5, seed = 1)

  expect_length(draws, 5L)
  for (p in draws) {
    expect_setequal(names(p),
                    c("start_age", "max_age", "discount_rate", "cost_currency",
                      "cohort_n", "init_prev", "qx", "mortality_hr",
                      "transition_probs", "cost_df"))
    expect_s3_class(p$mortality_hr, "data.frame")
    expect_true(is.numeric(p$mortality_hr$OW))
    expect_s3_class(p$cost_df, "data.frame")
    expect_true(is.numeric(p$cost_df$cost))
    expect_s3_class(p$transition_probs, "data.frame")
    expect_setequal(names(p$transition_probs),
                    c("age", "NW_OW", "OW_NW", "OW_OB1",
                      "OB1_OW", "OB1_OB2", "OB2_OB1"))
  }
})

test_that("each sampled params passes moon_check_params and runs the engine", {
  set.seed(2)
  spec <- .psa_spec()
  draws <- moon_sample_params(spec, n = 5, seed = 2)
  for (p in draws) {
    expect_silent(moon_check_params(p, strict = TRUE))
    res <- moon_deterministic(p)
    expect_s3_class(res, "moon_deterministic")
  }
})

test_that("seed makes moon_sample_params reproducible", {
  spec <- .psa_spec()
  d1   <- moon_sample_params(spec, n = 3, seed = 42)
  d2   <- moon_sample_params(spec, n = 3, seed = 42)
  for (i in seq_along(d1)) {
    expect_equal(d1[[i]]$mortality_hr,     d2[[i]]$mortality_hr)
    expect_equal(d1[[i]]$cost_df,          d2[[i]]$cost_df)
    expect_equal(d1[[i]]$transition_probs, d2[[i]]$transition_probs)
  }
})


# ==============================================================================
# correlate_hr / correlate_cost — within-sim shared randomness
# ==============================================================================

test_that("correlate_hr=TRUE drives all 9 HRs from the same z within an iter", {
  spec <- .psa_spec()

  # Pull the lognormal log_se / log_mean for every (band, state) cell so we
  # can back out z = (log(draw) - log_mean) / log_se per iter.
  cells_meta <- list()
  for (state in c("OW", "OB1", "OB2")) {
    for (b_idx in 1:3) {
      s <- spec$mortality_hr[[state]][[b_idx]]
      cells_meta[[length(cells_meta) + 1]] <- list(
        state = state, band_idx = b_idx,
        log_mean = s$log_mean, log_se = s$log_se
      )
    }
  }

  draws <- moon_sample_params(spec, n = 10, seed = 99, correlate_hr = TRUE)
  for (i in seq_along(draws)) {
    z_vals <- vapply(cells_meta, function(meta) {
      hr_val <- draws[[i]]$mortality_hr[[meta$state]][meta$band_idx]
      (log(hr_val) - meta$log_mean) / meta$log_se
    }, numeric(1))
    expect_equal(diff(range(z_vals)), 0, tolerance = 1e-12,
                 info = paste("iter", i))
  }
})

test_that("correlate_hr=FALSE produces independent z across cells", {
  spec  <- .psa_spec()
  draws <- moon_sample_params(spec, n = 200, seed = 7, correlate_hr = FALSE)

  # Standardise OW band 1 vs OB1 band 1 across iters. They should be ~uncorrelated.
  s_ow1  <- spec$mortality_hr$OW[[1]]
  s_ob11 <- spec$mortality_hr$OB1[[1]]

  z_ow1  <- vapply(draws, function(p) {
    (log(p$mortality_hr$OW[1])  - s_ow1$log_mean)  / s_ow1$log_se
  }, numeric(1))
  z_ob11 <- vapply(draws, function(p) {
    (log(p$mortality_hr$OB1[1]) - s_ob11$log_mean) / s_ob11$log_se
  }, numeric(1))
  expect_lt(abs(stats::cor(z_ow1, z_ob11)), 0.20)
})


# ==============================================================================
# moon_psa: structural anchor (§9.3)
# ==============================================================================

test_that("§9.3 anchor: per_iter has n_iter * n_metrics * n_sex unique rows", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 30, seed = 1, store_traces = "none")
  expect_s3_class(res, "moon_psa")

  uniq <- nrow(unique(res$per_iter[, c("iter", "metric", "sex")]))
  expect_equal(uniq, 30 * 12 * 1L)
})

test_that("moon_psa output layout matches §6.4", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 20, seed = 1, store_traces = "summary")

  expect_setequal(names(res),
                  c("summary", "per_iter", "traces", "draws",
                    "params_spec", "meta"))
  expect_setequal(names(res$summary),
                  c("sex", "metric", "mean", "lower95", "upper95", "sd"))
  expect_setequal(names(res$per_iter),
                  c("iter", "sex", "metric", "value"))
  expect_setequal(names(res$draws),
                  c("iter", "parameter", "value"))
  expect_identical(res$params_spec, spec)
  expect_setequal(names(res$meta),
                  c("n_iter", "seed", "parallel", "runtime_sec",
                    "store_traces", "correlate_hr", "correlate_cost",
                    "tp_overrides"))
})


# ==============================================================================
# summary aggregation matches manual aggregation of per_iter
# ==============================================================================

test_that("moon_psa summary equals manual aggregation of per_iter", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 25, seed = 5, store_traces = "none")

  manual <- aggregate(value ~ sex + metric, data = res$per_iter,
                       FUN = function(v) c(mean(v),
                                            unname(stats::quantile(v, 0.025)),
                                            unname(stats::quantile(v, 0.975)),
                                            stats::sd(v)))

  # Bring res$summary into the same shape and order
  summ_sorted <- res$summary[order(res$summary$sex, res$summary$metric), ]
  manual_sorted <- manual[order(manual$sex, manual$metric), ]

  expect_equal(summ_sorted$mean,    manual_sorted$value[, 1], tolerance = 1e-12)
  expect_equal(summ_sorted$lower95, manual_sorted$value[, 2], tolerance = 1e-12)
  expect_equal(summ_sorted$upper95, manual_sorted$value[, 3], tolerance = 1e-12)
  expect_equal(summ_sorted$sd,      manual_sorted$value[, 4], tolerance = 1e-12)
})


# ==============================================================================
# Mean of cumulative inc cost should sit near the deterministic anchor
# ==============================================================================

test_that("mean cum_inc_cost_total_undisc near female deterministic anchor", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 50, seed = 11, store_traces = "none")
  m <- res$summary
  v <- m$mean[m$metric == "cum_inc_cost_total_undisc" & m$sex == "female"]
  expect_lt(abs(v - 16104.6) / 16104.6, 0.10)   # ±10% on n=50
})


# ==============================================================================
# Trace storage policies
# ==============================================================================

test_that("store_traces='all' returns the list of moon_deterministic objects", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "all")
  expect_length(res$traces, 5L)
  for (r in res$traces) {
    expect_s3_class(r, "moon_deterministic")
    expect_true(!is.na(r$meta$iter))
  }
})

test_that("store_traces='summary' returns a 3-D array [iter, age, state]", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 7, seed = 1, store_traces = "summary")
  expect_true(is.array(res$traces))
  expect_equal(dim(res$traces), c(7, 99, 6))
  expect_setequal(dimnames(res$traces)$state,
                  c("N_always", "N_prev", "OW", "OB1", "OB2", "dead"))
})

test_that("store_traces='none' drops trace data", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 3, seed = 1, store_traces = "none")
  expect_null(res$traces)
})


# ==============================================================================
# tp_overrides flow through PSA (PSA on a scenario)
# ==============================================================================

test_that("tp_overrides apply to every PSA iteration", {
  spec <- .psa_spec()
  ip <- spec$init_prev
  ov <- list(
    set_zero  = "OW_OB1",
    init_prev = c(NW = unname(ip["NW"]),
                   OW = unname(ip["OW"] + ip["OB1"] + ip["OB2"]),
                   OB1 = 0, OB2 = 0)
  )
  res <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "all",
                   tp_overrides = ov)
  for (r in res$traces) {
    expect_equal(r$meta$tp_overrides, ov)
    ob1_total <- sum(r$trace$n[r$trace$state == "OB1"])
    ob2_total <- sum(r$trace$n[r$trace$state == "OB2"])
    expect_lt(ob1_total, 1e-6)
    expect_lt(ob2_total, 1e-6)
  }
  expect_equal(res$meta$tp_overrides, ov)
})


# ==============================================================================
# Reproducibility: same seed -> same per_iter / summary
# ==============================================================================

test_that("moon_psa with same seed produces identical results", {
  spec <- .psa_spec()
  r1 <- moon_psa(spec, n_iter = 12, seed = 99, store_traces = "none")
  r2 <- moon_psa(spec, n_iter = 12, seed = 99, store_traces = "none")
  expect_equal(r1$per_iter, r2$per_iter)
  expect_equal(r1$summary,  r2$summary)
  expect_equal(r1$draws,    r2$draws)
})


# ==============================================================================
# meta records seed, n_iter, runtime, correlate flags
# ==============================================================================

test_that("moon_psa meta records all required fields", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 4, seed = 33,
                    store_traces = "none",
                    correlate_hr = FALSE, correlate_cost = FALSE)
  expect_equal(res$meta$n_iter,        4L)
  expect_equal(res$meta$seed,          33L)
  expect_false(res$meta$parallel)
  expect_gt(res$meta$runtime_sec,      0)
  expect_equal(res$meta$store_traces,  "none")
  expect_false(res$meta$correlate_hr)
  expect_false(res$meta$correlate_cost)
  expect_null(res$meta$tp_overrides)
})


# ==============================================================================
# S3 methods
# ==============================================================================

test_that("print.moon_psa emits a non-empty header", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "none")
  out  <- capture.output(print(res))
  expect_true(any(grepl("<moon_psa>",     out)))
  expect_true(any(grepl("Iterations:",    out)))
  expect_true(any(grepl("Headline metrics", out)))
})

test_that("summary.moon_psa returns the summary df", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "none")
  expect_identical(summary(res), res$summary)
})

test_that("as.data.frame.moon_psa dispatches on `what`", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "none")
  expect_identical(as.data.frame(res),                 res$per_iter)
  expect_identical(as.data.frame(res, what = "draws"), res$draws)
  expect_identical(as.data.frame(res, what = "summary"), res$summary)
  expect_error(as.data.frame(res, what = "nope"), "should be one of")
})

test_that("plot.moon_psa(type='forest') returns a ggplot", {
  skip_if_not_installed("ggplot2")
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "none")
  expect_s3_class(plot(res, type = "forest"), "ggplot")
})

test_that("plot.moon_psa(type='incremental_cost_age') returns a ggplot", {
  skip_if_not_installed("ggplot2")
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "all")
  expect_s3_class(plot(res, type = "incremental_cost_age"), "ggplot")
})

test_that("plot.moon_psa(type='incremental_cost_age') errors without traces", {
  skip_if_not_installed("ggplot2")
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 5, seed = 1, store_traces = "summary")
  expect_error(plot(res, type = "incremental_cost_age"), "store_traces")
})


# ==============================================================================
# Draws table: 9 HR draws per iteration
# ==============================================================================

test_that("draws audit table has 9 rows per iteration (3 states × 3 bands)", {
  spec <- .psa_spec()
  res  <- moon_psa(spec, n_iter = 8, seed = 1, store_traces = "none")
  expect_equal(nrow(res$draws), 8 * 9)
  expect_setequal(unique(res$draws$parameter),
                  c("hr_OW_band35",  "hr_OW_band50",  "hr_OW_band70",
                    "hr_OB1_band35", "hr_OB1_band50", "hr_OB1_band70",
                    "hr_OB2_band35", "hr_OB2_band50", "hr_OB2_band70"))
})
