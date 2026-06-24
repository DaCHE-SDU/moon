#' Run a deterministic MOON simulation
#'
#' Runs the MOON Markov cohort model once with the supplied parameters,
#' returning a tidy `moon_deterministic` object containing the per-age state
#' trace, per-age per-state costs, the validated parameters, and run
#' metadata.
#'
#' Single-sex per call: the sex label is read from `names(params$cohort_n)`
#' (one of `"female"`, `"male"`, `"both"`). For sex-stratified results, run
#' twice and concatenate the trace / costs rows downstream.
#'
#' @param params A `params` list as returned by [moon_params_norway()]. Must
#'   pass [moon_check_params()] with `strict = TRUE`.
#' @param tp_overrides Optional named list of overrides applied at engine
#'   entry. Supported slots:
#'   * `set_zero` — character vector of transitions to zero out across all
#'     ages, e.g. `"OW_OB1"`.
#'   * `init_prev` — replaces the initial-state vector.
#'   * `start_age` — shifts the cohort entry age. The engine selects rows of
#'     `transition_probs` by positional index, so callers shifting
#'     `start_age` must also supply correspondingly subset
#'     `transition_probs` / `qx` / `cost_df`.
#' @param strict Passed through to [moon_check_params()]; `TRUE` (the
#'   default) halts on any validation failure.
#' @param record_meta Logical, default `TRUE`. When `FALSE` the returned
#'   `meta` list is reduced to the fields that downstream methods need
#'   (`iter`, `seed`, `horizon`, `discount_rate`, `tp_overrides`) and the
#'   per-call `moon_version` / `run_time` / `duration_sec` / `cycle_length`
#'   fields are skipped. [moon_psa()] sets this to `FALSE` to strip a few
#'   percent of per-iteration overhead; ordinary single-run callers should
#'   leave it `TRUE`.
#'
#' @return A `moon_deterministic` S3 object — a list with
#'   * `trace` — long data frame `(age, sex, state, n)` of head-counts
#'     across the six engine states (`N_always`, `N_prev`, `OW`, `OB1`,
#'     `OB2`, `dead`).
#'   * `costs` — long data frame `(age, sex, state, cost, cost_disc)` of
#'     total annual cohort costs by state, with `cost_disc` discounted at
#'     `params$discount_rate`. No `dead` rows.
#'   * `params` — the validated input parameters.
#'   * `meta` — run metadata (timestamps, horizon, discount rate, etc.).
#'
#' @section Initial-state mapping:
#'
#' MOON's engine internally distinguishes two normal-weight states:
#' `N_always` (currently NW, never previously OW or OB) and `N_prev`
#' (currently NW but previously overweight or obese at some earlier age).
#' These are conflated in the user-facing `init_prev` parameter, which is
#' a 4-vector `c(NW, OW, OB1, OB2)`.
#'
#' **Default mapping**: all NW initial mass is placed in `N_always` and
#' `N_prev` starts at 0. Both states then evolve independently per the
#' engine's six-state transition matrix; mass flows into `N_prev` only as
#' OW / OB1 / OB2 individuals regress to NW during the simulation.
#'
#' This reflects the published MOON model (Bjørnelv et al. 2021), where
#' the Norwegian birth cohort enters at age 2 with no obesity history.
#'
#' **Overriding the default**: there is no separate
#' `init_n_always_share` argument. Instead, supply a full six-element
#' initial-state vector via `tp_overrides$init_prev`; the engine uses it
#' verbatim and skips the 4-to-6 mapping. Example, for a hypothetical
#' cohort whose NW members had previously been overweight:
#'
#' ```
#' tp_overrides = list(
#'   init_prev = c(N_always = 0.5, N_prev = 0.4,
#'                 OW = 0.07, OB1 = 0.02, OB2 = 0.01, D = 0)
#' )
#' ```
#'
#' **Pairing with `start_age`**: `init_prev` is the BMI distribution at
#' the cohort entry age. If you shift the entry age — by mutating
#' `params$start_age` or by passing `tp_overrides$start_age` — also
#' supply a matching `init_prev` (mutate `params$init_prev` for the
#' former, pass `tp_overrides$init_prev` for the latter), or the cohort
#' will enter at the new age with the wrong BMI distribution. The
#' validator cannot catch this. See
#' `vignette("moon-customizing", package = "moon")` §6 for the
#' bootstrap recipe.
#'
#' @seealso [moon_psa()] for probabilistic uncertainty,
#'   [moon_params_norway()] for the bundled Norwegian parameters, and
#'   [run_markov_engine()] for direct access to the underlying pure engine.
#'
#' @examples
#' \donttest{
#' params <- moon_params_norway(sex = "female")
#' run    <- moon_deterministic(params)
#' head(run$trace)
#' head(run$costs)
#' }
#'
#' @export
moon_deterministic <- function(params,
                                tp_overrides = NULL,
                                strict       = TRUE,
                                record_meta  = TRUE) {
  t_start <- if (isTRUE(record_meta)) Sys.time() else NULL
  t_proc  <- if (isTRUE(record_meta)) proc.time()[[3]] else NA_real_

  moon_check_params(params, strict = strict)

  effective_start_age <- if (!is.null(tp_overrides$start_age)) {
    tp_overrides$start_age
  } else {
    params$start_age
  }
  max_age <- params$max_age
  ages    <- effective_start_age:max_age   # length n_cycles + 1

  engine_out <- run_markov_engine(
    start_age        = params$start_age,
    max_age          = params$max_age,
    discount_rate    = params$discount_rate,
    init_prev        = params$init_prev,
    transition_probs = params$transition_probs,
    qx               = params$qx,
    mortality_hr     = params$mortality_hr,
    cost_df          = params$cost_df,
    tp_overrides     = tp_overrides
  )

  sex_label <- names(params$cohort_n)
  cohort_n  <- unname(params$cohort_n)

  trace_df <- .build_trace_df(engine_out$trace, ages, sex_label, cohort_n)
  costs_df <- .build_costs_df(
    trace      = engine_out$trace,
    cost_mat   = engine_out$cost_matrix,
    ages       = ages,
    sex        = sex_label,
    cohort_n   = cohort_n,
    start_age  = effective_start_age,
    disc_rate  = params$discount_rate
  )

  meta <- if (isTRUE(record_meta)) {
    list(
      moon_version  = .moon_cache$version,
      run_time      = t_start,
      duration_sec  = proc.time()[[3]] - t_proc,
      cycle_length  = 1L,
      horizon       = c(start_age = effective_start_age, max_age = max_age),
      discount_rate = params$discount_rate,
      tp_overrides  = tp_overrides,
      seed          = NA_integer_,
      iter          = NA_integer_
    )
  } else {
    list(
      iter          = NA_integer_,
      seed          = NA_integer_,
      horizon       = c(start_age = effective_start_age, max_age = max_age),
      discount_rate = params$discount_rate,
      tp_overrides  = tp_overrides
    )
  }

  structure(
    list(
      trace  = trace_df,
      costs  = costs_df,
      params = params,
      meta   = meta
    ),
    class = "moon_deterministic"
  )
}


# ==============================================================================
# .build_trace_df
# Renames D -> "dead", scales by cohort_n, and pivots to long. The engine's
# 6-state space (N_always, N_prev, OW, OB1, OB2, D) is preserved in the
# external API — the N_always / N_prev split is exposed so callers can
# reproduce plots like plot_trace_WD() in the legacy MoonDeterministic.R.
# Output columns: (age, sex, state, n) with `n` = head-count.
# ==============================================================================

.build_trace_df <- function(trace_internal, ages, sex, cohort_n) {
  state_names <- c("N_always", "N_prev", "OW", "OB1", "OB2", "dead")
  external <- cbind(
    N_always = trace_internal[, "N_always"],
    N_prev   = trace_internal[, "N_prev"],
    OW       = trace_internal[, "OW"],
    OB1      = trace_internal[, "OB1"],
    OB2      = trace_internal[, "OB2"],
    dead     = trace_internal[, "D"]
  )
  data.frame(
    age   = rep(as.integer(ages), times = length(state_names)),
    sex   = sex,
    state = rep(state_names, each = length(ages)),
    n     = as.numeric(external) * cohort_n,
    stringsAsFactors = FALSE
  )
}


# ==============================================================================
# .build_costs_df
# Per (age, state) total cost across the cohort plus its 4%-discounted twin.
# Output columns: (age, sex, state, cost, cost_disc) — no "dead" rows since
# dead don't accrue costs.
#
# - cost      = occupancy_proportion * cohort_n * per_capita_cost
# - cost_disc = cost / (1 + r)^(age - start_age)   (cycle 0 undiscounted)
#
# The cost_df from the loader has 4 per-capita cost columns (NW/OW/OB1/OB2).
# Both N_always and N_prev draw from the NW column (per §2.6) — they have
# identical per-capita costs but separate occupancy, so the total euros
# spent in each is different and reported separately.
# ==============================================================================

.build_costs_df <- function(trace, cost_mat, ages, sex, cohort_n,
                             start_age, disc_rate) {
  c_NW <- cost_mat[, "NW"]
  per_age_state_cost <- cbind(
    N_always = trace[, "N_always"] * c_NW,
    N_prev   = trace[, "N_prev"]   * c_NW,
    OW       = trace[, "OW"]       * cost_mat[, "OW"],
    OB1      = trace[, "OB1"]      * cost_mat[, "OB1"],
    OB2      = trace[, "OB2"]      * cost_mat[, "OB2"]
  ) * cohort_n

  disc <- 1 / (1 + disc_rate) ^ (ages - start_age)
  per_age_state_cost_disc <- sweep(per_age_state_cost, 1, disc, `*`)

  state_names <- c("N_always", "N_prev", "OW", "OB1", "OB2")
  data.frame(
    age       = rep(as.integer(ages), times = length(state_names)),
    sex       = sex,
    state     = rep(state_names, each = length(ages)),
    cost      = as.numeric(per_age_state_cost),
    cost_disc = as.numeric(per_age_state_cost_disc),
    stringsAsFactors = FALSE
  )
}
