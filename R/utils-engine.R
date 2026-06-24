#' Lognormal survivor function S(t)
#'
#' @param t Numeric vector of times.
#' @param mu Numeric scalar; lognormal location parameter.
#' @param sigma Numeric scalar; lognormal scale parameter.
#' @return Numeric vector the same length as `t`.
#' @keywords internal
.S_lnorm <- function(t, mu, sigma) {
  1 - stats::pnorm((log(t) - mu) / sigma)
}

#' Weibull (proportional-hazards parameterisation) survivor function S(t)
#'
#' @param t Numeric vector of times.
#' @param ln_lambda Numeric scalar; log of the rate parameter.
#' @param gamma Numeric scalar; shape parameter.
#' @return Numeric vector the same length as `t`.
#' @keywords internal
.S_weibull_PH <- function(t, ln_lambda, gamma) {
  exp(-exp(ln_lambda) * (t ^ gamma))
}

#' Gompertz (proportional-hazards parameterisation) survivor function S(t)
#'
#' @param t Numeric vector of times.
#' @param ln_lambda Numeric scalar; log of the rate parameter.
#' @param gamma Numeric scalar; shape parameter.
#' @return Numeric vector the same length as `t`.
#' @keywords internal
.S_gompertz_PH <- function(t, ln_lambda, gamma) {
  exp(-(exp(ln_lambda) / gamma) * expm1(gamma * t))
}

#' Log-logistic survivor function S(t)
#'
#' @param t Numeric vector of times.
#' @param lambda Numeric scalar; rate parameter on the log scale (the
#'   survivor uses `exp(-lambda)`).
#' @param gamma Numeric scalar; shape parameter.
#' @return Numeric vector the same length as `t`.
#' @keywords internal
.S_loglogistic <- function(t, lambda, gamma) {
  1 / (1 + (exp(-lambda) * t) ^ (1 / gamma))
}


#' Convert survival-model parameters into per-cycle transition probabilities
#'
#' Computes `1 - S(t + dt) / S(t)` for each `t` in `cycles`, dispatching on
#' the parametric distribution name.
#'
#' @param dist One of `"lnorm"`, `"weibull"`, `"gompertz"`, `"loglogistic"`.
#' @param theta Numeric vector of length 2; coefficient parameters whose
#'   meaning depends on `dist`.
#' @param cycles Numeric vector of times at which to evaluate the
#'   per-cycle probability.
#' @param dt Cycle length; default 1.
#' @return Numeric vector the same length as `cycles`.
#' @keywords internal
.tp_from_survival <- function(dist, theta, cycles, dt = 1) {
  switch(dist,
    lnorm = {
      mu <- theta[1]; sigma <- exp(theta[2])
      S_t  <- .S_lnorm(cycles,      mu, sigma)
      S_t1 <- .S_lnorm(cycles + dt, mu, sigma)
    },
    weibull = {
      ln_lambda <- theta[1]; gamma <- max(theta[2], 1e-10)
      S_t  <- .S_weibull_PH(cycles,      ln_lambda, gamma)
      S_t1 <- .S_weibull_PH(cycles + dt, ln_lambda, gamma)
    },
    gompertz = {
      ln_lambda <- theta[1]; gamma <- theta[2]
      S_t  <- .S_gompertz_PH(cycles,      ln_lambda, gamma)
      S_t1 <- .S_gompertz_PH(cycles + dt, ln_lambda, gamma)
    },
    loglogistic = {
      lambda <- theta[1]; gamma <- max(theta[2], 1e-10)
      S_t  <- .S_loglogistic(cycles,      lambda, gamma)
      S_t1 <- .S_loglogistic(cycles + dt, lambda, gamma)
    },
    stop("Unknown distribution: ", dist)
  )
  1 - (S_t1 / S_t)
}


#' Build state-specific mortality probability vectors from baseline `qx` and HRs
#'
#' Applies age-band-specific mortality hazard ratios to the baseline NW
#' mortality vector `qx`. Banding: `age < 35` uses HR = 1;
#' `35 <= age < 50` uses the row where `age_lower == 35`;
#' `50 <= age < 70` uses `age_lower == 50`;
#' `age >= 70` uses `age_lower == 70` (the same band is used above age 89).
#'
#' @param qx Named numeric of NW mortality probabilities; names are ages
#'   as character.
#' @param mortality_hr Data frame with columns `age_lower`, `OW`, `OB1`,
#'   `OB2` (three rows).
#' @param ages Integer vector of model ages to process.
#' @return List with elements `NW`, `OW`, `OB1`, `OB2`, each a numeric
#'   vector the length of `ages`.
#' @keywords internal
.build_mortality_vec <- function(qx, mortality_hr, ages) {
  n <- length(ages)
  v_NW  <- numeric(n)
  v_OW  <- numeric(n)
  v_OB1 <- numeric(n)
  v_OB2 <- numeric(n)

  hr35 <- mortality_hr[mortality_hr$age_lower == 35, , drop = TRUE]
  hr50 <- mortality_hr[mortality_hr$age_lower == 50, , drop = TRUE]
  hr70 <- mortality_hr[mortality_hr$age_lower == 70, , drop = TRUE]

  age_chars <- as.character(ages)

  for (i in seq_len(n)) {
    age <- ages[i]
    p_nw <- qx[age_chars[i]]

    if (age < 35) {
      hr_ow <- 1; hr_ob1 <- 1; hr_ob2 <- 1
    } else if (age < 50) {
      hr_ow <- hr35$OW; hr_ob1 <- hr35$OB1; hr_ob2 <- hr35$OB2
    } else if (age < 70) {
      hr_ow <- hr50$OW; hr_ob1 <- hr50$OB1; hr_ob2 <- hr50$OB2
    } else {
      hr_ow <- hr70$OW; hr_ob1 <- hr70$OB1; hr_ob2 <- hr70$OB2
    }

    v_NW[i]  <- p_nw
    v_OW[i]  <- p_nw * hr_ow
    v_OB1[i] <- p_nw * hr_ob1
    v_OB2[i] <- p_nw * hr_ob2
  }

  list(NW = v_NW, OW = v_OW, OB1 = v_OB1, OB2 = v_OB2)
}


#' Build the 6 × 6 transition probability matrix for one Markov cycle
#'
#' @param tp_row Named numeric with keys `NW_OW`, `OW_NW`, `OW_OB1`,
#'   `OB1_OW`, `OB1_OB2`, `OB2_OB1`.
#' @param pN_D,pOW_D,pOB1_D,pOB2_D Scalar mortality probabilities for the
#'   NW, OW, OB1, OB2 states this cycle.
#' @param set_zero Optional character vector of transitions to zero out;
#'   supported values: `"OB1_OB2"`, `"OW_OB1"`.
#' @return 6 × 6 numeric matrix with dimnames
#'   `c("N_always", "N_prev", "OW", "OB1", "OB2", "D")`.
#' @keywords internal
.build_tp_matrix <- function(tp_row, pN_D, pOW_D, pOB1_D, pOB2_D,
                              set_zero = NULL) {
  states <- c("N_always", "N_prev", "OW", "OB1", "OB2", "D")
  m <- matrix(0, nrow = 6, ncol = 6, dimnames = list(states, states))

  p_NW_OW   <- tp_row[["NW_OW"]]
  p_OW_NW   <- tp_row[["OW_NW"]]
  p_OW_OB1  <- tp_row[["OW_OB1"]]
  p_OB1_OW  <- tp_row[["OB1_OW"]]
  p_OB1_OB2 <- tp_row[["OB1_OB2"]]
  p_OB2_OB1 <- tp_row[["OB2_OB1"]]

  if ("OB1_OB2" %in% set_zero) p_OB1_OB2 <- 0
  if ("OW_OB1"  %in% set_zero) p_OW_OB1  <- 0

  surv_N   <- 1 - pN_D
  surv_OW  <- 1 - pOW_D
  surv_OB1 <- 1 - pOB1_D
  surv_OB2 <- 1 - pOB2_D

  # From N_always
  m["N_always", "D"]        <- pN_D
  m["N_always", "OW"]       <- surv_N * p_NW_OW
  m["N_always", "N_always"] <- surv_N * (1 - p_NW_OW)

  # From N_prev (same mortality and NW->OW probability, but targets N_prev for stay)
  m["N_prev", "D"]      <- pN_D
  m["N_prev", "OW"]     <- surv_N * p_NW_OW
  m["N_prev", "N_prev"] <- surv_N * (1 - p_NW_OW)

  # From OW
  m["OW", "D"]      <- pOW_D
  m["OW", "N_prev"] <- surv_OW * p_OW_NW
  m["OW", "OB1"]    <- surv_OW * p_OW_OB1
  m["OW", "OW"]     <- surv_OW * (1 - p_OW_NW - p_OW_OB1)

  # From OB1
  m["OB1", "D"]   <- pOB1_D
  m["OB1", "OW"]  <- surv_OB1 * p_OB1_OW
  m["OB1", "OB2"] <- surv_OB1 * p_OB1_OB2
  m["OB1", "OB1"] <- surv_OB1 * (1 - p_OB1_OW - p_OB1_OB2)

  # From OB2
  m["OB2", "D"]   <- pOB2_D
  m["OB2", "OB1"] <- surv_OB2 * p_OB2_OB1
  m["OB2", "OB2"] <- surv_OB2 * (1 - p_OB2_OB1)

  # Dead (absorbing)
  m["D", "D"] <- 1

  m
}


#' Run the Markov loop over all cycles
#'
#' @param init Numeric of length 6 (initial state proportions, sums to 1).
#' @param tp_array `6 × 6 × n_cycles` array of per-cycle transition
#'   matrices. Dimnames are not required and are not propagated to the
#'   output; callers that want named columns should set them afterwards.
#' @return `(n_cycles + 1) × 6` numeric matrix; rows sum to 1 within
#'   floating-point error.
#' @keywords internal
.run_markov <- function(init, tp_array) {
  n_cycles <- dim(tp_array)[3]
  m_M <- matrix(0, nrow = n_cycles + 1, ncol = 6)
  m_M[1, ] <- init
  for (t in seq_len(n_cycles)) {
    m_M[t + 1, ] <- m_M[t, ] %*% tp_array[, , t]
  }
  m_M
}


#' Build the full 6 × 6 × n_cycles transition-probability array (vectorised)
#'
#' Same per-cell formulae as [.build_tp_matrix()] but populates the entire
#' array in one pass: 17 vector assignments instead of `17 * n_cycles`
#' scalar assignments, no per-cycle data-frame row extraction, no dimnames
#' on the inner slabs. State order matches `.build_tp_matrix`:
#' `1 = N_always, 2 = N_prev, 3 = OW, 4 = OB1, 5 = OB2, 6 = D`.
#'
#' @param transition_probs Data frame with the six per-age transition
#'   columns (`NW_OW`, `OW_NW`, `OW_OB1`, `OB1_OW`, `OB1_OB2`, `OB2_OB1`).
#' @param mort List from [.build_mortality_vec()] with elements `NW`, `OW`,
#'   `OB1`, `OB2`.
#' @param set_zero Optional character vector of transitions to zero out;
#'   supported values: `"OB1_OB2"`, `"OW_OB1"`.
#' @return `6 × 6 × n_cycles` numeric array, no dimnames.
#' @keywords internal
.build_tp_array <- function(transition_probs, mort, set_zero = NULL) {
  # Pull columns once as plain numeric vectors -- avoids 98x data.frame row
  # extraction inside the inner loop.
  p_NW_OW   <- transition_probs$NW_OW
  p_OW_NW   <- transition_probs$OW_NW
  p_OW_OB1  <- transition_probs$OW_OB1
  p_OB1_OW  <- transition_probs$OB1_OW
  p_OB1_OB2 <- transition_probs$OB1_OB2
  p_OB2_OB1 <- transition_probs$OB2_OB1
  n_cycles  <- length(p_NW_OW)

  if ("OB1_OB2" %in% set_zero) p_OB1_OB2 <- numeric(n_cycles)
  if ("OW_OB1"  %in% set_zero) p_OW_OB1  <- numeric(n_cycles)

  pN_D   <- mort$NW
  pOW_D  <- mort$OW
  pOB1_D <- mort$OB1
  pOB2_D <- mort$OB2

  surv_N   <- 1 - pN_D
  surv_OW  <- 1 - pOW_D
  surv_OB1 <- 1 - pOB1_D
  surv_OB2 <- 1 - pOB2_D

  a <- array(0, dim = c(6, 6, n_cycles))

  # Row 1: N_always
  a[1, 1, ] <- surv_N * (1 - p_NW_OW)
  a[1, 3, ] <- surv_N * p_NW_OW
  a[1, 6, ] <- pN_D
  # Row 2: N_prev (same dynamics as N_always but stays in N_prev)
  a[2, 2, ] <- surv_N * (1 - p_NW_OW)
  a[2, 3, ] <- surv_N * p_NW_OW
  a[2, 6, ] <- pN_D
  # Row 3: OW
  a[3, 2, ] <- surv_OW * p_OW_NW
  a[3, 3, ] <- surv_OW * (1 - p_OW_NW - p_OW_OB1)
  a[3, 4, ] <- surv_OW * p_OW_OB1
  a[3, 6, ] <- pOW_D
  # Row 4: OB1
  a[4, 3, ] <- surv_OB1 * p_OB1_OW
  a[4, 4, ] <- surv_OB1 * (1 - p_OB1_OW - p_OB1_OB2)
  a[4, 5, ] <- surv_OB1 * p_OB1_OB2
  a[4, 6, ] <- pOB1_D
  # Row 5: OB2
  a[5, 4, ] <- surv_OB2 * p_OB2_OB1
  a[5, 5, ] <- surv_OB2 * (1 - p_OB2_OB1)
  a[5, 6, ] <- pOB2_D
  # Row 6: D (absorbing)
  a[6, 6, ] <- 1

  a
}


#' Expand a tidy cost data frame into a per-age cost matrix
#'
#' Ages without a cost row receive value 0. Both `N_always` and `N_prev`
#' should use the `NW` column.
#'
#' @param cost_df Data frame with columns `age` (integer), `state`
#'   (`NW` / `OW` / `OB1` / `OB2`), `cost`. May be `NULL` or zero-row.
#' @param ages Integer vector of ages to fill (length `n_cycles + 1`).
#' @return Numeric matrix with columns `NW`, `OW`, `OB1`, `OB2`; rows
#'   correspond to `ages`.
#' @keywords internal
.expand_costs <- function(cost_df, ages) {
  mat <- matrix(0, nrow = length(ages), ncol = 4,
                dimnames = list(NULL, c("NW", "OW", "OB1", "OB2")))

  if (is.null(cost_df) || nrow(cost_df) == 0) return(mat)

  for (st in c("NW", "OW", "OB1", "OB2")) {
    rows <- cost_df[cost_df$state == st, , drop = FALSE]
    if (nrow(rows) == 0) next
    matched <- match(ages, rows$age)
    valid   <- !is.na(matched)
    mat[valid, st] <- rows$cost[matched[valid]]
  }

  mat
}
