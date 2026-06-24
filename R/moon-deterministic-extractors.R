#' Compute prevalence by age and state from a deterministic run
#'
#' Returns a long data frame with one row per `(age, [sex,] state)` and a
#' `prevalence` column. The state set carries the engine's six-state space
#' (`N_always`, `N_prev`, `OW`, `OB1`, `OB2`, `dead`).
#'
#' Choice of denominator:
#'
#' * `"alive"` — denominator is the per-age sum of head-counts over alive
#'   states. Prevalence sums to 1 per age. The `dead` state is dropped from
#'   the output.
#' * `"initial"` — denominator is `params$cohort_n` (constant). Prevalence
#'   sums to 1 per age **once the `dead` row is included**, since `dead`
#'   drains the live ones.
#'
#' @param x A [moon_deterministic()] object.
#' @param denominator `"alive"` (default) or `"initial"`.
#' @param ages Optional integer vector to filter; `NULL` (default) returns
#'   all ages.
#' @param by_sex `FALSE` (default) drops the `sex` column from the output;
#'   `TRUE` keeps it. Each `moon_deterministic` object is single-sex by
#'   construction, so this only matters for downstream multi-sex stitched
#'   objects.
#'
#' @return A long data frame with columns `age`, optionally `sex`,
#'   `state`, and `prevalence`.
#'
#' @seealso [moon_deterministic()], [moon_costs()].
#'
#' @examples
#' \donttest{
#' params <- moon_params_norway(sex = "female")
#' run    <- moon_deterministic(params)
#' head(moon_prevalence(run, ages = 40:45))
#' }
#'
#' @export
moon_prevalence <- function(x,
                             denominator = c("alive", "initial"),
                             ages        = NULL,
                             by_sex      = FALSE) {
  stopifnot(inherits(x, "moon_deterministic"))
  denominator <- match.arg(denominator)

  trace <- x$trace
  if (!is.null(ages)) trace <- trace[trace$age %in% ages, , drop = FALSE]

  cn <- unname(x$params$cohort_n)

  if (denominator == "alive") {
    alive_only <- trace[trace$state != "dead", , drop = FALSE]
    denom <- stats::aggregate(n ~ age + sex, alive_only, FUN = sum)
    names(denom)[names(denom) == "n"] <- "denom"
    out <- merge(alive_only, denom, by = c("age", "sex"))
  } else {
    out <- trace
    out$denom <- cn
  }
  out$prevalence <- out$n / out$denom

  keep <- c("age",
            if (isTRUE(by_sex)) "sex",
            "state", "prevalence")
  out <- out[, keep, drop = FALSE]
  out[order(out$age, out$state), , drop = FALSE]
}


#' Aggregate cohort costs by age, state, sex, or total
#'
#' Aggregates the `$costs` slot of a [moon_deterministic()] object over a
#' single grouping variable. For multi-variable groupings, run twice or
#' build your own `aggregate()` call against
#' `as.data.frame(x, what = "costs")`.
#'
#' @param x A [moon_deterministic()] object.
#' @param by One of `"age"`, `"state"`, `"sex"`, `"total"`. `"total"`
#'   returns a length-1 numeric (the grand total).
#' @param discounted `FALSE` (default) sums `$cost`; `TRUE` sums
#'   `$cost_disc`.
#' @param ages Optional integer vector to filter; `NULL` (default) returns
#'   all ages.
#'
#' @return A data frame with columns `<by>` and `cost`, except for
#'   `by = "total"` which returns a length-1 numeric.
#'
#' @seealso [moon_deterministic()], [moon_prevalence()].
#'
#' @examples
#' \donttest{
#' params <- moon_params_norway(sex = "female")
#' run    <- moon_deterministic(params)
#' moon_costs(run, by = "state")
#' moon_costs(run, by = "total", discounted = TRUE)
#' }
#'
#' @export
moon_costs <- function(x,
                       by         = c("age", "state", "sex", "total"),
                       discounted = FALSE,
                       ages       = NULL) {
  stopifnot(inherits(x, "moon_deterministic"))
  by <- match.arg(by)

  costs <- x$costs
  if (!is.null(ages)) costs <- costs[costs$age %in% ages, , drop = FALSE]

  cost_col <- if (isTRUE(discounted)) "cost_disc" else "cost"
  v <- costs[[cost_col]]

  if (by == "total") return(sum(v))

  agg <- stats::aggregate(v, by = list(costs[[by]]), FUN = sum)
  names(agg) <- c(by, "cost")
  agg[order(agg[[by]]), , drop = FALSE]
}
