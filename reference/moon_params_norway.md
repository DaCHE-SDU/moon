# Build a Norwegian default `params` list

Constructs the engine-shape `params` list for the published MOON
Norwegian birth cohort (Bjørnelv et al. 2021), reading the bundled CSVs
for life tables, costs, and survival-model coefficients. The returned
list plugs straight into
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
(or
[`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md)
/ [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
when `uncertainty = TRUE`) with no further reshape.

## Usage

``` r
moon_params_norway(
  sex = c("female", "male", "both"),
  uncertainty = FALSE,
  data_dir = system.file("extdata", package = "moon", mustWork = TRUE),
  lifetable_file = "Lifetable_Norway_2017.csv"
)
```

## Arguments

- sex:

  One of `"female"`, `"male"`, `"both"`. Selects which CSV file family
  to load and which life-table column to use as `qx`.

- uncertainty:

  If `FALSE` (default), returns plain numeric values ready for
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md).
  If `TRUE`, wraps the uncertain inputs (mortality hazard ratios, costs,
  transition coefficients) as `moon_param_*` spec objects ready for
  [`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md)
  /
  [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md).
  The result is **not** valid input for
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  directly — sample it first.

- data_dir:

  Directory containing the parameter CSVs. Defaults to
  `system.file("extdata", package = "moon", mustWork = TRUE)`, which
  resolves to the bundled files inside the installed package; override
  to point at a custom directory of CSVs with the same filenames and
  schema.

- lifetable_file:

  File name (within `data_dir`) of the life-table CSV. Defaults to
  `"Lifetable_Norway_2017.csv"` to match the bundled data; override when
  supplying a life table for a different country / year. The CSV must
  have an `Age` column and a sex-keyed column matching the `sex`
  argument (`F`, `M`, or `Both`).

## Value

A `params` list with elements `start_age`, `max_age`, `discount_rate`,
`cost_currency`, `cohort_n`, `init_prev`, `qx`, `mortality_hr`,
`transition_probs`, `cost_df`. Under `uncertainty = TRUE` the same
shape, with the uncertain slots replaced by `moon_param_*` specs:

- `mortality_hr$OW` / `OB1` / `OB2` become list-columns of
  [`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md)
  specs.

- `cost_df$cost` becomes a list of
  [`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md)
  specs (one per `(state, age)` cell; degenerate ages 2–19 get gammas
  with `mean = se = 0` which always sample 0).

- `transition_probs` becomes a list with `$specs` (named
  [`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md)
  objects keyed by `"<transition>_<age_start>_<age_end>"`) and `$bands`
  (the schema for stitching per-band draws back into the deterministic
  `transition_probs` layout).

## Details

Single-sex per call. `cohort_n` is a length-1 named integer (e.g.
`c(female = 26458L)`) so the stratification label is recoverable from
the params alone.

## Cost data ranges

The bundled cost CSVs carry **zero** values for ages 2–19 and are **held
constant at the age-80 value for ages 81–100**. This reflects the
original two-part regression's fitted age range of 20–80 (Bjørnelv et
al. 2021, §Health care costs; Supplementary Appendix 4 tables s8–s15) —
the published cost predictions only cover ages 20–80, so the engine
extends them flat at the boundaries. These are pre-existing data choices
baked into the bundled parameter files, not engine-side imputations.

## `init_prev` is keyed to `start_age`

`init_prev` is the BMI distribution **at age `start_age`**, despite the
field name not saying so. The bundled value is the published age-2
distribution and pairs with the bundled `start_age = 2L`. If you mutate
`start_age` to a later age, the stored `init_prev` will silently produce
wrong results unless you also supply a matched prevalence vector for
that age —
[`moon_check_params()`](https://dache-sdu.github.io/moon/reference/moon_check_params.md)
cannot detect this, since there is no external truth to check against.

See
[`vignette("moon-customizing", package = "moon")`](https://dache-sdu.github.io/moon/articles/moon-customizing.md)
§6 for a bootstrap recipe (run the baseline, read prevalence at the
target age out of
[`moon_prevalence()`](https://dache-sdu.github.io/moon/reference/moon_prevalence.md),
feed it back as `init_prev`).

## See also

[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md),
[`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md),
[`moon_check_params()`](https://dache-sdu.github.io/moon/reference/moon_check_params.md).

## Examples

``` r
# \donttest{
params <- moon_params_norway(sex = "female")
str(params, max.level = 1)
#> List of 10
#>  $ start_age       : int 2
#>  $ max_age         : int 100
#>  $ discount_rate   : num 0.04
#>  $ cost_currency   : chr "EUR"
#>  $ cohort_n        : Named int 26458
#>   ..- attr(*, "names")= chr "female"
#>  $ init_prev       : Named num [1:4] 0.89828 0.08983 0.00861 0.00328
#>   ..- attr(*, "names")= chr [1:4] "NW" "OW" "OB1" "OB2"
#>  $ qx              : Named num [1:98] 0.000136 0.000067 0.000132 0.000163 0.000064 0.000031 0.000063 0.000032 0 0.000032 ...
#>   ..- attr(*, "names")= chr [1:98] "2" "3" "4" "5" ...
#>  $ mortality_hr    :'data.frame':    3 obs. of  4 variables:
#>  $ transition_probs:'data.frame':    98 obs. of  7 variables:
#>  $ cost_df         :'data.frame':    396 obs. of  3 variables:
# }
```
