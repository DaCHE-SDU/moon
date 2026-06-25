# Materialise a spec'd `params` list into `n` concrete draws

Walks a spec'd `params` list (typically from
`moon_params_norway(uncertainty = TRUE)`) and materialises `n` fully
concrete `params` lists ready for
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md).

## Usage

``` r
moon_sample_params(
  spec,
  n,
  seed = NULL,
  correlate_hr = TRUE,
  correlate_cost = TRUE
)
```

## Arguments

- spec:

  A spec'd `params` list, typically from
  `moon_params_norway(uncertainty = TRUE)`.

- n:

  Integer; number of iterations to materialise.

- seed:

  Integer (or `NULL`); calls `set.seed(seed)` before drawing so the
  resulting list is reproducible.

- correlate_hr, correlate_cost:

  Logical; see Details. Both default to `TRUE` to match the published
  analysis.

## Value

A length-`n` list of plain-value `params` lists, each ready for
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md).

## Details

Two correlation flags reproduce the published MOON conventions:

- `correlate_hr` (default `TRUE`) — one `rnorm(n)` draw is reused as the
  Z-source for all 9 mortality-HR lognormals (3 states × 3 age bands).

- `correlate_cost` (default `TRUE`) — one `runif(n)` draw is reused as
  the inverse-CDF input for every cost gamma.

When a flag is `FALSE`, each spec generates its own independent draws.
Within a single call (with a fixed `seed`) the RNG order is HR `z` →
cost `u` → transition-coefficient mvnorm draws (in order of band-key).
The order is stable across calls but is not expected to match the legacy
MOON port byte-for-byte.

## See also

[`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md),
[`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md),
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md).

## Examples

``` r
# \donttest{
spec  <- moon_params_norway(sex = "female", uncertainty = TRUE)
draws <- moon_sample_params(spec, n = 5, seed = 1)
length(draws)
#> [1] 5
# }
```
