# Package index

## Run a model

Top-level entry points for deterministic and probabilistic simulation of
the MOON Markov cohort model.

- [`moon_deterministic()`](https://dache-sdu.github.io/moon/reference/moon_deterministic.md)
  : Run a deterministic MOON simulation
- [`moon_psa()`](https://dache-sdu.github.io/moon/reference/moon_psa.md)
  : Run a probabilistic sensitivity analysis (PSA) on a MOON spec
- [`run_markov_engine()`](https://dache-sdu.github.io/moon/reference/run_markov_engine.md)
  : Run the raw MOON Markov engine

## Build parameters

Build the bundled Norwegian default parameter set, define parametric
uncertainty for PSA, and validate `params` lists.

- [`moon_params_norway()`](https://dache-sdu.github.io/moon/reference/moon_params_norway.md)
  :

  Build a Norwegian default `params` list

- [`moon_param_fixed()`](https://dache-sdu.github.io/moon/reference/moon_param_fixed.md)
  : Spec for a value that is uncertain in principle but pinned for this
  run

- [`moon_param_lognormal()`](https://dache-sdu.github.io/moon/reference/moon_param_lognormal.md)
  : Lognormal spec from a point estimate and a 95% confidence interval

- [`moon_param_gamma()`](https://dache-sdu.github.io/moon/reference/moon_param_gamma.md)
  : Moment-matched gamma spec from per-cell means and standard errors

- [`moon_param_mvnorm()`](https://dache-sdu.github.io/moon/reference/moon_param_mvnorm.md)
  : Multivariate-normal spec for survival-model coefficients

- [`moon_param_dirichlet()`](https://dache-sdu.github.io/moon/reference/moon_param_dirichlet.md)
  : Dirichlet spec for simplex-valued parameters

- [`moon_param_value()`](https://dache-sdu.github.io/moon/reference/moon_param-methods.md)
  [`moon_param_sample()`](https://dache-sdu.github.io/moon/reference/moon_param-methods.md)
  : MOON parameter spec class system

- [`moon_sample_params()`](https://dache-sdu.github.io/moon/reference/moon_sample_params.md)
  :

  Materialise a spec'd `params` list into `n` concrete draws

- [`moon_check_params()`](https://dache-sdu.github.io/moon/reference/moon_check_params.md)
  :

  Validate a MOON `params` list

## Inspect results

Extractors and S3 methods over `moon_deterministic` and `moon_psa`
objects.

- [`moon_prevalence()`](https://dache-sdu.github.io/moon/reference/moon_prevalence.md)
  : Compute prevalence by age and state from a deterministic run

- [`moon_costs()`](https://dache-sdu.github.io/moon/reference/moon_costs.md)
  : Aggregate cohort costs by age, state, sex, or total

- [`print(`*`<moon_deterministic>`*`)`](https://dache-sdu.github.io/moon/reference/moon_deterministic-methods.md)
  [`summary(`*`<moon_deterministic>`*`)`](https://dache-sdu.github.io/moon/reference/moon_deterministic-methods.md)
  [`print(`*`<summary.moon_deterministic>`*`)`](https://dache-sdu.github.io/moon/reference/moon_deterministic-methods.md)
  [`as.data.frame(`*`<moon_deterministic>`*`)`](https://dache-sdu.github.io/moon/reference/moon_deterministic-methods.md)
  [`plot(`*`<moon_deterministic>`*`)`](https://dache-sdu.github.io/moon/reference/moon_deterministic-methods.md)
  :

  Methods for `moon_deterministic` objects

- [`print(`*`<moon_psa>`*`)`](https://dache-sdu.github.io/moon/reference/moon_psa-methods.md)
  [`summary(`*`<moon_psa>`*`)`](https://dache-sdu.github.io/moon/reference/moon_psa-methods.md)
  [`as.data.frame(`*`<moon_psa>`*`)`](https://dache-sdu.github.io/moon/reference/moon_psa-methods.md)
  [`plot(`*`<moon_psa>`*`)`](https://dache-sdu.github.io/moon/reference/moon_psa-methods.md)
  :

  Methods for `moon_psa` objects

## Package data

BMI cut-off reference datasets shipped with the package; used by a
future `moon_classify_bmi()` and not by the engine itself.

- [`moon_who_cutoffs`](https://dache-sdu.github.io/moon/reference/moon_who_cutoffs.md)
  : Adult BMI cut-offs (WHO)
- [`moon_iotf_cutoffs`](https://dache-sdu.github.io/moon/reference/moon_iotf_cutoffs.md)
  : Cole/IOTF child BMI cut-offs (LMS-based, ages 2–18, both sexes)
