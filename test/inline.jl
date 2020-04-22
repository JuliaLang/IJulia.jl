using Test
import IJulia: InlineIOContext, png_wh

@testset "Custom Jupyter inline display" begin
    @eval struct TestDataType
        payload
    end

    function Base.show(io::IO, m::MIME"text/plain", data::TestDataType)
        print(io, "TestDataType: ")
        if get(io, :jupyter, false)
            print(io, "Jupyter: ")
        end
        Base.show(io, m, data.payload)
    end

    data = TestDataType("foo")
    buf = IOBuffer()

    Base.show(buf, MIME("text/plain"), data)
    @test String(take!(buf)) == "TestDataType: \"foo\""

    Base.show(InlineIOContext(buf), MIME("text/plain"), data)
    @test String(take!(buf)) == "TestDataType: Jupyter: \"foo\""

    # test that we can extract a PNG header
    @test png_wh(
        "iVBORw0KGgoAAAANSUhEUgAAAAUAAAAMCAYAAACqYHctAAAAE0lEQVR42mNk+P"
        * "+/ngENMI4MQQCgfR3py/xS9AAAAABJRU5ErkJggg==") == (5,12)
    @test png_wh(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x"
        * "8AAwMCAO+ip1sAAAAASUVORK5CYII=") == (1,1)
end
