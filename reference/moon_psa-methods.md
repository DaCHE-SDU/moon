# Methods for `moon_psa` objects

S3 methods for inspecting, summarising, plotting, and coercing the
object returned by
[`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md).

## Usage

``` r
# S3 method for class 'moon_psa'
print(x, ...)

# S3 method for class 'moon_psa'
summary(object, ...)

# S3 method for class 'moon_psa'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("per_iter", "draws", "summary"),
  ...
)

# S3 method for class 'moon_psa'
plot(x, type = c("forest", "incremental_cost_age"), ...)
```

## Arguments

- x, object:

  A
  [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
  object.

- ...:

  Further arguments passed to or from other methods.

- row.names, optional:

  Standard
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  arguments; currently ignored.

- what:

  For [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html),
  one of `"per_iter"` (default), `"draws"`, or `"summary"` — selects
  which long-form data frame to return.

- type:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), one of
  `"forest"` (default; point + 95% CI per metric, faceted by metric
  family) or `"incremental_cost_age"` (per-age incremental cost vs NW,
  mean +/- 95% band; requires `store_traces = "all"` on the original
  [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
  call).

## Value

[`print()`](https://rdrr.io/r/base/print.html) returns its input
invisibly (and prints headline metric bands).
[`summary()`](https://rdrr.io/r/base/summary.html) returns the
precomputed summary data frame (mean, 95% CI, sd per `(sex, metric)`).
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the requested long data frame.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) returns a
`ggplot` object; the `ggplot2` package is required.

## See also

[`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md),
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md).
