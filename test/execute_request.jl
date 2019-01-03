using Test
using Base64, JSON

import IJulia
import IJulia: helpmode, error_content, docdict

@testset "errors" begin
    content = error_content(UndefVarError(:a))
    @test "UndefVarError" == content["ename"]
end

@testset "docdict" begin
    @test haskey(docdict("import"), "text/plain")
    @test haskey(docdict("sum"), "text/plain")
end

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

struct AngryData
    thing::AbstractString
end

@testset "Render 1st available MIME in MIME-vector." begin
    ANGRY_MIME_TYPE_1 = MIME"application/vnd.ijulia.angry-1"
    ANGRY_MIME_1 = ANGRY_MIME_TYPE_1()
    ANGRY_MIME_TYPE_2 = MIME"application/vnd.ijulia.angry-2"
    ANGRY_MIME_2 = ANGRY_MIME_TYPE_2()
    ANGRY_MIME_TYPE_3 = MIME"application/vnd.ijulia.angry-3"
    ANGRY_MIME_3 = ANGRY_MIME_TYPE_3()
    ANGRY_MIME_VECTOR = [ANGRY_MIME_1, ANGRY_MIME_2, ANGRY_MIME_3]

    Base.Multimedia.istextmime(::Union{ANGRY_MIME_TYPE_1, ANGRY_MIME_TYPE_2, ANGRY_MIME_TYPE_3}) = true
    Base.show(io, ::Union{ANGRY_MIME_TYPE_2, ANGRY_MIME_TYPE_3}, x::AngryData) = write(io, "I hate $(x.thing)!")
    IJulia.register_mime(ANGRY_MIME_VECTOR)

    broccoli = AngryData("broccoli")
    @test IJulia._showable(ANGRY_MIME_VECTOR, broccoli)
    @test !IJulia._showable(ANGRY_MIME_1, broccoli)

    data = IJulia.display_dict(broccoli)
    @test data[string(ANGRY_MIME_2)] == "I hate broccoli!"
    @test !haskey(data, ANGRY_MIME_1)
    @test !haskey(data, ANGRY_MIME_3)
end
