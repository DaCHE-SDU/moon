# Compute prevalence by age and state from a deterministic run

Returns a long data frame with one row per `(age, [sex,] state)` and a
`prevalence` column. The state set carries the engine's six-state space
(`N_always`, `N_prev`, `OW`, `OB1`, `OB2`, `dead`).

## Usage

``` r
moon_prevalence(
  x,
  denominator = c("alive", "initial"),
  ages = NULL,
  by_sex = FALSE
)
```

## Arguments

- x:

  A
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  object.

- denominator:

  `"alive"` (default) or `"initial"`.

- ages:

  Optional integer vector to filter; `NULL` (default) returns all ages.

- by_sex:

  `FALSE` (default) drops the `sex` column from the output; `TRUE` keeps
  it. Each `moon_deterministic` object is single-sex by construction, so
  this only matters for downstream multi-sex stitched objects.

## Value

A long data frame with columns `age`, optionally `sex`, `state`, and
`prevalence`.

## Details

Choice of denominator:

- `"alive"` — denominator is the per-age sum of head-counts over alive
  states. Prevalence sums to 1 per age. The `dead` state is dropped from
  the output.

- `"initial"` — denominator is `params$cohort_n` (constant). Prevalence
  sums to 1 per age **once the `dead` row is included**, since `dead`
  drains the live ones.

## See also

[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md),
[`moon_costs()`](https://dache-sdu.github.io/moon/reference/moon_costs.md).

## Examples

``` r
# \donttest{
params <- moon_params_norway(sex = "female")
run    <- moon_deterministic(params)
head(moon_prevalence(run, ages = 40:45))
#>   age    state prevalence
#> 1  40 N_always 0.35373080
#> 2  40   N_prev 0.12802946
#> 4  40      OB1 0.11659027
#> 5  40      OB2 0.04581782
#> 3  40       OW 0.35583165
#> 6  41 N_always 0.33911773
# }
```
