#' Build a Norwegian default `params` list
#'
#' Constructs the engine-shape `params` list for the published MOON
#' Norwegian birth cohort (Bjørnelv et al. 2021), reading the bundled CSVs
#' for life tables, costs, and survival-model coefficients. The returned
#' list plugs straight into [moon_deterministic()] (or [moon_sample_params()]
#' / [moon_psa()] when `uncertainty = TRUE`) with no further reshape.
#'
#' Single-sex per call. `cohort_n` is a length-1 named integer
#' (e.g. `c(female = 26458L)`) so the stratification label is recoverable
#' from the params alone.
#'
#' @param sex One of `"female"`, `"male"`, `"both"`. Selects which CSV
#'   file family to load and which life-table column to use as `qx`.
#' @param uncertainty If `FALSE` (default), returns plain numeric values
#'   ready for [moon_deterministic()]. If `TRUE`, wraps the uncertain
#'   inputs (mortality hazard ratios, costs, transition coefficients) as
#'   `moon_param_*` spec objects ready for [moon_sample_params()] /
#'   [moon_psa()]. The result is **not** valid input for
#'   [moon_deterministic()] directly — sample it first.
#' @param data_dir Directory containing the parameter CSVs. Defaults to
#'   `system.file("extdata", package = "moon", mustWork = TRUE)`, which
#'   resolves to the bundled files inside the installed package; override
#'   to point at a custom directory of CSVs with the same filenames and
#'   schema.
#' @param lifetable_file File name (within `data_dir`) of the life-table
#'   CSV. Defaults to `"Lifetable_Norway_2017.csv"` to match the bundled
#'   data; override when supplying a life table for a different
#'   country / year. The CSV must have an `Age` column and a sex-keyed
#'   column matching the `sex` argument (`F`, `M`, or `Both`).
#'
#' @return A `params` list with elements `start_age`, `max_age`,
#'   `discount_rate`, `cost_currency`, `cohort_n`, `init_prev`, `qx`,
#'   `mortality_hr`, `transition_probs`, `cost_df`. Under
#'   `uncertainty = TRUE` the same shape, with the uncertain slots replaced
#'   by `moon_param_*` specs:
#'   * `mortality_hr$OW` / `OB1` / `OB2` become list-columns of
#'     [moon_param_lognormal()] specs.
#'   * `cost_df$cost` becomes a list of [moon_param_gamma()] specs (one per
#'     `(state, age)` cell; degenerate ages 2–19 get gammas with
#'     `mean = se = 0` which always sample 0).
#'   * `transition_probs` becomes a list with `$specs` (named
#'     [moon_param_mvnorm()] objects keyed by
#'     `"<transition>_<age_start>_<age_end>"`) and `$bands` (the schema for
#'     stitching per-band draws back into the deterministic
#'     `transition_probs` layout).
#'
#' @section Cost data ranges:
#'
#' The bundled cost CSVs carry **zero** values for ages 2–19 and are **held
#' constant at the age-80 value for ages 81–100**. This reflects the
#' original two-part regression's fitted age range of 20–80
#' (Bjørnelv et al. 2021, §Health care costs; Supplementary Appendix 4
#' tables s8–s15) — the published cost predictions only cover ages 20–80,
#' so the engine extends them flat at the boundaries. These are pre-existing
#' data choices baked into the bundled parameter files, not engine-side
#' imputations.
#'
#' @section `init_prev` is keyed to `start_age`:
#'
#' `init_prev` is the BMI distribution **at age `start_age`**, despite the
#' field name not saying so. The bundled value is the published age-2
#' distribution and pairs with the bundled `start_age = 2L`. If you mutate
#' `start_age` to a later age, the stored `init_prev` will silently
#' produce wrong results unless you also supply a matched prevalence
#' vector for that age — [moon_check_params()] cannot detect this, since
#' there is no external truth to check against.
#'
#' See `vignette("moon-customizing", package = "moon")` §6 for a
#' bootstrap recipe (run the baseline, read prevalence at the target age
#' out of [moon_prevalence()], feed it back as `init_prev`).
#'
#' @seealso [moon_deterministic()], [moon_sample_params()],
#'   [moon_check_params()].
#'
#' @examples
#' \donttest{
#' params <- moon_params_norway(sex = "female")
#' str(params, max.level = 1)
#' }
#'
#' @export
moon_params_norway <- function(sex         = c("female", "male", "both"),
                                uncertainty    = FALSE,
                                data_dir       = system.file("extdata",
                                                              package  = "moon",
                                                              mustWork = TRUE),
                                lifetable_file = "Lifetable_Norway_2017.csv") {
  sex <- match.arg(sex)

  sex_code <- switch(sex, female = "F", male = "M", both = "Both")

  start_age     <- 2L
  max_age       <- 100L
  discount_rate <- 0.04
  cost_currency <- "EUR"

  cohort_n <- switch(sex,
    female = c(female = 26458L),
    male   = c(male   = 28662L),
    both   = c(both   = 55120L)
  )

  # Match legacy Input.R:19-26 to the displayed precision so loader-built
  # params drive the engine to bit-identical output as the legacy port.
  # Same values are used for all sexes in the original model.
  init_prev <- c(
    NW  = 0.898277276456112,
    OW  = 0.0898277276456112,
    OB1 = 0.008613617719442170,
    OB2 = 0.003281378178835110
  )

  qx     <- .read_lifetable(data_dir, sex_code, start_age, max_age,
                             file = lifetable_file)
  tp_raw <- .read_transition_params(data_dir, sex_code)

  if (isTRUE(uncertainty)) {
    mortality_hr     <- .build_mortality_hr_specs()
    cost_df          <- .build_cost_specs(.read_costs(data_dir, sex_code,
                                                       with_se = TRUE))
    transition_probs <- .build_transition_specs(tp_raw, start_age, max_age,
                                                 dt = 1)
  } else {
    mortality_hr     <- .build_mortality_hr()
    cost_df          <- .read_costs(data_dir, sex_code)
    transition_probs <- .build_transition_probs(tp_raw, start_age, max_age,
                                                 dt = 1)
    stopifnot(nrow(transition_probs) == max_age - start_age)
  }

  list(
    start_age        = start_age,
    max_age          = max_age,
    discount_rate    = discount_rate,
    cost_currency    = cost_currency,
    cohort_n         = cohort_n,
    init_prev        = init_prev,
    qx               = qx,
    mortality_hr     = mortality_hr,
    transition_probs = transition_probs,
    cost_df          = cost_df
  )
}


# ==============================================================================
# .build_mortality_hr_specs
# Wraps each (state, age band) HR as a moon_param_lognormal using the 95% CIs
# from .mortality_hr_bounds(). Returns a data frame with the same age_lower
# rows as .build_mortality_hr() but with list-columns for OW/OB1/OB2.
# ==============================================================================

.build_mortality_hr_specs <- function() {
  bounds <- .mortality_hr_bounds()
  spec_col <- function(state) {
    df <- bounds[[state]]
    lapply(seq_len(nrow(df)), function(i) {
      moon_param_lognormal(point = df$point[i],
                           lower = df$lower[i],
                           upper = df$upper[i])
    })
  }
  data.frame(
    age_lower = c(35, 50, 70),
    OW        = I(spec_col("OW")),
    OB1       = I(spec_col("OB1")),
    OB2       = I(spec_col("OB2"))
  )
}


# ==============================================================================
# .build_cost_specs
# Turns the loader's (age, state, cost, cost_se) data frame into a long
# data frame (age, state, cost) where `cost` is a list-column of
# moon_param_gamma. Each cell carries length-1 mean and SE vectors so the
# sampler can apply the "one-world U" via qgamma uniformly across cells.
# Ages 2-19 (mean = se = 0) get a degenerate gamma that always samples 0.
# ==============================================================================

.build_cost_specs <- function(cost_long_with_se) {
  cd <- cost_long_with_se
  out <- cd[, c("age", "state")]
  out$cost <- lapply(seq_len(nrow(cd)), function(i) {
    moon_param_gamma(mean_vec = cd$cost[i], se_vec = cd$cost_se[i])
  })
  out
}
