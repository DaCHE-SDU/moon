# Run a deterministic MOON simulation

Runs the MOON Markov cohort model once with the supplied parameters,
returning a tidy `moon_deterministic` object containing the per-age
state trace, per-age per-state costs, the validated parameters, and run
metadata.

## Usage

``` r
moon_deterministic(
  params,
  tp_overrides = NULL,
  strict = TRUE,
  record_meta = TRUE
)
```

## Arguments

- params:

  A `params` list as returned by
  [`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md).
  Must pass
  [`moon_check_params()`](https://dache-sdu.github.io/moon/reference/moon_check_params.md)
  with `strict = TRUE`.

- tp_overrides:

  Optional named list of overrides applied at engine entry. Supported
  slots:

  - `set_zero` — character vector of transitions to zero out across all
    ages, e.g. `"OW_OB1"`.

  - `init_prev` — replaces the initial-state vector.

  - `start_age` — shifts the cohort entry age. The engine selects rows
    of `transition_probs` by positional index, so callers shifting
    `start_age` must also supply correspondingly subset
    `transition_probs` / `qx` / `cost_df`.

- strict:

  Passed through to
  [`moon_check_params()`](https://dache-sdu.github.io/moon/reference/moon_check_params.md);
  `TRUE` (the default) halts on any validation failure.

- record_meta:

  Logical, default `TRUE`. When `FALSE` the returned `meta` list is
  reduced to the fields that downstream methods need (`iter`, `seed`,
  `horizon`, `discount_rate`, `tp_overrides`) and the per-call
  `moon_version` / `run_time` / `duration_sec` / `cycle_length` fields
  are skipped.
  [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
  sets this to `FALSE` to strip a few percent of per-iteration overhead;
  ordinary single-run callers should leave it `TRUE`.

## Value

A `moon_deterministic` S3 object — a list with

- `trace` — long data frame `(age, sex, state, n)` of head-counts across
  the six engine states (`N_always`, `N_prev`, `OW`, `OB1`, `OB2`,
  `dead`).

- `costs` — long data frame `(age, sex, state, cost, cost_disc)` of
  total annual cohort costs by state, with `cost_disc` discounted at
  `params$discount_rate`. No `dead` rows.

- `params` — the validated input parameters.

- `meta` — run metadata (timestamps, horizon, discount rate, etc.).

## Details

Single-sex per call: the sex label is read from `names(params$cohort_n)`
(one of `"female"`, `"male"`, `"both"`). For sex-stratified results, run
twice and concatenate the trace / costs rows downstream.

## Initial-state mapping

MOON's engine internally distinguishes two normal-weight states:
`N_always` (currently NW, never previously OW or OB) and `N_prev`
(currently NW but previously overweight or obese at some earlier age).
These are conflated in the user-facing `init_prev` parameter, which is a
4-vector `c(NW, OW, OB1, OB2)`.

**Default mapping**: all NW initial mass is placed in `N_always` and
`N_prev` starts at 0. Both states then evolve independently per the
engine's six-state transition matrix; mass flows into `N_prev` only as
OW / OB1 / OB2 individuals regress to NW during the simulation.

This reflects the published MOON model (Bjørnelv et al. 2021), where the
Norwegian birth cohort enters at age 2 with no obesity history.

**Overriding the default**: there is no separate `init_n_always_share`
argument. Instead, supply a full six-element initial-state vector via
`tp_overrides$init_prev`; the engine uses it verbatim and skips the
4-to-6 mapping. Example, for a hypothetical cohort whose NW members had
previously been overweight:

    tp_overrides = list(
      init_prev = c(N_always = 0.5, N_prev = 0.4,
                    OW = 0.07, OB1 = 0.02, OB2 = 0.01, D = 0)
    )

**Pairing with `start_age`**: `init_prev` is the BMI distribution at the
cohort entry age. If you shift the entry age — by mutating
`params$start_age` or by passing `tp_overrides$start_age` — also supply
a matching `init_prev` (mutate `params$init_prev` for the former, pass
`tp_overrides$init_prev` for the latter), or the cohort will enter at
the new age with the wrong BMI distribution. The validator cannot catch
this. See
[`vignette("moon-customizing", package = "moon")`](https://dache-sdu.github.io/moon/articles/moon-customizing.md)
§6 for the bootstrap recipe.

## See also

[`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
for probabilistic uncertainty,
[`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md)
for the bundled Norwegian parameters, and
[`run_markov_engine()`](https://dache-sdu.github.io/moon/reference/run_markov_engine.md)
for direct access to the underlying pure engine.

## Examples

``` r
# \donttest{
params <- moon_params_norway(sex = "female")
run    <- moon_deterministic(params)
head(run$trace)
#>   age    sex    state        n
#> 1   2 female N_always 23766.62
#> 2   3 female N_always 23647.83
#> 3   4 female N_always 23244.80
#> 4   5 female N_always 22671.03
#> 5   6 female N_always 22014.88
#> 6   7 female N_always 21327.79
head(run$costs)
#>   age    sex    state cost cost_disc
#> 1   2 female N_always    0         0
#> 2   3 female N_always    0         0
#> 3   4 female N_always    0         0
#> 4   5 female N_always    0         0
#> 5   6 female N_always    0         0
#> 6   7 female N_always    0         0
# }
```
