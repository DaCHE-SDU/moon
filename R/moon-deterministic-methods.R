#' Methods for `moon_deterministic` objects
#'
#' S3 methods for inspecting, summarising, plotting, and coercing the object
#' returned by [moon_deterministic()].
#'
#' @param x,object A [moon_deterministic()] object (or, for
#'   `print.summary.moon_deterministic`, the object returned by
#'   `summary()`).
#' @param ... Further arguments passed to or from other methods.
#' @param what For `as.data.frame()`, one of `"trace"` (default) or
#'   `"costs"` — selects which long-form data frame to return.
#' @param row.names,optional Standard `as.data.frame()` arguments;
#'   currently ignored.
#' @param type For `plot()`, one of `"occupancy"`, `"prevalence_alive"`,
#'   `"prevalence_initial"`, `"survival"`, or `"costs"`.
#' @param ages For `plot()`, optional integer vector to filter the
#'   underlying trace and costs to before plotting; `NULL` (default) plots
#'   all ages.
#' @param by_sex Forward-compatibility hook for multi-sex stitched runs;
#'   has no effect today since each `moon_deterministic` object is
#'   single-sex by construction.
#'
#' @return `print()` returns its input invisibly (and prints a one-screen
#'   headline). `summary()` returns a `summary.moon_deterministic` object
#'   carrying life-expectancy, total/discounted cost, age-45 prevalence,
#'   and per-state per-capita incremental cost vs NW. `as.data.frame()`
#'   returns the requested long data frame. `plot()` returns a `ggplot`
#'   object; the `ggplot2` package is required.
#'
#' @seealso [moon_deterministic()], [moon_prevalence()],
#'   [moon_costs()].
#'
#' @name moon_deterministic-methods
NULL


# Internal helper: per-capita cumulative incremental cost vs NW (undiscounted).
# Recovers c_state from cost / n (since `costs` stores total euros, not
# per-capita), then forms sum_state in {OW,OB1,OB2} of n_s * (c_s - c_NW)
# divided by cohort_n. The NW baseline per-capita cost is read from the
# `N_always` rows — `N_prev` carries the same per-capita cost (both draw
# from cost_df$state == "NW") so either works.

.per_capita_inc_cost <- function(x) {
  trace <- x$trace
  costs <- x$costs
  cn    <- unname(x$params$cohort_n)
  m <- merge(trace, costs, by = c("age", "sex", "state"), all.x = TRUE)
  m$c   <- ifelse(m$n > 0 & !is.na(m$cost), m$cost / m$n, 0)
  c_NW  <- m$c[m$state == "N_always"]
  names(c_NW) <- as.character(m$age[m$state == "N_always"])
  m$c_NW <- c_NW[as.character(m$age)]
  vapply(c("OW", "OB1", "OB2"), function(s) {
    sub <- m[m$state == s, ]
    sum(sub$n * (sub$c - sub$c_NW)) / cn
  }, numeric(1))
}


#' @rdname moon_deterministic-methods
#' @export
print.moon_deterministic <- function(x, ...) {
  sex     <- unique(x$trace$sex)
  cn      <- unname(x$params$cohort_n)
  horizon <- x$meta$horizon
  LE      <- sum(x$trace$n[x$trace$state != "dead"]) / cn
  inc     <- .per_capita_inc_cost(x)

  cat("<moon_deterministic>\n")
  cat(sprintf("  Sex:         %s (cohort N = %s)\n",
              paste(sex, collapse = ", "), format(cn, big.mark = ",")))
  cat(sprintf("  Horizon:     ages %d to %d\n",
              horizon[["start_age"]], horizon[["max_age"]]))
  cat(sprintf("  LE:          %.2f years\n", LE))
  cat(sprintf("  Total cost:  %s undisc / %s disc (r = %.0f%%)\n",
              .euro(sum(x$costs$cost)),
              .euro(sum(x$costs$cost_disc)),
              x$meta$discount_rate * 100))
  cat(sprintf("  Per-capita inc cost vs NW (undisc): %s\n",
              .euro(sum(inc))))
  if (!is.null(x$meta$tp_overrides)) {
    cat("  tp_overrides applied: ",
        paste(names(x$meta$tp_overrides), collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}


#' @rdname moon_deterministic-methods
#' @export
summary.moon_deterministic <- function(object, ...) {
  trace <- object$trace
  costs <- object$costs
  cn    <- unname(object$params$cohort_n)

  LE <- sum(trace$n[trace$state != "dead"]) / cn

  age45_alive <- trace[trace$age == 45 & trace$state != "dead", ]
  alive45     <- sum(age45_alive$n)
  prev45      <- if (alive45 > 0) {
    stats::setNames(age45_alive$n / alive45, age45_alive$state)
  } else {
    stats::setNames(rep(NA_real_, nrow(age45_alive)), age45_alive$state)
  }

  inc_by_state <- .per_capita_inc_cost(object)

  structure(
    list(
      sex             = unique(trace$sex),
      horizon         = object$meta$horizon,
      cohort_n        = cn,
      discount_rate   = object$meta$discount_rate,
      LE              = LE,
      total_cost      = sum(costs$cost),
      total_cost_disc = sum(costs$cost_disc),
      prev_age45      = prev45,
      inc_cost_state  = inc_by_state,
      inc_cost_total  = sum(inc_by_state),
      tp_overrides    = object$meta$tp_overrides
    ),
    class = "summary.moon_deterministic"
  )
}


#' @rdname moon_deterministic-methods
#' @export
print.summary.moon_deterministic <- function(x, ...) {
  cat("<summary.moon_deterministic>\n")
  cat(sprintf("  Sex:         %s (cohort N = %s)\n",
              paste(x$sex, collapse = ", "), format(x$cohort_n, big.mark = ",")))
  cat(sprintf("  Horizon:     ages %d to %d, discount rate %.0f%%\n",
              x$horizon[["start_age"]], x$horizon[["max_age"]],
              x$discount_rate * 100))
  cat(sprintf("  LE:          %.2f years\n", x$LE))
  cat(sprintf("  Total cost:  %s undisc / %s disc\n",
              .euro(x$total_cost), .euro(x$total_cost_disc)))
  cat("  Prevalence at age 45 (among alive):\n")
  for (s in names(x$prev_age45)) {
    cat(sprintf("    %-5s %5.1f%%\n", s, x$prev_age45[[s]] * 100))
  }
  cat("  Per-capita cumulative incremental cost vs NW (undisc):\n")
  for (s in names(x$inc_cost_state)) {
    cat(sprintf("    %-4s %s\n", s, .euro(x$inc_cost_state[[s]])))
  }
  cat(sprintf("    %-4s %s\n", "All", .euro(x$inc_cost_total)))
  if (!is.null(x$tp_overrides)) {
    cat("  tp_overrides applied: ",
        paste(names(x$tp_overrides), collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}


.euro <- function(v) {
  if (!is.finite(v)) return("NA")
  paste0("EUR ", format(round(v), big.mark = ",", scientific = FALSE))
}


#' @rdname moon_deterministic-methods
#' @export
as.data.frame.moon_deterministic <- function(x, row.names = NULL, optional = FALSE,
                                    what = c("trace", "costs"), ...) {
  what <- match.arg(what)
  switch(what,
    trace = x$trace,
    costs = x$costs
  )
}


#' @rdname moon_deterministic-methods
#' @export
plot.moon_deterministic <- function(x,
                           type   = c("occupancy", "prevalence_alive",
                                      "prevalence_initial", "survival",
                                      "costs"),
                           ages   = NULL,
                           by_sex = FALSE,
                           ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("plot.moon_deterministic() requires the ggplot2 package.")
  }
  type <- match.arg(type)

  trace <- x$trace
  costs <- x$costs
  cn    <- unname(x$params$cohort_n)
  if (!is.null(ages)) {
    trace <- trace[trace$age %in% ages, ]
    costs <- costs[costs$age %in% ages, ]
  }

  pct_labels <- function(v) paste0(round(v * 100), "%")

  switch(type,
    occupancy = {
      ggplot2::ggplot(trace, ggplot2::aes(x = age, y = n, colour = state)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::labs(x = "Age", y = "Cohort head-count", colour = "State",
                      title = "Cohort occupancy over the lifetime") +
        ggplot2::theme_minimal()
    },

    prevalence_alive = {
      df <- .compute_prev_df(trace, "alive", cn)
      ggplot2::ggplot(df, ggplot2::aes(x = age, y = prev, colour = state)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::scale_y_continuous(labels = pct_labels) +
        ggplot2::labs(x = "Age", y = "Prevalence (% of alive)",
                      colour = "State",
                      title = "Prevalence among alive over the lifetime") +
        ggplot2::theme_minimal()
    },

    prevalence_initial = {
      df <- .compute_prev_df(trace, "initial", cn)
      ggplot2::ggplot(df, ggplot2::aes(x = age, y = prev, colour = state)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::scale_y_continuous(labels = pct_labels) +
        ggplot2::labs(x = "Age", y = "Prevalence (% of initial cohort)",
                      colour = "State",
                      title = "Prevalence as % of initial cohort") +
        ggplot2::theme_minimal()
    },

    survival = {
      alive <- stats::aggregate(n ~ age + sex,
                         trace[trace$state != "dead", ], FUN = sum)
      alive$prop <- alive$n / cn
      ggplot2::ggplot(alive, ggplot2::aes(x = age, y = prop)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::scale_y_continuous(labels = pct_labels, limits = c(0, 1)) +
        ggplot2::labs(x = "Age", y = "Proportion alive",
                      title = "Cohort survival") +
        ggplot2::theme_minimal()
    },

    costs = {
      m <- merge(trace, costs, by = c("age", "sex", "state"), all.x = TRUE)
      m$c <- ifelse(m$n > 0 & !is.na(m$cost), m$cost / m$n, 0)
      c_NW <- m$c[m$state == "N_always"]
      names(c_NW) <- as.character(m$age[m$state == "N_always"])
      m$c_NW <- c_NW[as.character(m$age)]
      m$inc_per_capita <- m$n * (m$c - m$c_NW) / cn
      df <- m[m$state %in% c("OW", "OB1", "OB2"), ]
      ggplot2::ggplot(df, ggplot2::aes(x = age, y = inc_per_capita,
                                        colour = state)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::labs(x = "Age", y = "Per-capita incremental cost (EUR)",
                      colour = "State",
                      title = "Per-age per-capita incremental cost vs NW") +
        ggplot2::theme_minimal()
    }
  )
}


.compute_prev_df <- function(trace, denominator, cn) {
  if (denominator == "alive") {
    alive <- stats::aggregate(n ~ age + sex,
                       trace[trace$state != "dead", ], FUN = sum)
    names(alive)[names(alive) == "n"] <- "denom"
    out <- merge(trace[trace$state != "dead", ], alive,
                 by = c("age", "sex"))
  } else {
    out <- trace
    out$denom <- cn
  }
  out$prev <- out$n / out$denom
  out
}
