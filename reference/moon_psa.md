# Run a probabilistic sensitivity analysis (PSA) on a MOON spec

Materialises `n_iter` parameter draws from a spec built with
`moon_params_norway(uncertainty = TRUE)`, runs
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
on each, computes per-iteration metrics, and aggregates them into a
`moon_psa` object.

## Usage

``` r
moon_psa(
  spec,
  n_iter,
  seed = NULL,
  parallel = FALSE,
  store_traces = c("summary", "all", "none"),
  correlate_hr = TRUE,
  correlate_cost = TRUE,
  tp_overrides = NULL
)
```

## Arguments

- spec:

  A spec'd `params` list, typically from
  `moon_params_norway(sex = ..., uncertainty = TRUE)`.

- n_iter:

  Integer; number of PSA iterations. The published MOON analysis uses
  `1000`.

- seed:

  Integer (or `NULL`); passed to
  [`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md)
  so the draw sequence is reproducible.

- parallel:

  Logical. `FALSE` (default) runs iterations sequentially with `lapply`.
  `TRUE` uses
  [`furrr::future_map`](https://furrr.futureverse.org/reference/future_map.html)
  with a multicore (Linux / macOS) or multisession (Windows) plan; falls
  back to sequential with a warning if `furrr` / `future` are
  unavailable.

- store_traces:

  One of `"summary"` (default — keep a 3-D array `[iter, age, state]` of
  trace counts), `"all"` (keep the full list of `moon_deterministic`
  objects; large), or `"none"` (drop traces; keep only summary, per-iter
  metrics, and draws).

- correlate_hr, correlate_cost:

  Logical, passed to
  [`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md);
  both default `TRUE`.

- tp_overrides:

  Optional, forwarded to every
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  call. Use to run a PSA on a scenario rather than the base case.

## Value

A `moon_psa` S3 object — a list with

- `summary` — per `(sex, metric)` summary (mean, 2.5 / 97.5 quantile,
  sd).

- `per_iter` — long data frame of per-iteration metric values.

- `traces` — depends on `store_traces`.

- `draws` — long table of sampled mortality HRs by `(iter, parameter)`.

- `params_spec` — the input spec, preserved for replay.

- `meta` — run metadata.

## See also

[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md),
[`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md),
[`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md).

## Examples

``` r
# \donttest{
spec <- moon_params_norway(sex = "female", uncertainty = TRUE)
psa  <- moon_psa(spec, n_iter = 50, seed = 1)
head(psa$summary)
#>      sex                  metric       mean    lower95     upper95          sd
#> 1 female                      LE   81.46952   81.09877    82.03209   0.2371043
#> 2 female   cum_inc_cost_OB1_disc  853.10539  703.96352  1013.37529  81.5338525
#> 3 female cum_inc_cost_OB1_undisc 8706.09802 7308.87835 10441.67944 793.6975208
#> 4 female   cum_inc_cost_OB2_disc  379.87982  280.33550   495.49920  65.9470876
#> 5 female cum_inc_cost_OB2_undisc 3791.18610 2792.58681  5039.99097 643.9293715
#> 6 female    cum_inc_cost_OW_disc  490.66197  440.24559   559.44126  30.9103630
# }
```
