# Phase 2 — range checks

Each numeric slot's values lie inside its documented domain. Assumes the
structural schema is intact.

## Usage

``` r
.check_ranges(params)
```

## Arguments

- params:

  A `params` list.

## Value

Character vector of problem messages (length 0 on success).
