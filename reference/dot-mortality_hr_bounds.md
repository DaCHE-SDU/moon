# Hard-coded 95% CI bounds for each (age band, state) mortality HR

Used only by the `uncertainty = TRUE` branch of
[`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md)
to construct `moon_param_lognormal` specs. Source: Global BMI Mortality
Collaboration (Bjørnelv et al. 2021, Supplementary Appendix 3).

## Usage

``` r
.mortality_hr_bounds()
```

## Value

List with elements `OW`, `OB1`, `OB2`, each a data frame with columns
`age_lower`, `point`, `lower`, `upper`.
