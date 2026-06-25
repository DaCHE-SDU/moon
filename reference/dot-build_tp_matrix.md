# Build the 6 × 6 transition probability matrix for one Markov cycle

Build the 6 × 6 transition probability matrix for one Markov cycle

## Usage

``` r
.build_tp_matrix(tp_row, pN_D, pOW_D, pOB1_D, pOB2_D, set_zero = NULL)
```

## Arguments

- tp_row:

  Named numeric with keys `NW_OW`, `OW_NW`, `OW_OB1`, `OB1_OW`,
  `OB1_OB2`, `OB2_OB1`.

- pN_D, pOW_D, pOB1_D, pOB2_D:

  Scalar mortality probabilities for the NW, OW, OB1, OB2 states this
  cycle.

- set_zero:

  Optional character vector of transitions to zero out; supported
  values: `"OB1_OB2"`, `"OW_OB1"`.

## Value

6 × 6 numeric matrix with dimnames
`c("N_always", "N_prev", "OW", "OB1", "OB2", "D")`.
