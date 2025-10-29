# Copied from:
# https://github.com/JuliaIO/JSON.jl/tree/b2787c38d18aa5a6828eefabc8d4f4726e1c09e7/vendor

# Tests for JSONX module
using Test

# Include the JSONX module
import IJulia: JSONX

@testset "JSONX Tests" begin
    @testset "Basic Types" begin
        # Test null
        @test JSONX.parse("null") === nothing
        # Test booleans
        @test JSONX.parse("true") === true
        @test JSONX.parse("false") === false
        # Test integers (return Int64)
        @test JSONX.parse("0") === Int64(0)
        @test JSONX.parse("123") === Int64(123)
        @test JSONX.parse("-123") === Int64(-123)
        # Test floats (return Float64)
        @test JSONX.parse("3.14") == 3.14
        @test JSONX.parse("-3.14") == -3.14
        @test JSONX.parse("1e2") == 100.0
        @test JSONX.parse("1E2") == 100.0
        @test JSONX.parse("1.5e-2") == 0.015
        # Test strings
        @test JSONX.parse("\"hello\"") == "hello"
        @test JSONX.parse("\"\"") == ""
        @test JSONX.parse("\"\\\"quoted\\\"\"") == "\"quoted\""
        @test JSONX.parse("\"\\\\backslash\\\\\"") == "\\backslash\\"
        @test JSONX.parse("\"\\n\\t\\r\\b\\f\"") == "\n\t\r\b\f"
    end

    @testset "Integer vs Float Parsing" begin
        # Integers without decimal/exponent -> Int64
        @test JSONX.parse("42") === Int64(42)
        @test JSONX.parse("-100") === Int64(-100)
        @test JSONX.parse("0") === Int64(0)

        # Numbers with decimal point -> Float64
        @test JSONX.parse("42.0") === 42.0
        @test JSONX.parse("1.5") === 1.5

        # Numbers with exponent -> Float64
        @test JSONX.parse("1e10") === 1e10
        @test JSONX.parse("1E5") === 1e5
        @test JSONX.parse("2.5e3") === 2500.0
        @test JSONX.parse("1e10") isa Float64

        # Int64 overflow fallback to Float64
        @test JSONX.parse("99999999999999999999") == 1e20

        # Negative overflow
        @test JSONX.parse("-99999999999999999999") == -1e20

        # Edge case: numbers at Int64 boundary
        @test JSONX.parse(string(typemax(Int64))) === typemax(Int64)
        @test JSONX.parse(string(typemin(Int64))) === typemin(Int64)
    end
    
    @testset "Arrays" begin
        # Test empty array
        @test JSONX.parse("[]") == []
        # Test simple arrays
        @test JSONX.parse("[1,2,3]") == [1, 2, 3]
        @test JSONX.parse("[\"a\",\"b\",\"c\"]") == ["a", "b", "c"]
        @test JSONX.parse("[true,false,null]") == [true, false, nothing]
        # Test nested arrays
        @test JSONX.parse("[[1,2],[3,4]]") == [[1, 2], [3, 4]]
        @test JSONX.parse("[1,[2,3],4]") == [1, [2, 3], 4]
        # Test mixed types
        @test JSONX.parse("[1,\"two\",3.0,true,null]") == [1, "two", 3.0, true, nothing]
    end
    
    @testset "Objects" begin
        # Test empty object
        @test JSONX.parse("{}") == Dict{String, Any}()
        # Test simple objects
        @test JSONX.parse("{\"key\":\"value\"}") == Dict("key" => "value")
        @test JSONX.parse("{\"a\":1,\"b\":2}") == Dict("a" => 1, "b" => 2)
        # Test nested objects
        @test JSONX.parse("{\"a\":{\"b\":\"c\"}}") == Dict("a" => Dict("b" => "c"))
        @test JSONX.parse("{\"a\":[1,2,3]}") == Dict("a" => [1, 2, 3])
        # Test mixed types
        @test JSONX.parse("{\"str\":\"hello\",\"num\":123,\"bool\":true,\"null\":null}") ==
              Dict("str" => "hello", "num" => 123, "bool" => true, "null" => nothing)
    end
    
    @testset "Whitespace Handling" begin
        # Test various whitespace
        @test JSONX.parse("  null  ") === nothing
        @test JSONX.parse("\t\n\r null \t\n\r") === nothing
        @test JSONX.parse("[ 1 , 2 , 3 ]") == [1, 2, 3]
        @test JSONX.parse("{ \"key\" : \"value\" }") == Dict("key" => "value")
    end
    
    @testset "Error Cases" begin
        # Test invalid JSON
        @test_throws ArgumentError JSONX.parse("")
        @test_throws ArgumentError JSONX.parse("   ")
        @test_throws ArgumentError JSONX.parse("invalid")
        @test_throws ArgumentError JSONX.parse("nul")
        @test_throws ArgumentError JSONX.parse("tru")
        @test_throws ArgumentError JSONX.parse("fals")
        # Test incomplete structures
        @test_throws ArgumentError JSONX.parse("[1,2,")
        @test_throws ArgumentError JSONX.parse("{\"key\":")
        @test_throws ArgumentError JSONX.parse("\"unterminated")
        @test_throws ArgumentError JSONX.parse("123abc")
        # Test invalid escape sequences
        @test_throws ArgumentError JSONX.parse("\"\\x\"")
        @test_throws ArgumentError JSONX.parse("\"\\u123\"")
    end
    
    @testset "JSON Writing" begin
        # Test basic types
        @test JSONX.json(nothing) == "null"
        @test JSONX.json(true) == "true"
        @test JSONX.json(false) == "false"
        @test JSONX.json(123) == "123"
        @test JSONX.json(3.14) == "3.14"
        @test JSONX.json("hello") == "\"hello\""
        @test JSONX.json(missing) == "null"
        # Test arrays
        @test JSONX.json([]) == "[]"
        @test JSONX.json([1, 2, 3]) == "[1,2,3]"
        @test JSONX.json(["a", "b", "c"]) == "[\"a\",\"b\",\"c\"]"
        @test JSONX.json([1, "two", 3.0, true, nothing]) == "[1,\"two\",3.0,true,null]"
        # Test objects
        @test JSONX.json(Dict{String, Any}()) == "{}"
        @test JSONX.json(Dict("key" => "value")) == "{\"key\":\"value\"}"
        # Note: Dictionary order is not guaranteed, so we parse and compare
        @test JSONX.parse(JSONX.json(Dict("a" => 1, "b" => 2))) == Dict("a" => 1, "b" => 2)
        # Test nested structures
        @test JSONX.json(Dict("a" => Dict("b" => "c"))) == "{\"a\":{\"b\":\"c\"}}"
        @test JSONX.json(Dict("a" => [1, 2, 3])) == "{\"a\":[1,2,3]}"
        # Test other types
        @test JSONX.json(:symbol) == "\"symbol\""
        @test JSONX.json((1, 2, 3)) == "[1,2,3]"
        # Note: NamedTuple order is not guaranteed, so we parse and compare
        @test JSONX.parse(JSONX.json((a=1, b=2))) == Dict("a" => 1, "b" => 2)
        # Test JSONText
        @test JSONX.json(JSONX.JSONText("{\"x\": invalid json}")) == "{\"x\": invalid json}"
    end
    
    @testset "AbstractSet Support" begin
        # Test Set types
        @test JSONX.json(Set([1, 2, 3])) == "[1,2,3]" || JSONX.json(Set([1, 2, 3])) == "[1,3,2]" || JSONX.json(Set([1, 2, 3])) == "[2,1,3]" || JSONX.json(Set([1, 2, 3])) == "[2,3,1]" || JSONX.json(Set([1, 2, 3])) == "[3,1,2]" || JSONX.json(Set([1, 2, 3])) == "[3,2,1]"
        @test JSONX.json(Set(["a", "b", "c"])) == "[\"a\",\"b\",\"c\"]" || JSONX.json(Set(["a", "b", "c"])) == "[\"a\",\"c\",\"b\"]" || JSONX.json(Set(["a", "b", "c"])) == "[\"b\",\"a\",\"c\"]" || JSONX.json(Set(["a", "b", "c"])) == "[\"b\",\"c\",\"a\"]" || JSONX.json(Set(["a", "b", "c"])) == "[\"c\",\"a\",\"b\"]" || JSONX.json(Set(["a", "b", "c"])) == "[\"c\",\"b\",\"a\"]"
        # Test round trip for Set
        set_data = Set([1, "two", 3.0, true])
        json_str = JSONX.json(set_data)
        parsed = JSONX.parse(json_str)
        @test Set(parsed) == set_data
    end
    
    @testset "String Escaping" begin
        # Test string escaping in writing
        @test JSONX.json("\"quoted\"") == "\"\\\"quoted\\\"\""
        @test JSONX.json("\\backslash\\") == "\"\\\\backslash\\\\\""
        @test JSONX.json("line1\nline2") == "\"line1\\nline2\""
        @test JSONX.json("tab\there") == "\"tab\\there\""
        @test JSONX.json("carriage\rreturn") == "\"carriage\\rreturn\""
        @test JSONX.json("backspace\bhere") == "\"backspace\\bhere\""
        @test JSONX.json("form\ffeed") == "\"form\\ffeed\""
        # Test control characters
        @test JSONX.json("control\x01char") == "\"control\\u0001char\""
    end
    
    @testset "Round Trip" begin
        # Test that parse(json(x)) == x for various types
        test_cases = [
            nothing,
            true,
            false,
            0,
            123,
            -123,
            3.14,
            -3.14,
            "",
            "hello",
            "quoted \"string\"",
            [],
            [1, 2, 3],
            ["a", "b", "c"],
            [1, "mixed", 3.0, true, nothing],
            Dict{String, Any}(),
            Dict("key" => "value"),
            Dict("a" => 1, "b" => 2),
            Dict("nested" => Dict("key" => "value")),
            Dict("array" => [1, 2, 3]),
        ]

        for case in test_cases
            json_str = JSONX.json(case)
            parsed = JSONX.parse(json_str)
            @test parsed == case
        end
    end
    
    @testset "Edge Cases" begin
        # Test very large numbers
        @test JSONX.parse("1234567890123456789") === 1234567890123456789
        @test JSONX.parse("1.234567890123456789") == 1.234567890123456789
        # Test scientific notation
        @test JSONX.parse("1e10") == 1e10
        @test JSONX.parse("1E-10") == 1e-10
        @test JSONX.parse("1.5e+5") == 1.5e5
        # Test empty strings and arrays
        @test JSONX.parse("\"\"") == ""
        @test JSONX.parse("[]") == []
        @test JSONX.parse("{}") == Dict{String, Any}()
        # Test nested structures
        complex_json = """
        {
            "name": "John",
            "age": 30,
            "active": true,
            "scores": [85, 92, 78],
            "address": {
                "street": "123 Main St",
                "city": "Anytown"
            },
            "tags": ["developer", "programmer"],
            "metadata": null
        }
        """
        expected = Dict(
            "name" => "John",
            "age" => 30,
            "active" => true,
            "scores" => [85, 92, 78],
            "address" => Dict("street" => "123 Main St", "city" => "Anytown"),
            "tags" => ["developer", "programmer"],
            "metadata" => nothing
        )
        @test JSONX.parse(complex_json) == expected
    end
    
    @testset "Error Handling" begin
        # Test writing unsupported types
        @test_throws ArgumentError JSONX.json(Complex(1, 2))
        # Test malformed JSON
        @test_throws ArgumentError JSONX.parse("[1,2,]")
        @test_throws ArgumentError JSONX.parse("{\"key\":}")
        @test_throws ArgumentError JSONX.parse("{\"key\"}")
        @test_throws ArgumentError JSONX.parse("[1,2,3")
        @test_throws ArgumentError JSONX.parse("{\"key\":\"value\"")
    end

    @testset "AbstractVector{UInt8} Support" begin
        @test JSONX.parse(Vector{UInt8}("null")) === nothing
        @test JSONX.parse(Vector{UInt8}("42")) === Int64(42)
        @test JSONX.parse(Vector{UInt8}("\"hello\"")) == "hello"
        @test JSONX.parse(Vector{UInt8}("[1,2,3]")) == [1, 2, 3]
        @test JSONX.parse(Vector{UInt8}("{\"a\":1}")) == Dict("a" => 1)
    end

    @testset "Unicode Handling" begin
        # Basic Unicode escapes
        @test JSONX.parse("\"\\u0041\"") == "A"
        @test JSONX.parse("\"\\u0048\\u0065\\u006C\\u006C\\u006F\"") == "Hello"
        # Surrogate pairs
        @test JSONX.parse("\"\\uD83D\\uDE00\"") == "😀"  # Grinning face emoji
        @test JSONX.parse("\"\\uD83C\\uDF55\"") == "🍕"  # Pizza emoji
        # Mixed content
        @test JSONX.parse("\"Hello \\u0041\\u006E\\u0064\\u0072\\u0065\\u0077!\"") == "Hello Andrew!"
        # String unescaping
        @test JSONX.parse(raw"\"𝔸\\a\"") == "𝔸\\a"
        # Writing Unicode
        @test JSONX.json("A") == "\"A\""
        @test JSONX.json("😀") == "\"😀\""
        @test JSONX.json("Hello Andrew!") == "\"Hello Andrew!\""
    end

    @testset "Escape Sequences" begin
        @test JSONX.parse("\"\\\"\"") == "\""
        @test JSONX.parse("\"\\\\\"") == "\\"
        @test JSONX.parse("\"\\/\"") == "/"
        @test JSONX.parse("\"\\b\"") == "\b"
        @test JSONX.parse("\"\\f\"") == "\f"
        @test JSONX.parse("\"\\n\"") == "\n"
        @test JSONX.parse("\"\\r\"") == "\r"
        @test JSONX.parse("\"\\t\"") == "\t"
        # Writing escape sequences
        @test JSONX.json("\"") == "\"\\\"\""
        @test JSONX.json("\\") == "\"\\\\\""
        @test JSONX.json("/") == "\"/\""
        @test JSONX.json("\b") == "\"\\b\""
        @test JSONX.json("\f") == "\"\\f\""
        @test JSONX.json("\n") == "\"\\n\""
        @test JSONX.json("\r") == "\"\\r\""
        @test JSONX.json("\t") == "\"\\t\""
    end

    @testset "Error Cases for Unicode" begin
        @test_throws ArgumentError JSONX.parse("\"\\u\"")  # Incomplete Unicode escape
        @test_throws ArgumentError JSONX.parse("\"\\u123\"")  # Incomplete Unicode escape
        @test_throws ArgumentError JSONX.parse("\"\\u123G\"")  # Invalid hex digit
        @test length(JSONX.parse("\"\\uD83D\"")) == 1  # Lone surrogate produces a character
        @test_throws ArgumentError JSONX.parse("\"\\uD83D\\u\"")  # Incomplete surrogate pair
        @test_throws ArgumentError JSONX.parse("\"\\uD83D\\u123G\"")  # Invalid hex in surrogate pair
    end

    @testset "Complex Unicode Round-trip" begin
        # Test complex Unicode content
        unicode_text = "Hello 世界! 🌍 こんにちは! Привет! مرحبا!"
        json_str = JSONX.json(unicode_text)
        parsed = JSONX.parse(json_str)
        @test parsed == unicode_text
        # Test with simple escape sequences
        mixed_text = "Hello\nWorld\tTest\rSimple"
        json_str = JSONX.json(mixed_text)
        parsed = JSONX.parse(json_str)
        @test parsed == mixed_text
    end

    @testset "File I/O" begin
        # Create a temporary file for testing
        test_file = tempname()
        try
            # Write test JSON to file
            write(test_file, "{\"test\":\"value\",\"number\":42}")
            # Test parsefile
            result = JSONX.parsefile(test_file)
            @test result == Dict("test" => "value", "number" => 42)
            # Test with Unicode content
            write(test_file, "\"Hello 世界! 🌍\"")
            result = JSONX.parsefile(test_file)
            @test result == "Hello 世界! 🌍"
        finally
            # Clean up
            isfile(test_file) && rm(test_file)
        end
    end
end

println("All JSONX tests passed!")
