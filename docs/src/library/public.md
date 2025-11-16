# Public API


## General

```@docs
IJulia.IJulia
IJulia.inited
IJulia.installkernel
```


## Launching the server

```@docs
IJulia.jupyterlab
IJulia.notebook
IJulia.nbclassic
IJulia.qtconsole
```


## History

```@docs
IJulia.In
IJulia.Out
IJulia.ans
IJulia.n
IJulia.clear_history
IJulia.history
```


## Cells

```@docs
IJulia.clear_output
IJulia.load
IJulia.load_string
```


## I/O

```@docs
IJulia.readprompt
IJulia.set_max_stdio
IJulia.reset_stdio_count
```

## Cell execution hooks

```@docs
IJulia.push_preexecute_hook
IJulia.pop_preexecute_hook
IJulia.push_postexecute_hook
IJulia.pop_postexecute_hook
IJulia.push_posterror_hook
IJulia.pop_posterror_hook
```

## Python initializers

See the [Python integration](../manual/usage.md#Python-integration) docs for
more details.

```@docs
IJulia.init_matplotlib
IJulia.init_ipywidgets
IJulia.init_ipython
```
