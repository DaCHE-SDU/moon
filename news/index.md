# Changelog

## moon 0.1.1

- Add citation infrastructure now that the package is archived on
  Zenodo: `CITATION.cff`, `inst/CITATION` (so `citation("moon")` returns
  the software citation with the Zenodo concept DOI
  `10.5281/zenodo.20842690`), and a DOI badge plus software citation in
  the README.

## moon 0.1.0

### New features

- First public release of the MOON Markov cohort model.
- Public API:
  [`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md)
  builds the Norwegian default parameter set (or a spec’d uncertainty
  version);
  [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  runs a single deterministic simulation;
  [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
  runs probabilistic sensitivity analysis.
- S3 methods (`print`, `summary`, `plot`, `as.data.frame`) and
  extractors
  ([`moon_prevalence()`](https://dache-sdu.github.io/moon/reference/moon_prevalence.md),
  [`moon_costs()`](https://dache-sdu.github.io/moon/reference/moon_costs.md))
  cover routine inspection of the results.
- Bundled package data: `moon_who_cutoffs` (WHO adult BMI cut-offs) and
  `moon_iotf_cutoffs` (Cole/IOTF child BMI cut-offs, ages 2–18 in
  0.5-year steps).
