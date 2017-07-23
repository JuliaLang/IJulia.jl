using Base.Test

import IJulia: helpcode, error_content

@test !haskey(Docs.keywords, :+)
@test "Base.Docs.@repl +" == helpcode("+")

@test haskey(Docs.keywords, :import)
@test """eval(:(Base.Docs.@repl \$(Symbol("import"))))""" == helpcode("import")

content = error_content(UndefVarError(:a))
@test "UndefVarError" == content["ename"]

@test haskey(IJulia.docdict("sum"), "text/plain")
