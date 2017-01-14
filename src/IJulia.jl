__precompile__()

"""
**IJulia** is a [Julia-language](http://julialang.org/) backend
combined with the [Jupyter](http://jupyter.org/) interactive
environment (also used by [IPython](http://ipython.org/)).  This
combination allows you to interact with the Julia language using
Jupyter/IPython's powerful [graphical
notebook](http://ipython.org/notebook.html), which combines code,
formatted text, math, and multimedia in a single document.

The `IJulia` module is used in three ways:

* Typing `using IJulia; notebook()` will launch the Jupyter notebook
  interface in your web browser.  This is an alternative to launching
  `jupyter notebook` directly from your operating-system command line.
* In a running notebook, the `IJulia` module is loaded and `IJulia.somefunctions`
  can be used to interact with the running IJulia kernel:

  - `IJulia.load(filename)` and `IJulia.load_string(s)` load the contents
    of a file or a string, respectively, into a notebook cell.
  - `IJulia.clear_output()` to clear the output from the notebook cell,
    useful for simple animations.
  - `IJulia.clear_history()` to clear the history variables `In` and `Out`.
  - `push_X_hook(f)` and `pop_X_hook(f)`, where `X` is either
    `preexecute`, `postexecute`, or `posterror`.  This allows you to
    insert a "hook" function into a list of functions to execute
    when notebook cells are evaluated.
  - `IJulia.set_verbose()` enables verbose output about what IJulia
    is doing internally; this is mainly used for debugging.

* It is used internally by the IJulia kernel when talking
  to the Jupyter server.
"""
module IJulia
export notebook

using ZMQ, JSON, Compat
import Compat.String

#######################################################################
# Debugging IJulia

# in the Jupyter front-end, enable verbose output via IJulia.set_verbose()
verbose = false
"""
    set_verbose(v=true)

This function enables (or disables, for `set_verbose(false)`) verbose
output from the IJulia kernel, when called within a running notebook.
This consists of log messages printed to the terminal window where
`jupyter` was launched, displaying information about every message sent
or received by the kernel.   Used for debugging IJulia.
"""
function set_verbose(v::Bool=true)
    global verbose = v
end

"""
`inited` is a global variable that is set to `true` if the IJulia
kernel is running, i.e. in a running IJulia notebook.  To test
whether you are in an IJulia notebook, therefore, you can check
`isdefined(Main, :IJulia) && IJulia.inited`.
"""
inited = false

# set this to false for debugging, to disable stderr redirection
"""
The IJulia kernel captures all [stdout and stderr](https://en.wikipedia.org/wiki/Standard_streams)
output and redirects it to the notebook.   When debugging IJulia problems,
however, it can be more convenient to *not* capture stdout and stderr output
(since the notebook may not be functioning). This can be done by editing
`IJulia.jl` to set `capture_stderr` and/or `capture_stdout` to `false`.
"""
const capture_stdout = true
const capture_stderr = true

#######################################################################

"""
    notebook(; dir=homedir(), detached=false)

The `notebook()` function launches the Jupyter notebook, and is
equivalent to running `jupyter notebook` at the operating-system
command-line.    The advantage of launching the notebook from Julia
is that, depending on how Jupyter was installed, the user may not
know where to find the `jupyter` executable.

By default, the notebook server is launched in the user's home directory,
but this location can be changed by passing the desired path in the
`dir` keyword argument.  e.g. `notebook(dir=pwd())` to use the current
directory.

By default, `notebook()` does not return; you must hit ctrl-c
or quit Julia to interrupt it, which halts Jupyter.  So, you
must leave the Julia terminal open for as long as you want to
run Jupyter.  Alternatively, if you run `notebook(detached=true)`,
the `jupyter notebook` will launch in the background, and will
continue running even after you quit Julia.  (The only way to
stop Jupyter will then be to kill it in your operating system's
process manager.)
"""
function notebook(; dir=homedir(), detached=false)
    inited && error("IJulia is already running")
    p = spawn(Cmd(`$notebook_cmd`, detach=true, dir=dir))
    if !detached
        try
            wait(p)
        catch e
            if isa(e, InterruptException)
                kill(p, 2) # SIGINT
            else
                kill(p) # SIGTERM
                rethrow()
            end
        end
    end
    return p
end

#######################################################################

"""
    load_string(s, replace=false)

Load the string `s` into a new input code cell in the running IJulia notebook,
somewhat analogous to the `%load` magics in IPython. If the optional argument
`replace` is `true`, then `s` replaces the *current* cell rather than creating
a new cell.
"""
function load_string(s::AbstractString, replace::Bool=false)
    push!(execute_payloads, Dict(
        "source"=>"set_next_input",
        "text"=>s,
        "replace"=>replace
    ))
    return nothing
end

"""
    load(filename, replace=false)

Load the file given by `filename` into a new input code cell in the running
IJulia notebook, analogous to the `%load` magics in IPython.
If the optional argument `replace` is `true`, then the file contents
replace the *current* cell rather than creating a new cell.
"""
load(filename::AbstractString, replace::Bool=false) =
    load_string(readstring(filename), replace)

#######################################################################
# History: global In/Out and other exported history variables
"""
`In` is a global dictionary of input strings, where `In[n]`
returns the string for input cell `n` of the notebook (as it was
when it was *last evaluated*).
"""
const In = Dict{Int,String}()
"""
`Out` is a global dictionary of output values, where `Out[n]`
returns the output from the last evaluation of cell `n` in the
notebook.
"""
const Out = Dict{Int,Any}()
"""
`ans` is a global variable giving the value returned by the last
notebook cell evaluated.
"""
ans = nothing

# execution counter
"""
`IJulia.n` is the (integer) index of the last-evaluated notebook cell.
"""
n = 0

#######################################################################
# methods to clear history or any subset thereof

function clear_history(indices)
    for n in indices
        delete!(In, n)
        if haskey(Out, n)
            delete!(Out, n)
        end
    end
end

# since a range could be huge, intersect it with 1:n first
clear_history{T<:Integer}(r::Range{T}) =
    invoke(clear_history, Tuple{Any}, intersect(r, 1:n))

function clear_history()
    empty!(In)
    empty!(Out)
    global ans = nothing
end

"""
    clear_history([indices])

The `clear_history()` function clears all of the input and output
history stored in the running IJulia notebook.  This is sometimes
useful because all cell outputs are remember in the `Out` global variable,
which prevents them from being freed, so potentially this could
waste a lot of memory in a notebook with many large outputs.

The optional `indices` argument is a collection of indices indicating
a subset of cell inputs/outputs to clear.
"""
clear_history

#######################################################################
# methods to print history or any subset thereof
function print_history(io::IO, indices)
    for n in indices
      if haskey(In, n)
        print(In[n])
      end
    end
end

# since a range could be huge, intersect it with 1:n first
print_history{T<:Integer}(io::IO=Base.STDOUT, r::Range{T}=1:n) =
    invoke(print_history, Tuple{IO, Any}, io, intersect(r, 1:n))

print_history{T<:Integer}(r::Range{T}) =
    invoke(print_history, Tuple{IO, Any}, Base.STDOUT, intersect(r, 1:n))

"""
    print_history([io], [indices])

The `print_history()` function prints all of the input history stored in
the running IJulia notebook, with most recent last. The Input history is
printed without cell numbers so it can be directly pasted into an editor.

The optional `indices` argument is a collection of indices indicating
a subset of cell inputs to print.

The optional `io` argument is for specifying an output stream. The default
is Base.STDOUT.
"""
print_history

#######################################################################
# Similar to the ipython kernel, we provide a mechanism by
# which modules can register thunk functions to be called after
# executing an input cell, e.g. to "close" the current plot in Pylab.
# Modules should only use these if isdefined(Main, IJulia) is true.

const postexecute_hooks = Function[]
"""
    push_postexecute_hook(f::Function)

Push a function `f()` onto the end of a list of functions to
execute after executing any notebook cell.
"""
push_postexecute_hook(f::Function) = push!(postexecute_hooks, f)
"""
    pop_postexecute_hook(f::Function)

Remove a function `f()` from the list of functions to
execute after executing any notebook cell.
"""
pop_postexecute_hook(f::Function) = splice!(postexecute_hooks, findfirst(postexecute_hooks, f))

const preexecute_hooks = Function[]
"""
    push_preexecute_hook(f::Function)

Push a function `f()` onto the end of a list of functions to
execute before executing any notebook cell.
"""
push_preexecute_hook(f::Function) = push!(preexecute_hooks, f)
"""
    pop_preexecute_hook(f::Function)

Remove a function `f()` from the list of functions to
execute before executing any notebook cell.
"""
pop_preexecute_hook(f::Function) = splice!(preexecute_hooks, findfirst(pretexecute_hooks, f))

# similar, but called after an error (e.g. to reset plotting state)
const posterror_hooks = Function[]
"""
    pop_posterror_hook(f::Function)

Remove a function `f()` from the list of functions to
execute after an error occurs when a notebook cell is evaluated.
"""
push_posterror_hook(f::Function) = push!(posterror_hooks, f)
"""
    pop_posterror_hook(f::Function)

Remove a function `f()` from the list of functions to
execute after an error occurs when a notebook cell is evaluated.
"""
pop_posterror_hook(f::Function) = splice!(posterror_hooks, findfirst(posterror_hooks, f))

#######################################################################

# The user can call IJulia.clear_output() to clear visible output from the
# front end, useful for simple animations.  Using wait=true clears the
# output only when new output is available, for minimal flickering.
"""
    clear_output(wait=false)

Call `clear_output()` to clear visible output from the current notebook
cell.  Using `wait=true` clears the output only when new output is
available, which reduces flickering and is useful for simple animations.
"""
function clear_output(wait=false)
    # flush pending stdio
    flush_all()
    empty!(displayqueue) # discard pending display requests
    send_ipython(publish[], msg_reply(execute_msg::Msg, "clear_output",
                                    Dict("wait" => wait)))
end


"""
    set_max_stdio(max_output::Integer)

Sets the maximum number of bytes, `max_output`, that can be written to stdout and
stderr before getting truncated. A large value here allows a lot of output to be
displayed in the notebook, potentially bogging down the browser.
"""
function set_max_stdio(max_output::Integer)
    max_output_per_request[] = max_output
end


#######################################################################

include("init.jl")
include("hmac.jl")
include("eventloop.jl")
include("stdio.jl")
include("msg.jl")
include("handlers.jl")
include("heartbeat.jl")
include("inline.jl")

end # IJulia
