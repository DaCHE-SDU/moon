# MOON parameter spec class system

S3 generics dispatched on `moon_param_*` spec classes.
`moon_param_value()` returns the deterministic point value of a spec —
used internally as a safety net when a spec is encountered in a
deterministic context. `moon_param_sample()` returns `n` random draws
and accepts auxiliary shared-randomness vectors (`z` for lognormal HRs,
`u` for gamma costs) so
[`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md)
can reuse one set of random numbers across multiple specs to reproduce
the published MOON "one-world" convention.

## Usage

``` r
moon_param_value(x, ...)

moon_param_sample(x, n, ...)
```

## Arguments

- x:

  A spec object inheriting from `moon_param`.

- ...:

  Additional arguments. Lognormal methods accept `z` (a length-`n`
  [`rnorm()`](https://rdrr.io/r/stats/Normal.html) vector); gamma
  methods accept `u` (a length-`n`
  [`runif()`](https://rdrr.io/r/stats/Uniform.html) vector); both
  default to `NULL`.

- n:

  Integer; number of random draws to generate.

## Value

`moon_param_value()` returns a numeric (vector or scalar depending on
the spec). `moon_param_sample()` returns a length-`n` vector for scalar
specs, or an `n`-row matrix for vector-valued specs.

## Details

When the auxiliary argument is `NULL` (the default) each spec generates
its own independent draws.

## See also

the constructors:
[`moon_param_fixed()`](https://dache-sdu.github.io/moon/reference/moon_param_fixed.md),
[`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md),
[`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md),
[`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md),
[`moon_param_dirichlet()`](https://dache-sdu.github.io/moon/reference/moon_param_dirichlet.md).
