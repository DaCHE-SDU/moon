# test_engine.R
#
# Step 1 unit and integration tests for the pure Markov engine.
# Run from moon/: testthat::test_file("tests/testthat/test_engine.R")
# Or: testthat::test_dir("tests/testthat")
#
# No file I/O. All inputs are constructed in-memory.

source(file.path("..", "..", "R", "utils-engine.R"))
source(file.path("..", "..", "R", "engine.R"))

# ==============================================================================
# Survival functions
# ==============================================================================

test_that("S_lnorm at median equals 0.5", {
  # When t = exp(mu) and sigma=1, log(t)=mu so (log(t)-mu)/sigma = 0 → pnorm(0) = 0.5
  expect_equal(.S_lnorm(exp(0), mu = 0, sigma = 1), 0.5)
  expect_equal(.S_lnorm(exp(2), mu = 2, sigma = 1), 0.5)
})

test_that("S_lnorm is monotone decreasing", {
  vals <- .S_lnorm(1:10, mu = 0, sigma = 1)
  expect_true(all(diff(vals) < 0))
})

test_that("S_weibull_PH at t=0 equals 1", {
  expect_equal(.S_weibull_PH(0, ln_lambda = -1, gamma = 1), 1)
  expect_equal(.S_weibull_PH(0, ln_lambda =  0, gamma = 2), 1)
})

test_that("S_weibull_PH is monotone decreasing for t > 0", {
  vals <- .S_weibull_PH(1:10, ln_lambda = -2, gamma = 1.5)
  expect_true(all(diff(vals) < 0))
})

test_that("S_gompertz_PH at t=0 equals 1", {
  # expm1(0) = 0 so exp(-(exp(ln_lambda)/gamma)*0) = 1
  expect_equal(.S_gompertz_PH(0, ln_lambda = -1, gamma = 0.01), 1)
})

test_that("S_loglogistic at t=0 equals 1", {
  # 1 / (1 + (exp(-lambda)*0)^(1/gamma)) = 1/(1+0) = 1
  expect_equal(.S_loglogistic(0, lambda = 0, gamma = 1), 1)
})

test_that(".tp_from_survival returns values in [0, 1]", {
  p <- .tp_from_survival("lnorm", theta = c(0, log(1)), cycles = 0:9)
  expect_true(all(p >= 0 & p <= 1))
})

test_that(".tp_from_survival all four distributions run without error", {
  cycles <- 0:4
  expect_no_error(.tp_from_survival("lnorm",       c(0, 0),   cycles))
  expect_no_error(.tp_from_survival("weibull",     c(-2, 1),  cycles))
  expect_no_error(.tp_from_survival("gompertz",    c(-3, 0.05), cycles))
  expect_no_error(.tp_from_survival("loglogistic", c(0, 1),   cycles))
})


# ==============================================================================
# .build_mortality_vec
# ==============================================================================

.make_hr_df <- function() {
  data.frame(
    age_lower = c(35, 50, 70),
    OW  = c(1.17, 1.11, 0.98),
    OB1 = c(1.90, 1.60, 1.12),
    OB2 = c(3.48, 2.59, 1.63)
  )
}

test_that("HR = 1 for all states when age < 35", {
  qx   <- setNames(rep(0.005, 5), as.character(20:24))
  mort <- .build_mortality_vec(qx, .make_hr_df(), ages = 20:24)
  expect_equal(mort$NW,  mort$OW)
  expect_equal(mort$NW,  mort$OB1)
  expect_equal(mort$NW,  mort$OB2)
})

test_that("HR applied correctly for ages in 35-49 band", {
  qx   <- setNames(0.01, "40")
  mort <- .build_mortality_vec(qx, .make_hr_df(), ages = 40L)
  expect_equal(mort$OW[1],  0.01 * 1.17)
  expect_equal(mort$OB1[1], 0.01 * 1.90)
  expect_equal(mort$OB2[1], 0.01 * 3.48)
})

test_that("HR applied correctly for ages in 50-69 band", {
  qx   <- setNames(0.02, "60")
  mort <- .build_mortality_vec(qx, .make_hr_df(), ages = 60L)
  expect_equal(mort$OW[1],  0.02 * 1.11)
  expect_equal(mort$OB1[1], 0.02 * 1.60)
  expect_equal(mort$OB2[1], 0.02 * 2.59)
})

test_that("70+ band HR used for age 80 and above 89", {
  qx <- setNames(c(0.03, 0.05), c("80", "95"))
  mort <- .build_mortality_vec(qx, .make_hr_df(), ages = c(80L, 95L))
  expect_equal(mort$OW,  c(0.03, 0.05) * 0.98)
  expect_equal(mort$OB1, c(0.03, 0.05) * 1.12)
  expect_equal(mort$OB2, c(0.03, 0.05) * 1.63)
})

test_that("mortality vectors have correct length", {
  qx   <- setNames(rep(0.01, 10), as.character(5:14))
  mort <- .build_mortality_vec(qx, .make_hr_df(), ages = 5:14)
  expect_length(mort$NW,  10)
  expect_length(mort$OW,  10)
  expect_length(mort$OB1, 10)
  expect_length(mort$OB2, 10)
})


# ==============================================================================
# .build_tp_matrix
# ==============================================================================

.make_tp_row <- function() {
  list(NW_OW = 0.10, OW_NW = 0.05, OW_OB1 = 0.05,
       OB1_OW = 0.04, OB1_OB2 = 0.03, OB2_OB1 = 0.02)
}

test_that("transition matrix rows sum to 1", {
  m <- .build_tp_matrix(.make_tp_row(), pN_D = 0.01, pOW_D = 0.01,
                         pOB1_D = 0.01, pOB2_D = 0.01)
  expect_true(all(abs(rowSums(m) - 1) < 1e-12))
})

test_that("all transition matrix entries in [0, 1]", {
  m <- .build_tp_matrix(.make_tp_row(), pN_D = 0.01, pOW_D = 0.012,
                         pOB1_D = 0.015, pOB2_D = 0.02)
  expect_true(all(m >= 0))
  expect_true(all(m <= 1))
})

test_that("D row is absorbing (D -> D = 1)", {
  m <- .build_tp_matrix(.make_tp_row(), pN_D = 0.01, pOW_D = 0.01,
                         pOB1_D = 0.01, pOB2_D = 0.01)
  expect_equal(m["D", "D"], 1)
  expect_equal(sum(m["D", -which(colnames(m) == "D")]), 0)
})

test_that("set_zero OB1_OB2 zeros that entry and rebalances OB1 stay", {
  tp <- .make_tp_row()  # OB1_OB2 = 0.03, OB1_OW = 0.04
  pOB1_D <- 0.01

  m_base     <- .build_tp_matrix(tp, 0.01, 0.01, pOB1_D, 0.01)
  m_override <- .build_tp_matrix(tp, 0.01, 0.01, pOB1_D, 0.01,
                                  set_zero = "OB1_OB2")

  # OB1 -> OB2 is zeroed
  expect_equal(m_override["OB1", "OB2"], 0)
  # OB1 stay = (1 - pOB1_D) * (1 - p_OB1_OW) after zeroing OB1_OB2
  expect_equal(m_override["OB1", "OB1"], (1 - pOB1_D) * (1 - tp$OB1_OW))
  # OB1 -> OW unchanged
  expect_equal(m_override["OB1", "OW"], m_base["OB1", "OW"])
  # Row still sums to 1
  expect_true(abs(rowSums(m_override)["OB1"] - 1) < 1e-12)
})

test_that("set_zero OW_OB1 zeros that entry and rebalances OW stay", {
  tp    <- .make_tp_row()  # OW_OB1 = 0.05, OW_NW = 0.05
  pOW_D <- 0.01

  m_override <- .build_tp_matrix(tp, 0.01, pOW_D, 0.01, 0.01,
                                  set_zero = "OW_OB1")

  expect_equal(m_override["OW", "OB1"], 0)
  expect_equal(m_override["OW", "OW"], (1 - pOW_D) * (1 - tp$OW_NW))
  expect_true(abs(rowSums(m_override)["OW"] - 1) < 1e-12)
})

test_that("set_zero with both OB1_OB2 and OW_OB1", {
  tp <- .make_tp_row()
  m  <- .build_tp_matrix(tp, 0.01, 0.01, 0.01, 0.01,
                          set_zero = c("OB1_OB2", "OW_OB1"))
  expect_equal(m["OB1", "OB2"], 0)
  expect_equal(m["OW",  "OB1"], 0)
  expect_true(all(abs(rowSums(m) - 1) < 1e-12))
})


# ==============================================================================
# .run_markov — unit test
# ==============================================================================

test_that(".run_markov output has correct dimensions and row sums", {
  states <- c("N_always", "N_prev", "OW", "OB1", "OB2", "D")
  n_cyc  <- 5
  tp_arr <- array(0, dim = c(6, 6, n_cyc), dimnames = list(states, states, NULL))
  # Fill a simple identity-like matrix: everyone stays in their state, no death
  for (t in seq_len(n_cyc)) diag(tp_arr[, , t]) <- 1

  init <- c(N_always = 0.5, N_prev = 0.1, OW = 0.2, OB1 = 0.1, OB2 = 0.05, D = 0.05)
  trace <- .run_markov(init, tp_arr)

  expect_equal(dim(trace), c(n_cyc + 1, 6))
  expect_true(all(abs(rowSums(trace) - 1) < 1e-12))
  # With identity TP, all rows should equal the initial vector
  for (r in seq_len(nrow(trace))) {
    expect_equal(unname(trace[r, ]), unname(init))
  }
})


# ==============================================================================
# Full 3-cycle integration test (hand-computed expected values)
# ==============================================================================
#
# Setup:
#   start_age=5, max_age=8  → 3 cycles; all ages 5/6/7 < 35 → HR = 1
#   qx = 0.01 for all ages (so survival = 0.99)
#   init_prev: NW=0.9, OW=0.08, OB1=0.015, OB2=0.005
#   TPs (constant): NW_OW=0.10, OW_NW=0.05, OW_OB1=0.05,
#                   OB1_OW=0.04, OB1_OB2=0.03, OB2_OB1=0.02
#
# Hand-computed cycle 1 state:
#   N_always = 0.9 * 0.99 * 0.90                                   = 0.801900
#   N_prev   = 0.08 * 0.99 * 0.05                                  = 0.003960
#   OW       = 0.9*0.99*0.10 + 0.08*0.99*0.90 + 0.015*0.99*0.04   = 0.160974
#   OB1      = 0.08*0.99*0.05 + 0.015*0.99*0.93 + 0.005*0.99*0.02 = 0.017870 (see below)
#   OB2      = 0.015*0.99*0.03 + 0.005*0.99*0.98                   = 0.005297 (see below)
#   D        = 1.000 * 0.01                                         = 0.010000
#   Sum      = 1.000000
#
# Exact values:
#   OB1 = 0.08*0.0495 + 0.015*0.9207 + 0.005*0.0198
#       = 0.003960 + 0.013811 (=0.015*0.9207 exactly: 0.0138105)
#         + 0.000099 = 0.0178695
#   OB2 = 0.015*0.0297 + 0.005*0.9702
#       = 0.0004455 + 0.004851 = 0.0052965

.make_3cycle_inputs <- function() {
  tp_df <- data.frame(
    age    = 5:7,
    NW_OW  = 0.10, OW_NW  = 0.05, OW_OB1  = 0.05,
    OB1_OW = 0.04, OB1_OB2 = 0.03, OB2_OB1 = 0.02
  )
  qx <- setNames(rep(0.01, 3), c("5", "6", "7"))

  hr_df <- data.frame(
    age_lower = c(35, 50, 70),
    OW = c(1.17, 1.11, 0.98), OB1 = c(1.90, 1.60, 1.12), OB2 = c(3.48, 2.59, 1.63)
  )

  list(tp_df = tp_df, qx = qx, hr_df = hr_df)
}

test_that("3-cycle integration: row sums equal 1 at every cycle", {
  inp <- .make_3cycle_inputs()
  res <- run_markov_engine(
    start_age        = 5L,
    max_age          = 8L,
    discount_rate    = 0,
    init_prev        = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df,
    qx               = inp$qx,
    mortality_hr     = inp$hr_df,
    cost_df          = NULL
  )
  expect_true(all(abs(rowSums(res$trace) - 1) < 1e-12),
              info = paste("Max deviation:", max(abs(rowSums(res$trace) - 1))))
})

test_that("3-cycle integration: cycle 0 equals initial state", {
  inp <- .make_3cycle_inputs()
  res <- run_markov_engine(
    start_age        = 5L,
    max_age          = 8L,
    discount_rate    = 0,
    init_prev        = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df,
    qx               = inp$qx,
    mortality_hr     = inp$hr_df,
    cost_df          = NULL
  )
  tr <- res$trace
  expect_equal(as.numeric(tr[1, "N_always"]), 0.9)
  expect_equal(as.numeric(tr[1, "N_prev"]),   0)
  expect_equal(as.numeric(tr[1, "OW"]),       0.08)
  expect_equal(as.numeric(tr[1, "OB1"]),      0.015)
  expect_equal(as.numeric(tr[1, "OB2"]),      0.005)
  expect_equal(as.numeric(tr[1, "D"]),        0)
})

test_that("3-cycle integration: cycle 1 matches hand-computed values", {
  inp <- .make_3cycle_inputs()
  res <- run_markov_engine(
    start_age        = 5L,
    max_age          = 8L,
    discount_rate    = 0,
    init_prev        = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df,
    qx               = inp$qx,
    mortality_hr     = inp$hr_df,
    cost_df          = NULL
  )
  tr  <- res$trace
  tol <- 1e-12
  expect_equal(as.numeric(tr[2, "N_always"]), 0.801900,   tolerance = tol)
  expect_equal(as.numeric(tr[2, "N_prev"]),   0.003960,   tolerance = tol)
  expect_equal(as.numeric(tr[2, "OW"]),       0.160974,   tolerance = tol)
  expect_equal(as.numeric(tr[2, "OB1"]),      0.0178695,  tolerance = tol)
  expect_equal(as.numeric(tr[2, "OB2"]),      0.0052965,  tolerance = tol)
  expect_equal(as.numeric(tr[2, "D"]),        0.010000,   tolerance = tol)
})

test_that("3-cycle integration: output structure is correct", {
  inp <- .make_3cycle_inputs()
  res <- run_markov_engine(
    start_age = 5L, max_age = 8L, discount_rate = 0,
    init_prev = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df, qx = inp$qx,
    mortality_hr = inp$hr_df, cost_df = NULL
  )
  expect_true(is.list(res))
  expect_true(all(c("trace", "cost_matrix", "mortality") %in% names(res)))
  expect_equal(dim(res$trace), c(4L, 6L))             # 3 cycles + 1 initial
  expect_equal(dim(res$cost_matrix), c(4L, 4L))       # 4 ages (5,6,7,8) x 4 states
  expect_true(is.list(res$mortality))
  expect_true(all(c("NW", "OW", "OB1", "OB2") %in% names(res$mortality)))
  expect_length(res$mortality$NW, 3L)                 # one entry per cycle
})


# ==============================================================================
# tp_overrides: set_zero = "OB1_OB2"
#
# Same 3-cycle setup. Expected after cycle 1 with OB1->OB2 zeroed:
#   OB1 stay = 0.99 * (1 - 0.04) = 0.9504
#   OB1 = 0.08*0.0495 + 0.015*0.9504 + 0.005*0.0198 = 0.018315
#   OB2 = 0 (from OB1) + 0.005*0.99*0.98 = 0.004851
# ==============================================================================

test_that("tp_overrides set_zero OB1_OB2: OB2 reduced, OB1 increased, rows sum to 1", {
  inp <- .make_3cycle_inputs()
  res_base <- run_markov_engine(
    start_age = 5L, max_age = 8L, discount_rate = 0,
    init_prev = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df, qx = inp$qx,
    mortality_hr = inp$hr_df, cost_df = NULL
  )
  res_ov <- run_markov_engine(
    start_age = 5L, max_age = 8L, discount_rate = 0,
    init_prev = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df, qx = inp$qx,
    mortality_hr = inp$hr_df, cost_df = NULL,
    tp_overrides = list(set_zero = "OB1_OB2")
  )
  tol <- 1e-12
  # Row sums still 1 after override
  expect_true(all(abs(rowSums(res_ov$trace) - 1) < 1e-12))
  # OB1 is higher (no mass leaving to OB2)
  expect_gt(as.numeric(res_ov$trace[2, "OB1"]), as.numeric(res_base$trace[2, "OB1"]))
  # OB2 is lower
  expect_lt(as.numeric(res_ov$trace[2, "OB2"]), as.numeric(res_base$trace[2, "OB2"]))
  # Hand-computed values
  expect_equal(as.numeric(res_ov$trace[2, "OB1"]), 0.018315, tolerance = tol)
  expect_equal(as.numeric(res_ov$trace[2, "OB2"]), 0.004851, tolerance = tol)
})

test_that("tp_overrides init_prev overrides initial state", {
  inp <- .make_3cycle_inputs()
  new_init <- c(NW = 1, OW = 0, OB1 = 0, OB2 = 0)
  res <- run_markov_engine(
    start_age = 5L, max_age = 8L, discount_rate = 0,
    init_prev = c(NW = 0.9, OW = 0.08, OB1 = 0.015, OB2 = 0.005),
    transition_probs = inp$tp_df, qx = inp$qx,
    mortality_hr = inp$hr_df, cost_df = NULL,
    tp_overrides = list(init_prev = new_init)
  )
  expect_equal(as.numeric(res$trace[1, "N_always"]), 1)
  expect_equal(as.numeric(res$trace[1, "OW"]),       0)
})
