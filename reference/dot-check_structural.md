# Phase 1 — structural checks

Type / name / scalar-range checks that can be performed without
examining the values inside the slots. Failure short-circuits range and
consistency checks (which assume the schema is intact).

## Usage

``` r
.check_structural(params)
```

## Arguments

- params:

  A `params` list.

## Value

Character vector of problem messages (length 0 on success).
