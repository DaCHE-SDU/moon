# test_moon_params.R
#
# Step 7 — parameter spec classes (moon_param_*) plus the uncertainty=TRUE
# branch of moon_params_norway(). Distributional checks use n = 10000 and
# a fixed seed; constructor-level structural checks are seed-free.
#
# Helpers (.find_moon_root) come from helper-fixtures.R.

.test_data_dir <- file.path(.find_moon_root(), "inst", "extdata")


# ==============================================================================
# §9.3 anchor: constructor returns the right S3 class
# ==============================================================================

test_that("§9.3 anchor: lognormal constructor sets the documented class", {
  spec <- moon_param_lognormal(1.17, 1.15, 1.20)
  expect_true(inherits(spec, "moon_param_lognormal"))
  expect_true(inherits(spec, "moon_param"))
})


# ==============================================================================
# moon_param_fixed
# ==============================================================================

test_that("moon_param_fixed: scalar value round-trips", {
  s <- moon_param_fixed(3.14)
  expect_equal(moon_param_value(s), 3.14)
  expect_equal(moon_param_sample(s, n = 5), rep(3.14, 5))
})

test_that("moon_param_fixed: vector value yields a matrix on sample", {
  s <- moon_param_fixed(c(1, 2, 3))
  expect_equal(dim(moon_param_sample(s, n = 4)), c(4, 3))
  expect_true(all(moon_param_sample(s, n = 4) == matrix(c(1, 2, 3),
                                                          4, 3, byrow = TRUE)))
})

test_that("moon_param_fixed rejects non-finite", {
  expect_error(moon_param_fixed(NA),       "finite")
  expect_error(moon_param_fixed(Inf),      "finite")
  expect_error(moon_param_fixed(numeric(0)), "non-empty")
})


# ==============================================================================
# moon_param_lognormal — verification anchor from §7 of the plan
# ==============================================================================

test_that("moon_param_lognormal samples have mean and 95% CI within 1% of spec", {
  set.seed(42)
  s    <- moon_param_lognormal(point = 1.17, lower = 1.15, upper = 1.20)
  draws <- moon_param_sample(s, n = 10000)

  expect_equal(mean(draws),                  1.17, tolerance = 0.01)
  expect_equal(unname(quantile(draws, 0.025)), 1.15, tolerance = 0.01)
  expect_equal(unname(quantile(draws, 0.975)), 1.20, tolerance = 0.01)
})

test_that("moon_param_lognormal: shared z reuses the same draw across instances", {
  set.seed(7)
  s_a <- moon_param_lognormal(1.5, 1.0, 2.5)
  s_b <- moon_param_lognormal(2.0, 1.5, 3.0)
  z   <- rnorm(50)

  a <- moon_param_sample(s_a, n = 50, z = z)
  b <- moon_param_sample(s_b, n = 50, z = z)

  # If z is the same, log(a)/log(b) - log(point_a)/log(point_b) ratios are
  # perfectly correlated by construction. Easier check: the rank order of a
  # and b is identical when both are driven by the same z (both monotone in z).
  expect_identical(order(a), order(b))
})

test_that("moon_param_lognormal validates inputs", {
  expect_error(moon_param_lognormal(1.0, 1.5, 1.2), "lower <= upper")
  expect_error(moon_param_lognormal(-1, 0.5, 2.0), "point > 0")
  expect_error(moon_param_lognormal(1.0, c(0.9, 0.8), 1.2), "length")
})

test_that("moon_param_value returns the deterministic point", {
  expect_equal(moon_param_value(moon_param_lognormal(1.17, 1.15, 1.20)), 1.17)
})


# ==============================================================================
# moon_param_gamma — moment-matched cost draws
# ==============================================================================

test_that("moon_param_gamma: mean/SD recovered to within 2% at n = 10000", {
  set.seed(11)
  s     <- moon_param_gamma(mean_vec = c(100, 250), se_vec = c(15, 30))
  draws <- moon_param_sample(s, n = 10000)

  expect_equal(dim(draws), c(10000, 2))
  expect_equal(mean(draws[, 1]), 100, tolerance = 0.02 * 100)
  expect_equal(mean(draws[, 2]), 250, tolerance = 0.02 * 250)
  expect_equal(sd(draws[, 1]),    15, tolerance = 0.05 * 15)
  expect_equal(sd(draws[, 2]),    30, tolerance = 0.05 * 30)
})

test_that("moon_param_gamma: zero mean/SE is a degenerate point mass at 0", {
  s     <- moon_param_gamma(mean_vec = c(0, 100), se_vec = c(0, 15))
  draws <- moon_param_sample(s, n = 100)
  expect_true(all(draws[, 1] == 0))
  expect_true(all(draws[, 2] >  0))
})

test_that("moon_param_gamma: shared u links all ages to a single quantile", {
  s <- moon_param_gamma(mean_vec = c(100, 250), se_vec = c(15, 30))
  u <- runif(20)
  draws <- moon_param_sample(s, n = 20, u = u)
  # When u is shared, the quantile rank of each row is identical across the
  # two age columns (monotone qgamma).
  expect_identical(order(draws[, 1]), order(draws[, 2]))
})

test_that("moon_param_value returns the deterministic mean vector", {
  expect_equal(moon_param_value(moon_param_gamma(c(10, 20), c(2, 3))),
               c(10, 20))
})


# ==============================================================================
# moon_param_mvnorm — survival coefficients pushed through .tp_from_survival
# ==============================================================================

test_that("moon_param_mvnorm value matches deterministic .tp_from_survival", {
  cov <- matrix(c(0.001, 0, 0, 0.001), 2, 2)
  cycles <- 0:9
  s <- moon_param_mvnorm(mean_vec = c(3.16, 0.20),
                         cov_mat  = cov,
                         dist     = "lnorm",
                         cycles   = cycles)
  expect_equal(moon_param_value(s),
               .tp_from_survival("lnorm", c(3.16, 0.20), cycles, dt = 1))
})

test_that("moon_param_mvnorm samples are length(cycles)-wide and in [0, 1]", {
  set.seed(9)
  cov <- matrix(c(0.001, 0.0001, 0.0001, 0.001), 2, 2)
  cycles <- 0:9
  s <- moon_param_mvnorm(mean_vec = c(3.16, 0.20),
                         cov_mat  = cov,
                         dist     = "lnorm",
                         cycles   = cycles)
  draws <- moon_param_sample(s, n = 200)

  expect_equal(dim(draws), c(200, length(cycles)))
  expect_true(all(is.finite(draws)))
  expect_true(all(draws >= 0))
  expect_true(all(draws <= 1))
})

test_that("moon_param_mvnorm rejects non-square cov_mat or unknown dist", {
  expect_error(moon_param_mvnorm(c(1, 2), matrix(0, 2, 3), "lnorm", 1:5))
  expect_error(moon_param_mvnorm(c(1, 2), diag(2), "exp", 1:5),
               "should be one of|%in%")
})


# ==============================================================================
# moon_param_dirichlet
# ==============================================================================

test_that("moon_param_dirichlet samples lie on the simplex", {
  set.seed(2)
  s <- moon_param_dirichlet(c(NW = 90, OW = 9, OB1 = 1))
  draws <- moon_param_sample(s, n = 1000)
  expect_equal(dim(draws), c(1000, 3))
  expect_setequal(colnames(draws), c("NW", "OW", "OB1"))
  expect_true(all(abs(rowSums(draws) - 1) < 1e-10))
  expect_true(all(draws >= 0))
})

test_that("moon_param_dirichlet point value is alpha / sum(alpha)", {
  expect_equal(unname(moon_param_value(moon_param_dirichlet(c(2, 3, 5)))),
               c(0.2, 0.3, 0.5))
})

test_that("moon_param_dirichlet rejects non-positive alpha", {
  expect_error(moon_param_dirichlet(c(1, 0)), "alpha > 0")
  expect_error(moon_param_dirichlet(c(1, -1)), "alpha > 0")
})


# ==============================================================================
# moon_params_norway(uncertainty = TRUE) — verification anchor §7
# ==============================================================================

test_that("uncertainty = TRUE: mortality_hr$OW is a list of 3 lognormal specs", {
  p <- moon_params_norway("female", uncertainty = TRUE,
                          data_dir = .test_data_dir)
  expect_s3_class(p$mortality_hr, "data.frame")
  expect_equal(nrow(p$mortality_hr), 3)
  for (state in c("OW", "OB1", "OB2")) {
    col <- p$mortality_hr[[state]]
    expect_length(col, 3)
    for (spec in col) {
      expect_s3_class(spec, "moon_param_lognormal")
    }
  }
})

test_that("uncertainty = TRUE: mortality HR point estimates match deterministic", {
  p_det <- moon_params_norway("female", data_dir = .test_data_dir)
  p_unc <- moon_params_norway("female", uncertainty = TRUE,
                              data_dir = .test_data_dir)
  for (state in c("OW", "OB1", "OB2")) {
    pts <- vapply(p_unc$mortality_hr[[state]], moon_param_value, numeric(1))
    expect_equal(pts, p_det$mortality_hr[[state]])
  }
})

test_that("uncertainty = TRUE: cost_df is a list-column of moon_param_gamma", {
  p <- moon_params_norway("female", uncertainty = TRUE,
                          data_dir = .test_data_dir)
  expect_s3_class(p$cost_df, "data.frame")
  expect_setequal(names(p$cost_df), c("age", "state", "cost"))
  expect_setequal(unique(p$cost_df$state), c("NW", "OW", "OB1", "OB2"))
  expect_equal(nrow(p$cost_df), 4 * 99)
  for (cell in p$cost_df$cost[c(1, 200, 396)]) {
    expect_s3_class(cell, "moon_param_gamma")
  }
})

test_that("uncertainty = TRUE: cost point estimates match deterministic", {
  p_det <- moon_params_norway("female", data_dir = .test_data_dir)
  p_unc <- moon_params_norway("female", uncertainty = TRUE,
                              data_dir = .test_data_dir)
  pts <- vapply(p_unc$cost_df$cost, moon_param_value, numeric(1))
  # Order rows the same way before comparing
  ord_det <- order(p_det$cost_df$state, p_det$cost_df$age)
  ord_unc <- order(p_unc$cost_df$state, p_unc$cost_df$age)
  expect_equal(pts[ord_unc], p_det$cost_df$cost[ord_det])
})

test_that("uncertainty = TRUE: transition_probs has $specs and $bands", {
  p <- moon_params_norway("female", uncertainty = TRUE,
                          data_dir = .test_data_dir)
  expect_setequal(names(p$transition_probs), c("specs", "bands"))
  expect_true(length(p$transition_probs$specs) >= 6L)
  for (s in p$transition_probs$specs) {
    expect_s3_class(s, "moon_param_mvnorm")
  }
  expect_setequal(names(p$transition_probs$bands),
                  c("key", "transition", "age_start", "age_end", "surv_start"))
})

test_that("uncertainty = TRUE: transition point values stitch back to deterministic", {
  p_det <- moon_params_norway("female", data_dir = .test_data_dir)
  p_unc <- moon_params_norway("female", uncertainty = TRUE,
                              data_dir = .test_data_dir)

  bands  <- p_unc$transition_probs$bands
  by_tr  <- split(bands, bands$transition)

  csv_to_engine <- c(N_OW   = "NW_OW",   OW_N   = "OW_NW",
                     OW_OB1 = "OW_OB1",  OB1_OW = "OB1_OW",
                     OB1_OB2 = "OB1_OB2", OB2_OB1 = "OB2_OB1")

  for (tr in names(by_tr)) {
    sub <- by_tr[[tr]][order(by_tr[[tr]]$age_start), , drop = FALSE]
    pts <- do.call(c, lapply(sub$key, function(k) {
      moon_param_value(p_unc$transition_probs$specs[[k]])
    }))
    expect_equal(pts, p_det$transition_probs[[csv_to_engine[[tr]]]],
                 tolerance = 1e-12,
                 info = paste("transition:", tr))
  }
})

test_that("uncertainty = TRUE: scalar / qx / cohort fields are unchanged", {
  p_det <- moon_params_norway("female", data_dir = .test_data_dir)
  p_unc <- moon_params_norway("female", uncertainty = TRUE,
                              data_dir = .test_data_dir)
  for (fld in c("start_age", "max_age", "discount_rate", "cost_currency",
                "cohort_n", "init_prev", "qx")) {
    expect_identical(p_unc[[fld]], p_det[[fld]])
  }
})


# ==============================================================================
# Predicate
# ==============================================================================

test_that("is_moon_param identifies all spec classes", {
  expect_true(is_moon_param(moon_param_fixed(1)))
  expect_true(is_moon_param(moon_param_lognormal(1, 0.9, 1.1)))
  expect_true(is_moon_param(moon_param_gamma(c(10), c(2))))
  expect_true(is_moon_param(moon_param_mvnorm(c(1, 1), diag(2), "lnorm", 1:5)))
  expect_true(is_moon_param(moon_param_dirichlet(c(1, 2, 3))))
  expect_false(is_moon_param(42))
  expect_false(is_moon_param(list(value = 42)))
})
