#' Run the raw MOON Markov engine
#'
#' Low-level pure-function entry point to the MOON Markov cohort engine.
#' Most users should call [moon_deterministic()] instead, which builds and
#' validates the inputs and returns tidy output. `run_markov_engine()` is
#' exported for advanced sensitivity-analysis workflows that need direct
#' access to the engine's six-state trace and per-capita cost matrix.
#'
#' The engine is pure: identical inputs produce byte-identical outputs.
#' No I/O, no global state, no `set.seed()` calls.
#'
#' @param start_age Integer; first model age (e.g. `2`).
#' @param max_age Integer; one past the last model age (e.g. `100`).
#'   `n_cycles = max_age - start_age`.
#' @param discount_rate Numeric in `[0, 1)`; applied to `cost_matrix` only.
#' @param init_prev Named numeric `c(NW = ..., OW = ..., OB1 = ..., OB2 = ...)`
#'   summing to 1. All `NW` mass enters the engine as `N_always`; `N_prev`
#'   starts at 0.
#' @param transition_probs Data frame with columns `age, NW_OW, OW_OB1,
#'   OB1_OB2, OW_NW, OB1_OW, OB2_OB1` — one row per age in
#'   `start_age:(max_age - 1)`.
#' @param qx Named numeric vector of NW baseline mortality probabilities;
#'   names are ages as character.
#' @param mortality_hr Data frame with columns `age_lower, OW, OB1, OB2`
#'   (three rows, one per age band 35 / 50 / 70).
#' @param cost_df Data frame with columns `age, state`
#'   (`NW` / `OW` / `OB1` / `OB2`), `cost`. Single-sex, already filtered.
#'   `NULL` or zero-row for no costs.
#' @param tp_overrides Optional list. Supported slots: `set_zero` (character
#'   vector of transitions to zero out), `init_prev` (overrides
#'   `init_prev`), `start_age` (overrides `start_age`).
#'
#' @return A list with
#'   * `trace` — `(n_cycles + 1) x 6` matrix of state proportions
#'     (rows sum to 1).
#'   * `cost_matrix` — `(n_cycles + 1) x 4` matrix of per-capita costs by
#'     `(age, state)`.
#'   * `mortality` — list of mortality probability vectors per state
#'     (`NW`, `OW`, `OB1`, `OB2`).
#'
#' @seealso [moon_deterministic()] for the validated-input wrapper most
#'   users want.
#'
#' @examples
#' \donttest{
#' params <- moon_params_norway(sex = "female")
#' out <- run_markov_engine(
#'   start_age        = params$start_age,
#'   max_age          = params$max_age,
#'   discount_rate    = params$discount_rate,
#'   init_prev        = params$init_prev,
#'   transition_probs = params$transition_probs,
#'   qx               = params$qx,
#'   mortality_hr     = params$mortality_hr,
#'   cost_df          = params$cost_df
#' )
#' dim(out$trace)
#' }
#'
#' @keywords internal
#' @export
run_markov_engine <- function(start_age,
                               max_age,
                               discount_rate,
                               init_prev,
                               transition_probs,
                               qx,
                               mortality_hr,
                               cost_df,
                               tp_overrides = NULL) {

  # Apply tp_overrides (start_age and init_prev slots)
  if (!is.null(tp_overrides$start_age)) start_age <- tp_overrides$start_age
  if (!is.null(tp_overrides$init_prev)) init_prev  <- tp_overrides$init_prev

  n_cycles  <- max_age - start_age
  ages      <- start_age:(max_age - 1)   # ages for cycle t = 1..n_cycles

  # Map user-facing 4-state init_prev to internal 6 states.
  # All NW mass goes to N_always (N_prev = 0); see plan §10.1.
  init_6 <- c(
    N_always = unname(init_prev["NW"]),
    N_prev   = 0,
    OW       = unname(init_prev["OW"]),
    OB1      = unname(init_prev["OB1"]),
    OB2      = unname(init_prev["OB2"]),
    D        = 0
  )

  # Build age-specific mortality vectors for all states
  mort <- .build_mortality_vec(qx, mortality_hr, ages)

  # Build the 6 x 6 x n_cycles transition array in one vectorised pass --
  # no dimnames on the inner slabs (the colnames go on the trace below).
  tp_array <- .build_tp_array(transition_probs, mort,
                              set_zero = tp_overrides$set_zero)

  # Run the Markov loop; attach column names afterwards for downstream
  # by-name indexing in .build_trace_df / .build_costs_df.
  trace <- .run_markov(init_6, tp_array)
  colnames(trace) <- c("N_always", "N_prev", "OW", "OB1", "OB2", "D")

  # Expand cost data frame into a matrix aligned to model ages (cycles 0..n_cycles)
  cost_matrix <- .expand_costs(cost_df, ages = start_age:max_age)

  list(
    trace       = trace,
    cost_matrix = cost_matrix,
    mortality   = mort
  )
}
