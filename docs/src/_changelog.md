```@meta
CurrentModule = IJulia
```

# Changelog

This documents notable changes in IJulia.jl. The format is based on [Keep a
Changelog](https://keepachangelog.com).

## [v1.27.0]

### Added
- [`installkernel()`](@ref) now supports a `displayname` argument to customize
  the kernel display name ([#1137]).

### Fixed
- The internal heartbeat thread will now shut down cleanly ([#1135],
  [#1144], [#1150]). This should prevent segfaults upon exit.
- Various fixes to the messaging code to be compliant with Jupyter ([#1138],
  [#1150]).
- Improved threadsafety of the IO-handling code so that it should be safe to
  call `flush()` concurrently ([#1149]).
