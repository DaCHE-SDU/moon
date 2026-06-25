# Log-logistic survivor function S(t)

Log-logistic survivor function S(t)

## Usage

``` r
.S_loglogistic(t, lambda, gamma)
```

## Arguments

- t:

  Numeric vector of times.

- lambda:

  Numeric scalar; rate parameter on the log scale (the survivor uses
  `exp(-lambda)`).

- gamma:

  Numeric scalar; shape parameter.

## Value

Numeric vector the same length as `t`.
