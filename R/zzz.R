# Package-local cache populated at load time.
#
# `utils::packageVersion()` walks DESCRIPTION on every call, which becomes a
# measurable per-iteration cost when moon_deterministic() runs inside the PSA
# loop. Cache it once at load and read from .moon_cache$version thereafter.

.moon_cache <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  .moon_cache$version <- tryCatch(
    utils::packageVersion(pkgname),
    error = function(e) NA
  )
}
