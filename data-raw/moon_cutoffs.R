## moon_cutoffs.R — prepare `moon_who_cutoffs` and `moon_iotf_cutoffs`
##
## Run interactively, or:  Rscript data-raw/moon_cutoffs.R
##
## Sources
## --------
## moon_who_cutoffs:
##   World Health Organization. Obesity: preventing and managing the
##   global epidemic. WHO Technical Report Series 894. Geneva: WHO; 2000.
##   Adult BMI cut-offs at 25 (overweight), 30 (obese class I) and 35
##   (obese class II) kg/m^2.
##
## moon_iotf_cutoffs (Cole 2012 LMS-based extended cut-offs, Web Table W2):
##   Cole TJ, Lobstein T. Extended international (IOTF) body mass index
##   cut-offs for thinness, overweight and obesity. Pediatric Obesity.
##   2012;7(4):284-294. doi:10.1111/j.2047-6310.2012.00064.x.
##   We use only the BMI 25 / 30 / 35 columns (cutoff_NW / cutoff_OW /
##   cutoff_OB1) of Web Table W2; the BMI 16 / 17 / 18.5 thinness columns
##   are not used by the engine and are omitted.

# WHO adult BMI cut-offs --------------------------------------------------

moon_who_cutoffs <- c(NW = 25, OW = 30, OB1 = 35)


# Cole 2012 IOTF cut-offs (Web Table W2) ---------------------------------

# Verbatim transcription of the BMI 25 / 30 / 35 columns of Web Table W2.
# Boys (= male) and girls (= female), ages 2.0 to 18.0 in 0.5-year steps.
# At age 18.0 the cut-offs equal the adult anchor values by definition.

iotf_csv <- "
age,sex,cutoff_NW,cutoff_OW,cutoff_OB1
2.0,male,18.36,19.99,21.20
2.0,female,18.09,19.81,21.13
2.5,male,18.09,19.73,20.95
2.5,female,17.84,19.57,20.90
3.0,male,17.85,19.50,20.75
3.0,female,17.64,19.38,20.74
3.5,male,17.66,19.33,20.61
3.5,female,17.48,19.25,20.65
4.0,male,17.52,19.23,20.56
4.0,female,17.36,19.16,20.62
4.5,male,17.43,19.20,20.60
4.5,female,17.27,19.14,20.67
5.0,male,17.39,19.27,20.79
5.0,female,17.23,19.20,20.85
5.5,male,17.42,19.46,21.15
5.5,female,17.25,19.36,21.16
6.0,male,17.52,19.76,21.69
6.0,female,17.33,19.62,21.61
6.5,male,17.67,20.15,22.35
6.5,female,17.48,19.96,22.19
7.0,male,17.88,20.59,23.08
7.0,female,17.69,20.39,22.88
7.5,male,18.12,21.06,23.83
7.5,female,17.96,20.89,23.65
8.0,male,18.41,21.56,24.61
8.0,female,18.28,21.44,24.50
8.5,male,18.73,22.11,25.45
8.5,female,18.63,22.04,25.42
9.0,male,19.07,22.71,26.40
9.0,female,18.99,22.66,26.39
9.5,male,19.43,23.34,27.39
9.5,female,19.38,23.31,27.38
10.0,male,19.80,23.96,28.35
10.0,female,19.78,23.97,28.36
10.5,male,20.15,24.54,29.22
10.5,female,20.21,24.62,29.28
11.0,male,20.51,25.07,29.97
11.0,female,20.66,25.25,30.14
11.5,male,20.85,25.56,30.63
11.5,female,21.12,25.87,30.93
12.0,male,21.20,26.02,31.21
12.0,female,21.59,26.47,31.66
12.5,male,21.54,26.45,31.73
12.5,female,22.05,27.04,32.33
13.0,male,21.89,26.87,32.19
13.0,female,22.49,27.57,32.91
13.5,male,22.25,27.26,32.61
13.5,female,22.90,28.03,33.39
14.0,male,22.60,27.64,32.98
14.0,female,23.27,28.42,33.78
14.5,male,22.95,28.00,33.29
14.5,female,23.60,28.74,34.07
15.0,male,23.28,28.32,33.56
15.0,female,23.89,29.01,34.28
15.5,male,23.59,28.61,33.78
15.5,female,24.13,29.22,34.43
16.0,male,23.89,28.88,33.98
16.0,female,24.34,29.40,34.55
16.5,male,24.18,29.15,34.19
16.5,female,24.53,29.55,34.64
17.0,male,24.46,29.43,34.43
17.0,female,24.70,29.70,34.75
17.5,male,24.73,29.71,34.71
17.5,female,24.85,29.85,34.87
18.0,male,25.00,30.00,35.00
18.0,female,25.00,30.00,35.00
"

moon_iotf_cutoffs <- read.csv(text = iotf_csv, stringsAsFactors = FALSE)
moon_iotf_cutoffs <- moon_iotf_cutoffs[order(moon_iotf_cutoffs$age,
                                              moon_iotf_cutoffs$sex), ]
rownames(moon_iotf_cutoffs) <- NULL


# Sanity checks -----------------------------------------------------------

stopifnot(
  identical(names(moon_who_cutoffs), c("NW", "OW", "OB1")),
  unname(moon_who_cutoffs) == c(25, 30, 35),
  nrow(moon_iotf_cutoffs) == 33L * 2L,
  identical(sort(unique(moon_iotf_cutoffs$sex)), c("female", "male")),
  identical(sort(unique(moon_iotf_cutoffs$age)),
            seq(2, 18, by = 0.5)),
  # cut-offs are strictly ordered NW < OW < OB1 at every age
  with(moon_iotf_cutoffs, all(cutoff_NW < cutoff_OW & cutoff_OW < cutoff_OB1)),
  # at age 18 they equal the adult anchors
  with(moon_iotf_cutoffs[moon_iotf_cutoffs$age == 18, ],
       all(cutoff_NW == 25 & cutoff_OW == 30 & cutoff_OB1 == 35))
)


# Write to data/ ---------------------------------------------------------

usethis::use_data(moon_who_cutoffs, moon_iotf_cutoffs, overwrite = TRUE)
