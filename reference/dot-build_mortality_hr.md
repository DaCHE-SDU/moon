# Build the deterministic mortality-hazard-ratio data frame

Hard-coded three-row data frame from the Global BMI Mortality
Collaboration (Bjørnelv et al. 2021, Supplementary Appendix 3). The same
HRs are used for all sexes in the original model, so the function takes
no arguments.

## Usage

``` r
.build_mortality_hr()
```

## Value

Data frame with columns `age_lower` (`c(35, 50, 70)`), `OW`, `OB1`,
`OB2`.
