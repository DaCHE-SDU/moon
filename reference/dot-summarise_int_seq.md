# Compact integer-sequence summary for error messages

Avoids dumping 100 numbers into a "missing ages" error. Returns the
input as `"1, 2, 3"` for short sequences, or `"start-end (n values)"`
for longer ones.

## Usage

``` r
.summarise_int_seq(x)
```

## Arguments

- x:

  Integer vector.

## Value

Length-1 character.
