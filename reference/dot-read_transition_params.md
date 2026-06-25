# Read the transition-parameter CSV

Normalises the `"Transtition"` header typo (present in all three
sex-specific files) to `"Transition"`.

## Usage

``` r
.read_transition_params(data_dir, sex_code)
```

## Arguments

- data_dir:

  Directory containing the CSV.

- sex_code:

  `"F"`, `"M"`, or `"Both"`.

## Value

Data frame with the columns published in the source file plus the
normalised `Transition` column.
