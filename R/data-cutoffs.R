#' Adult BMI cut-offs (WHO)
#'
#' WHO adult body-mass index cut-offs that separate the four MOON adult
#' weight states. Each entry gives the BMI value at which a person leaves
#' one state and enters the next — i.e. the lower bound of the *next*
#' state in the sequence NW → OW → OB1 → OB2.
#'
#' Above age 18, MOON classifies BMI directly against this vector. Below
#' age 18 it uses [moon_iotf_cutoffs] instead.
#'
#' @format A named numeric vector of length 3:
#' \describe{
#'   \item{NW}{`25` — separates NW from OW (overweight threshold).}
#'   \item{OW}{`30` — separates OW from OB1 (obese threshold).}
#'   \item{OB1}{`35` — separates OB1 from OB2 (severe obesity threshold).}
#' }
#'
#' @source World Health Organization. \emph{Obesity: preventing and
#'   managing the global epidemic.} WHO Technical Report Series 894.
#'   Geneva: WHO; 2000.
#'
#' @seealso [moon_iotf_cutoffs] for the age- and sex-specific child
#'   equivalents.
"moon_who_cutoffs"


#' Cole/IOTF child BMI cut-offs (LMS-based, ages 2–18, both sexes)
#'
#' Age- and sex-specific BMI cut-offs for children aged 2–18, derived
#' from the pooled LMS curves in Cole & Lobstein (2012). Each row gives
#' the three BMI values that, at the corresponding age and sex, are
#' equivalent to adult BMI 25, 30, and 35 — the boundaries between MOON's
#' NW / OW / OB1 / OB2 states.
#'
#' At age 18 the cut-offs equal the adult anchor values (25 / 30 / 35) by
#' definition. The 2012 LMS-based values differ from Cole et al. (2000)
#' country-averaged values by less than 0.2% on average.
#'
#' Only the BMI 25 / 30 / 35 columns of Cole 2012's Web Table W2 are
#' reproduced here; the BMI 16 / 17 / 18.5 thinness columns are not used
#' by the engine and are omitted.
#'
#' @format A data frame with 66 rows and 5 columns:
#' \describe{
#'   \item{age}{Numeric. Age in years, from `2.0` to `18.0` in 0.5-year
#'     steps.}
#'   \item{sex}{Character. `"female"` or `"male"`.}
#'   \item{cutoff_NW}{Numeric BMI. Separates NW from OW (BMI 25 line).}
#'   \item{cutoff_OW}{Numeric BMI. Separates OW from OB1 (BMI 30 line).}
#'   \item{cutoff_OB1}{Numeric BMI. Separates OB1 from OB2 (BMI 35 line,
#'     the morbid-obesity threshold added in the 2012 update).}
#' }
#'
#' @source Cole TJ, Lobstein T. Extended international (IOTF) body mass
#'   index cut-offs for thinness, overweight and obesity. \emph{Pediatric
#'   Obesity}. 2012;7(4):284–294.
#'   \doi{10.1111/j.2047-6310.2012.00064.x}.
#'   Web Table W2, BMI 25 / 30 / 35 columns.
#'
#' @seealso [moon_who_cutoffs] for the adult anchor values.
"moon_iotf_cutoffs"
