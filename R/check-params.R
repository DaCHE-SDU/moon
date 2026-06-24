#' Validate a MOON `params` list
#'
#' Three-phase structural / range / cross-object validation of a `params`
#' list. Returns the input invisibly so the call can be chained:
#' `moon_deterministic(moon_check_params(params))`.
#'
#' Phase 1 (cheap structural checks — types, names, scalar ranges)
#' short-circuits the rest: range and consistency checks assume the schema
#' is intact, so reporting them on a structurally broken `params` would add
#' noise. Phases 2 (range checks: values inside domain bounds) and 3
#' (cross-object consistency: ages line up across fields) are run together,
#' and any messages are reported in one batch.
#'
#' @param params A `params` list to validate.
#' @param strict If `TRUE` (the default; what [moon_deterministic()] uses
#'   internally) any problem raises an error listing every issue found in
#'   the active phase. If `FALSE` the same message is downgraded to a
#'   warning and `params` is returned unchanged, so the caller can decide
#'   whether to proceed.
#'
#' @return `invisible(params)`.
#'
#' @seealso [moon_params_norway()] for the canonical builder,
#'   [moon_deterministic()] which calls `moon_check_params()` internally.
#'
#' @examples
#' \donttest{
#' params <- moon_params_norway(sex = "female")
#' moon_check_params(params)
#' }
#'
#' @export
moon_check_params <- function(params, strict = TRUE) {
  reporter <- if (isTRUE(strict)) stop else warning

  msgs <- .check_structural(params)
  if (length(msgs) > 0L) {
    reporter(.format_msgs(msgs), call. = FALSE)
    return(invisible(params))
  }

  msgs <- c(.check_ranges(params), .check_consistency(params))
  if (length(msgs) > 0L) {
    reporter(.format_msgs(msgs), call. = FALSE)
  }

  invisible(params)
}


#' Format the moon_check_params message list into a single string
#'
#' @param msgs Character vector of problem messages.
#' @return Length-1 character.
#' @keywords internal
.format_msgs <- function(msgs) {
  paste0("moon_check_params() found ", length(msgs), " problem(s):\n  - ",
         paste(msgs, collapse = "\n  - "))
}


#' Phase 1 — structural checks
#'
#' Type / name / scalar-range checks that can be performed without
#' examining the values inside the slots. Failure short-circuits range and
#' consistency checks (which assume the schema is intact).
#'
#' @param params A `params` list.
#' @return Character vector of problem messages (length 0 on success).
#' @keywords internal
.check_structural <- function(params) {
  if (!is.list(params)) return("`params` must be a list.")

  required <- c("start_age", "max_age", "discount_rate", "cost_currency",
                "cohort_n", "init_prev", "qx", "mortality_hr",
                "transition_probs", "cost_df")
  missing_fields <- setdiff(required, names(params))
  if (length(missing_fields) > 0L) {
    return(sprintf("missing required field(s): %s",
                   paste(missing_fields, collapse = ", ")))
  }

  msgs <- character(0)

  # Scalar numerics: type + finiteness + range
  for (nm in c("start_age", "max_age", "discount_rate")) {
    v <- params[[nm]]
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v)) {
      msgs <- c(msgs, sprintf("`%s` must be a finite length-1 numeric.", nm))
    }
  }
  if (.is_scalar_finite(params$start_age) && params$start_age < 0) {
    msgs <- c(msgs, "`start_age` must be >= 0.")
  }
  if (.is_scalar_finite(params$start_age) && .is_scalar_finite(params$max_age) &&
      params$max_age <= params$start_age) {
    msgs <- c(msgs, "`max_age` must be > `start_age`.")
  }
  if (.is_scalar_finite(params$discount_rate) &&
      (params$discount_rate < 0 || params$discount_rate >= 1)) {
    msgs <- c(msgs, "`discount_rate` must be in [0, 1).")
  }

  # cost_currency
  cc <- params$cost_currency
  if (!is.character(cc) || length(cc) != 1L || is.na(cc) ||
      !cc %in% c("EUR", "NOK", "USD")) {
    msgs <- c(msgs, "`cost_currency` must be one of 'EUR', 'NOK', 'USD'.")
  }

  # cohort_n: length-1 named integer with allowed name
  cn <- params$cohort_n
  cn_ok <- is.integer(cn) && length(cn) == 1L &&
    !is.null(names(cn)) && names(cn) %in% c("female", "male", "both")
  if (!cn_ok) {
    msgs <- c(msgs, "`cohort_n` must be a length-1 named integer with name in c('female', 'male', 'both').")
  }

  # init_prev: length-4 named numeric, names == c('NW','OW','OB1','OB2'), sum 1
  ip <- params$init_prev
  if (!is.numeric(ip) || length(ip) != 4L) {
    msgs <- c(msgs, "`init_prev` must be a length-4 named numeric.")
  } else if (!setequal(names(ip), c("NW", "OW", "OB1", "OB2"))) {
    msgs <- c(msgs,
              sprintf("`init_prev` names must be c('NW', 'OW', 'OB1', 'OB2') (got: %s).",
                      paste(names(ip), collapse = ", ")))
  } else if (any(!is.finite(ip)) || abs(sum(ip) - 1) > 1e-8) {
    msgs <- c(msgs, sprintf("`init_prev` must sum to 1 within 1e-8 (got %s).",
                            format(sum(ip), digits = 17)))
  }

  # qx: named numeric vector
  qx <- params$qx
  if (!is.numeric(qx) || is.null(names(qx))) {
    msgs <- c(msgs, "`qx` must be a named numeric (names = age as character).")
  }

  # mortality_hr: data frame with required columns
  hr <- params$mortality_hr
  if (!is.data.frame(hr)) {
    msgs <- c(msgs, "`mortality_hr` must be a data frame.")
  } else {
    hr_missing <- setdiff(c("age_lower", "OW", "OB1", "OB2"), names(hr))
    if (length(hr_missing) > 0L) {
      msgs <- c(msgs, sprintf("`mortality_hr` is missing column(s): %s.",
                              paste(hr_missing, collapse = ", ")))
    }
  }

  # transition_probs: data frame with documented columns
  tp <- params$transition_probs
  tp_cols <- c("age", "NW_OW", "OW_NW", "OW_OB1", "OB1_OW", "OB1_OB2", "OB2_OB1")
  if (!is.data.frame(tp)) {
    msgs <- c(msgs, "`transition_probs` must be a data frame.")
  } else {
    tp_missing <- setdiff(tp_cols, names(tp))
    if (length(tp_missing) > 0L) {
      msgs <- c(msgs, sprintf("`transition_probs` is missing column(s): %s.",
                              paste(tp_missing, collapse = ", ")))
    }
  }

  # cost_df: data frame with age/state/cost
  cd <- params$cost_df
  if (!is.data.frame(cd)) {
    msgs <- c(msgs, "`cost_df` must be a data frame.")
  } else {
    cd_missing <- setdiff(c("age", "state", "cost"), names(cd))
    if (length(cd_missing) > 0L) {
      msgs <- c(msgs, sprintf("`cost_df` is missing column(s): %s.",
                              paste(cd_missing, collapse = ", ")))
    }
  }

  msgs
}


#' Test whether `x` is a finite length-1 numeric
#'
#' @param x Object to test.
#' @return `TRUE` / `FALSE`.
#' @keywords internal
.is_scalar_finite <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x)
}


#' Phase 2 — range checks
#'
#' Each numeric slot's values lie inside its documented domain. Assumes
#' the structural schema is intact.
#'
#' @param params A `params` list.
#' @return Character vector of problem messages (length 0 on success).
#' @keywords internal
.check_ranges <- function(params) {
  msgs <- character(0)

  tp <- params$transition_probs
  for (col in c("NW_OW", "OW_NW", "OW_OB1", "OB1_OW", "OB1_OB2", "OB2_OB1")) {
    v <- tp[[col]]
    if (any(!is.finite(v)) || any(v < 0) || any(v > 1)) {
      msgs <- c(msgs, sprintf("`transition_probs$%s` contains values outside [0, 1] or non-finite.",
                              col))
    }
  }

  # OW row: regression + progression cannot exceed 1 (otherwise the engine
  # would produce a negative OW->OW stay-probability before mortality is even
  # applied — see §5.2 of IMPLEMENTATION_PLAN.md).
  ow_sum <- tp$OW_NW + tp$OW_OB1
  if (any(ow_sum > 1 + 1e-12)) {
    bad <- which(ow_sum > 1 + 1e-12)
    msgs <- c(msgs, sprintf("`transition_probs`: OW_NW + OW_OB1 > 1 at age(s) %s.",
                            paste(tp$age[bad], collapse = ", ")))
  }
  ob1_sum <- tp$OB1_OW + tp$OB1_OB2
  if (any(ob1_sum > 1 + 1e-12)) {
    bad <- which(ob1_sum > 1 + 1e-12)
    msgs <- c(msgs, sprintf("`transition_probs`: OB1_OW + OB1_OB2 > 1 at age(s) %s.",
                            paste(tp$age[bad], collapse = ", ")))
  }

  qx <- params$qx
  if (any(!is.finite(qx)) || any(qx < 0) || any(qx > 1)) {
    msgs <- c(msgs, "`qx` contains values outside [0, 1] or non-finite.")
  }

  hr <- params$mortality_hr
  for (col in c("OW", "OB1", "OB2")) {
    v <- hr[[col]]
    if (any(!is.finite(v)) || any(v <= 0)) {
      msgs <- c(msgs, sprintf("`mortality_hr$%s` must be positive and finite.", col))
    }
  }

  # cost_df costs must be finite and non-negative
  cd <- params$cost_df
  if (any(!is.finite(cd$cost)) || any(cd$cost < 0)) {
    msgs <- c(msgs, "`cost_df$cost` contains negative or non-finite values.")
  }

  msgs
}


#' Phase 3 — cross-object consistency
#'
#' Ages line up across `transition_probs`, `qx`, `cost_df`, and the
#' `mortality_hr` bands. Assumes structure and ranges are intact.
#'
#' @param params A `params` list.
#' @return Character vector of problem messages (length 0 on success).
#' @keywords internal
.check_consistency <- function(params) {
  msgs <- character(0)

  start_age     <- as.integer(params$start_age)
  max_age       <- as.integer(params$max_age)
  expected_ages <- start_age:(max_age - 1L)

  tp_ages <- as.integer(params$transition_probs$age)
  if (length(tp_ages) != length(expected_ages) ||
      !all(tp_ages == expected_ages)) {
    msgs <- c(msgs, sprintf("`transition_probs$age` must cover exactly %d:%d.",
                            start_age, max_age - 1L))
  }

  qx_ages <- suppressWarnings(as.integer(names(params$qx)))
  if (any(is.na(qx_ages))) {
    msgs <- c(msgs, "`qx` names must be coercible to integer (ages as character).")
  } else {
    missing_ages <- setdiff(expected_ages, qx_ages)
    if (length(missing_ages) > 0L) {
      msgs <- c(msgs, sprintf("`qx` is missing age(s): %s.",
                              .summarise_int_seq(missing_ages)))
    }
  }

  cd <- params$cost_df
  states_found <- unique(cd$state)
  if (!setequal(states_found, c("NW", "OW", "OB1", "OB2"))) {
    msgs <- c(msgs,
              sprintf("`cost_df$state` must be exactly NW, OW, OB1, OB2 (found: %s).",
                      paste(sort(states_found), collapse = ", ")))
  } else {
    for (s in c("NW", "OW", "OB1", "OB2")) {
      rows <- cd[cd$state == s, , drop = FALSE]
      in_range <- rows$age >= 2L & rows$age <= 100L
      missing_cost_ages <- setdiff(2:100, rows$age[in_range])
      if (length(missing_cost_ages) > 0L) {
        msgs <- c(msgs, sprintf("`cost_df` for state '%s' is missing age(s): %s.",
                                s, .summarise_int_seq(missing_cost_ages)))
      }
      out_rows <- rows[!in_range, , drop = FALSE]
      if (nrow(out_rows) > 0L && any(out_rows$cost != 0)) {
        msgs <- c(msgs, sprintf("`cost_df` for state '%s' has non-zero cost(s) outside ages 2..100.",
                                s))
      }
    }
  }

  hr_band <- params$mortality_hr$age_lower
  if (length(hr_band) != 3L ||
      !isTRUE(all.equal(sort(as.numeric(hr_band)), c(35, 50, 70)))) {
    msgs <- c(msgs, sprintf("`mortality_hr$age_lower` must be exactly c(35, 50, 70) (got: %s).",
                            paste(hr_band, collapse = ", ")))
  }

  msgs
}


#' Compact integer-sequence summary for error messages
#'
#' Avoids dumping 100 numbers into a "missing ages" error. Returns the
#' input as `"1, 2, 3"` for short sequences, or `"start-end (n values)"`
#' for longer ones.
#'
#' @param x Integer vector.
#' @return Length-1 character.
#' @keywords internal
.summarise_int_seq <- function(x) {
  x <- sort(unique(as.integer(x)))
  if (length(x) == 0L) return("")
  if (length(x) <= 6L) return(paste(x, collapse = ", "))
  paste0(x[1], "-", x[length(x)], " (", length(x), " values)")
}
