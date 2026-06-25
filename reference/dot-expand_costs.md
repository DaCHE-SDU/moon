# Expand a tidy cost data frame into a per-age cost matrix

Ages without a cost row receive value 0. Both `N_always` and `N_prev`
should use the `NW` column.

## Usage

``` r
.expand_costs(cost_df, ages)
```

## Arguments

- cost_df:

  Data frame with columns `age` (integer), `state` (`NW` / `OW` / `OB1`
  / `OB2`), `cost`. May be `NULL` or zero-row.

- ages:

  Integer vector of ages to fill (length `n_cycles + 1`).

## Value

Numeric matrix with columns `NW`, `OW`, `OB1`, `OB2`; rows correspond to
`ages`.
