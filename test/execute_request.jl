using Base.Test

import IJulia: helpcode, error_content

@test !haskey(Docs.keywords, :+)
@test "Base.Docs.@repl +" == helpcode("+")

@test haskey(Docs.keywords, :import)
if VERSION < v"0.5.0-dev+3831"
    @test """eval(:(Base.Docs.@repl \$(symbol("import"))))""" == helpcode("import")
else
    @test """eval(:(Base.Docs.@repl \$(Symbol("import"))))""" == helpcode("import")
end

content = error_content(UndefVarError(:a))
@test "UndefVarError" == content["ename"]

@test haskey(IJulia.docdict("sum"), "text/plain")
