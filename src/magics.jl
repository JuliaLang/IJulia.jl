# IJulia does not use IPython magic syntax, because there are better
# alternatives in Julia, whereas "magics" are inherently limited to
# running in Jupyter cells only.   The alternatives in Julia, which
# can work in any Julia code regardless of whether it is in a notebook
# cell, are:
#     * To interact with the running kernel, we can use IJulia.foo(...),
#       since the running IJulia kernel is loaded into Main.
#     * For implementing special syntax, Julia has @macros and
#       stringmacros"....".
# However, to ease the transition for users coming from other Jupyter kernels,
# we implement some magics that tell the user how to do the corresponding
# thing in Julia.   These are executed whenever a cell beginning with %
# is encountered.

# regex to find the presence of magics in a code-cell string
const magics_regex = r"^\s*(%%?[A-Za-z_][A-Za-z_0-9]*\b)\s*(.*)\s*$"m

# given the cell contents "code" (which start with %foo) output help
# that indicates the Julia equivalent, if possible.
function magics_help(code::AbstractString)
    for m in eachmatch(magics_regex, code)
        display(get(magic_help, m[1], generic_magic_help)(m[1], m[2]))
    end
end

using Base.Markdown

const magic_help_string = """
    Julia does not use the IPython `%magic` syntax.   To interact
    with the IJulia kernel, use `IJulia.somefunction(...)`, for
    example.  Julia macros, string macros, and functions can be used to
    accomplish most of the other functionalities of IPython magics."""
generic_magic_help(magic::AbstractString, args::AbstractString) =
    Base.Markdown.parse("""
        Unrecognized magic `$magic`.

        $magic_help_string""")

lsmagic_help(magic::AbstractString, args::AbstractString) =
    Base.Markdown.parse("""
    $magic_help_string

    The Julia analogues of many IPython magics are printed if
    you try to input the IPython magic in a code cell.""")

alias_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The equivalent of `%alias` magic in Julia is simply to write
    a function that [runs a command object](http://docs.julialang.org/en/latest/manual/running-external-programs/).

    For example, the equivalent of `%alias bracket echo "Input in brackets: <%l>"`
    in IPython would be the Julia function

        bracket(l) = run(`echo "Input in brackets: <$l>"`)

    which you can then run with e.g. `bracket("hello world")`."""

autosave_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The equivalent of `%autosave 60` magic in Julia is `IJulia.autosave!(60)`,
    to set the notebook autosave frequency, in seconds. Use `0` to disable
    autosaving.
"""

function cd_magic_help(magic::AbstractString, args::AbstractString)
    if magic == "%cd" && !ismatch(r"\s*-", args)
        return md"""The equivalent of `%cd 'dir'` in IPython is `cd("dir")` in Julia."""
    else
        return md"""
    The equivalent of `%cd 'dir'` in IPython is `cd("dir")` in Julia.

    Julia does not keep a history of visited directories, so it
    has no built-in equivalent of IPython's `%cd -`, `%dhist`,
    `%pushd`, and `%popd`.

    However, if you are interested, it would be easy to write a
    Julia function `mycd(x)` that worked like IPython's `%cd`
    (accepting a string, `-`, `-n`, and so on, and keeping a stack
    of directory history).  This might make a nice little Julia package
    if you are sufficiently motivated."""
    end
end

debug_magic_help(magic::AbstractString, args::AbstractString) =
md"""The Julia interactive debugger is provided by the [Gallium](https://github.com/Keno/Gallium.jl) package."""

edit_magic_help(magic::AbstractString, args::AbstractString) = md"""
    An analogue of IPython's `%edit` magic is provided by
    the `edit` function and the `@edit` macro in Julia, as
    described [in the Julia manual](http://docs.julialang.org/en/latest/stdlib/base/#Base.edit).

    For example, instead of `%edit -n line 'filename'` in IPython, you would do
    `edit("filename", line)` followed by `include("filename")` if you
    want to execute the file when you are done editing.  The analogue
    of `%edit` (which creates a temporary file) is `n=tempname(); edit(n)`
    followed by `include(n)`.

    If you have a function `foo()`, then `%edit foo` in IPython opens
    the file where `foo` was defined.  The analogue of this in Julia is
    to do `@edit foo()`   Note that you need to supply sample arguments
    to `foo` (which is not actually called), so that Julia knows *which*
    method of `foo` you want to edit.

    If `s` is a string variable, IPython's `%edit s` loads its contents
    into an editor.  In Julia, you would have to explicitly write
    to a temporary file with `n=tempname(); write(n, s); edit(n)` followed
    by `include(n)` to execute it."""

env_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The equivalent of `%env` in IPython, which lists all environment
    variables, is `ENV` in Julia, and the equivalent of
    `%env var=val` is `ENV["var"]=val`.

    (The `ENV` built-in global variable in Julia provides a dictionary-like
    interface to the system environment variables.)
"""

gui_magic_help(magic::AbstractString, args::AbstractString) = md"""
    There is an analogue of IPython's `%gui` in the
    [PyCall package](https://github.com/stevengj/PyCall.jl)
    for calling Python from Julia.   If you have done `using PyCall`
    to load PyCall, then the analogue of `%gui wx` is `pygui_start(:wx)`,
    and the analogue of `%gui` is `pygui_stop()`.  See the PyCall
    documentation for more information.

    Other Julia packages for GUI toolkits, e.g. the
    [Tk package](https://github.com/JuliaGraphics/Tk.jl) or
    the [Gtk package](https://github.com/JuliaGraphics/Gtk.jl), also
    provide their own event-loop integration."""

history_magic_help(magic::AbstractString, args::AbstractString) = md"""
    An analogue of the `%history` or `%hist` magic of IPython, which provides
    access to the input history, is given by IJulia.history(). It is
    based on the global variable `In` in IJulia. `In` is a dictionary
    mapping cell numbers to the inputs. However, IJulia does not currently
    keep any other history, e.g. it discards input cells that you overwrite.
"""

load_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of `%load filename` in IPython is `IJulia.load("filename")`
    in IJulia (to load code from `filename` into the current frontend)

    The analogue of `%load url` is `IJulia.load(download("url"))`.
"""

paste_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of `%paste` in IPython is `IJulia.load_string(clipboard())`
    in IJulia (to load code from the clipboard into the current frontend).
"""

matplotlib_magic_help(magic::AbstractString, args::AbstractString) =
Base.Markdown.parse("""
    The analogue of IPython's `$magic` in Julia is to use
    the [PyPlot package](https://github.com/stevengj/PyPlot.jl),
    which gives a Julia interface to Matplotlib including inline
    plots in IJulia notebooks.   (The equivalent of `numpy` is already
    loaded by default in Julia.)

    Given PyPlot, the analogue of `$magic inline` is `using PyPlot`,
    since PyPlot defaults to inline plots in IJulia.

    To enable separate GUI windows in PyPlot, analogous to `$magic`,
    do `using PyPlot; pygui(true)`.   To specify a particular gui
    backend, analogous to `$magic gui`, you can either do
    `using PyPlot; pygui(:gui); using PyPlot; pygui(true)` (where
    `gui` is `wx`, `qt`, `tk`, or `gtk`), or you can do
    `ENV["MPLBACKEND"]=backend; using PyPlot; pygui(true)` (where
    `backend` is the name of a Matplotlib backend, like `tkagg`).

    For more options, see the PyPlot documentation.""")

pdef_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%pdef somefunction` in Julia is
    `methods(somefunction)`, which prints out all of the possible
    calling signatures of `somefunction`.  (Note that, unlike Python,
    Julia is based on multiple dispatch, so a given function will
    often be callable with many different argument signatures.)"""

pdoc_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%pdoc object` is `?object` in IJulia."""

pfile_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%pfile somefunction` (also `%psource`) is
    roughly `@less somefunction(somearguments...)` in Julia.   The
    reason that you need to supply sample arguments (the function is
    not actually evaluated) is because Julia functions can
    have multiple definitions for different argument types.
    `@less somefunction(somearguments...)` will print (or run
    through the `less` pager) the `somefunction` definition
    corresponding to the arguments you supply."""

file_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%file somefunction` is
    roughly `methods(somefunction)` in Julia.   This lists
    all the methods of `sumfunction` along with the locations where
    they are defined."""

precision_magic_help(magic::AbstractString, args::AbstractString) = md"""
    There currently is no way to globally set the output precision
    in Julia, analogous to `%precision` in IPython, as discussed
    in [Julia issue #6493](https://github.com/JuliaLang/julia/issues/6493)."""

prun_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%prun statement` in Julia is
    `@profile statement`, which runs the
    [Julia profiler](http://docs.julialang.org/en/latest/manual/profile/).
    The analogue of `%%prun ...code...` is
    ```
    @profile begin
        ...code...
    end
    ```
    Note, however, that you should put all performance-critical
    code into a function, avoiding global variables, before
    doing performance measurements in Julia; see the
    [performance tips in the Julia manual](http://docs.julialang.org/en/latest/manual/performance-tips/).

    See also the
    [ProfileView package](https://github.com/timholy/ProfileView.jl) for
    richer graphical display of profiling output."""

psearch_magic_help(magic::AbstractString, args::AbstractString) = md"""
    A rough analogue of IPython's `%psearch PATTERN` in Julia might be
    `filter(s -> ismatch(r"PATTERN", string(s)), names(Base))`, which
    searches all the symbols defined in the `Base` module for a given
    regular-expression pattern `PATTERN`."""

pwd_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%pwd` is `pwd()` in Julia."""

qtconsole_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%qtconsole` is `IJulia.qtconsole()` in Julia."""

recall_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%recall n` in IJulia is
    `IJulia.load_string(In[n])`, and the analogue of
    `%recall n-m` is `IJulia.load_string(join([get(In,i,"") for i in n:m],"\n"))`."""

run_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%run file` is `include("file")` in Julia.

    The analogue of `%run -t file`, to print timing information, is
    `@time include("file")` in Julia.  The analogue of `%run -t -N n file`
    is `@time for i in 1:n; include("file"); end` in Julia.

    For running under a debugger, see the
    [Gallium Julia debugger](https://github.com/Keno/Gallium.jl).  To
    run other IJulia notebooks, see the
    [NBInclude package](https://github.com/stevengj/NBInclude.jl)."""

save_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%save filename n1-n2 n3-n4` is
    ```
    open("filename","w") do io
        for i in [n1:n2; n3:n4]
            println(get(In,i,""))
        end
    end
    ```
    in IJulia."""

sc_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%sc shell command` is `; shell command` in IJulia, or
        read(`shell command`, String)
    to capture the output as a string in Julia."""

set_env_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%set_env var val` is `ENV["var"]=val` in Julia."""

sx_magic_help(magic::AbstractString, args::AbstractString) =
Base.Markdown.parse("""
    The analogue of IPython's `$magic shell command` is
        split(read(`shell command`, String),'\n')
    in Julia.""")

time_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%time statement` (also `%timeit`) in Julia is
    `@time statement`.  The analogue of `%%time ...code...` is
    ```
    @time begin
        ...code...
    end
    ```
    Note, however, that you should put all performance-critical
    code into a function, avoiding global variables, before
    doing performance measurements in Julia; see the
    [performance tips in the Julia manual](http://docs.julialang.org/en/latest/manual/performance-tips/).

    The `@time` macro prints the timing results, and returns the
    value of evaluating the expression.  To instead return the time
    (in seconds), use `@elapsed statement`.

    For more extensive benchmarking tools, including the ability
    to collect statistics from multiple runs, see the
    [BenchmarkTools package](https://github.com/JuliaCI/BenchmarkTools.jl)."""

who_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%who` and `%whos` is `whos()` in Julia.

    You can also use `whos(r"PATTERN")` to find variables matching
    a given regular expression `PATTERN`."""

html_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%%html` is
    ```
    HTML(""\"
    ...html text...
    ""\")
    ```
    in Julia."""

javascript_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%%javascript ...code...` in Julia can be
    constructed by first evaluating
    ```
    macro javascript_str(s) display("text/javascript", s); end
    ```
    to define the `javascript"...."` [string macro](http://docs.julialang.org/en/latest/manual/strings/#non-standard-string-literals)
    in Julia.  Subsequently, you can simply do:
    ```
    javascript""\"
    ...code...
    ""\"
    ```
    to execute the script in an IJulia notebook."""

latex_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%%latex` is
    ```
    display("text/latex", ""\"
    ...latex text...
    ""\")
    ```
    in Julia.  Note, however, that `$` and `\` in the LaTeX text
    needs to be escaped as `\$` and `\\` so that they aren't
    interpreted by Julia.  See, however, the
    [LaTeXStrings package](https://github.com/stevengj/LaTeXStrings.jl)
    for easier input of LaTeX text as
    L""\"
    ...latex text...
    ""\"
    without requiring any extra backslashes.
"""

function pipe_magic_help(magic::AbstractString, args::AbstractString)
    cmd = magic[3:end] # magic is "%%cmd"
    if cmd == "script"
        arglist = split(args)
        cmd = isempty(arglist) ? "someprogram" : arglist[end]
        magic = "%%script $cmd"
    end
    Base.Markdown.parse("""
    The analogue of IPython's `$magic ...code...` in Julia can be
    constructed by first evaluating
    ```
    macro $(cmd)_str(s) open(`$cmd`,"w",STDOUT) do io; print(io, s); end; end
    ```
    to define the `$cmd"...."` [string macro](http://docs.julialang.org/en/latest/manual/strings/#non-standard-string-literals)
    in Julia.  Subsequently, you can simply do:
    ```
    $cmd""\"
    ...code...
    ""\"
    ```
    to evaluate the code in `$cmd` (outputting to `STDOUT`).""")
end

svg_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%%svg` is
    ```
    display("image/svg+xml", ""\"
    ...svg text...
    ""\")
    ```
    in Julia. To be even nicer, you can define
    ```
    macro svg_str(s) display("image/svg+xml", s); end
    ```
    to define the `svg"...."` [string macro](http://docs.julialang.org/en/latest/manual/strings/#non-standard-string-literals)
    in Julia.  Subsequently, you can simply do:
    ```
    svg""\"
    ...svg text...
    ""\"
    ```
    to display the SVG image.  Using a custom string macro like this
    has the advantage that you don't need to escape `$` and `\` if they
    appear in the SVG code."""

writefile_magic_help(magic::AbstractString, args::AbstractString) = md"""
    The analogue of IPython's `%%writefile filename` is
    `write("filename", In[IJulia.n])`.

    (`IJulia.n` is the index of the current code cell.  Of
    course, you can also use `In[N]` for some other `N` to output
    the contents of a different input cell.)"""

# map from magic to helpfunction(magic, magicargument)
const magic_help = Dict{String, Function}(
    "%alias" => alias_magic_help,
    "%autosave" => autosave_magic_help,
    "%cd" => cd_magic_help,
    "%dhist" => cd_magic_help,
    "%dirs" => cd_magic_help,
    "%popd" => cd_magic_help,
    "%pushd" => cd_magic_help,
    "%debug" => debug_magic_help,
    "%pdb" => debug_magic_help,
    "%edit" => edit_magic_help,
    "%env" => env_magic_help,
    "%gui" => gui_magic_help,
    "%hist" => history_magic_help,
    "%history" => history_magic_help,
    "%load" => load_magic_help,
    "%loadpy" => load_magic_help,
    "%paste" => paste_magic_help,
    "%lsmagic" => lsmagic_help,
    "%matplotlib" => matplotlib_magic_help,
    "%pylab" => matplotlib_magic_help,
    "%pdef" => pdef_magic_help,
    "%pdoc" => pdoc_magic_help,
    "%pinfo" => pdoc_magic_help,
    "%pinfo2" => pdoc_magic_help,
    "%pfile" => pfile_magic_help,
    "%file" => file_magic_help,
    "%psource" => pfile_magic_help,
    "%precision" => precision_magic_help,
    "%prun" => prun_magic_help,
    "%%prun" => prun_magic_help,
    "%psearch" => psearch_magic_help,
    "%pwd" => pwd_magic_help,
    "%qtconsole" => qtconsole_magic_help,
    "%recall" => recall_magic_help,
    "%run" => run_magic_help,
    "%save" => save_magic_help,
    "%sc" => sc_magic_help,
    "%set_env" => set_env_magic_help,
    "%sx" => sx_magic_help,
    "%system" => sx_magic_help,
    "%time" => time_magic_help,
    "%%time" => time_magic_help,
    "%timeit" => time_magic_help,
    "%%timeit" => time_magic_help,
    "%who" => who_magic_help,
    "%who_ls" => who_magic_help,
    "%whos" => who_magic_help,
    "%%html" => html_magic_help,
    "%%javascript" => javascript_magic_help,
    "%%latex" => latex_magic_help,
    "%%bash" => pipe_magic_help,
    "%%perl" => pipe_magic_help,
    "%%python" => pipe_magic_help,
    "%%python2" => pipe_magic_help,
    "%%python3" => pipe_magic_help,
    "%%ruby" => pipe_magic_help,
    "%%script" => pipe_magic_help,
    "%%sh" => pipe_magic_help,
    "%%svg" => svg_magic_help,
    "%%writefile" => writefile_magic_help,
)
