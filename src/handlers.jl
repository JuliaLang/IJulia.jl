include("comm_manager.jl")
include("execute_request.jl")

using .CommManager

# Don't send previous lines to the completions function,
# due to issue #380.  Find the start of the first line
# (if any) where the expression is parseable.  Replace
# with find_parsestart(c,p) = start(c) once julia#9467 is merged.
parseok(s) = !Meta.isexpr(parse(s, raise=false), :error)
function find_parsestart(code, cursorpos)
    s = start(code)
    while s < cursorpos
        parseok(code[s:cursorpos]) && return s
        s = nextind(code, s)
        while s < cursorpos && code[s] ∉ ('\n','\r')
            s = nextind(code, s)
        end
    end
    return start(code) # failed to find parseable lines
end

function complete_request(socket, msg)
    code = msg.content["code"]
    cursor_chr = msg.content["cursor_pos"]
    cursorpos = cursor_chr <= 0 ? 0 : chr2ind(code, cursor_chr)
    if isspace(code[1:cursorpos])
        send_ipython(requests[], msg_reply(msg, "complete_reply",
                                 Dict("status" => "ok",
                                              "matches" => String[],
                                              "cursor_start" => cursor_chr,
                                              "cursor_end" => cursor_chr)))
        return
    end

    codestart = find_parsestart(code, cursorpos)
    comps, positions = Base.REPLCompletions.completions(code[codestart:end], cursorpos-codestart+1)
    positions += codestart-1
    if isempty(positions) # true if comps to be inserted without replacement
        cursor_start = (cursor_end = ind2chr(code, last(positions)))
    else
        cursor_start = ind2chr(code, first(positions)) - 1
        cursor_end = ind2chr(code, last(positions))
    end
    send_ipython(requests[], msg_reply(msg, "complete_reply",
                                     Dict("status" => "ok",
                                                  "matches" => comps,
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
                                                              "url"=>"http://pkg.julialang.org/")
                                                        ])))
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

stripdots(ex) = :_
stripdots(ex::Symbol) = ex
stripdots(ex::Expr) = Meta.isexpr(ex, :.) ? stripdots(ex.args[2]) : :_
stripdots(ex::QuoteNode) = ex.value
stripdots(ex::GlobalRef) = ex.name
rm_sideeffects(ex) = ex
function rm_sideeffects(ex::Expr)
    if Meta.isexpr(ex, :call)
        name = stripdots(ex.args[1])
        if name == :repl_search || name == :repl_corrections
            return nothing
        else
            return ex
        end
    else
        return Expr(ex.head, map(rm_sideeffects, ex.args)...)
    end
end
function docdict(s::AbstractString)
    ex = macroexpand(parse(helpcode(s)))
    # unfortunately, the REPL help macros sometimes have
    # expressions with side effects (I/O), so we need to
    # remove these.
    display_dict(eval(Main, rm_sideeffects(ex)))
end
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
    while startpos > start(code)
        if is_id_char(code[startpos])
            break
        else
            startpos = prevind(code, startpos)
        end
    end
    endpos = startpos
    while startpos >= start(code) && (is_id_char(code[startpos]) || code[startpos] == '.')
        startpos = prevind(code, startpos)
    end
    startpos = startpos < pos ? nextind(code, startpos) : pos
    if !is_id_start_char(code[startpos])
        return ""
    end
    while endpos < endof(code) && is_id_char(code[endpos])
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
        s = get_token(code, chr2ind(code, msg.content["cursor_pos"]))
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
    ex = parse(msg.content["code"], raise=false)
    status = Meta.isexpr(ex, :incomplete) ? "incomplete" : Meta.isexpr(ex, :error) ? "invalid" : "complete"
    send_ipython(requests[],
                 msg_reply(msg, "is_complete_reply",
                           Dict("status"=>status, "indent"=>"")))
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
    "comm_open" => comm_open,
    "comm_info_request" => comm_info_request,
    "comm_msg" => comm_msg,
    "comm_close" => comm_close
)
