#' Read a life table CSV and return the per-age NW mortality vector
#'
#' Reads `<data_dir>/<file>`, filters to `start_age:(max_age - 1)`, and
#' returns the `sex_col` column as a named numeric (names are ages as
#' character) — matches the engine's `.build_mortality_vec()` lookup
#' contract.
#'
#' @param data_dir Directory containing the CSV.
#' @param sex_col `"F"`, `"M"`, or `"Both"`.
#' @param start_age,max_age Integer; bounds of the age sequence (inclusive
#'   of `start_age`, exclusive of `max_age`).
#' @param file File name within `data_dir`. Public callers reach this via
#'   the `lifetable_file =` argument of [moon_params_norway()].
#' @return Named numeric of length `max_age - start_age`.
#' @keywords internal
.read_lifetable <- function(data_dir, sex_col, start_age, max_age, file) {
  path <- file.path(data_dir, file)
  lt   <- utils::read.csv2(path, stringsAsFactors = FALSE)
  lt   <- lt[lt$Age >= start_age & lt$Age <= (max_age - 1), , drop = FALSE]
  lt   <- lt[order(lt$Age), , drop = FALSE]
  stats::setNames(as.numeric(lt[[sex_col]]), as.character(lt$Age))
}


#' Read a per-capita cost CSV into a tidy `(age, state, cost)` data frame
#'
#' Renames the source file's `State == "N"` to `"NW"` so output uses the
#' engine's state vocabulary. Costs for ages 2–19 (zeros) and 81–100
#' (constant at the age-80 value) come straight from the source file — no
#' engine-side imputation. Drops NOK columns and trailing empty columns by
#' selecting only the columns we need.
#'
#' @param data_dir Directory containing the CSV.
#' @param sex_code `"F"`, `"M"`, or `"Both"`.
#' @param with_se If `TRUE`, also return the `Cost_SE` column as `cost_se`.
#' @return Data frame with columns `age`, `state`, `cost` (and `cost_se`
#'   if `with_se = TRUE`).
#' @keywords internal
.read_costs <- function(data_dir, sex_code, with_se = FALSE) {
  fname <- switch(sex_code,
    F    = "Cost_Female_2_100.csv",
    M    = "Cost_Male_2_100.csv",
    Both = "Cost_Both_2_100.csv",
    stop("Unknown sex_code: ", sex_code)
  )
  raw <- utils::read.csv2(
    file.path(data_dir, fname),
    stringsAsFactors = FALSE,
    fileEncoding     = "UTF-8-BOM"
  )
  out <- data.frame(
    age   = as.integer(raw$Age),
    state = ifelse(raw$State == "N", "NW", raw$State),
    cost  = as.numeric(raw$Cost_Mean),
    stringsAsFactors = FALSE
  )
  if (isTRUE(with_se)) out$cost_se <- as.numeric(raw$Cost_SE)
  out
}


#' Read the transition-parameter CSV
#'
#' Normalises the `"Transtition"` header typo (present in all three
#' sex-specific files) to `"Transition"`.
#'
#' @param data_dir Directory containing the CSV.
#' @param sex_code `"F"`, `"M"`, or `"Both"`.
#' @return Data frame with the columns published in the source file plus
#'   the normalised `Transition` column.
#' @keywords internal
.read_transition_params <- function(data_dir, sex_code) {
  fname <- switch(sex_code,
    F    = "TransitionParamsFemale.csv",
    M    = "TransitionParamsMale.csv",
    Both = "TransitionParamsBoth.csv",
    stop("Unknown sex_code: ", sex_code)
  )
  df <- utils::read.csv2(file.path(data_dir, fname), stringsAsFactors = FALSE)
  if (!"Transition" %in% names(df) && "Transtition" %in% names(df)) {
    df$Transition <- df$Transtition
  }
  if (!"Transition" %in% names(df)) {
    stop("Missing required column: Transition (or Transtition)")
  }
  df
}


#' Build the deterministic engine's per-age `transition_probs` data frame
#'
#' For each band, builds the `band_cycles` vector via
#' `seq(start_val, by, length.out)`, calls `.tp_from_survival()`, then
#' stitches per-band probability vectors per transition (ordered by
#' `age_start`) and asserts the resulting age sequence covers
#' `start_age:(max_age - 1)` contiguously. CSV transition labels (`N_OW`,
#' `OW_N`, …) are renamed to engine column names (`NW_OW`, `OW_NW`, …).
#'
#' @param df_params Raw transition-parameter data frame, e.g. from
#'   `.read_transition_params()`.
#' @param start_age,max_age Bounds of the age sequence (inclusive of
#'   `start_age`, exclusive of `max_age`).
#' @param dt Cycle length; default 1.
#' @return Data frame with columns `age`, `NW_OW`, `OW_NW`, `OW_OB1`,
#'   `OB1_OW`, `OB1_OB2`, `OB2_OB1`.
#' @keywords internal
.build_transition_probs <- function(df_params, start_age, max_age, dt = 1) {
  band_keys <- paste0(df_params$age_start, "_", df_params$age_end, "_",
                      df_params$Transition)
  l_tp <- vector("list", length(band_keys))
  names(l_tp) <- band_keys

  for (i in seq_len(nrow(df_params))) {
    row          <- df_params[i, ]
    age_start_i  <- as.numeric(row$age_start)
    age_end_i    <- as.numeric(row$age_end)
    surv_start_i <- as.numeric(row$survival_function_starting_age)

    total_cycles <- (age_end_i - age_start_i) / dt
    start_val    <- age_start_i - surv_start_i
    band_cycles  <- seq(from = start_val, by = dt, length.out = total_cycles)

    l_tp[[band_keys[i]]] <- .tp_from_survival(
      dist   = row$dist,
      theta  = c(as.numeric(row$mean1), as.numeric(row$mean2)),
      cycles = band_cycles,
      dt     = dt
    )
  }

  stitch <- function(trans) {
    idx <- which(df_params$Transition == trans)
    idx <- idx[order(as.numeric(df_params$age_start[idx]))]
    do.call(c, lapply(band_keys[idx], function(nm) l_tp[[nm]]))
  }

  bands           <- unique(df_params[, c("age_start", "age_end")])
  bands$age_start <- as.numeric(bands$age_start)
  bands$age_end   <- as.numeric(bands$age_end)
  bands           <- bands[order(bands$age_start), , drop = FALSE]
  age_seq <- do.call(c, lapply(seq_len(nrow(bands)), function(i) {
    len <- (bands$age_end[i] - bands$age_start[i]) / dt
    seq(from = bands$age_start[i], by = dt, length.out = len)
  }))

  if (!isTRUE(all.equal(as.integer(age_seq), start_age:(max_age - 1)))) {
    stop("Transition parameter age bands do not cover ", start_age,
         ":", max_age - 1, " contiguously.")
  }

  data.frame(
    age     = as.integer(age_seq),
    NW_OW   = stitch("N_OW"),
    OW_NW   = stitch("OW_N"),
    OW_OB1  = stitch("OW_OB1"),
    OB1_OW  = stitch("OB1_OW"),
    OB1_OB2 = stitch("OB1_OB2"),
    OB2_OB1 = stitch("OB2_OB1"),
    stringsAsFactors = FALSE
  )
}


#' Build the deterministic mortality-hazard-ratio data frame
#'
#' Hard-coded three-row data frame from the Global BMI Mortality
#' Collaboration (Bjørnelv et al. 2021, Supplementary Appendix 3). The
#' same HRs are used for all sexes in the original model, so the function
#' takes no arguments.
#'
#' @return Data frame with columns `age_lower` (`c(35, 50, 70)`), `OW`,
#'   `OB1`, `OB2`.
#' @keywords internal
.build_mortality_hr <- function() {
  data.frame(
    age_lower = c(35, 50, 70),
    OW        = c(1.17, 1.11, 0.98),
    OB1       = c(1.90, 1.60, 1.12),
    OB2       = c(3.48, 2.59, 1.63)
  )
}


#' Hard-coded 95% CI bounds for each (age band, state) mortality HR
#'
#' Used only by the `uncertainty = TRUE` branch of `moon_params_norway()`
#' to construct `moon_param_lognormal` specs. Source: Global BMI Mortality
#' Collaboration (Bjørnelv et al. 2021, Supplementary Appendix 3).
#'
#' @return List with elements `OW`, `OB1`, `OB2`, each a data frame with
#'   columns `age_lower`, `point`, `lower`, `upper`.
#' @keywords internal
.mortality_hr_bounds <- function() {
  list(
    OW  = data.frame(age_lower = c(35, 50, 70),
                     point     = c(1.17, 1.11, 0.98),
                     lower     = c(1.15, 1.07, 0.93),
                     upper     = c(1.20, 1.15, 1.02)),
    OB1 = data.frame(age_lower = c(35, 50, 70),
                     point     = c(1.90, 1.60, 1.12),
                     lower     = c(1.72, 1.51, 1.03),
                     upper     = c(2.09, 1.70, 1.21)),
    OB2 = data.frame(age_lower = c(35, 50, 70),
                     point     = c(3.48, 2.59, 1.63),
                     lower     = c(2.93, 2.36, 1.27),
                     upper     = c(4.12, 2.83, 2.10))
  )
}


#' Build the spec'd transition-parameter list for the uncertainty path
#'
#' Mirror of `.build_transition_probs()` for the `uncertainty = TRUE`
#' branch of `moon_params_norway()`. Produces `moon_param_mvnorm` specs
#' instead of plain probability vectors. CSV transition labels (`N_OW`,
#' `OW_N`, …) are kept verbatim here; the rename to engine column names
#' happens at stitch time in `moon_sample_params()`.
#'
#' @param df_params Raw transition-parameter data frame.
#' @param start_age,max_age Bounds of the age sequence.
#' @param dt Cycle length; default 1.
#' @return List with two elements:
#'   * `specs` — list keyed by `"<transition>_<age_start>_<age_end>"` of
#'     [moon_param_mvnorm()] objects.
#'   * `bands` — data frame with columns `key`, `transition`, `age_start`,
#'     `age_end`, `surv_start`, sorted by `(transition, age_start)`.
#' @keywords internal
.build_transition_specs <- function(df_params, start_age, max_age, dt = 1) {
  if (!requireNamespace("stats", quietly = TRUE)) stop("stats required")

  band_keys <- paste0(df_params$Transition, "_",
                      df_params$age_start, "_", df_params$age_end)
  specs <- vector("list", length(band_keys))
  names(specs) <- band_keys

  for (i in seq_len(nrow(df_params))) {
    row          <- df_params[i, ]
    age_start_i  <- as.numeric(row$age_start)
    age_end_i    <- as.numeric(row$age_end)
    surv_start_i <- as.numeric(row$survival_function_starting_age)

    total_cycles <- (age_end_i - age_start_i) / dt
    start_val    <- age_start_i - surv_start_i
    band_cycles  <- seq(from = start_val, by = dt, length.out = total_cycles)

    cov_mat <- matrix(c(
      as.numeric(row$cov_r1c1), as.numeric(row$cov_r1c2),
      as.numeric(row$cov_r2c1), as.numeric(row$cov_r2c2)
    ), nrow = 2, byrow = TRUE)

    specs[[band_keys[i]]] <- moon_param_mvnorm(
      mean_vec = c(as.numeric(row$mean1), as.numeric(row$mean2)),
      cov_mat  = cov_mat,
      dist     = row$dist,
      cycles   = band_cycles
    )
  }

  bands <- data.frame(
    key        = band_keys,
    transition = df_params$Transition,
    age_start  = as.numeric(df_params$age_start),
    age_end    = as.numeric(df_params$age_end),
    surv_start = as.numeric(df_params$survival_function_starting_age),
    stringsAsFactors = FALSE
  )
  bands <- bands[order(bands$transition, bands$age_start), , drop = FALSE]
  rownames(bands) <- NULL

  list(specs = specs, bands = bands)
}
