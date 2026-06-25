# Multivariate-normal spec for survival-model coefficients

Used for transition-probability coefficient vectors fitted to parametric
survival models. Stores the mean coefficient vector, its covariance, the
parametric distribution name, and the per-band age vector so that a draw
can be pushed through the same
[`.tp_from_survival()`](https://dache-sdu.github.io/moon/reference/dot-tp_from_survival.md)
pipeline used by the deterministic loader (Cholesky decomposition of the
covariance matrix).

## Usage

``` r
moon_param_mvnorm(mean_vec, cov_mat, dist, cycles)
```

## Arguments

- mean_vec:

  Numeric coefficient vector (length k).

- cov_mat:

  k-by-k covariance matrix.

- dist:

  Character; one of `"lnorm"`, `"weibull"`, `"gompertz"`,
  `"loglogistic"`.

- cycles:

  Numeric vector of ages (cycles) at which to evaluate the resulting
  per-cycle transition probability.

## Value

A `moon_param_mvnorm` spec object.

## See also

[moon_param-methods](https://dache-sdu.github.io/moon/reference/moon_param-methods.md),
[`moon_param_fixed()`](https://dache-sdu.github.io/moon/reference/moon_param_fixed.md),
[`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md),
[`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md).
