using Test
import IJulia: InlineIOContext

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
end
