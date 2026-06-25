# Adult BMI cut-offs (WHO)

WHO adult body-mass index cut-offs that separate the four MOON adult
weight states. Each entry gives the BMI value at which a person leaves
one state and enters the next — i.e. the lower bound of the *next* state
in the sequence NW → OW → OB1 → OB2.

## Usage

``` r
moon_who_cutoffs
```

## Format

A named numeric vector of length 3:

- NW:

  `25` — separates NW from OW (overweight threshold).

- OW:

  `30` — separates OW from OB1 (obese threshold).

- OB1:

  `35` — separates OB1 from OB2 (severe obesity threshold).

## Source

World Health Organization. *Obesity: preventing and managing the global
epidemic.* WHO Technical Report Series 894. Geneva: WHO; 2000.

## Details

Above age 18, MOON classifies BMI directly against this vector. Below
age 18 it uses
[moon_iotf_cutoffs](https://dache-sdu.github.io/moon/reference/moon_iotf_cutoffs.md)
instead.

## See also

[moon_iotf_cutoffs](https://dache-sdu.github.io/moon/reference/moon_iotf_cutoffs.md)
for the age- and sex-specific child equivalents.
