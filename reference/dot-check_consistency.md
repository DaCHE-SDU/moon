# Phase 3 — cross-object consistency

Ages line up across `transition_probs`, `qx`, `cost_df`, and the
`mortality_hr` bands. Assumes structure and ranges are intact.

## Usage

``` r
.check_consistency(params)
```

## Arguments

- params:

  A `params` list.

## Value

Character vector of problem messages (length 0 on success).
