#' Materialise a spec'd `params` list into `n` concrete draws
#'
#' Walks a spec'd `params` list (typically from
#' `moon_params_norway(uncertainty = TRUE)`) and materialises `n` fully
#' concrete `params` lists ready for [moon_deterministic()].
#'
#' Two correlation flags reproduce the published MOON conventions:
#'
#' * `correlate_hr` (default `TRUE`) — one `rnorm(n)` draw is reused as the
#'   Z-source for all 9 mortality-HR lognormals (3 states × 3 age bands).
#' * `correlate_cost` (default `TRUE`) — one `runif(n)` draw is reused as
#'   the inverse-CDF input for every cost gamma.
#'
#' When a flag is `FALSE`, each spec generates its own independent draws.
#' Within a single call (with a fixed `seed`) the RNG order is HR `z` →
#' cost `u` → transition-coefficient mvnorm draws (in order of band-key).
#' The order is stable across calls but is not expected to match the legacy
#' MOON port byte-for-byte.
#'
#' @param spec A spec'd `params` list, typically from
#'   `moon_params_norway(uncertainty = TRUE)`.
#' @param n Integer; number of iterations to materialise.
#' @param seed Integer (or `NULL`); calls `set.seed(seed)` before drawing
#'   so the resulting list is reproducible.
#' @param correlate_hr,correlate_cost Logical; see Details. Both default
#'   to `TRUE` to match the published analysis.
#'
#' @return A length-`n` list of plain-value `params` lists, each ready for
#'   [moon_deterministic()].
#'
#' @seealso [moon_params_norway()], [moon_psa()],
#'   [moon_deterministic()].
#'
#' @examples
#' \donttest{
#' spec  <- moon_params_norway(sex = "female", uncertainty = TRUE)
#' draws <- moon_sample_params(spec, n = 5, seed = 1)
#' length(draws)
#' }
#'
#' @export
moon_sample_params <- function(spec, n, seed = NULL,
                                correlate_hr   = TRUE,
                                correlate_cost = TRUE) {
  stopifnot(is.list(spec), is.numeric(n), length(n) == 1L, n >= 1L)
  if (!is.null(seed)) set.seed(seed)

  # 1. Mortality HR draws — 3 bands × 3 states (OW, OB1, OB2)
  z_hr <- if (isTRUE(correlate_hr)) stats::rnorm(n) else NULL
  hr_draws <- list()
  for (state in c("OW", "OB1", "OB2")) {
    cells <- spec$mortality_hr[[state]]
    # vapply gives n × 3 matrix (cols = age bands)
    hr_draws[[state]] <- vapply(cells, function(s) {
      moon_param_sample(s, n = n, z = z_hr)
    }, numeric(n))
  }

  # 2. Cost draws — long form, length-1 spec per (state, age) cell
  u_cost <- if (isTRUE(correlate_cost)) stats::runif(n) else NULL
  cost_specs <- spec$cost_df$cost
  cost_mat <- vapply(cost_specs, function(cell) {
    drop(moon_param_sample(cell, n = n, u = u_cost))   # length-n
  }, numeric(n))                                         # n × n_cells matrix

  # 3. Transition coefficient draws — one mvnorm per band-key
  band_specs <- spec$transition_probs$specs
  band_draws <- lapply(band_specs, function(s) {
    moon_param_sample(s, n = n)                          # n × length(cycles)
  })
  bands <- spec$transition_probs$bands

  # 4. Assemble per-iteration params
  out <- vector("list", n)
  for (i in seq_len(n)) {
    out[[i]] <- list(
      start_age        = spec$start_age,
      max_age          = spec$max_age,
      discount_rate    = spec$discount_rate,
      cost_currency    = spec$cost_currency,
      cohort_n         = spec$cohort_n,
      init_prev        = spec$init_prev,
      qx               = spec$qx,
      mortality_hr     = data.frame(
                            age_lower = c(35, 50, 70),
                            OW  = hr_draws$OW[i, ],
                            OB1 = hr_draws$OB1[i, ],
                            OB2 = hr_draws$OB2[i, ]
                          ),
      transition_probs = .stitch_transition_draws(band_draws, bands, i),
      cost_df          = data.frame(
                            age   = spec$cost_df$age,
                            state = spec$cost_df$state,
                            cost  = cost_mat[i, ]
                          )
    )
  }
  out
}


# ==============================================================================
# .stitch_transition_draws
# Rebuilds the deterministic engine's transition_probs data frame from the
# per-band sample matrices for a single iteration. Mirrors the stitch logic
# in .build_transition_probs (utils-data.R) but operates on draws.
# ==============================================================================

.stitch_transition_draws <- function(band_draws, bands, i) {
  csv_to_engine <- c(N_OW   = "NW_OW",   OW_N   = "OW_NW",
                     OW_OB1 = "OW_OB1",  OB1_OW = "OB1_OW",
                     OB1_OB2 = "OB1_OB2", OB2_OB1 = "OB2_OB1")

  by_tr  <- split(bands, bands$transition)
  result <- list()
  for (tr in names(by_tr)) {
    sub <- by_tr[[tr]][order(by_tr[[tr]]$age_start), , drop = FALSE]
    result[[csv_to_engine[[tr]]]] <- do.call(c, lapply(sub$key, function(k) {
      band_draws[[k]][i, ]
    }))
  }

  age_seq <- seq(min(bands$age_start), max(bands$age_end) - 1L)

  data.frame(
    age     = as.integer(age_seq),
    NW_OW   = result[["NW_OW"]],
    OW_NW   = result[["OW_NW"]],
    OW_OB1  = result[["OW_OB1"]],
    OB1_OW  = result[["OB1_OW"]],
    OB1_OB2 = result[["OB1_OB2"]],
    OB2_OB1 = result[["OB2_OB1"]],
    stringsAsFactors = FALSE
  )
}
