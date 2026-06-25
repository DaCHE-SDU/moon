
<!-- README.md is generated from README.Rmd. Please edit that file -->

# moon

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/DaCHE-SDU/moon/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/DaCHE-SDU/moon/actions/workflows/R-CMD-check.yaml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20842690.svg)](https://doi.org/10.5281/zenodo.20842690)
<!-- badges: end -->

**moon** is an R implementation of the MOON (Modeling Obesity in Norway)
Markov cohort model originally published by Bjørnelv et al. (2021). It
simulates obesity prevalence, incremental health-care costs, and years
of life lost in a Norwegian birth cohort over the life course, and
supports both deterministic runs and 1000-iteration probabilistic
sensitivity analysis (PSA) with the published correlated-draw
conventions for mortality hazard ratios, costs, and transition
probabilities.

> **Status: early development.** `moon` is in active early development.
> The public API may change without deprecation warnings until the first
> tagged release, and outputs should be verified against your own
> expectations (see the [Disclaimer](#disclaimer)).

## Installation

`moon` is not on CRAN. Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("DaCHE-SDU/moon")
```

## Quick example

``` r
library(moon)

# 1. Build a Norwegian default `params` list (single sex per call).
params <- moon_params_norway(sex = "female")

# 2. Run the deterministic simulation.
run <- moon_deterministic(params)

run
#> <moon_deterministic>
#>   Sex:         female (cohort N = 26,458)
#>   Horizon:     ages 2 to 100
#>   LE:          81.49 years
#>   Total cost:  EUR 3,090,827,645 undisc / EUR 435,536,655 disc (r = 4%)
#>   Per-capita inc cost vs NW (undisc): EUR 16,105

# 3. Inspect costs and prevalence.
moon_costs(run, by = "state")
#>      state       cost
#> 1 N_always  584363548
#> 2   N_prev  307381370
#> 3      OB1  815463456
#> 4      OB2  334218808
#> 5       OW 1049400463
moon_prevalence(run, ages = 45)
#>   age    state prevalence
#> 1  45 N_always 0.28539951
#> 2  45   N_prev 0.10935520
#> 4  45      OB1 0.15295536
#> 5  45      OB2 0.06166763
#> 3  45       OW 0.39062230
```

For probabilistic uncertainty, use the spec’d parameter list and
`moon_psa()`:

``` r
spec <- moon_params_norway(sex = "female", uncertainty = TRUE)
psa <- moon_psa(spec, n_iter = 1000, seed = 1)

summary(psa)
plot(psa) # forest plot of headline metrics
```

The PSA call materialises 1000 parameter draws via
`moon_sample_params()` and runs `moon_deterministic()` over each. See
`?moon_psa` for the correlation flags and `store_traces` options.

## Citation

If you use `moon` in published work, please cite **both** the software
and the original model paper. Running `citation("moon")` returns these
entries.

**Software** (this package):

> Damslund N, Bjørnelv GMW, Jiang Y, Larsen MS, Edwards CH, Halsteinli
> V, Ødegaard RA, Kongstad LP (2026). *moon: An R Package Implementing
> the Modeling Obesity in Norway (MOON) Markov Cohort Model.*
> [doi:10.5281/zenodo.20842690](https://doi.org/10.5281/zenodo.20842690)
> (concept DOI; resolves to the latest version).
> <https://dache-sdu.github.io/moon/>

For reproducibility, cite the version DOI of the specific release you
used.

**Model** (original paper):

> Bjørnelv GMW, Halsteinli V, Kulseng BE, Sonntag D, Ødegaard RA.
> Modeling Obesity in Norway (The MOON Study): A Decision-Analytic
> Approach—Prevalence, Costs, and Years of Life Lost. *Medical Decision
> Making.* 2021;41(1):21–36.
> [doi:10.1177/0272989X20971589](https://doi.org/10.1177/0272989X20971589)

## Differences from the published paper

Running `moon` with the bundled Norwegian parameters produces results
that differ slightly from those reported in Bjørnelv et al. (2021), due
to minor improvements made to the model during its transition from the
original Excel/VBA implementation to R. The improvements are:

- **Mortality–cycle alignment.** Baseline life-table mortality is
  aligned so that each cycle uses the mortality probability for the age
  the cohort occupies at the start of that cycle (cycle 1, advancing
  from age 2 to 3, uses `q_2`).
- **Survival-conditional transitions.** State transitions are applied
  only to individuals who survive the cycle, so mortality and BMI-state
  transitions are modelled as sequential rather than independent events
  within a cycle.
- **Consistent survival functions across sex strata.** The same
  parametric survival distribution is used for each transition and age
  band across the female, male, and combined-sex models.

## Disclaimer

`moon` is a population-level decision-analytic model intended for
research and educational use. It is designed to inform exploratory
cohort-level analyses of obesity prevalence, health-care costs, and
years of life lost, and is **not** intended to model individual patient
trajectories. Results from this package should not be used as the sole
basis for health-policy, reimbursement, or regulatory decisions without
independent expert review and validation.

Users are responsible for verifying that the model’s assumptions,
parameters, and outputs are appropriate for their intended use, and for
checking the correctness of any results produced by the package in their
analytical context. The authors and contributors accept no
responsibility for decisions made on the basis of model outputs.

The software is distributed under the MIT License, which disclaims all
warranties — see [LICENSE.md](LICENSE.md) for the full text.

## Contributing

Contributions are welcome. Please see the [contributing
guide](.github/CONTRIBUTING.md) for how to file issues and open pull
requests. Note that the `moon` project is released with a [Contributor
Code of Conduct](.github/CODE_OF_CONDUCT.md); by contributing you agree
to abide by its terms.

## License

MIT. See [LICENSE](LICENSE) for the short form and
[LICENSE.md](LICENSE.md) for the full text.
