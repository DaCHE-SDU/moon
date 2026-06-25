# Spec for a value that is uncertain in principle but pinned for this run

Useful for specs you don't yet have data for, or for ablations that pin
one input while varying the rest.
[`moon_param_sample()`](https://dache-sdu.github.io/moon/reference/moon_param-methods.md)
returns `n` copies of `value`.

## Usage

``` r
moon_param_fixed(value)
```

## Arguments

- value:

  Finite numeric. Scalar or vector.

## Value

A `moon_param_fixed` spec object.

## See also

[moon_param-methods](https://dache-sdu.github.io/moon/reference/moon_param-methods.md),
[`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md),
[`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md),
[`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md),
[`moon_param_dirichlet()`](https://dache-sdu.github.io/moon/reference/moon_param_dirichlet.md).

## Examples

``` r
p <- moon_param_fixed(1.5)
moon_param_value(p)
#> [1] 1.5
moon_param_sample(p, n = 3)
#> [1] 1.5 1.5 1.5
```
