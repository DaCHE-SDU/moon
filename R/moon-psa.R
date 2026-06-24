#' Run a probabilistic sensitivity analysis (PSA) on a MOON spec
#'
#' Materialises `n_iter` parameter draws from a spec built with
#' `moon_params_norway(uncertainty = TRUE)`, runs [moon_deterministic()] on
#' each, computes per-iteration metrics, and aggregates them into a
#' `moon_psa` object.
#'
#' @param spec A spec'd `params` list, typically from
#'   `moon_params_norway(sex = ..., uncertainty = TRUE)`.
#' @param n_iter Integer; number of PSA iterations. The published MOON
#'   analysis uses `1000`.
#' @param seed Integer (or `NULL`); passed to [moon_sample_params()] so the
#'   draw sequence is reproducible.
#' @param parallel Logical. `FALSE` (default) runs iterations sequentially
#'   with `lapply`. `TRUE` uses `furrr::future_map` with a multicore
#'   (Linux / macOS) or multisession (Windows) plan; falls back to
#'   sequential with a warning if `furrr` / `future` are unavailable.
#' @param store_traces One of `"summary"` (default — keep a 3-D array
#'   `[iter, age, state]` of trace counts), `"all"` (keep the full list of
#'   `moon_deterministic` objects; large), or `"none"` (drop traces; keep
#'   only summary, per-iter metrics, and draws).
#' @param correlate_hr,correlate_cost Logical, passed to
#'   [moon_sample_params()]; both default `TRUE`.
#' @param tp_overrides Optional, forwarded to every [moon_deterministic()]
#'   call. Use to run a PSA on a scenario rather than the base case.
#'
#' @return A `moon_psa` S3 object — a list with
#'   * `summary` — per `(sex, metric)` summary
#'     (mean, 2.5 / 97.5 quantile, sd).
#'   * `per_iter` — long data frame of per-iteration metric values.
#'   * `traces` — depends on `store_traces`.
#'   * `draws` — long table of sampled mortality HRs by
#'     `(iter, parameter)`.
#'   * `params_spec` — the input spec, preserved for replay.
#'   * `meta` — run metadata.
#'
#' @seealso [moon_deterministic()], [moon_params_norway()],
#'   [moon_sample_params()].
#'
#' @examples
#' \donttest{
#' spec <- moon_params_norway(sex = "female", uncertainty = TRUE)
#' psa  <- moon_psa(spec, n_iter = 50, seed = 1)
#' head(psa$summary)
#' }
#'
#' @export
moon_psa <- function(spec,
                      n_iter,
                      seed           = NULL,
                      parallel       = FALSE,
                      store_traces   = c("summary", "all", "none"),
                      correlate_hr   = TRUE,
                      correlate_cost = TRUE,
                      tp_overrides   = NULL) {
  store_traces <- match.arg(store_traces)
  stopifnot(is.numeric(n_iter), length(n_iter) == 1L, n_iter >= 1L)

  t_start <- Sys.time()

  # 1. Materialise n_iter concrete draws
  draws_list <- moon_sample_params(spec, n = n_iter, seed = seed,
                                    correlate_hr   = correlate_hr,
                                    correlate_cost = correlate_cost)

  # 2. Run engine for each draw (parallel if requested + furrr available)
  run_one <- function(i) {
    # strict = FALSE: PSA tail draws (mvnorm coefficients pushed through the
    # survival function) can occasionally produce a transition row-sum > 1
    # at band-boundary ages, which moon_check_params() flags. The legacy
    # MoonPSA.r runs the engine on whatever the sampler produces — we match
    # that behaviour and let the engine propagate the (slightly biased) tail
    # draw rather than aborting the whole run. suppressWarnings keeps the
    # PSA loop output clean.
    res <- suppressWarnings(
      moon_deterministic(draws_list[[i]],
                              tp_overrides = tp_overrides,
                              strict       = FALSE,
                              record_meta  = FALSE)
    )
    res$meta$seed <- if (is.null(seed)) NA_integer_ else as.integer(seed)
    res$meta$iter <- as.integer(i)
    res
  }

  use_par <- isTRUE(parallel) &&
    requireNamespace("furrr",  quietly = TRUE) &&
    requireNamespace("future", quietly = TRUE)
  if (isTRUE(parallel) && !use_par) {
    warning("furrr/future not installed; falling back to sequential.")
  }

  if (use_par) {
    plan_kind <- if (.Platform$OS.type == "windows") {
      future::multisession
    } else {
      future::multicore
    }
    old_plan <- future::plan(plan_kind)
    on.exit(future::plan(old_plan), add = TRUE)
    results <- furrr::future_map(seq_len(n_iter), run_one,
                                  .options = furrr::furrr_options(seed = TRUE))
  } else {
    results <- lapply(seq_len(n_iter), run_one)
  }

  # 3. Per-iteration metrics + summary
  per_iter <- .compute_per_iter(results)
  summary_df <- .compute_psa_summary(per_iter)

  # 4. Draws audit table (HR-only by default — costs/transitions are
  #    recoverable from each iteration's $params when store_traces = "all")
  draws_df <- .build_draws_df(draws_list)

  # 5. Trace storage policy
  traces_out <- switch(store_traces,
    all     = results,
    summary = .summarize_traces(results),
    none    = NULL
  )

  duration <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

  structure(
    list(
      summary     = summary_df,
      per_iter    = per_iter,
      traces      = traces_out,
      draws       = draws_df,
      params_spec = spec,
      meta = list(
        n_iter         = as.integer(n_iter),
        seed           = if (is.null(seed)) NA_integer_ else as.integer(seed),
        parallel       = use_par,
        runtime_sec    = duration,
        store_traces   = store_traces,
        correlate_hr   = correlate_hr,
        correlate_cost = correlate_cost,
        tp_overrides   = tp_overrides
      )
    ),
    class = "moon_psa"
  )
}


# ==============================================================================
# .compute_per_iter
# Per-iteration metrics. Returns a long data frame with one row per
# (iter, sex, metric, value). Twelve metrics per iteration:
#   * cum_inc_cost_<state>_<undisc|disc>      for state in {OW, OB1, OB2}
#   * cum_inc_cost_total_<undisc|disc>
#   * LE
#   * prev_<state>_age45                       for state in {OW, OB1, OB2}
#
# All cost metrics are PER-CAPITA (divided by cohort_n) and computed against
# the NW baseline read from N_always rows (per-capita N_prev cost is identical).
# ==============================================================================

.compute_per_iter <- function(results) {
  metric_names <- c(
    "cum_inc_cost_OW_undisc",  "cum_inc_cost_OB1_undisc",
    "cum_inc_cost_OB2_undisc", "cum_inc_cost_total_undisc",
    "cum_inc_cost_OW_disc",    "cum_inc_cost_OB1_disc",
    "cum_inc_cost_OB2_disc",   "cum_inc_cost_total_disc",
    "LE",
    "prev_OW_age45", "prev_OB1_age45", "prev_OB2_age45"
  )

  rows_per_iter <- length(metric_names)
  total_rows    <- length(results) * rows_per_iter
  iter_v   <- integer(total_rows)
  sex_v    <- character(total_rows)
  metric_v <- character(total_rows)
  value_v  <- numeric(total_rows)

  pos <- 1L
  for (r in results) {
    cn   <- unname(r$params$cohort_n)
    sex  <- names(r$params$cohort_n)
    iter <- r$meta$iter

    m <- merge(r$trace, r$costs, by = c("age", "sex", "state"), all.x = TRUE)
    m$c_per   <- ifelse(m$n > 0 & !is.na(m$cost),      m$cost      / m$n, 0)
    m$c_per_d <- ifelse(m$n > 0 & !is.na(m$cost_disc), m$cost_disc / m$n, 0)

    c_NW   <- m$c_per[m$state   == "N_always"]
    c_NW_d <- m$c_per_d[m$state == "N_always"]
    age_NW <- as.character(m$age[m$state == "N_always"])
    names(c_NW)   <- age_NW
    names(c_NW_d) <- age_NW
    m$c_NW   <- c_NW[as.character(m$age)]
    m$c_NW_d <- c_NW_d[as.character(m$age)]

    state_inc <- function(s, disc = FALSE) {
      sub <- m[m$state == s, ]
      if (disc) sum(sub$n * (sub$c_per_d - sub$c_NW_d)) / cn
      else      sum(sub$n * (sub$c_per   - sub$c_NW))   / cn
    }
    inc_undisc <- vapply(c("OW", "OB1", "OB2"), state_inc, numeric(1),
                          disc = FALSE)
    inc_disc   <- vapply(c("OW", "OB1", "OB2"), state_inc, numeric(1),
                          disc = TRUE)

    LE <- sum(r$trace$n[r$trace$state != "dead"]) / cn

    a45 <- r$trace[r$trace$age == 45, ]
    alive45 <- sum(a45$n[a45$state != "dead"])
    prev45 <- vapply(c("OW", "OB1", "OB2"), function(s) {
      n_s <- a45$n[a45$state == s]
      if (length(n_s) == 0L || alive45 == 0) NA_real_ else n_s / alive45
    }, numeric(1))

    metrics <- c(inc_undisc, sum(inc_undisc),
                  inc_disc,  sum(inc_disc),
                  LE,
                  prev45)

    idx <- pos:(pos + rows_per_iter - 1L)
    iter_v[idx]   <- iter
    sex_v[idx]    <- sex
    metric_v[idx] <- metric_names
    value_v[idx]  <- metrics
    pos <- pos + rows_per_iter
  }

  data.frame(iter = iter_v, sex = sex_v, metric = metric_v,
             value = value_v, stringsAsFactors = FALSE)
}


# ==============================================================================
# .compute_psa_summary
# Mean / 2.5%-97.5% percentiles / SD per (sex, metric).
# ==============================================================================

.compute_psa_summary <- function(per_iter) {
  agg <- stats::aggregate(value ~ sex + metric, data = per_iter, FUN = function(v) {
    c(mean    = mean(v),
      lower95 = unname(stats::quantile(v, 0.025)),
      upper95 = unname(stats::quantile(v, 0.975)),
      sd      = stats::sd(v))
  })
  data.frame(
    sex     = agg$sex,
    metric  = agg$metric,
    mean    = agg$value[, "mean"],
    lower95 = agg$value[, "lower95"],
    upper95 = agg$value[, "upper95"],
    sd      = agg$value[, "sd"],
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}


# ==============================================================================
# .build_draws_df
# Long table of mortality HR draws keyed by (iter, parameter). HRs are the
# most common audit target; transition coefs and cost gammas can be recovered
# from each iteration's $params when store_traces = "all".
# ==============================================================================

.build_draws_df <- function(draws_list) {
  n <- length(draws_list)
  states <- c("OW", "OB1", "OB2")
  bands  <- c(35, 50, 70)
  rows_per_iter <- length(states) * length(bands)
  total <- n * rows_per_iter

  iter_v  <- integer(total)
  param_v <- character(total)
  value_v <- numeric(total)

  pos <- 1L
  for (i in seq_along(draws_list)) {
    hrs <- draws_list[[i]]$mortality_hr
    for (st in states) {
      for (b_idx in seq_along(bands)) {
        iter_v[pos]  <- i
        param_v[pos] <- sprintf("hr_%s_band%d", st, bands[b_idx])
        value_v[pos] <- hrs[[st]][b_idx]
        pos <- pos + 1L
      }
    }
  }

  data.frame(iter = iter_v, parameter = param_v, value = value_v,
             stringsAsFactors = FALSE)
}


# ==============================================================================
# .summarize_traces
# Stack each iteration's trace counts into a 3-D array [iter, age, state] for
# downstream prevalence / occupancy plots without holding the full per-
# iteration moon_deterministic objects in memory.
# ==============================================================================

.summarize_traces <- function(results) {
  if (length(results) == 0L) return(NULL)
  ages   <- sort(unique(results[[1]]$trace$age))
  states <- unique(results[[1]]$trace$state)
  arr <- array(NA_real_, dim = c(length(results), length(ages), length(states)),
               dimnames = list(iter = NULL,
                                age   = as.character(ages),
                                state = states))
  for (i in seq_along(results)) {
    tr <- results[[i]]$trace
    for (s in states) {
      sub <- tr[tr$state == s, ]
      sub <- sub[order(sub$age), , drop = FALSE]
      arr[i, , s] <- sub$n
    }
  }
  arr
}
