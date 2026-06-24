# test_check_params.R
#
# Step 4 — moon_check_params() validation. Each test feeds a deliberately
# broken `params` and confirms the right error fires identifying the field
# at fault. Happy paths (real loader output) must pass silently.
#
# Helpers (.find_moon_root) come from helper-fixtures.R, auto-loaded by
# testthat before this file.

.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")


# Build a fresh known-good params for each test (loader is the canonical
# source). Wrapped in a closure so tests can mutate fields without leaking
# state across tests.
.good_params <- function(sex = "female") {
  moon_params_norway(sex, data_dir = .test_data_dir)
}


# ==============================================================================
# Happy path — real loader output passes silently for all three sexes.
# ==============================================================================

test_that("moon_check_params accepts loader output (all sexes)", {
  for (sx in c("female", "male", "both")) {
    p <- .good_params(sx)
    expect_silent(out <- moon_check_params(p, strict = TRUE))
    expect_identical(out, p)
  }
})


# ==============================================================================
# Phase 1 — structural failures
# ==============================================================================

test_that("non-list params errors", {
  expect_error(moon_check_params("not a list"), "must be a list")
  expect_error(moon_check_params(NULL),         "must be a list")
})

test_that("missing required fields named in error", {
  p <- .good_params()
  p$qx <- NULL
  p$cost_df <- NULL
  expect_error(moon_check_params(p), "missing required field.*qx")
  expect_error(moon_check_params(p), "cost_df")
})

test_that("non-finite or wrong-shape scalar fields error", {
  p <- .good_params(); p$start_age <- c(2, 3)
  expect_error(moon_check_params(p), "`start_age`.*length-1 numeric")

  p <- .good_params(); p$max_age <- NA_real_
  expect_error(moon_check_params(p), "`max_age`.*length-1 numeric")

  p <- .good_params(); p$discount_rate <- "0.04"
  expect_error(moon_check_params(p), "`discount_rate`.*length-1 numeric")
})

test_that("scalar range violations error", {
  p <- .good_params(); p$start_age <- -1
  expect_error(moon_check_params(p), "`start_age` must be >= 0")

  p <- .good_params(); p$max_age <- p$start_age
  expect_error(moon_check_params(p), "`max_age` must be > `start_age`")

  p <- .good_params(); p$discount_rate <- 1
  expect_error(moon_check_params(p), "`discount_rate` must be in \\[0, 1\\)")

  p <- .good_params(); p$discount_rate <- -0.01
  expect_error(moon_check_params(p), "`discount_rate` must be in \\[0, 1\\)")
})

test_that("cost_currency must be in allowlist", {
  p <- .good_params(); p$cost_currency <- "GBP"
  expect_error(moon_check_params(p), "`cost_currency`")

  p <- .good_params(); p$cost_currency <- c("EUR", "NOK")
  expect_error(moon_check_params(p), "`cost_currency`")
})

test_that("cohort_n must be a length-1 named integer with allowed name", {
  p <- .good_params(); p$cohort_n <- 26458L  # unnamed
  expect_error(moon_check_params(p), "`cohort_n`")

  p <- .good_params(); p$cohort_n <- c(female = 26458)  # numeric, not integer
  expect_error(moon_check_params(p), "`cohort_n`")

  p <- .good_params(); p$cohort_n <- c(other = 26458L)  # wrong name
  expect_error(moon_check_params(p), "`cohort_n`")

  p <- .good_params(); p$cohort_n <- c(female = 26458L, male = 28662L)
  expect_error(moon_check_params(p), "`cohort_n`")
})

test_that("init_prev shape and sum errors", {
  p <- .good_params(); p$init_prev <- c(NW = 1, OW = 0, OB1 = 0)  # length 3
  expect_error(moon_check_params(p), "`init_prev`.*length-4")

  p <- .good_params(); p$init_prev <- setNames(c(0.9, 0.05, 0.04, 0.01),
                                               c("N", "OW", "OB1", "OB2"))
  expect_error(moon_check_params(p), "`init_prev` names")

  p <- .good_params(); p$init_prev <- c(NW = 0.5, OW = 0.5, OB1 = 0.5, OB2 = 0.5)
  expect_error(moon_check_params(p), "`init_prev` must sum to 1")
})

test_that("structural type errors on key fields", {
  p <- .good_params(); p$qx <- as.numeric(p$qx)  # drop names
  expect_error(moon_check_params(p), "`qx` must be a named numeric")

  p <- .good_params(); p$mortality_hr <- as.list(p$mortality_hr)
  expect_error(moon_check_params(p), "`mortality_hr` must be a data frame")

  p <- .good_params(); p$transition_probs <- as.list(p$transition_probs)
  expect_error(moon_check_params(p), "`transition_probs` must be a data frame")

  p <- .good_params(); p$cost_df <- as.list(p$cost_df)
  expect_error(moon_check_params(p), "`cost_df` must be a data frame")
})

test_that("missing required columns in data-frame fields error", {
  p <- .good_params(); p$transition_probs$NW_OW <- NULL
  expect_error(moon_check_params(p), "`transition_probs` is missing column")

  p <- .good_params(); p$mortality_hr$OB2 <- NULL
  expect_error(moon_check_params(p), "`mortality_hr` is missing column")

  p <- .good_params(); p$cost_df$cost <- NULL
  expect_error(moon_check_params(p), "`cost_df` is missing column")
})


# ==============================================================================
# Phase 2 — range checks
# ==============================================================================

test_that("transition probabilities outside [0, 1] error", {
  p <- .good_params(); p$transition_probs$NW_OW[1] <- 1.5
  expect_error(moon_check_params(p), "`transition_probs\\$NW_OW`.*outside \\[0, 1\\]")

  p <- .good_params(); p$transition_probs$OB1_OW[10] <- -0.01
  expect_error(moon_check_params(p), "`transition_probs\\$OB1_OW`.*outside \\[0, 1\\]")
})

test_that("OW row sum > 1 errors with offending ages", {
  p <- .good_params()
  p$transition_probs$OW_NW[5]  <- 0.6
  p$transition_probs$OW_OB1[5] <- 0.5
  expect_error(moon_check_params(p), "OW_NW \\+ OW_OB1 > 1")
})

test_that("OB1 row sum > 1 errors with offending ages", {
  p <- .good_params()
  p$transition_probs$OB1_OW[3]  <- 0.7
  p$transition_probs$OB1_OB2[3] <- 0.4
  expect_error(moon_check_params(p), "OB1_OW \\+ OB1_OB2 > 1")
})

test_that("qx out of [0, 1] errors", {
  p <- .good_params(); p$qx[5] <- 1.5
  expect_error(moon_check_params(p), "`qx` contains values outside \\[0, 1\\]")
})

test_that("non-positive HRs error", {
  p <- .good_params(); p$mortality_hr$OW[1] <- 0
  expect_error(moon_check_params(p), "`mortality_hr\\$OW`")

  p <- .good_params(); p$mortality_hr$OB2[2] <- -1
  expect_error(moon_check_params(p), "`mortality_hr\\$OB2`")
})

test_that("negative costs error", {
  p <- .good_params(); p$cost_df$cost[1] <- -100
  expect_error(moon_check_params(p), "`cost_df\\$cost`.*negative")
})


# ==============================================================================
# Phase 3 — cross-object consistency
# ==============================================================================

test_that("transition_probs ages must cover start_age:(max_age-1)", {
  p <- .good_params()
  # Drop the first row: now ages 3..99 instead of 2..99
  p$transition_probs <- p$transition_probs[-1, , drop = FALSE]
  expect_error(moon_check_params(p), "`transition_probs\\$age` must cover exactly")
})

test_that("qx missing required ages errors", {
  p <- .good_params()
  p$qx <- p$qx[as.integer(names(p$qx)) >= 10]   # drop ages 2..9
  expect_error(moon_check_params(p), "`qx` is missing age")
})

test_that("qx names not coercible to integer errors", {
  p <- .good_params()
  names(p$qx) <- paste0("age", names(p$qx))
  expect_error(moon_check_params(p), "`qx` names must be coercible to integer")
})

test_that("cost_df with wrong state set errors", {
  p <- .good_params()
  p$cost_df <- p$cost_df[p$cost_df$state != "OW", , drop = FALSE]
  expect_error(moon_check_params(p), "`cost_df\\$state` must be exactly")

  p <- .good_params()
  p$cost_df$state[1] <- "EXTRA"
  expect_error(moon_check_params(p), "`cost_df\\$state` must be exactly")
})

test_that("cost_df missing ages within 2..100 errors per state", {
  p <- .good_params()
  # Drop age 50 from OW only
  drop_idx <- which(p$cost_df$state == "OW" & p$cost_df$age == 50)
  p$cost_df <- p$cost_df[-drop_idx, , drop = FALSE]
  expect_error(moon_check_params(p), "`cost_df` for state 'OW' is missing")
})

test_that("mortality_hr$age_lower must be c(35, 50, 70)", {
  p <- .good_params(); p$mortality_hr$age_lower <- c(30, 50, 70)
  expect_error(moon_check_params(p), "`mortality_hr\\$age_lower`")

  p <- .good_params()
  p$mortality_hr <- rbind(p$mortality_hr,
                          data.frame(age_lower = 80, OW = 1, OB1 = 1, OB2 = 1))
  expect_error(moon_check_params(p), "`mortality_hr\\$age_lower`")
})


# ==============================================================================
# strict = FALSE downgrades to warning and returns params unchanged
# ==============================================================================

test_that("strict = FALSE warns instead of erroring and returns params", {
  p <- .good_params(); p$discount_rate <- 1.5
  expect_warning(out <- moon_check_params(p, strict = FALSE),
                 "`discount_rate`")
  expect_identical(out, p)
})

test_that("strict = FALSE on a happy path is silent", {
  p <- .good_params()
  expect_silent(out <- moon_check_params(p, strict = FALSE))
  expect_identical(out, p)
})


# ==============================================================================
# Aggregated error: a single error message covers multiple problems found in
# the same phase, so a sloppy params doesn't hide N-1 issues behind 1.
# ==============================================================================

test_that("multiple problems in one phase are reported together", {
  p <- .good_params()
  p$transition_probs$NW_OW[1] <- 1.5     # range issue
  p$mortality_hr$OW[1]        <- -1      # range issue
  err <- tryCatch(moon_check_params(p), error = function(e) conditionMessage(e))
  expect_match(err, "transition_probs\\$NW_OW")
  expect_match(err, "mortality_hr\\$OW")
})


# ==============================================================================
# Step 4 verification anchor: structural check
# ==============================================================================

test_that("inherits(try(moon_check_params(broken)), 'try-error') for a broken case", {
  p <- .good_params(); p$discount_rate <- 2
  expect_true(inherits(try(moon_check_params(p), silent = TRUE), "try-error"))
})
