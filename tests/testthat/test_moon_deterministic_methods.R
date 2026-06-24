# test_moon_deterministic_methods.R
#
# Step 6 — S3 methods (print, summary, plot, as.data.frame) and extractors
# (moon_prevalence, moon_costs). Plot tests check ggplot identity per `type`
# rather than image content; numeric methods are checked against the same
# anchors as test_moon_deterministic.R.
#
# Helpers (.find_moon_root, .fixtures, .calc_*) come from helper-fixtures.R.

.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")

.fast_result <- function(sex = "female") {
  moon_deterministic(moon_params_norway(sex, data_dir = .test_data_dir))
}


# ==============================================================================
# as.data.frame.moon_deterministic
# ==============================================================================

test_that("as.data.frame returns trace by default and costs on demand", {
  res <- .fast_result()
  expect_identical(as.data.frame(res),                res$trace)
  expect_identical(as.data.frame(res, what = "trace"), res$trace)
  expect_identical(as.data.frame(res, what = "costs"), res$costs)
  expect_error(as.data.frame(res, what = "nope"), "should be one of")
})


# ==============================================================================
# print.moon_deterministic / summary.moon_deterministic
# ==============================================================================

test_that("print.moon_deterministic emits a non-empty one-screen header", {
  res <- .fast_result()
  out <- capture.output(print(res))
  expect_true(any(grepl("<moon_deterministic>", out)))
  expect_true(any(grepl("Sex:",       out)))
  expect_true(any(grepl("Horizon:",   out)))
  expect_true(any(grepl("LE:",        out)))
  expect_true(any(grepl("Total cost", out)))
})

test_that("print.moon_deterministic mentions tp_overrides when applied", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)
  ip <- p$init_prev
  ov <- list(set_zero  = "OW_OB1",
             init_prev = c(NW = unname(ip["NW"]),
                            OW = unname(ip["OW"] + ip["OB1"] + ip["OB2"]),
                            OB1 = 0, OB2 = 0))
  res_sa2 <- moon_deterministic(p, tp_overrides = ov)
  out <- capture.output(print(res_sa2))
  expect_true(any(grepl("tp_overrides", out)))
})

test_that("summary.moon_deterministic returns documented metrics", {
  res <- .fast_result()
  s   <- summary(res)

  expect_s3_class(s, "summary.moon_deterministic")
  expect_setequal(names(s),
                  c("sex", "horizon", "cohort_n", "discount_rate", "LE",
                    "total_cost", "total_cost_disc", "prev_age45",
                    "inc_cost_state", "inc_cost_total", "tp_overrides"))

  expect_equal(s$sex,           "female")
  expect_equal(s$cohort_n,      26458)
  expect_equal(s$discount_rate, 0.04)

  # LE matches sum(alive)/cohort_n
  expect_equal(s$LE,
               sum(res$trace$n[res$trace$state != "dead"]) / s$cohort_n)

  # Cum inc cost matches the engine-level anchor (same female reference)
  expect_equal(s$inc_cost_total, 16104.6292694934, tolerance = 1e-6)

  # prev_age45 covers all 5 alive states and sums to 1
  expect_setequal(names(s$prev_age45),
                  c("N_always", "N_prev", "OW", "OB1", "OB2"))
  expect_equal(sum(s$prev_age45), 1, tolerance = 1e-12)
})

test_that("print.summary.moon_deterministic prints the metrics", {
  res <- .fast_result()
  out <- capture.output(print(summary(res)))
  expect_true(any(grepl("<summary.moon_deterministic>", out)))
  expect_true(any(grepl("Prevalence at age 45", out)))
  expect_true(any(grepl("incremental cost",     out)))
  expect_true(any(grepl("OW",                   out)))
})


# ==============================================================================
# moon_prevalence
# ==============================================================================

test_that("moon_prevalence: alive-denom rows sum to 1 per age (5 alive states)", {
  res <- .fast_result()
  pa  <- moon_prevalence(res, denominator = "alive")

  expect_setequal(names(pa), c("age", "state", "prevalence"))
  expect_setequal(unique(pa$state),
                  c("N_always", "N_prev", "OW", "OB1", "OB2"))

  per_age <- aggregate(prevalence ~ age, pa, sum)
  expect_true(all(abs(per_age$prevalence - 1) < 1e-12))
})

test_that("moon_prevalence: initial-denom rows sum to 1 per age (incl. dead)", {
  res <- .fast_result()
  pi  <- moon_prevalence(res, denominator = "initial")

  expect_setequal(unique(pi$state),
                  c("N_always", "N_prev", "OW", "OB1", "OB2", "dead"))
  per_age <- aggregate(prevalence ~ age, pi, sum)
  expect_true(all(abs(per_age$prevalence - 1) < 1e-12))
})

test_that("moon_prevalence: ages filter restricts output", {
  res <- .fast_result()
  pa  <- moon_prevalence(res, ages = c(2, 45, 90))
  expect_setequal(unique(pa$age), c(2, 45, 90))
})

test_that("moon_prevalence: by_sex toggles the sex column", {
  res <- .fast_result()
  expect_false("sex" %in% names(moon_prevalence(res, by_sex = FALSE)))
  expect_true( "sex" %in% names(moon_prevalence(res, by_sex = TRUE)))
})

test_that("moon_prevalence anchor: female OW at age 45 ≈ 0.391 (reference)", {
  res <- .fast_result("female")
  pa  <- moon_prevalence(res, denominator = "alive", ages = 45)
  ow  <- pa$prevalence[pa$state == "OW"]
  expect_equal(ow, 0.390622267826527, tolerance = 1e-6)
})


# ==============================================================================
# moon_costs
# ==============================================================================

test_that("moon_costs by = total returns the grand total", {
  res <- .fast_result()
  expect_equal(moon_costs(res, by = "total"), sum(res$costs$cost))
  expect_equal(moon_costs(res, by = "total", discounted = TRUE),
               sum(res$costs$cost_disc))
})

test_that("moon_costs by = age returns 99 ages", {
  res <- .fast_result()
  by_age <- moon_costs(res, by = "age")
  expect_setequal(names(by_age), c("age", "cost"))
  expect_equal(nrow(by_age), 99)
  expect_setequal(by_age$age, 2:100)
  expect_equal(sum(by_age$cost), sum(res$costs$cost), tolerance = 1e-9)
})

test_that("moon_costs by = state returns 5 cost-bearing states", {
  res <- .fast_result()
  by_state <- moon_costs(res, by = "state")
  expect_setequal(by_state$state,
                  c("N_always", "N_prev", "OW", "OB1", "OB2"))
  expect_equal(sum(by_state$cost), sum(res$costs$cost), tolerance = 1e-9)
})

test_that("moon_costs by = sex returns one row matching the trace's sex", {
  res <- .fast_result("male")
  by_sex <- moon_costs(res, by = "sex")
  expect_equal(nrow(by_sex), 1)
  expect_equal(by_sex$sex, "male")
})

test_that("moon_costs discounted = TRUE strictly less than undiscounted", {
  res <- .fast_result()
  expect_lt(moon_costs(res, by = "total", discounted = TRUE),
            moon_costs(res, by = "total", discounted = FALSE))
})

test_that("moon_costs ages filter restricts the sum", {
  res <- .fast_result()
  v_full   <- moon_costs(res, by = "total")
  v_window <- moon_costs(res, by = "total", ages = 50:60)
  expect_lt(v_window, v_full)
  expect_gt(v_window, 0)
})


# ==============================================================================
# plot.moon_deterministic — §9.3 anchor: each type yields a ggplot
# ==============================================================================

test_that("plot.moon_deterministic returns a ggplot for each type (§9.3 anchor)", {
  skip_if_not_installed("ggplot2")
  res <- .fast_result()
  for (ty in c("occupancy", "prevalence_alive", "prevalence_initial",
               "survival", "costs")) {
    p <- plot(res, type = ty)
    expect_s3_class(p, "ggplot")
  }
})

test_that("plot.moon_deterministic honours the ages filter", {
  skip_if_not_installed("ggplot2")
  res <- .fast_result()
  p   <- plot(res, type = "occupancy", ages = 30:50)
  expect_s3_class(p, "ggplot")
  # The underlying data on the plot is restricted to the requested ages.
  expect_setequal(unique(p$data$age), 30:50)
})

test_that("plot.moon_deterministic rejects unknown types", {
  skip_if_not_installed("ggplot2")
  res <- .fast_result()
  expect_error(plot(res, type = "nope"), "should be one of")
})


# ==============================================================================
# Round-trip: as.data.frame -> moon_costs (manual aggregate) matches
# moon_costs() on the same key.
# ==============================================================================

test_that("moon_costs(by='age') matches base-R aggregate(as.data.frame(...))", {
  res <- .fast_result()
  manual <- aggregate(cost ~ age, as.data.frame(res, what = "costs"), sum)
  via_helper <- moon_costs(res, by = "age")
  expect_equal(manual, via_helper, tolerance = 1e-12)
})
