# Read a life table CSV and return the per-age NW mortality vector

Reads `<data_dir>/<file>`, filters to `start_age:(max_age - 1)`, and
returns the `sex_col` column as a named numeric (names are ages as
character) — matches the engine's
[`.build_mortality_vec()`](https://dache-sdu.github.io/moon/reference/dot-build_mortality_vec.md)
lookup contract.

## Usage

``` r
.read_lifetable(data_dir, sex_col, start_age, max_age, file)
```

## Arguments

- data_dir:

  Directory containing the CSV.

- sex_col:

  `"F"`, `"M"`, or `"Both"`.

- start_age, max_age:

  Integer; bounds of the age sequence (inclusive of `start_age`,
  exclusive of `max_age`).

- file:

  File name within `data_dir`. Public callers reach this via the
  `lifetable_file =` argument of
  [`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md).

## Value

Named numeric of length `max_age - start_age`.
