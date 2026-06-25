# Lognormal spec from a point estimate and a 95% confidence interval

Used for mortality hazard ratios. `log_se` is derived from the CI
bounds: `log_se = (log(upper) - log(lower)) / (2 * 1.96)`.
`log_mean = log(point)`, so the lognormal's *median* equals the
published point estimate (the mean is `point * exp(0.5 * log_se^2)`,
slightly larger).

## Usage

``` r
moon_param_lognormal(point, lower, upper)
```

## Arguments

- point:

  Numeric, the point estimate (median of the lognormal).

- lower, upper:

  Numeric, the lower and upper bounds of the 95% CI. Both must be
  positive and `lower <= upper`.

## Value

A `moon_param_lognormal` spec object.

## See also

[moon_param-methods](https://dache-sdu.github.io/moon/reference/moon_param-methods.md),
[`moon_param_fixed()`](https://dache-sdu.github.io/moon/reference/moon_param_fixed.md),
[`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md),
[`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md).

## Examples

``` r
hr <- moon_param_lognormal(point = 1.45, lower = 1.30, upper = 1.62)
moon_param_value(hr)
#> [1] 1.45
moon_param_sample(hr, n = 5)
#> [1] 1.384237 1.331971 1.528173 1.464438 1.469972
```
