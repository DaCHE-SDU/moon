# Contributing to moon

Thanks for taking the time to contribute! `moon` is an R implementation
of the MOON (Modeling Obesity in Norway) Markov cohort model. This guide
explains how to propose a change.

## Code of conduct

This project is released with a [Contributor Code of
Conduct](https://dache-sdu.github.io/moon/CODE_OF_CONDUCT.md). By
participating you agree to abide by its terms.

## Fixing typos

Small typos or grammatical errors in documentation may be fixed directly
via a pull request. Documentation lives in the roxygen comments above
each function (the `.R` files), **not** the generated `.Rd` files under
`man/` — edit the `.R` source so the change survives the next
`devtools::document()`.

## Bigger changes

If you want to make a substantial change, please **open an issue first**
so we can agree it is needed before you invest time in it. This is
especially important for changes that affect model output: `moon` is
validated to bit-level reference baselines (see below), so any intended
change to the numbers needs to be discussed and the baselines
regenerated deliberately.

## Pull request process

1.  Fork the repository and create a Git branch for your change.
2.  Make your change, keeping it focused — one logical change per pull
    request.
3.  Add or update tests under `tests/testthat/` to cover the change.
4.  Run the checks below and make sure they pass.
5.  Add a bullet to `NEWS.md` describing the change, in the present
    tense.
6.  Open the pull request against the `main` branch and describe the
    *why*.

## Development checks

From the package root:

``` r

devtools::document()   # regenerate man/ + NAMESPACE from roxygen
devtools::test()       # fast unit tests (< 5 s)
devtools::check()      # full R CMD check
```

The slow tests (full PSA and scenario anchors) are gated behind an
environment variable:

``` r

Sys.setenv(MOON_RUN_SLOW_TESTS = "1")
devtools::test()
```

Reference baselines in `tests/reference/` are bit-level (tolerance
1e-10). If you make an intentional change to model behaviour, regenerate
them with `source("tests/reference/generate_reference.R")` and commit
the updated `.rds` files alongside the code change, explaining the
reason in the pull request.

## Code style

Please follow the [tidyverse style guide](https://style.tidyverse.org).
New code should match the conventions of the surrounding code — naming,
spacing, and the use of the native pipe.

## Questions

For questions that are not bug reports or feature requests, open a
[discussion or issue](https://github.com/DaCHE-SDU/moon/issues).
