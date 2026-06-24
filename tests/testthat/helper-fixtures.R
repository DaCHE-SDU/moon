# helper-fixtures.R
#
# Auto-loaded by testthat before each test file in this directory. The
# package itself is loaded by devtools::load_all() (or library(moon) under
# R CMD check), so no source() block is needed here. This file just
# provides:
#   * .find_moon_root()     — locates moon/ root by walking up from CWD;
#                             still useful for tests that read .Rbuildignored
#                             reference baselines outside tests/testthat/
#   * .run_base / .run_sa2  — engine wrappers for the base + SA2 scenarios
#                             that take any params list (loader-built or
#                             hand-built)
#   * .calc_inc_cost / .calc_LE / .calc_prev45 — anchor metrics computed
#                             directly off the engine's raw output


# ==============================================================================
# Locate moon/ root by walking up from the current working directory.
# When testthat::test_dir runs, CWD is typically tests/testthat/.
# ==============================================================================

.find_moon_root <- function() {
  d <- normalizePath(".", mustWork = TRUE)
  for (i in 1:6) {
    if (file.exists(file.path(d, "R", "engine.R"))) return(d)
    parent <- dirname(d)
    if (parent == d) break
    d <- parent
  }
  NA_character_
}


# ==============================================================================
# Engine wrappers (base + SA2). Take any params list — loader-built or
# hand-built — and call run_markov_engine() directly.
# ==============================================================================

.run_base <- function(p) {
  run_markov_engine(
    start_age        = p$start_age,
    max_age          = p$max_age,
    discount_rate    = p$discount_rate,
    init_prev        = p$init_prev,
    transition_probs = p$transition_probs,
    qx               = p$qx,
    mortality_hr     = p$mortality_hr,
    cost_df          = p$cost_df
  )
}

.run_sa2 <- function(p) {
  ip <- p$init_prev
  init_sa2 <- c(
    NW  = unname(ip[["NW"]]),
    OW  = unname(ip[["OW"]] + ip[["OB1"]] + ip[["OB2"]]),
    OB1 = 0,
    OB2 = 0
  )
  run_markov_engine(
    start_age        = p$start_age,
    max_age          = p$max_age,
    discount_rate    = p$discount_rate,
    init_prev        = p$init_prev,
    transition_probs = p$transition_probs,
    qx               = p$qx,
    mortality_hr     = p$mortality_hr,
    cost_df          = p$cost_df,
    tp_overrides     = list(set_zero = "OW_OB1", init_prev = init_sa2)
  )
}


# ==============================================================================
# Anchor metrics computed off the engine's raw output (trace + cost_matrix).
# ==============================================================================

.calc_inc_cost <- function(res) {
  cm <- res$cost_matrix
  tr <- res$trace
  sum(tr[, "OW"]  * (cm[, "OW"]  - cm[, "NW"])) +
    sum(tr[, "OB1"] * (cm[, "OB1"] - cm[, "NW"])) +
    sum(tr[, "OB2"] * (cm[, "OB2"] - cm[, "NW"]))
}

.calc_LE <- function(res) sum(1 - res$trace[, "D"])

.calc_prev45 <- function(res) {
  unname(res$trace[44, "OW"] / (1 - res$trace[44, "D"]))
}
