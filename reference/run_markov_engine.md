# Run the raw MOON Markov engine

Low-level pure-function entry point to the MOON Markov cohort engine.
Most users should call
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
instead, which builds and validates the inputs and returns tidy output.
`run_markov_engine()` is exported for advanced sensitivity-analysis
workflows that need direct access to the engine's six-state trace and
per-capita cost matrix.

## Usage

``` r
run_markov_engine(
  start_age,
  max_age,
  discount_rate,
  init_prev,
  transition_probs,
  qx,
  mortality_hr,
  cost_df,
  tp_overrides = NULL
)
```

## Arguments

- start_age:

  Integer; first model age (e.g. `2`).

- max_age:

  Integer; one past the last model age (e.g. `100`).
  `n_cycles = max_age - start_age`.

- discount_rate:

  Numeric in `[0, 1)`; applied to `cost_matrix` only.

- init_prev:

  Named numeric `c(NW = ..., OW = ..., OB1 = ..., OB2 = ...)` summing
  to 1. All `NW` mass enters the engine as `N_always`; `N_prev` starts
  at 0.

- transition_probs:

  Data frame with columns
  `age, NW_OW, OW_OB1, OB1_OB2, OW_NW, OB1_OW, OB2_OB1` — one row per
  age in `start_age:(max_age - 1)`.

- qx:

  Named numeric vector of NW baseline mortality probabilities; names are
  ages as character.

- mortality_hr:

  Data frame with columns `age_lower, OW, OB1, OB2` (three rows, one per
  age band 35 / 50 / 70).

- cost_df:

  Data frame with columns `age, state` (`NW` / `OW` / `OB1` / `OB2`),
  `cost`. Single-sex, already filtered. `NULL` or zero-row for no costs.

- tp_overrides:

  Optional list. Supported slots: `set_zero` (character vector of
  transitions to zero out), `init_prev` (overrides `init_prev`),
  `start_age` (overrides `start_age`).

## Value

A list with

- `trace` — `(n_cycles + 1) x 6` matrix of state proportions (rows sum
  to 1).

- `cost_matrix` — `(n_cycles + 1) x 4` matrix of per-capita costs by
  `(age, state)`.

- `mortality` — list of mortality probability vectors per state (`NW`,
  `OW`, `OB1`, `OB2`).

## Details

The engine is pure: identical inputs produce byte-identical outputs. No
I/O, no global state, no
[`set.seed()`](https://rdrr.io/r/base/Random.html) calls.

## See also

[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
for the validated-input wrapper most users want.

## Examples

``` r
# \donttest{
params <- moon_params_norway(sex = "female")
out <- run_markov_engine(
  start_age        = params$start_age,
  max_age          = params$max_age,
  discount_rate    = params$discount_rate,
  init_prev        = params$init_prev,
  transition_probs = params$transition_probs,
  qx               = params$qx,
  mortality_hr     = params$mortality_hr,
  cost_df          = params$cost_df
)
dim(out$trace)
#> [1] 99  6
# }
```
