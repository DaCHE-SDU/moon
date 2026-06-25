# Build the full 6 × 6 × n_cycles transition-probability array (vectorised)

Same per-cell formulae as
[`.build_tp_matrix()`](https://dache-sdu.github.io/moon/reference/dot-build_tp_matrix.md)
but populates the entire array in one pass: 17 vector assignments
instead of `17 * n_cycles` scalar assignments, no per-cycle data-frame
row extraction, no dimnames on the inner slabs. State order matches
`.build_tp_matrix`:
`1 = N_always, 2 = N_prev, 3 = OW, 4 = OB1, 5 = OB2, 6 = D`.

## Usage

``` r
.build_tp_array(transition_probs, mort, set_zero = NULL)
```

## Arguments

- transition_probs:

  Data frame with the six per-age transition columns (`NW_OW`, `OW_NW`,
  `OW_OB1`, `OB1_OW`, `OB1_OB2`, `OB2_OB1`).

- mort:

  List from
  [`.build_mortality_vec()`](https://dache-sdu.github.io/moon/reference/dot-build_mortality_vec.md)
  with elements `NW`, `OW`, `OB1`, `OB2`.

- set_zero:

  Optional character vector of transitions to zero out; supported
  values: `"OB1_OB2"`, `"OW_OB1"`.

## Value

`6 × 6 × n_cycles` numeric array, no dimnames.
