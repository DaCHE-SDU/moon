# moon 0.1.0

## New features

* First public release of the MOON Markov cohort model.
* Public API: `moon_params_norway()` builds the Norwegian default
  parameter set (or a spec'd uncertainty version);
  `moon_deterministic()` runs a single deterministic simulation;
  `moon_psa()` runs probabilistic sensitivity analysis.
* S3 methods (`print`, `summary`, `plot`, `as.data.frame`) and
  extractors (`moon_prevalence()`, `moon_costs()`) cover routine
  inspection of the results.
* Bundled package data: `moon_who_cutoffs` (WHO adult BMI cut-offs)
  and `moon_iotf_cutoffs` (Cole/IOTF child BMI cut-offs, ages 2–18 in
  0.5-year steps).
