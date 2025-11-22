```@meta
CurrentModule = IJulia
```

# Changelog

This documents notable changes in IJulia.jl. The format is based on [Keep a
Changelog](https://keepachangelog.com).

## [v1.33.0] - 2025-11-22

### Added
- Added support for flushing the Python stdio streams in the [PythonCall
  extension](manual/usage.md#Python-integration), now the output from
  `pyprint()` etc will show up immediately in the cell output just like with
  Julia ([#1223]). Note that Julia's stdio is flushed first, so if you have
  interleaved print statements in both Julia and Python then the output may not
  appear in order of execution.
- Added [`nbclassic()`](@ref) to run the classic notebook ([#1228]).

### Fixed
- Previously the Python stacktraces from `PyException`'s were not displayed, now
  they are displayed along with the corresponding Julia stacktrace ([#1224]).
- Significantly improved the reliability of interrupt handling ([#1227]).

### Changed
- Added speculative precompilation of common Jupyter request handlers to improve
  TTFX ([#1220]).
- Moved Revise.jl support into a package extension to improve TTFX and
  implemented a special hook to lazily call `Revise.revise()` ([#1220]). This
  helps improve TTFX from invalidations after loading packages in the common
  case where no files need to be revised.
- Some display methods have been selectively despecialized to improve TTFX, for
  complex types like highly dimensional arrays this is often a ~2x speedup
  ([#1220]).
- IJulia will now remove the Jupyter-specific arguments from `ARGS` ([#1226]).

## [v1.32.1] - 2025-11-05

### Fixed
- Disabled the juliaup binary detection, sadly it was too buggy ([#1214]).

## [v1.32.0] - 2025-11-04

### Added
- *Note: this turned out to be buggy and was disabled in v1.32.1.*

  The most important change in this release is that support for juliaup was
  added. IJulia now checks if juliaup is used during the build step when
  installing the default kernel, and if it is used then it will set the kernel
  command to the equivalent of `julia +major.minor` ([#1201]). This has the
  advantage of not needing to rebuild IJulia to update the kernel after every
  patch release of Julia, but it does mean that IJulia will only create kernels
  for each Julia minor release instead of each patch release.

### Fixed
- Fixed the display of `UnionAll` types such as `Pair.body` ([#1203]).
- Fixed a bug in the [PythonCall extension](manual/usage.md#Python-integration)
  that would break opening comms from the frontend side ([#1206]).
- The [PythonCall extension](manual/usage.md#Python-integration) accidentally
  forced some Python test dependencies to be installed outside of the tests, now
  they have been fully moved into the test suite ([#1209]).
- A long-standing issue with `show()` exceptions being silently discarded was
  fixed ([#1202]).

### Changed
- Replaced JSON.jl with a vendored copy of
  [JSONX](https://github.com/JuliaIO/JSON.jl/tree/master/vendor) ([#1200]). This
  lets us remove one more dependency and remove all of the invalidations caused
  by JSON.jl. Load time is also slightly improved, from ~0.08s to ~0.05s on
  Julia 1.12.
- Switched the default matplotlib backend for [`IJulia.init_matplotlib()`](@ref)
  to the ipympl default, which should be more backwards compatible ([#1206]).
- Extended the precompilation workload to cover more calls, and added a
  workaround to minimize TTFX when Revise is used ([#1210]).
- Previously, running special mode commands like `] st` would not work if the
  cell contained comment lines:
  ```julia
  # Check environment
  ] st
  ```

  Now the comment lines are stripped from special mode commands so the above
  will work ([#1207]). Note that this only applies to *whole comment lines*, the
  inline comments in code like `] st # check environment` will still not be
  stripped.

## [v1.31.1] - 2025-10-20

### Added
- Added support for JSON v1 ([#1197]).

### Fixed
- Fixed support for 32bit systems ([#1196]).

### Changed
- Improved precompilation for the [PythonCall.jl
  extension](manual/usage.md#Python-integration), if `ipywidgets` is installed
  in the Python environment then it will be used to execute a simple workload
  ([#1199]).

## [v1.31.0] - 2025-10-13

### Added
- Implemented a [PythonCall.jl extension](manual/usage.md#Python-integration) to
  support interactive ipywidgets and matplotlib widgets in Julia ([#1190]).
- Added support for buffers in the Jupyter messaging protocol ([#1190]).

## [v1.30.6] - 2025-10-06

### Fixed
- It's now possible to register hooks at any time, even if an IJulia kernel is
  not running ([#1188]). This was accidentally broken in v1.30.

### Changed
- Implemented lazy loading for Conda.jl ([#1187]), which shaves off about 60% of
  the load time (~0.21s to ~0.08s on Julia 1.12).

## [v1.30.5] - 2025-10-03

### Fixed
- Fixed a major performance regression in message hashing from the switch to
  SHA.jl in v1.29.1, which particularly affected things like plot/dataframe
  outputs ([#1185]).

## [v1.30.4] - 2025-09-08

### Fixed
- Fixed usage of [`In`](@ref) and [`Out`](@ref) so that they actually contain
  the cell history instead of just being empty ([#1182]). This was accidentally
  broken in v1.30.0.

## [v1.30.3] - 2025-09-02

### Fixed
- Modified the internal `IJuliaStdio` struct to be deepcopy-able, which was
  inadvertently broken in v1.30.0 ([#1180]).

## [v1.30.2] - 2025-08-29

### Changed
- Implemented lazy loading for Pkg.jl ([#1177]), which significantly cuts down
  the load time (~0.75s to ~0.25s on Julia 1.11). Also made various other
  improvements to precompilation and inference to improve TTFX.

## [v1.30.1] - 2025-08-27

### Fixed
- Added the default value `kernel=_default_kernel` to the function
  [`set_max_stdio`](@ref), which fixes a breaking change introduced in v1.30.0
  ([#1178]).

## [v1.30.0] - 2025-08-24

### Added
- Implemented [`reset_stdio_count()`](@ref) to provide a public API for
  resetting the stdio count ([#1145]).
- A precompilation workload was added to improve TTFX ([#1145], [#1174]).

### Changed
- IJulia was completely refactored to minimize global state ([#1145]). This
  allows for better testing (for the first time we can test kernel execution)
  and for executing precompilation workloads. We've tried to avoid any breaking
  changes but it's possible that some packages may be relying on internals that
  have changed. If you have any problems with this release please [open an issue
  on Github](https://github.com/JuliaLang/IJulia.jl/issues/new) so we can help.
- [`history()`](@ref) now prints each entry on a new line ([#1145]).

## [v1.29.2] - 2025-07-29

### Fixed
- Fixed a typo in the tooltip lookup code ([#1171]).

## [v1.29.1] - 2025-07-26

### Changed
- Improved the token-finding functionality to return more accurate tooltips when
  Shift + Tab is pressed ([#847]).
- IJulia switched from using MbedTLS.jl to the SHA.jl stdlib. This should not
  change anything for users except that now only SHA message digests are
  supported instead of e.g. MD5, and Jupyter uses SHA256 by default ([#1170]).

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
