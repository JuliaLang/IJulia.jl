# This extension implements a Comm and CommManager for the comm package:
# https://github.com/ipython/comm
#
# comm is by ipywidgets and is designed to be extended, so by implementing the
# interfaces it specifies we can get full support for ipywidgets and all other
# libraries that use ipywidgets (like matplotlib/ipympl).

module IJuliaPythonCallExt

import IJulia
using PythonCall
import PrecompileTools: @compile_workload

# `_repr_mimebundle_()` is a standard in the IPython ecosystem for returning all
# the MIME's an object supports at once.
function IJulia.display_dict(x::Py)
    if hasproperty(x, :_repr_mimebundle_) && !pyis(x._repr_mimebundle_, pybuiltins.None)
        recursive_pyconvert(x._repr_mimebundle_())
    else
        IJulia._display_dict(x)
    end
end

# Passing `backtrace=false` when calling showerror() on a PyException will also
# block printing the Python stacktrace, which is confusing. In this situation we
# *only* want the Python stacktrace to be printed so we pass `backtrace=true`
# but give an empty vector as a backtrace so that the Julia backtrace is not
# printed twice.
IJulia.showerror_nobt(io, e::PyException, _) = showerror(io, e, []; backtrace=true)

function recursive_pyconvert(x)
    x_type = pyconvert(String, pytype(x).__name__)

    if x_type == "dict"
        x = pyconvert(Dict{String, Any}, x)
        for key in copy(keys(x))
            if x[key] isa Py
                x[key] = recursive_pyconvert(x[key])
            elseif x[key] isa PythonCall.PyDict
                x[key] = recursive_pyconvert(x[key].py)
            end
        end
    elseif x_type == "str"
        x = pyconvert(String, x)
    end

    return x
end

function recursive_pydict(x)
    dict_py = pydict(x)
    for (key, value) in x
        if value isa Dict
            dict_py[key] = recursive_pydict(value)
        end
    end

    dict_py
end

function convert_buffers(buffers)
    if !(buffers isa Py)
        buffers
    elseif pyis(buffers, pybuiltins.None)
        Vector{UInt8}[]
    else
        jl_buffers = Vector{UInt8}[]
        for buf in buffers
            push!(jl_buffers, pyconvert(Vector{UInt8}, buf))
        end

        jl_buffers
    end
end

function arrays_to_pylist!(dict::Dict)
    for (key, value) in dict
        if value isa AbstractArray
            dict[key] = pylist(value)
        elseif value isa Dict
            arrays_to_pylist!(value)
        end
    end
end

function flush_pystdio()
    sys = pyimport("sys")
    sys.stdout.flush()
    sys.stderr.flush()
end

function pycomm_init(self; target_name="comm", data=nothing, metadata=nothing, buffers=nothing,
                     comm_id=IJulia.uuid4(), comm=nothing)
    try
        if target_name isa Py
            target_name = pyconvert(String, target_name)
        end
        if data isa Py
            data = recursive_pyconvert(data)
        end
        if metadata isa Py
            metadata = recursive_pyconvert(metadata)
        end
        if comm_id isa Py
            comm_id = pyconvert(String, comm_id)
        end
        buffers = convert_buffers(buffers)

        if isnothing(comm)
            comm = IJulia.Comm(target_name, comm_id, true; data, metadata, buffers)
        end
        self._comm = comm
        IJuliaPythonCallExt.pycomm_registry[comm_id] = self
    catch e
        @error "pycomm_init() failed" exception=(e, catch_backtrace())
    end

    return nothing
end

function pycomm_on_msg(self, callback)
    self._comm.on_msg = (msg) -> try
        @debug "Received msg $(msg)"

        # We need to convert Julia arrays to Python lists so that some widget
        # values can be set properly. e.g., IntRangeSlider.value is a Tuple
        # trait object (from traitlets) so it expects to be set with a tuple or
        # list, it won't work with a juliacall.ArrayValue.
        arrays_to_pylist!(msg.content)

        msg_dict = Dict("idents" => msg.idents,
                        "header" => msg.header,
                        "content" => msg.content,
                        "parent_header" => msg.parent_header,
                        "metadata" => msg.metadata,
                        "buffers" => msg.buffers
        )
        callback(msg_dict)
    catch e
        @error "pycomm_on_msg() callback failed" exception=(e, catch_backtrace())
    end
end

function pycomm_send(self; data=Dict(), metadata=Dict(), buffers=nothing)
    try
        if data isa Py
            data = recursive_pyconvert(data)
        end
        if metadata isa Py
            metadata = recursive_pyconvert(metadata)
        end
        buffers = convert_buffers(buffers)

        @debug "Sending $(data) with buffers $(length.(buffers))"

        comm = IJulia._default_kernel.comms[pyconvert(String, self.comm_id)]
        IJulia.CommManager.send_comm(comm, data, metadata, buffers)
    catch e
        @error "pycomm_send() failed" exception=(e, catch_backtrace())
    end
end

# This method is needed by ipywidgets. Unlike Julia, Python allows mixing
# keyword and positional arguments so we need to have overloads for all the
# calls with different numbers of positional arguments.
pycomm_send(self, data; buffers=nothing) = pycomm_send(self; data, buffers)

function pycomm_close(self)
    try
        if !isnothing(IJulia._default_kernel)
            comm = IJulia._default_kernel.comms[pyconvert(String, self.comm_id)]
            IJulia.CommManager.close_comm(comm)
            delete!(IJuliaPythonCallExt.pycomm_registry, comm.id)
        end
    catch e
        @error "pycomm_close() failed" exception=(e, catch_backtrace())
    end
end

function py_notimplemented(func_name, args...; kwargs...)
    @error "$(func_name) has not been implemented"
end

pycomm_notimplemented(func_name::String) = pyfunc(Base.Fix1(py_notimplemented, "PyComm.$(func_name)"); name=func_name)
pycommmanager_notimplemented(func_name::String) = pyfunc(Base.Fix1(py_notimplemented, "PyCommManager.$(func_name)"); name=func_name)

PyComm::Union{Py, Nothing} = nothing
PyCommManager::Union{Py, Nothing} = nothing

const pycomm_registry = Dict{String, Py}()

function manager_register_target(self, target_name, callback)
    try
        if callback isa String
            @error "String callbacks are not supported by register_target()"
            return
        end

        target_name = pyconvert(String, target_name)
        comm_sym = Symbol(target_name)
        self.on_open_callbacks[comm_sym] = callback

        if @ccall(jl_generating_output()::Cint) == 0
            # Only create the method if we aren't precompiling
            @eval function IJulia.CommManager.register_comm(comm::IJulia.CommManager.Comm{$(QuoteNode(comm_sym))}, msg::IJulia.Msg)
                msg_dict = Dict("idents" => msg.idents,
                                "header" => msg.header,
                                "content" => msg.content,
                                "parent_header" => msg.parent_header,
                                "metadata" => msg.metadata,
                                "buffers" => msg.buffers)
                # We need to convert the Msg to a Python dict because that's
                # what the callbacks expect, and they may call `.get()` etc on
                # the dict.
                msg_dict_py = recursive_pydict(msg_dict)
                callback = IJuliaPythonCallExt.PyCommManager.on_open_callbacks[$(QuoteNode(comm_sym))]

                # Register a PyComm corresponding to the new `comm`
                if !haskey(IJuliaPythonCallExt.pycomm_registry, comm.id)
                    PyComm(; target_name=$(target_name), comm_id=comm.id, comm)
                end

                try
                    callback(IJuliaPythonCallExt.pycomm_registry[comm.id], msg_dict_py)
                catch ex
                    @error "PyCommManager.register_target() callback failed" exception=(ex, catch_backtrace())
                end
            end
        end
    catch e
        @error "PyCommManager.register_target() failed" exception=(e, catch_backtrace())
    end
end

function IJulia.init_ipython()
    # Some libraries like mpl-interactions call IPython.display() directly, so
    # we override it to call Julia's own display() function.
    ipython_display = pyimport("IPython.display")
    ipython_display.display = display

    nothing
end

function create_pycomm()
    pytype("PyComm", (), [
        "_comm" => nothing,
        "comm_id" => pyproperty(; get=self -> pystr(self._comm.id)),
        pyfunc(pycomm_init; name="__init__"),
        pycomm_notimplemented("publish_msg"),
        pycomm_notimplemented("open"),
        pyfunc(pycomm_close; name="close"),
        pyfunc(pycomm_send; name="send"),
        pycomm_notimplemented("on_close"),
        pyfunc(pycomm_on_msg; name="on_msg"),
        pycomm_notimplemented("handle_close"),
        pycomm_notimplemented("handle_msg")
    ])
end

function create_pycommmanager()
    pytype("PyCommManager", (), [
        "on_open_callbacks" => Dict{Symbol, Py}(),
        pyfunc(manager_register_target; name="register_target"),
        pycommmanager_notimplemented("unregister_target"),
        pycommmanager_notimplemented("register_comm"),
        pycommmanager_notimplemented("unregister_comm"),
        pycommmanager_notimplemented("get_comm"),
        pycommmanager_notimplemented("comm_open"),
        pycommmanager_notimplemented("comm_msg"),
        pycommmanager_notimplemented("comm_close"),
    ])
end

function IJulia.init_ipywidgets()
    global PyComm
    global PyCommManager

    IJulia.init_ipython()

    if isnothing(PyComm)
        PyComm = create_pycomm()
    end
    if isnothing(PyCommManager)
        PyCommManager = create_pycommmanager()
    end

    comm = pyimport("comm")
    ipywidgets = pyimport("ipywidgets")

    comm.get_comm_manager = () -> PyCommManager()
    comm.create_comm = PyComm
    ipywidgets.register_comm_target()

    nothing
end

function IJulia.init_matplotlib(backend::String="module://ipympl.backend_nbagg")
    IJulia.init_ipywidgets()

    # Make sure it's in interactive mode and it's using the backend
    mpl = pyimport("matplotlib")
    if backend == "widget" || backend == "ipympl" || contains(backend, "nbagg")
        mpl.rcParams["interactive"] = true
    end
    mpl.use(backend)

    # Set a hook to automatically display figures that were created without
    # having to return them from the cell.
    nbagg = pyimport("ipympl.backend_nbagg")
    IJulia.push_postexecute_hook(() -> nbagg.flush_figures())
    IJulia.push_posterror_hook(() -> nbagg.flush_figures())

    nothing
end

function __init__()
    push!(IJulia._flush_hooks, flush_pystdio)
end

precompile(manager_register_target, (Py, Py, Py))
precompile(IJulia.display_dict, (Py,))
precompile(convert_buffers, (Py,))
precompile(pycomm_init, (Py, Py, Py, Py, Py, Py))
precompile(pycomm_on_msg, (Py, Py))
precompile(pycomm_send, (Py, Py, Py, Py))
precompile(pycomm_close, (Py,))

@compile_workload begin
    create_pycomm()
    create_pycommmanager()
    flush_pystdio()

    recursive_pydict(Dict{String, Any}("foo" => 2, "bar" => Dict("baz" => "quux")))

    # If ipywidgets is installed in the environment try to precompile its
    # initializer. This is useful because the `ipywigets.register_comm_target()`
    # line is pretty heavy.
    try
        pyimport("ipywidgets")
        IJulia.init_ipywidgets()
    catch ex
        if !(ex isa PyException)
            @error "Ipywidgets precompilation failed" exception=(ex, catch_backtrace())
        end
    finally
        global PyComm = nothing
        global PyCommManager = nothing
        empty!(pycomm_registry)
    end
end

end
