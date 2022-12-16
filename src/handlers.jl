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
function complete_types(comps)
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
                    ctype = complete_type(Core.eval(current_module[], :(typeof($expr))))
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

function complete_request(socket, msg)
    code = msg.content["code"]
    cursor_chr = msg.content["cursor_pos"]
    cursorpos = chr2ind(msg, code, cursor_chr)
    if all(isspace, code[1:cursorpos])
        send_ipython(requests[], msg_reply(msg, "complete_reply",
                                 Dict("status" => "ok",
                                              "metadata" => Dict(),
                                              "matches" => String[],
                                              "cursor_start" => cursor_chr,
                                              "cursor_end" => cursor_chr)))
        return
    end

    codestart = find_parsestart(code, cursorpos)
    comps_, positions, should_complete = REPLCompletions.completions(code[codestart:end], cursorpos-codestart+1, current_module[])
    comps = unique!(REPLCompletions.completion_text.(comps_)) # julia#26930
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
            metadata["_jupyter_types_experimental"] = complete_types(comps)
        else
            # should_complete is false for cases where we only want to show
            # a list of possible completions but not complete, e.g. foo(\t
            pushfirst!(comps, code[positions])
        end
    end
    send_ipython(requests[], msg_reply(msg, "complete_reply",
                                     Dict("status" => "ok",
                                                  "matches" => comps,
                                                  "metadata" => metadata,
                                                  "cursor_start" => cursor_start,
                                                  "cursor_end" => cursor_end)))
end

function kernel_info_request(socket, msg)
    send_ipython(requests[],
                 msg_reply(msg, "kernel_info_reply",
                           Dict("protocol_version" => "5.0",
                                        "implementation" => "ijulia",
                                        # TODO: "implementation_version" => IJulia version string from Pkg
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

function connect_request(socket, msg)
    send_ipython(requests[],
                 msg_reply(msg, "connect_reply",
                           Dict("shell_port" => profile["shell_port"],
                                        "iopub_port" => profile["iopub_port"],
                                        "stdin_port" => profile["stdin_port"],
                                        "hb_port" => profile["hb_port"])))
end

function shutdown_request(socket, msg)
    send_ipython(requests[], msg_reply(msg, "shutdown_reply",
                                     msg.content))
    sleep(0.1) # short delay (like in ipykernel), to hopefully ensure shutdown_reply is sent
    exit()
end

docdict(s::AbstractString) = display_dict(Core.eval(Main, helpmode(devnull, s)))

import Base: is_id_char, is_id_start_char
function get_token(code, pos)
    # given a string and a cursor position, find substring to request
    # help on by:
    #   1) searching backwards, skipping invalid identifier chars
    #        ... search forward for end of identifier
    #   2) search backwards to find the biggest identifier (including .)
    #   3) if nothing found, do return empty string
    # TODO: detect operators?

    startpos = pos
    while startpos > firstindex(code)
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
        return ""
    end
    while endpos < lastindex(code) && is_id_char(code[endpos])
        endpos = nextind(code, endpos)
    end
    if !is_id_char(code[endpos])
        endpos = prevind(code, endpos)
    end
    return code[startpos:endpos]
end

function inspect_request(socket, msg)
    try
        code = msg.content["code"]
        s = get_token(code, chr2ind(msg, code, msg.content["cursor_pos"]))
        if isempty(s)
            content = Dict("status" => "ok", "found" => false)
        else
            d = docdict(s)
            content = Dict("status" => "ok",
                           "found" => !isempty(d),
                           "data" => d)
        end
        send_ipython(requests[], msg_reply(msg, "inspect_reply", content))
    catch e
        content = error_content(e, backtrace_top=:inspect_request);
        content["status"] = "error"
        send_ipython(requests[],
                     msg_reply(msg, "inspect_reply", content))
    end
end

function history_request(socket, msg)
    # we will just send back empty history for now, pending clarification
    # as requested in ipython/ipython#3806
    send_ipython(requests[],
                 msg_reply(msg, "history_reply",
                           Dict("history" => [])))
end

function is_complete_request(socket, msg)
    ex = Meta.parse(msg.content["code"], raise=false)
    status = Meta.isexpr(ex, :incomplete) ? "incomplete" : Meta.isexpr(ex, :error) ? "invalid" : "complete"
    send_ipython(requests[],
                 msg_reply(msg, "is_complete_reply",
                           Dict("status"=>status, "indent"=>"")))
end

function interrupt_request(socket, msg)
    @async Base.throwto(requests_task[], InterruptException())
    send_ipython(requests[], msg_reply(msg, "interrupt_reply", Dict()))
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
