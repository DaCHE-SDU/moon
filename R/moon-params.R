#' MOON parameter spec class system
#'
#' S3 generics dispatched on `moon_param_*` spec classes.
#' `moon_param_value()` returns the deterministic point value of a spec —
#' used internally as a safety net when a spec is encountered in a
#' deterministic context. `moon_param_sample()` returns `n` random draws and
#' accepts auxiliary shared-randomness vectors (`z` for lognormal HRs, `u`
#' for gamma costs) so [moon_sample_params()] can reuse one set of random
#' numbers across multiple specs to reproduce the published MOON
#' "one-world" convention.
#'
#' When the auxiliary argument is `NULL` (the default) each spec generates
#' its own independent draws.
#'
#' @param x A spec object inheriting from `moon_param`.
#' @param n Integer; number of random draws to generate.
#' @param ... Additional arguments. Lognormal methods accept `z` (a
#'   length-`n` `rnorm()` vector); gamma methods accept `u` (a length-`n`
#'   `runif()` vector); both default to `NULL`.
#'
#' @return `moon_param_value()` returns a numeric (vector or scalar
#'   depending on the spec). `moon_param_sample()` returns a length-`n`
#'   vector for scalar specs, or an `n`-row matrix for vector-valued specs.
#'
#' @seealso the constructors: [moon_param_fixed()], [moon_param_lognormal()],
#'   [moon_param_gamma()], [moon_param_mvnorm()], [moon_param_dirichlet()].
#'
#' @name moon_param-methods
NULL

#' @rdname moon_param-methods
#' @export
moon_param_value  <- function(x, ...) UseMethod("moon_param_value")

#' @rdname moon_param-methods
#' @export
moon_param_sample <- function(x, n, ...) UseMethod("moon_param_sample")


#' Spec for a value that is uncertain in principle but pinned for this run
#'
#' Useful for specs you don't yet have data for, or for ablations that pin
#' one input while varying the rest. `moon_param_sample()` returns `n`
#' copies of `value`.
#'
#' @param value Finite numeric. Scalar or vector.
#'
#' @return A `moon_param_fixed` spec object.
#'
#' @seealso [moon_param-methods], [moon_param_lognormal()],
#'   [moon_param_gamma()], [moon_param_mvnorm()], [moon_param_dirichlet()].
#'
#' @examples
#' p <- moon_param_fixed(1.5)
#' moon_param_value(p)
#' moon_param_sample(p, n = 3)
#'
#' @export
moon_param_fixed <- function(value) {
  if (length(value) == 0L || any(!is.finite(value))) {
    stop("`value` must be finite and non-empty.")
  }
  structure(list(value = value),
            class = c("moon_param_fixed", "moon_param"))
}

#' @export
moon_param_value.moon_param_fixed <- function(x, ...) x$value

#' @export
moon_param_sample.moon_param_fixed <- function(x, n, ...) {
  if (length(x$value) == 1L) rep(x$value, n)
  else                       matrix(x$value, n, length(x$value), byrow = TRUE)
}


#' Lognormal spec from a point estimate and a 95% confidence interval
#'
#' Used for mortality hazard ratios. `log_se` is derived from the CI bounds:
#' `log_se = (log(upper) - log(lower)) / (2 * 1.96)`. `log_mean = log(point)`,
#' so the lognormal's *median* equals the published point estimate (the mean
#' is `point * exp(0.5 * log_se^2)`, slightly larger).
#'
#' @param point Numeric, the point estimate (median of the lognormal).
#' @param lower,upper Numeric, the lower and upper bounds of the 95% CI.
#'   Both must be positive and `lower <= upper`.
#'
#' @return A `moon_param_lognormal` spec object.
#'
#' @seealso [moon_param-methods], [moon_param_fixed()],
#'   [moon_param_gamma()], [moon_param_mvnorm()].
#'
#' @examples
#' hr <- moon_param_lognormal(point = 1.45, lower = 1.30, upper = 1.62)
#' moon_param_value(hr)
#' moon_param_sample(hr, n = 5)
#'
#' @export
moon_param_lognormal <- function(point, lower, upper) {
  stopifnot(
    is.numeric(point), is.numeric(lower), is.numeric(upper),
    length(point) == 1L, length(lower) == 1L, length(upper) == 1L,
    is.finite(point), is.finite(lower), is.finite(upper),
    lower > 0, upper > 0, point > 0,
    lower <= upper
  )
  log_se <- (log(upper) - log(lower)) / (2 * 1.96)
  structure(
    list(point = point, lower = lower, upper = upper,
         log_mean = log(point), log_se = log_se),
    class = c("moon_param_lognormal", "moon_param")
  )
}

#' @export
moon_param_value.moon_param_lognormal <- function(x, ...) x$point

#' @export
moon_param_sample.moon_param_lognormal <- function(x, n, z = NULL, ...) {
  if (is.null(z)) z <- stats::rnorm(n)
  if (length(z) != n) stop("`z` must have length n.")
  exp(x$log_mean + z * x$log_se)
}


#' Moment-matched gamma spec from per-cell means and standard errors
#'
#' Used for per-capita health-care costs. Each cell uses a gamma with
#' `shape = (mean / se)^2` and `scale = se^2 / mean`. Degenerate cells where
#' `mean == 0` or `se == 0` (e.g. ages 2–19 in the bundled cost CSVs) are
#' returned as deterministic 0 rather than NaN.
#'
#' @param mean_vec Non-negative numeric vector of per-cell means.
#' @param se_vec Non-negative numeric vector of per-cell standard errors,
#'   the same length as `mean_vec`.
#'
#' @return A `moon_param_gamma` spec object.
#'
#' @seealso [moon_param-methods], [moon_param_fixed()],
#'   [moon_param_lognormal()], [moon_param_mvnorm()].
#'
#' @examples
#' g <- moon_param_gamma(mean_vec = c(0, 100, 250), se_vec = c(0, 30, 60))
#' moon_param_value(g)
#' moon_param_sample(g, n = 5)
#'
#' @export
moon_param_gamma <- function(mean_vec, se_vec) {
  stopifnot(
    is.numeric(mean_vec), is.numeric(se_vec),
    length(mean_vec) == length(se_vec),
    all(is.finite(mean_vec)), all(is.finite(se_vec)),
    all(mean_vec >= 0), all(se_vec >= 0)
  )
  structure(
    list(mean_vec = as.numeric(mean_vec),
         se_vec   = as.numeric(se_vec)),
    class = c("moon_param_gamma", "moon_param")
  )
}

#' @export
moon_param_value.moon_param_gamma <- function(x, ...) x$mean_vec

#' @export
moon_param_sample.moon_param_gamma <- function(x, n, u = NULL, ...) {
  k <- length(x$mean_vec)
  if (!is.null(u) && length(u) != n) stop("`u` must have length n.")
  out <- matrix(0, nrow = n, ncol = k)
  for (j in seq_len(k)) {
    m <- x$mean_vec[j]; s <- x$se_vec[j]
    if (m == 0 || s == 0) next   # degenerate -> already zeros
    shape <- (m / s) ^ 2
    scale <- s ^ 2 / m
    u_j <- if (is.null(u)) stats::runif(n) else u
    out[, j] <- stats::qgamma(u_j, shape = shape, scale = scale)
  }
  out
}


#' Multivariate-normal spec for survival-model coefficients
#'
#' Used for transition-probability coefficient vectors fitted to parametric
#' survival models. Stores the mean coefficient vector, its covariance, the
#' parametric distribution name, and the per-band age vector so that a draw
#' can be pushed through the same `.tp_from_survival()` pipeline used by the
#' deterministic loader (Cholesky decomposition of the covariance matrix).
#'
#' @param mean_vec Numeric coefficient vector (length k).
#' @param cov_mat k-by-k covariance matrix.
#' @param dist Character; one of `"lnorm"`, `"weibull"`, `"gompertz"`,
#'   `"loglogistic"`.
#' @param cycles Numeric vector of ages (cycles) at which to evaluate the
#'   resulting per-cycle transition probability.
#'
#' @return A `moon_param_mvnorm` spec object.
#'
#' @seealso [moon_param-methods], [moon_param_fixed()],
#'   [moon_param_lognormal()], [moon_param_gamma()].
#'
#' @export
moon_param_mvnorm <- function(mean_vec, cov_mat, dist, cycles) {
  valid_dists <- c("lnorm", "weibull", "gompertz", "loglogistic")
  stopifnot(
    is.numeric(mean_vec), length(mean_vec) >= 1L,
    is.matrix(cov_mat),
    nrow(cov_mat) == ncol(cov_mat),
    nrow(cov_mat) == length(mean_vec),
    is.character(dist), length(dist) == 1L, dist %in% valid_dists,
    is.numeric(cycles), length(cycles) >= 1L
  )
  structure(
    list(mean_vec = as.numeric(mean_vec),
         cov_mat  = cov_mat,
         dist     = dist,
         cycles   = as.numeric(cycles)),
    class = c("moon_param_mvnorm", "moon_param")
  )
}

#' @export
moon_param_value.moon_param_mvnorm <- function(x, ...) {
  .tp_from_survival(x$dist, x$mean_vec, x$cycles, dt = 1)
}

#' @export
moon_param_sample.moon_param_mvnorm <- function(x, n, ...) {
  k <- length(x$mean_vec)
  L <- tryCatch(chol(x$cov_mat),
                error = function(e) stop(
                  "Cholesky factorisation of cov_mat failed: ",
                  conditionMessage(e)))
  Z      <- matrix(stats::rnorm(n * k), n, k)
  thetas <- sweep(Z %*% L, 2, x$mean_vec, `+`)   # n x k coefficient draws
  out <- matrix(0, n, length(x$cycles))
  for (i in seq_len(n)) {
    out[i, ] <- .tp_from_survival(x$dist, thetas[i, ], x$cycles, dt = 1)
  }
  out
}


#' Dirichlet spec for simplex-valued parameters
#'
#' For `init_prev` (or any other simplex-valued vector) treated as
#' uncertain. Sampling uses the Gamma trick: draw
#' `X_j ~ Gamma(alpha_j, 1)` independently across components, then
#' normalise by row sum.
#'
#' @param alpha Positive numeric vector of Dirichlet concentration
#'   parameters (length >= 2). Names, if any, are carried through to the
#'   sampled rows.
#'
#' @return A `moon_param_dirichlet` spec object.
#'
#' @seealso [moon_param-methods], [moon_param_fixed()],
#'   [moon_param_lognormal()], [moon_param_gamma()],
#'   [moon_param_mvnorm()].
#'
#' @examples
#' d <- moon_param_dirichlet(c(NW = 90, OW = 9, OB1 = 0.7, OB2 = 0.3))
#' moon_param_value(d)
#' moon_param_sample(d, n = 3)
#'
#' @export
moon_param_dirichlet <- function(alpha) {
  stopifnot(
    is.numeric(alpha),
    length(alpha) >= 2L,
    all(is.finite(alpha)),
    all(alpha > 0)
  )
  if (!is.null(names(alpha))) names(alpha) <- as.character(names(alpha))
  structure(list(alpha = alpha),
            class = c("moon_param_dirichlet", "moon_param"))
}

#' @export
moon_param_value.moon_param_dirichlet <- function(x, ...) {
  out <- x$alpha / sum(x$alpha)
  if (!is.null(names(x$alpha))) names(out) <- names(x$alpha)
  out
}

#' @export
moon_param_sample.moon_param_dirichlet <- function(x, n, ...) {
  k <- length(x$alpha)
  gammas <- matrix(0, n, k)
  for (j in seq_len(k)) {
    gammas[, j] <- stats::rgamma(n, shape = x$alpha[j], rate = 1)
  }
  out <- gammas / rowSums(gammas)
  if (!is.null(names(x$alpha))) colnames(out) <- names(x$alpha)
  out
}


#' Test whether an object is a MOON parameter spec
#'
#' @param x Object to test.
#' @return `TRUE` if `x` inherits from class `"moon_param"`, otherwise `FALSE`.
#' @keywords internal
is_moon_param <- function(x) inherits(x, "moon_param")
