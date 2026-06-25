# Run the Markov loop over all cycles

Run the Markov loop over all cycles

## Usage

``` r
.run_markov(init, tp_array)
```

## Arguments

- init:

  Numeric of length 6 (initial state proportions, sums to 1).

- tp_array:

  `6 × 6 × n_cycles` array of per-cycle transition matrices. Dimnames
  are not required and are not propagated to the output; callers that
  want named columns should set them afterwards.

## Value

`(n_cycles + 1) × 6` numeric matrix; rows sum to 1 within floating-point
error.
