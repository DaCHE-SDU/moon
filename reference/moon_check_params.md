# Validate a MOON `params` list

Three-phase structural / range / cross-object validation of a `params`
list. Returns the input invisibly so the call can be chained:
`moon_deterministic(moon_check_params(params))`.

## Usage

``` r
moon_check_params(params, strict = TRUE)
```

## Arguments

- params:

  A `params` list to validate.

- strict:

  If `TRUE` (the default; what
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  uses internally) any problem raises an error listing every issue found
  in the active phase. If `FALSE` the same message is downgraded to a
  warning and `params` is returned unchanged, so the caller can decide
  whether to proceed.

## Value

`invisible(params)`.

## Details

Phase 1 (cheap structural checks — types, names, scalar ranges)
short-circuits the rest: range and consistency checks assume the schema
is intact, so reporting them on a structurally broken `params` would add
noise. Phases 2 (range checks: values inside domain bounds) and 3
(cross-object consistency: ages line up across fields) are run together,
and any messages are reported in one batch.

## See also

[`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md)
for the canonical builder,
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
which calls `moon_check_params()` internally.

## Examples

``` r
# \donttest{
params <- moon_params_norway(sex = "female")
moon_check_params(params)
# }
```
