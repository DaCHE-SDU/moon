#' @keywords internal
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL

# NSE column references inside ggplot2 aes() and stats::aggregate()
# formulas. R CMD check otherwise reports these as undefined globals.
utils::globalVariables(c(
  "age", "n", "sex", "state", "metric", "value",
  "prev", "prop", "inc_per_capita",
  "mean", "lower", "lower95", "upper", "upper95",
  "family"
))
