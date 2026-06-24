#' Methods for `moon_psa` objects
#'
#' S3 methods for inspecting, summarising, plotting, and coercing the
#' object returned by [moon_psa()].
#'
#' @param x,object A [moon_psa()] object.
#' @param ... Further arguments passed to or from other methods.
#' @param what For `as.data.frame()`, one of `"per_iter"` (default),
#'   `"draws"`, or `"summary"` — selects which long-form data frame to
#'   return.
#' @param row.names,optional Standard `as.data.frame()` arguments;
#'   currently ignored.
#' @param type For `plot()`, one of `"forest"` (default; point + 95% CI
#'   per metric, faceted by metric family) or `"incremental_cost_age"`
#'   (per-age incremental cost vs NW, mean +/- 95% band; requires
#'   `store_traces = "all"` on the original [moon_psa()] call).
#'
#' @return `print()` returns its input invisibly (and prints headline
#'   metric bands). `summary()` returns the precomputed summary data frame
#'   (mean, 95% CI, sd per `(sex, metric)`). `as.data.frame()` returns the
#'   requested long data frame. `plot()` returns a `ggplot` object; the
#'   `ggplot2` package is required.
#'
#' @seealso [moon_psa()], [moon_deterministic()].
#'
#' @name moon_psa-methods
NULL


#' @rdname moon_psa-methods
#' @export
print.moon_psa <- function(x, ...) {
  cat("<moon_psa>\n")
  cat(sprintf("  Iterations:    %d\n", x$meta$n_iter))
  sx <- if (length(x$per_iter)) unique(x$per_iter$sex) else "(empty)"
  cat(sprintf("  Sex:           %s\n", paste(sx, collapse = ", ")))
  cat(sprintf("  Seed:          %s\n",
              if (is.na(x$meta$seed)) "(none)" else x$meta$seed))
  cat(sprintf("  Parallel:      %s\n", x$meta$parallel))
  cat(sprintf("  Runtime:       %.2f s\n", x$meta$runtime_sec))
  cat(sprintf("  Correlate HR:  %s\n", x$meta$correlate_hr))
  cat(sprintf("  Correlate $:   %s\n", x$meta$correlate_cost))
  cat(sprintf("  Store traces:  %s\n", x$meta$store_traces))
  if (!is.null(x$meta$tp_overrides)) {
    cat(sprintf("  tp_overrides:  %s\n",
                paste(names(x$meta$tp_overrides), collapse = ", ")))
  }
  cat("\nHeadline metrics (mean [95% CI]):\n")
  topm <- c("cum_inc_cost_total_undisc", "LE", "prev_OW_age45")
  for (m in topm) {
    rows <- x$summary[x$summary$metric == m, , drop = FALSE]
    for (r_idx in seq_len(nrow(rows))) {
      cat(sprintf("  %-32s %s [%s, %s]\n",
                  paste0(rows$metric[r_idx], " (", rows$sex[r_idx], ")"),
                  format(round(rows$mean[r_idx],    3), big.mark = ","),
                  format(round(rows$lower95[r_idx], 3), big.mark = ","),
                  format(round(rows$upper95[r_idx], 3), big.mark = ",")))
    }
  }
  invisible(x)
}


#' @rdname moon_psa-methods
#' @export
summary.moon_psa <- function(object, ...) object$summary


#' @rdname moon_psa-methods
#' @export
as.data.frame.moon_psa <- function(x, row.names = NULL, optional = FALSE,
                                    what = c("per_iter", "draws", "summary"),
                                    ...) {
  what <- match.arg(what)
  switch(what,
    per_iter = x$per_iter,
    draws    = x$draws,
    summary  = x$summary
  )
}


#' @rdname moon_psa-methods
#' @export
plot.moon_psa <- function(x, type = c("forest", "incremental_cost_age"),
                          ...) {
  type <- match.arg(type)
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("plot.moon_psa() requires the ggplot2 package.")
  }

  switch(type,
    forest = .plot_psa_forest(x),
    incremental_cost_age = .plot_psa_inc_cost_age(x)
  )
}


.psa_metric_family <- function(metric) {
  ifelse(grepl("^prev_",     metric), "Prevalence",
  ifelse(metric == "LE",                 "LE",
  ifelse(grepl("_undisc$",   metric), "Cost (undiscounted)",
  ifelse(grepl("_disc$",     metric), "Cost (discounted)",
                                          "Other"))))
}

.plot_psa_forest <- function(x) {
  df <- x$summary
  family_levels <- c("Cost (undiscounted)", "Cost (discounted)",
                     "Prevalence", "LE")
  df$family <- factor(.psa_metric_family(df$metric), levels = family_levels)
  df$metric <- factor(df$metric, levels = unique(df$metric))
  ggplot2::ggplot(df,
                   ggplot2::aes(x = metric, y = mean,
                                 ymin = lower95, ymax = upper95)) +
    ggplot2::geom_pointrange() +
    ggplot2::coord_flip() +
    ggplot2::facet_wrap(~ family, scales = "free", ncol = 2) +
    ggplot2::labs(x = NULL, y = "Mean \u00b1 95% CI",
                   title = sprintf("PSA summary (n_iter = %d)", x$meta$n_iter)) +
    ggplot2::theme_minimal()
}


.plot_psa_inc_cost_age <- function(x) {
  if (x$meta$store_traces == "none") {
    stop("plot type 'incremental_cost_age' needs store_traces != 'none'.")
  }
  if (x$meta$store_traces == "summary") {
    stop("plot type 'incremental_cost_age' needs store_traces = 'all' so ",
         "each iteration's per-age cost vector can be reconstructed.")
  }
  results <- x$traces
  cn   <- unname(results[[1]]$params$cohort_n)
  ages <- sort(unique(results[[1]]$trace$age))

  # Per-age, per-state incremental cost per capita, per iteration
  states <- c("OW", "OB1", "OB2")
  inc_arr <- array(NA_real_,
                   dim = c(length(results), length(ages), length(states)),
                   dimnames = list(NULL, as.character(ages), states))

  for (i in seq_along(results)) {
    r  <- results[[i]]
    tr <- r$trace; ct <- r$costs
    # Per-capita state cost (cost / n) for each row
    m <- merge(tr, ct, by = c("age", "sex", "state"), all.x = TRUE)
    m$c <- ifelse(m$n > 0 & !is.na(m$cost), m$cost / m$n, 0)
    cnw <- m$c[m$state == "N_always"]
    names(cnw) <- as.character(m$age[m$state == "N_always"])
    m$c_NW <- cnw[as.character(m$age)]
    m$inc <- m$n * (m$c - m$c_NW) / cn
    for (s in states) {
      sub <- m[m$state == s, ]
      sub <- sub[order(sub$age), ]
      inc_arr[i, , s] <- sub$inc
    }
  }

  rows <- list()
  for (s in states) {
    mean_v   <- apply(inc_arr[, , s], 2, mean)
    p025_v   <- apply(inc_arr[, , s], 2, stats::quantile, 0.025, names = FALSE)
    p975_v   <- apply(inc_arr[, , s], 2, stats::quantile, 0.975, names = FALSE)
    rows[[s]] <- data.frame(age = ages, state = s,
                              mean = mean_v, lower = p025_v, upper = p975_v)
  }
  df <- do.call(rbind, rows)

  ggplot2::ggplot(df, ggplot2::aes(x = age, y = mean,
                                    ymin = lower, ymax = upper,
                                    colour = state, fill = state)) +
    ggplot2::geom_ribbon(alpha = 0.2, colour = NA) +
    ggplot2::geom_line(linewidth = 1) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed") +
    ggplot2::labs(x = "Age", y = "Per-capita incremental cost (EUR)",
                   colour = "State", fill = "State",
                   title = "Per-age incremental cost vs NW (PSA mean \u00b1 95% CI)") +
    ggplot2::theme_minimal()
}
