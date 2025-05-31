```@meta
CurrentModule = IJulia
```

# Changelog

This documents notable changes in IJulia.jl. The format is based on [Keep a
Changelog](https://keepachangelog.com).

## Unreleased

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
