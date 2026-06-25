# Read a per-capita cost CSV into a tidy `(age, state, cost)` data frame

Renames the source file's `State == "N"` to `"NW"` so output uses the
engine's state vocabulary. Costs for ages 2–19 (zeros) and 81–100
(constant at the age-80 value) come straight from the source file — no
engine-side imputation. Drops NOK columns and trailing empty columns by
selecting only the columns we need.

## Usage

``` r
.read_costs(data_dir, sex_code, with_se = FALSE)
```

## Arguments

- data_dir:

  Directory containing the CSV.

- sex_code:

  `"F"`, `"M"`, or `"Both"`.

- with_se:

  If `TRUE`, also return the `Cost_SE` column as `cost_se`.

## Value

Data frame with columns `age`, `state`, `cost` (and `cost_se` if
`with_se = TRUE`).
