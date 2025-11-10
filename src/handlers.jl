using .CommManager

# Don't send previous lines to the completions function,
# due to issue #380.  Find the start of the first line
# (if any) where the expression is parseable.  Replace
# with find_parsestart(c,p) = start(c) once julia#9467 is merged.
parseok(s) = !Meta.isexpr(Meta.parse(s, raise=false), :error)
function find_parsestart(code, cursorpos)
    s = firstindex(code)
    while s < cursorpos
        parseok(code[s:cursorpos]) && return s
        s = nextind(code, s)
        while s < cursorpos && code[s] ∉ ('\n','\r')
            s = nextind(code, s)
        end
    end
    return firstindex(code) # failed to find parseable lines
end

# As described in jupyter/jupyter_client#259, Jupyter's cursor
# positions are actually measured in UTF-16 code units, not
# Unicode characters.  Hence, these functions are similar to
# Base.chr2ind and Base.ind2chr but count non-BMP characters
# as 2 code units.
function utf16_to_ind(str, ic)
    i = 0
    e = lastindex(str)
    while ic > 0 && i < e
        i = nextind(str, i)
        ic -= UInt32(str[i]) < 0x10000 ? 1 : 2
    end
    return i
end
function ind_to_utf16(str, i)
    ic = 0
    i = min(i, lastindex(str))
    while i > 0
        ic += UInt32(str[i]) < 0x10000 ? 1 : 2
        i = prevind(str, i)
    end
    return ic
end

# protocol change in Jupyter 5.2 (jupyter/jupyter_client#262)
chr2ind(m::Msg, str::String, ic::Integer) = ic == 0 ? 0 :
    VersionNumber(m.header["version"]) ≥ v"5.2" ? nextind(str, 0, ic) : utf16_to_ind(str, ic)
ind2chr(m::Msg, str::String, i::Integer) = i == 0 ? 0 :
    VersionNumber(m.header["version"]) ≥ v"5.2" ? length(str, 1, i) : ind_to_utf16(str, i)
#Compact display of types for Jupyterlab completion

import REPL: REPLCompletions
import REPL.REPLCompletions: sorted_keywords, emoji_symbols, latex_symbols

if isdefined(REPLCompletions, :named_completion)
    # julia#54800 (julia 1.12)
    repl_completion_text(c) = REPLCompletions.named_completion(c).completion::String
else
    # julia#26930
    repl_completion_text(c) = REPLCompletions.completion_text(c)
end

complete_type(::Type{<:Function}) = "function"
complete_type(::Type{<:Type}) = "type"
complete_type(::Type{<:Tuple}) = "tuple"
complete_type(::Any) = ""

function complete_type(T::DataType)
    s = string(T)
    (textwidth(s) ≤ 20 || isempty(T.parameters)) && return s
    buf = IOBuffer()
    print(buf, T.name)
    position(buf) > 19 && return String(take!(buf))
    print(buf, '{')
    comma = false
    for p in T.parameters
        s = string(p)
        if position(buf) + sizeof(s) > 20
            comma || print(buf, '…')
            break
        end
        comma && print(buf, ',')
        comma = true
        print(buf, s)
    end
    print(buf, '}')
    return String(take!(buf))
end

#Get typeMap for Jupyter completions
function complete_types(comps, kernel=_default_kernel)
    typeMap = []
    for c in comps
        ctype = ""
        if !isempty(searchsorted(sorted_keywords, c))
            ctype = "keyword"
        elseif startswith(c, "\\:")
            ctype = get(emoji_symbols, c, "")
            isempty(ctype) || (ctype = "emoji: $ctype")
        elseif startswith(c, "\\")
            ctype = get(latex_symbols, c, "")
        else
            expr = Meta.parse(c, raise=false)
            if typeof(expr) == Symbol
                try
                    ctype = complete_type(Core.eval(kernel.current_module, :(typeof($expr))))
                catch
                end
            elseif !isa(expr, Expr)
                ctype = complete_type(expr)
            elseif expr.head == :macrocall
                ctype = "macro"
            end
        end
        isempty(ctype) || push!(typeMap, Dict("text" => c, "type" => ctype))
    end
    return typeMap
end

"""
    complete_request(socket, kernel, msg)

Handle a [completion
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#completion).
"""
function complete_request(socket, kernel, msg)
    code = msg.content["code"]::String
    cursor_chr = msg.content["cursor_pos"]::Int64
    cursorpos = chr2ind(msg, code, cursor_chr)
    # Ensure that `cursorpos` is within bounds, Jupyter may send a position out
    # of bounds when autocompletion is enabled.
    cursorpos = min(cursorpos, lastindex(code))

    if all(isspace, code[1:cursorpos])
        send_ipython(kernel.requests[], kernel, msg_reply(msg, "complete_reply",
                                 Dict("status" => "ok",
                                              "metadata" => Dict(),
                                              "matches" => String[],
                                              "cursor_start" => cursor_chr,
                                              "cursor_end" => cursor_chr)))
        return
    end

    codestart = find_parsestart(code, cursorpos)
    comps_, positions, should_complete = REPLCompletions.completions(code[codestart:end], cursorpos-codestart+1, kernel.current_module)
    comps = unique!(repl_completion_text.(comps_))
    # positions = positions .+ (codestart - 1) on Julia 0.7
    positions = (first(positions) + codestart - 1):(last(positions) + codestart - 1)
    metadata = Dict()
    if isempty(comps)
        # issue #530: REPLCompletions returns inconsistent results
        # for positions when no completions are found
        cursor_start = cursor_end = cursor_chr
    elseif isempty(positions) # true if comps to be inserted without replacement
        cursor_start = (cursor_end = ind2chr(msg, code, last(positions)))
    else
        cursor_start = ind2chr(msg, code, prevind(code, first(positions)))
        cursor_end = ind2chr(msg, code, last(positions))
        if should_complete
            metadata["_jupyter_types_experimental"] = complete_types(comps, kernel)
        else
            # should_complete is false for cases where we only want to show
            # a list of possible completions but not complete, e.g. foo(\t
            pushfirst!(comps, code[positions])
        end
    end

    maybe_launch_precompile(kernel)

    send_ipython(kernel.requests[], kernel, msg_reply(msg, "complete_reply",
                                     Dict("status" => "ok",
                                                  "matches" => comps,
                                                  "metadata" => metadata,
                                                  "cursor_start" => cursor_start,
                                                  "cursor_end" => cursor_end)))
end

"""
    kernel_info_request(socket, kernel, msg)

Handle a [kernel info
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#kernel-info).
"""
function kernel_info_request(socket, kernel, msg)
    send_ipython(socket, kernel,
                 msg_reply(msg, "kernel_info_reply",
                           Dict("protocol_version" => "5.4",
                                "implementation" => "ijulia",
                                "implementation_version" => string(pkgversion(@__MODULE__)),
                                "language_info" =>
                                    Dict("name" => "julia",
                                         "version" =>
                                             string(VERSION.major, '.',
                                                    VERSION.minor, '.',
                                                    VERSION.patch),
                                         "mimetype" => "application/julia",
                                         "file_extension" => ".jl"),
                                "banner" => "Julia: A fresh approach to technical computing.",
                                "help_links" => [
                                    Dict("text"=>"Julia Home Page",
                                         "url"=>"http://julialang.org/"),
                                    Dict("text"=>"Julia Documentation",
                                         "url"=>"http://docs.julialang.org/"),
                                    Dict("text"=>"Julia Packages",
                                         "url"=>"https://juliahub.com/ui/Packages")
                                ],
                                "status" => "ok")))
end

"""
    connect_request(socket, kernel, msg)

Handle a [connect
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#connect).
"""
function connect_request(socket, kernel, msg)
    send_ipython(kernel.requests[], kernel,
                 msg_reply(msg, "connect_reply",
                           Dict("shell_port" => kernel.profile["shell_port"],
                                "iopub_port" => kernel.profile["iopub_port"],
                                "stdin_port" => kernel.profile["stdin_port"],
                                "hb_port" => kernel.profile["hb_port"])))
end

"""
    shutdown_request(socket, kernel, msg)

Handle a [shutdown
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#kernel-shutdown). After
sending the reply this will exit the process.
"""
function shutdown_request(socket, kernel, msg)
    send_ipython(kernel.control[], kernel,
                 msg_reply(msg, "shutdown_reply", msg.content))
    sleep(0.1) # short delay (like in ipykernel), to hopefully ensure shutdown_reply is sent

    kernel.shutdown(kernel)

    nothing
end

docdict(s::AbstractString) = display_dict(Core.eval(Main, helpmode(devnull, s)))

import Base: is_id_char, is_id_start_char

"""
    get_previous_token(code, pos, crossed_parentheses)

Given a string and a cursor position, find substring corresponding to previous token.
`crossed_parentheses:Int` keeps track of how many parentheses have been crossed.
A pair of parentheses yields 0 crossing; a '(' add 1; a ')' subtracts 1.

Returns `(startpos, endpos, crossed_parentheses, stop)`

- `startpos` is the start position of the closest potential token before `pos`.
- `endpos` is end position if said token is can be valid identifier, or `-1` otherwise
- `crossed_parentheses` is the new count for parentheses.
- `stop` is true if ';' is hit, denoting the beginning of a clause.
"""
function get_previous_token(code, pos, crossed_parentheses)
    startpos = pos
    separator = false
    stop = false
    while startpos > firstindex(code)
        c = code[startpos]
        if c == '('
            crossed_parentheses += 1
            separator = false
        elseif c == ')'
            crossed_parentheses -= 1
            separator = false
        elseif c == ';'
            stop = true
        elseif !is_id_char(c) && !isspace(c) && !separator
            separator = true
            crossed_parentheses = max(0, crossed_parentheses - 1)
        end
        if is_id_char(code[startpos])
            break
        else
            startpos = prevind(code, startpos)
        end
    end
    endpos = startpos
    while startpos >= firstindex(code) && (is_id_char(code[startpos]) || code[startpos] == '.')
        startpos = prevind(code, startpos)
    end
    startpos = startpos < pos ? nextind(code, startpos) : pos
    if !is_id_start_char(code[startpos])
        return startpos, -1, crossed_parentheses, stop
    end
    while endpos < lastindex(code) && is_id_char(code[endpos])
        endpos = nextind(code, endpos)
    end
    if !is_id_char(code[endpos])
        endpos = prevind(code, endpos)
    end
    return startpos, endpos, crossed_parentheses, stop
end

"""
    get_token(code, pos)

Given a string and a cursor position, find substring to request
help on by:

1. Searching backwards for the closest token (may be invalid)
2. Keep searching backwards until we find an token before an unbalanced '('
    a. If (1) is not valid, store the first valid token
    b. We assume a token before an unbalanced '(' is a function
3. If we find a possible function token, return this token.
4. Otherwise, return the last valid token

# Important Note

Tokens are chosen following several empirical observations instead of rigorous rules.
We assume that the first valid token before left-imbalanced (more '(' than ')') parentheses is the function "closest" to cursor.
The following examples use '|' to denote cursor, showing observations on parentheses.

- `f()|` has balanced parentheses with nothing within, thus `f` is the desired token.
- `f(|)` has imbalanced parentheses, thus `f` is the desired token.
- `f(x|, y)` gives tokens `x` and `f`. `x` has balanced parentheses, while `f` is left-imbalanced. `f` is desired.
- `f(x)|` returns `f`
- `f(x, y)|` returns `f`.
- `f((x|))` returns `f`, as expected
- `f(x, (|y))` returns `f`. **This is a hack**, as I deduct `crossed_parentheses` whenever a separator is encountered, clamped to 0!
    Otherwise, `x` would be returned.
- `f(x, (y|))`, `f(x, (y)|)`, and `f(x, (y))|` all behave as above. Arbitrary nesting of tuples should not cause misbehavior.
- `expr1 ; expr2`, cursor in `expr2` never causes search in `expr1`

TODO: detect operators? More robust parsing using the Julia parser instead of string hacks?
"""
function get_token(code, pos)
    # Keep cursor in code range
    pos = max(1, pos)
    pos = min(pos, lastindex(code))

    crossed_parentheses = 0
    prev_startpos, prev_endpos, crossed_parentheses, stop =
        get_previous_token(code, pos, crossed_parentheses)
    startpos = prev_startpos
    endpos = prev_endpos # Does not matter
    last_valid_start = startpos
    last_valid_end = -1
    while !stop && startpos > firstindex(code) && crossed_parentheses <= 0
        pos = prevind(code, startpos)
        startpos, endpos, crossed_parentheses, stop = get_previous_token(code, pos, crossed_parentheses)
        if endpos != -1 && last_valid_end == -1
            last_valid_start = startpos
            last_valid_end = endpos
        end
    end

    token = ""
    if crossed_parentheses > 0 # Potential function token
        if endpos != -1 # Function token valid
            token = code[startpos:endpos]
        elseif prev_endpos != -1 # Closest token valid
            token = code[prev_startpos:prev_endpos]
        elseif last_valid_end != -1 # Another, farther token valid
            token = code[last_valid_start:last_valid_end]
        end
    else # No function token found
        if prev_endpos != -1 # Closest token valid
            token = code[prev_startpos:prev_endpos]
        elseif last_valid_end != -1 # Another, farther token valid
            token = code[last_valid_start:last_valid_end]
        end
    end
    return token
end

"""
    inspect_request(socket, kernel, msg)

Handle a [introspection
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#introspection).
"""
function inspect_request(socket, kernel, msg)
    try
        code = msg.content["code"]::String
        cursor_pos = msg.content["cursor_pos"]::Int64
        s = get_token(code, chr2ind(msg, code, cursor_pos))
        if isempty(s)
            content = Dict("status" => "ok", "found" => false)
        else
            d = docdict(s)
            content = Dict("status" => "ok",
                           "found" => !isempty(d),
                           "data" => d,
                           "metadata" => Dict())
        end
        send_ipython(kernel.requests[], kernel, msg_reply(msg, "inspect_reply", content))
    catch e
        content = error_content(e, backtrace_top=:inspect_request);
        content["status"] = "error"
        send_ipython(kernel.requests[], kernel,
                     msg_reply(msg, "inspect_reply", content))
    end
end

"""
    history_request(socket, kernel, msg)

Handle a [history
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#history). This
is currently only a dummy implementation that doesn't actually do anything.
"""
function history_request(socket, kernel, msg)
    # we will just send back empty history for now, pending clarification
    # as requested in ipython/ipython#3806
    send_ipython(kernel.requests[], kernel,
                 msg_reply(msg, "history_reply",
                           Dict("history" => [])))
end

"""
    is_complete_request(socket, kernel, msg)

Handle a [completeness
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#code-completeness).
"""
function is_complete_request(socket, kernel, msg)
    ex = Meta.parse(msg.content["code"]::String, raise=false)
    status = Meta.isexpr(ex, :incomplete) ? "incomplete" : Meta.isexpr(ex, :error) ? "invalid" : "complete"
    send_ipython(kernel.requests[], kernel,
                 msg_reply(msg, "is_complete_reply",
                           Dict("status"=>status, "indent"=>"")))
end

"""
    interrupt_request(socket, kernel, msg)

Handle a [interrupt
request](https://jupyter-client.readthedocs.io/en/latest/messaging.html#kernel-interrupt). This
will throw an `InterruptException` to the currently executing request handler.
"""
function interrupt_request(socket, kernel, msg)
    @async Base.throwto(kernel.requests_task[], InterruptException())
    send_ipython(socket, kernel, msg_reply(msg, "interrupt_reply", Dict()))
end

function unknown_request(socket, kernel, msg)
    @vprintln("UNKNOWN MESSAGE TYPE $(msg.header["msg_type"])")
end

const handlers = Dict{String,Function}(
    "execute_request" => execute_request,
    "complete_request" => complete_request,
    "kernel_info_request" => kernel_info_request,
    "inspect_request" => inspect_request,
    "connect_request" => connect_request,
    "shutdown_request" => shutdown_request,
    "history_request" => history_request,
    "is_complete_request" => is_complete_request,
    "interrupt_request" => interrupt_request,
    "comm_open" => comm_open,
    "comm_info_request" => comm_info_request,
    "comm_msg" => comm_msg,
    "comm_close" => comm_close
)
