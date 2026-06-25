# Methods for `moon_deterministic` objects

S3 methods for inspecting, summarising, plotting, and coercing the
object returned by
[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md).

## Usage

``` r
# S3 method for class 'moon_deterministic'
print(x, ...)

# S3 method for class 'moon_deterministic'
summary(object, ...)

# S3 method for class 'summary.moon_deterministic'
print(x, ...)

# S3 method for class 'moon_deterministic'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("trace", "costs"),
  ...
)

# S3 method for class 'moon_deterministic'
plot(
  x,
  type = c("occupancy", "prevalence_alive", "prevalence_initial", "survival", "costs"),
  ages = NULL,
  by_sex = FALSE,
  ...
)
```

## Arguments

- x, object:

  A
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  object (or, for `print.summary.moon_deterministic`, the object
  returned by [`summary()`](https://rdrr.io/r/base/summary.html)).

- ...:

  Further arguments passed to or from other methods.

- row.names, optional:

  Standard
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  arguments; currently ignored.

- what:

  For [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html),
  one of `"trace"` (default) or `"costs"` — selects which long-form data
  frame to return.

- type:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), one of
  `"occupancy"`, `"prevalence_alive"`, `"prevalence_initial"`,
  `"survival"`, or `"costs"`.

- ages:

  For [`plot()`](https://rdrr.io/r/graphics/plot.default.html), optional
  integer vector to filter the underlying trace and costs to before
  plotting; `NULL` (default) plots all ages.

- by_sex:

  Forward-compatibility hook for multi-sex stitched runs; has no effect
  today since each `moon_deterministic` object is single-sex by
  construction.

## Value

[`print()`](https://rdrr.io/r/base/print.html) returns its input
invisibly (and prints a one-screen headline).
[`summary()`](https://rdrr.io/r/base/summary.html) returns a
`summary.moon_deterministic` object carrying life-expectancy,
total/discounted cost, age-45 prevalence, and per-state per-capita
incremental cost vs NW.
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the requested long data frame.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) returns a
`ggplot` object; the `ggplot2` package is required.

## See also

[`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md),
[`moon_prevalence()`](https://dache-sdu.github.io/moon/reference/moon_prevalence.md),
[`moon_costs()`](https://dache-sdu.github.io/moon/reference/moon_costs.md).
