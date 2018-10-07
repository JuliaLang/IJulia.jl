using Test

import IJulia: helpmode, error_content, docdict

content = error_content(UndefVarError(:a))
@test "UndefVarError" == content["ename"]

@test haskey(docdict("import"), "text/plain")
@test haskey(docdict("sum"), "text/plain")

@testset "Custom MIME types" begin
    FRIENDLY_MIME_TYPE = MIME"application/vnd.ijulia.friendly"
    FRIENDLY_MIME = FRIENDLY_MIME_TYPE()
    Base.show(io, ::FRIENDLY_MIME_TYPE, x::AbstractString) = write(io, "hello, $x")
    IJulia.register_ijulia_mime(FRIENDLY_MIME())
    data = IJulia.display_dict("world")
    @test data[string(FRIENDLY_MIME)] == "hello, world"
end
