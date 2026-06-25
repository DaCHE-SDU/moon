# Build the deterministic engine's per-age `transition_probs` data frame

For each band, builds the `band_cycles` vector via
`seq(start_val, by, length.out)`, calls
[`.tp_from_survival()`](https://dache-sdu.github.io/moon/reference/dot-tp_from_survival.md),
then stitches per-band probability vectors per transition (ordered by
`age_start`) and asserts the resulting age sequence covers
`start_age:(max_age - 1)` contiguously. CSV transition labels (`N_OW`,
`OW_N`, …) are renamed to engine column names (`NW_OW`, `OW_NW`, …).

## Usage

``` r
.build_transition_probs(df_params, start_age, max_age, dt = 1)
```

## Arguments

- df_params:

  Raw transition-parameter data frame, e.g. from
  [`.read_transition_params()`](https://dache-sdu.github.io/moon/reference/dot-read_transition_params.md).

- start_age, max_age:

  Bounds of the age sequence (inclusive of `start_age`, exclusive of
  `max_age`).

- dt:

  Cycle length; default 1.

## Value

Data frame with columns `age`, `NW_OW`, `OW_NW`, `OW_OB1`, `OB1_OW`,
`OB1_OB2`, `OB2_OB1`.
