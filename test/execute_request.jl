using Test
using Base64, JSON

import IJulia
import IJulia: helpmode, error_content, docdict

content = error_content(UndefVarError(:a))
@test "UndefVarError" == content["ename"]

@test haskey(docdict("import"), "text/plain")
@test haskey(docdict("sum"), "text/plain")

struct FriendlyData
    name::AbstractString
end

@testset "Custom MIME types" begin
    friend = FriendlyData("world")

    FRIENDLY_MIME_TYPE = MIME"application/vnd.ijulia.friendly-text"
    FRIENDLY_MIME = FRIENDLY_MIME_TYPE()
    Base.Multimedia.istextmime(::FRIENDLY_MIME_TYPE) = true
    Base.show(io, ::FRIENDLY_MIME_TYPE, x::FriendlyData) = write(io, "Hello, $(x.name)!")
    IJulia.register_mime(FRIENDLY_MIME)

    BINARY_MIME_TYPE = MIME"application/vnd.ijulia.friendly-binary"
    BINARY_MIME = BINARY_MIME_TYPE()
    Base.Multimedia.istextmime(::BINARY_MIME_TYPE) = false
    Base.show(io, ::BINARY_MIME_TYPE, x::FriendlyData) = write(io, "Hello, $(x.name)!")
    IJulia.register_mime(BINARY_MIME)

    JSON_MIME_TYPE = MIME"application/vnd.ijulia.friendly-json"
    JSON_MIME = JSON_MIME_TYPE()
    Base.Multimedia.istextmime(::JSON_MIME_TYPE) = true
    Base.show(io, ::JSON_MIME_TYPE, x::FriendlyData) = write(io, JSON.json(Dict("name" => x.name)))
    IJulia.register_jsonmime(JSON_MIME)

    FRIENDLY_MIME_TYPE_1 = MIME"application/vnd.ijulia.friendly-text-1"
    FRIENDLY_MIME_TYPE_2 = MIME"application/vnd.ijulia.friendly-text-2"
    FRIENDLY_MIME_1 = FRIENDLY_MIME_TYPE_1()
    FRIENDLY_MIME_2 = FRIENDLY_MIME_TYPE_2()
    FRIENDLY_MIME_TYPE_UNION = Union{FRIENDLY_MIME_TYPE_1, FRIENDLY_MIME_TYPE_2}
    Base.Multimedia.istextmime(::FRIENDLY_MIME_TYPE_UNION) = true
    Base.show(io, ::FRIENDLY_MIME_TYPE_UNION, x::FriendlyData) = write(io, "Hello, $(x.name)!")
    IJulia.register_mime([FRIENDLY_MIME_1, FRIENDLY_MIME_2])

    # We stringify then re-parse the dict so that JSONText's are parsed as
    # actual JSON objects and we can index into them.
    data = JSON.parse(JSON.json(IJulia.display_dict(friend)))
    @test data[string(FRIENDLY_MIME)] == "Hello, world!"
    @test data[string(BINARY_MIME)] == base64encode("Hello, world!")
    @test data[string(JSON_MIME)]["name"] == "world"
    @test data[string(FRIENDLY_MIME_1)] == "Hello, world!"
    @test !haskey(data, string(FRIENDLY_MIME_2))


end
