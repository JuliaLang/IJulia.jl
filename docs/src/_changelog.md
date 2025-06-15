```@meta
CurrentModule = IJulia
```

# Changelog

This documents notable changes in IJulia.jl. The format is based on [Keep a
Changelog](https://keepachangelog.com).

## Unreleased

### Changed
- Improved the token-finding functionality to return more accurate tooltips when
  Shift + Tab is pressed ([#847]).

## [v1.29.0] - 2025-06-13

### Added
- Added an `args` argument to [`notebook()`](@ref) and [`jupyterlab()`](@ref) to
  allow passing custom arguments to the underlying commands ([#1164]).

### Fixed
- Fixed handling of the Jupyter process in [`notebook()`](@ref) and
  [`jupyterlab()`](@ref) when Ctrl + C'ing to shutdown the server, now any
  running kernels will be cleanly shutdown as well ([#1165]).

## [v1.28.1] - 2025-06-02

### Fixed

- Fixed a deadlock in the `shutdown_request` handler that would cause the kernel
  to hang when exiting ([#1163]).

## [v1.28.0] - 2025-06-01

### Added
- [`notebook()`](@ref) and [`jupyterlab()`](@ref) now support a `verbose`
  keyword argument to echo output from Jupyter to the terminal, which can be
  useful when debugging kernels ([#1157]).

### Changed
- IJulia no longer uses a standalone `kernel.jl` file to launch the kernel, it
  instead calls a function inside the IJulia module. This means that kernel
  specs don't use absolute paths anymore and it's not necessary to rebuild
  IJulia after updating the package ([#1158]).
- Colors in stacktraces are now displayed properly in Jupyter ([#1161]).

### Fixed

- The Julia major and minor version are no longer appended to a custom
  `specname` in [`installkernel()`](@ref). The default `specname` that derives
  from `name` and appends the Julia version remains unchanged ([#1154]).
- Fixed adding multiple packages in Pkg mode ([#1160]).
- Fixed an edge-case in inspection requests that would cause autocompletion to
  not work properly ([#1159]).

## [v1.27.0] - 2025-04-01

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
