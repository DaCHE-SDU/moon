# Convert survival-model parameters into per-cycle transition probabilities

Computes `1 - S(t + dt) / S(t)` for each `t` in `cycles`, dispatching on
the parametric distribution name.

## Usage

``` r
.tp_from_survival(dist, theta, cycles, dt = 1)
```

## Arguments

- dist:

  One of `"lnorm"`, `"weibull"`, `"gompertz"`, `"loglogistic"`.

- theta:

  Numeric vector of length 2; coefficient parameters whose meaning
  depends on `dist`.

- cycles:

  Numeric vector of times at which to evaluate the per-cycle
  probability.

- dt:

  Cycle length; default 1.

## Value

Numeric vector the same length as `cycles`.
