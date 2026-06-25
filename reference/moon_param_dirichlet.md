# Dirichlet spec for simplex-valued parameters

For `init_prev` (or any other simplex-valued vector) treated as
uncertain. Sampling uses the Gamma trick: draw `X_j ~ Gamma(alpha_j, 1)`
independently across components, then normalise by row sum.

## Usage

``` r
moon_param_dirichlet(alpha)
```

## Arguments

- alpha:

  Positive numeric vector of Dirichlet concentration parameters (length
  \>= 2). Names, if any, are carried through to the sampled rows.

## Value

A `moon_param_dirichlet` spec object.

## See also

[moon_param-methods](https://dache-sdu.github.io/moon/reference/moon_param-methods.md),
[`moon_param_fixed()`](https://dache-sdu.github.io/moon/reference/moon_param_fixed.md),
[`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md),
[`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md),
[`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md).

## Examples

``` r
d <- moon_param_dirichlet(c(NW = 90, OW = 9, OB1 = 0.7, OB2 = 0.3))
moon_param_value(d)
#>    NW    OW   OB1   OB2 
#> 0.900 0.090 0.007 0.003 
moon_param_sample(d, n = 3)
#>             NW         OW          OB1          OB2
#> [1,] 0.8749659 0.12333483 0.0003092824 1.390010e-03
#> [2,] 0.8979065 0.06706703 0.0349738853 5.256671e-05
#> [3,] 0.9197486 0.08014467 0.0001008460 5.910006e-06
```
