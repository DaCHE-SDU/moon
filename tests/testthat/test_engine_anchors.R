# test_engine_anchors.R
#
# Verify the engine reproduces the canonical-code anchor numbers when fed
# loader-built `params` from moon_params_norway(). All numeric assertions
# anchor on tests/testthat/fixtures/{sex}/deterministic/anchors.rds + cohort_trace_det.rds,
# regenerated from the same R/ code under test (so a deviation flags an
# unintended engine change, not paper drift).
#
# Helpers (.find_moon_root, .run_base, .run_sa2, .calc_inc_cost, .calc_LE,
# .calc_prev45) live in helper-fixtures.R, auto-loaded by testthat.

.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")

.engine_params <- list(
  female = moon_params_norway("female", data_dir = .test_data_dir),
  male   = moon_params_norway("male",   data_dir = .test_data_dir),
  both   = moon_params_norway("both",   data_dir = .test_data_dir)
)

.read_anchors <- function(sex_long) {
  readRDS(testthat::test_path("fixtures", sex_long,
                              "deterministic", "anchors.rds"))
}

.read_trace_ref <- function(sex_long) {
  readRDS(testthat::test_path("fixtures", sex_long,
                              "deterministic", "cohort_trace_det.rds"))
}


# ==============================================================================
# Bit-level: engine trace matches the regenerated reference per sex.
# ==============================================================================

invisible(lapply(c("female", "male", "both"), function(sex_long) {
  test_that(sprintf("engine trace is bit-identical to reference (%s)", sex_long), {
    res <- .run_base(.engine_params[[sex_long]])
    ref <- .read_trace_ref(sex_long)
    expect_equal(dim(res$trace), dim(ref))
    expect_equal(unname(res$trace), unname(ref), tolerance = 1e-10)
  })
}))


# ==============================================================================
# Anchor A — cumulative undiscounted incremental cost OW+OB1+OB2 vs NW
# Bit-level vs anchors$inc_cost_undisc$total per sex.
# ==============================================================================

invisible(lapply(c("female", "male", "both"), function(sex_long) {
  test_that(sprintf("anchor A: cumulative undiscounted incremental cost (%s)", sex_long), {
    inc <- .calc_inc_cost(.run_base(.engine_params[[sex_long]]))
    expected <- .read_anchors(sex_long)$inc_cost_undisc$total
    expect_equal(inc, expected, tolerance = 1e-9)
  })
}))


# ==============================================================================
# Anchor B — YLL from full obesity elimination (SA2: zero OW->OB1, redistribute
# initial OB1+OB2 mass into OW). Bit-level vs anchors$yll_obboth_undisc per sex.
# ==============================================================================

invisible(lapply(c("female", "male", "both"), function(sex_long) {
  test_that(sprintf("anchor B: YLL from OB1+OB2 elimination (%s)", sex_long), {
    p   <- .engine_params[[sex_long]]
    yll <- .calc_LE(.run_sa2(p)) - .calc_LE(.run_base(p))
    expected <- .read_anchors(sex_long)$yll_obboth_undisc
    expect_equal(yll, expected, tolerance = 1e-10)
  })
}))


# ==============================================================================
# Anchor C — OW prevalence at age 45 among alive. Bit-level vs
# anchors$prev_ow_age45 per sex. (Trace row 1 = age 2, so age 45 is row 44.)
# ==============================================================================

invisible(lapply(c("female", "male", "both"), function(sex_long) {
  test_that(sprintf("anchor C: OW prevalence at age 45 (%s)", sex_long), {
    prev45 <- .calc_prev45(.run_base(.engine_params[[sex_long]]))
    expected <- .read_anchors(sex_long)$prev_ow_age45
    expect_equal(prev45, expected, tolerance = 1e-10)
  })
}))
