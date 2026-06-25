# Aggregate cohort costs by age, state, sex, or total

Aggregates the `$costs` slot of a
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
object over a single grouping variable. For multi-variable groupings,
run twice or build your own
[`aggregate()`](https://rdrr.io/r/stats/aggregate.html) call against
`as.data.frame(x, what = "costs")`.

## Usage

``` r
moon_costs(
  x,
  by = c("age", "state", "sex", "total"),
  discounted = FALSE,
  ages = NULL
)
```

## Arguments

- x:

  A
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  object.

- by:

  One of `"age"`, `"state"`, `"sex"`, `"total"`. `"total"` returns a
  length-1 numeric (the grand total).

- discounted:

  `FALSE` (default) sums `$cost`; `TRUE` sums `$cost_disc`.

- ages:

  Optional integer vector to filter; `NULL` (default) returns all ages.

## Value

A data frame with columns `<by>` and `cost`, except for `by = "total"`
which returns a length-1 numeric.

## See also

[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md),
[`moon_prevalence()`](https://dache-sdu.github.io/moon/reference/moon_prevalence.md).

## Examples

``` r
# \donttest{
params <- moon_params_norway(sex = "female")
run    <- moon_deterministic(params)
moon_costs(run, by = "state")
#>      state       cost
#> 1 N_always  584363548
#> 2   N_prev  307381370
#> 3      OB1  815463456
#> 4      OB2  334218808
#> 5       OW 1049400463
moon_costs(run, by = "total", discounted = TRUE)
#> [1] 435536655
# }
```
