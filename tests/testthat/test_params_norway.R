# test_params_norway.R
#
# Verify that moon_params_norway() builds a well-formed engine-shape `params`
# list, and that running the engine end-to-end on loader-built params
# reproduces the female deterministic reference (bit-identical to 1e-10).
#
# Helpers (.find_moon_root, .run_base, .run_sa2) come from helper-fixtures.R,
# auto-loaded by testthat before this file.

# Resolve the data directory once. The loader is CWD-independent: callers pass
# data_dir explicitly so test_dir() can run from anywhere.
.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")


# ==============================================================================
# Field-level shape checks per sex.
# ==============================================================================

invisible(lapply(
  list(c(long = "female", code = "F"),
       c(long = "male",   code = "M"),
       c(long = "both",   code = "Both")),
  function(s) {
    sex_long <- s[["long"]]
    sex_code <- s[["code"]]
    expected_cohort <- c(F = 26458L, M = 28662L, Both = 55120L)[[sex_code]]

    test_that(sprintf("loader returns engine-shape params (%s)", sex_code), {
      p <- moon_params_norway(sex_long, data_dir = .test_data_dir)

      expect_equal(p$start_age,     2L)
      expect_equal(p$max_age,       100L)
      expect_equal(p$discount_rate, 0.04)

      expect_named(p$init_prev, c("NW", "OW", "OB1", "OB2"))
      expect_equal(sum(p$init_prev), 1, tolerance = 1e-8)

      expect_equal(nrow(p$transition_probs), 98)
      expect_setequal(
        names(p$transition_probs),
        c("age", "NW_OW", "OW_NW", "OW_OB1", "OB1_OW", "OB1_OB2", "OB2_OB1")
      )
      expect_identical(p$transition_probs$age, 2:99)

      expect_equal(length(p$qx), 98)
      expect_equal(names(p$qx)[1], "2")
      expect_equal(names(p$qx)[98], "99")

      expect_equal(p$mortality_hr$age_lower, c(35, 50, 70))
      expect_equal(p$mortality_hr$OW, c(1.17, 1.11, 0.98))

      expect_setequal(unique(p$cost_df$state), c("NW", "OW", "OB1", "OB2"))

      expect_equal(unname(p$cohort_n), expected_cohort)
      expect_named(p$cohort_n, sex_long)
      expect_type(p$cohort_n, "integer")
    })
  }
))


# ==============================================================================
# Top-level structural check.
# ==============================================================================

test_that("loader returns the documented top-level fields", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)
  expect_setequal(
    names(p),
    c("start_age", "max_age", "discount_rate", "cost_currency",
      "cohort_n", "init_prev", "qx", "mortality_hr",
      "transition_probs", "cost_df")
  )
  expect_equal(p$cost_currency, "EUR")
})


# ==============================================================================
# uncertainty = TRUE returns spec-laden params (covered exhaustively in
# test_moon_params.R; this is just a smoke check that the flag is wired).
# ==============================================================================

test_that("uncertainty = TRUE returns a list with the same top-level fields", {
  p <- moon_params_norway("female", uncertainty = TRUE,
                          data_dir = .test_data_dir)
  expect_setequal(
    names(p),
    c("start_age", "max_age", "discount_rate", "cost_currency",
      "cohort_n", "init_prev", "qx", "mortality_hr",
      "transition_probs", "cost_df")
  )
})


# ==============================================================================
# End-to-end: SA2 base/scenario run on loader-built params produces a trace.
# Structural sanity check that the loader's outputs flow through the engine.
# ==============================================================================

test_that("loader-built params drive the engine end-to-end (female base + SA2)", {
  p <- moon_params_norway("female", data_dir = .test_data_dir)

  base <- .run_base(p)
  expect_equal(dim(base$trace), c(99, 6))
  expect_setequal(colnames(base$trace),
                  c("N_always", "N_prev", "OW", "OB1", "OB2", "D"))

  sa2 <- .run_sa2(p)
  expect_equal(dim(sa2$trace), dim(base$trace))
  # SA2 zeros OW->OB1 + redistributes initial OB1/OB2 mass into OW; OB1/OB2
  # occupancy must drop to ~0 across the run.
  expect_lt(sum(sa2$trace[, "OB1"]), 1e-8)
  expect_lt(sum(sa2$trace[, "OB2"]), 1e-8)
})


# ==============================================================================
# Bit-level reference check (female): loader-built path matches the canonical
# .rds reference at 1e-10. Strongest correctness signal in the test suite —
# every cell of the trace agrees with the regenerated reference.
# ==============================================================================

test_that("loader trace is bit-identical to reference (female deterministic)", {
  ref_path <- testthat::test_path("fixtures", "female",
                                   "deterministic", "cohort_trace_det.rds")
  skip_if_not(file.exists(ref_path), "reference cohort_trace_det.rds not found")

  p   <- moon_params_norway("female", data_dir = .test_data_dir)
  res <- .run_base(p)
  ref <- readRDS(ref_path)

  expect_equal(dim(res$trace), dim(ref))
  expect_equal(unname(res$trace), unname(ref), tolerance = 1e-10)
})
