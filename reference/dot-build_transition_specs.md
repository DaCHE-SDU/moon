# Build the spec'd transition-parameter list for the uncertainty path

Mirror of
[`.build_transition_probs()`](https://dache-sdu.github.io/moon/reference/dot-build_transition_probs.md)
for the `uncertainty = TRUE` branch of
[`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md).
Produces `moon_param_mvnorm` specs instead of plain probability vectors.
CSV transition labels (`N_OW`, `OW_N`, …) are kept verbatim here; the
rename to engine column names happens at stitch time in
[`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md).

## Usage

``` r
.build_transition_specs(df_params, start_age, max_age, dt = 1)
```

## Arguments

- df_params:

  Raw transition-parameter data frame.

- start_age, max_age:

  Bounds of the age sequence.

- dt:

  Cycle length; default 1.

## Value

List with two elements:

- `specs` — list keyed by `"<transition>_<age_start>_<age_end>"` of
  [`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md)
  objects.

- `bands` — data frame with columns `key`, `transition`, `age_start`,
  `age_end`, `surv_start`, sorted by `(transition, age_start)`.
