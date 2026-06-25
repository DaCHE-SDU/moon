# Moment-matched gamma spec from per-cell means and standard errors

Used for per-capita health-care costs. Each cell uses a gamma with
`shape = (mean / se)^2` and `scale = se^2 / mean`. Degenerate cells
where `mean == 0` or `se == 0` (e.g. ages 2–19 in the bundled cost CSVs)
are returned as deterministic 0 rather than NaN.

## Usage

``` r
moon_param_gamma(mean_vec, se_vec)
```

## Arguments

- mean_vec:

  Non-negative numeric vector of per-cell means.

- se_vec:

  Non-negative numeric vector of per-cell standard errors, the same
  length as `mean_vec`.

## Value

A `moon_param_gamma` spec object.

## See also

[moon_param-methods](https://dache-sdu.github.io/moon/reference/moon_param-methods.md),
[`moon_param_fixed()`](https://dache-sdu.github.io/moon/reference/moon_param_fixed.md),
[`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md),
[`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md).

## Examples

``` r
g <- moon_param_gamma(mean_vec = c(0, 100, 250), se_vec = c(0, 30, 60))
moon_param_value(g)
#> [1]   0 100 250
moon_param_sample(g, n = 5)
#>      [,1]      [,2]     [,3]
#> [1,]    0 120.41935 217.7763
#> [2,]    0 183.88477 193.8120
#> [3,]    0 163.82680 249.9470
#> [4,]    0  88.95688 244.2717
#> [5,]    0  94.17294 293.7731
```
