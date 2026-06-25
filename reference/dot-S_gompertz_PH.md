# Gompertz (proportional-hazards parameterisation) survivor function S(t)

Gompertz (proportional-hazards parameterisation) survivor function S(t)

## Usage

``` r
.S_gompertz_PH(t, ln_lambda, gamma)
```

## Arguments

- t:

  Numeric vector of times.

- ln_lambda:

  Numeric scalar; log of the rate parameter.

- gamma:

  Numeric scalar; shape parameter.

## Value

Numeric vector the same length as `t`.
