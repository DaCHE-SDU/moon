# Build state-specific mortality probability vectors from baseline `qx` and HRs

Applies age-band-specific mortality hazard ratios to the baseline NW
mortality vector `qx`. Banding: `age < 35` uses HR = 1; `35 <= age < 50`
uses the row where `age_lower == 35`; `50 <= age < 70` uses
`age_lower == 50`; `age >= 70` uses `age_lower == 70` (the same band is
used above age 89).

## Usage

``` r
.build_mortality_vec(qx, mortality_hr, ages)
```

## Arguments

- qx:

  Named numeric of NW mortality probabilities; names are ages as
  character.

- mortality_hr:

  Data frame with columns `age_lower`, `OW`, `OB1`, `OB2` (three rows).

- ages:

  Integer vector of model ages to process.

## Value

List with elements `NW`, `OW`, `OB1`, `OB2`, each a numeric vector the
length of `ages`.
