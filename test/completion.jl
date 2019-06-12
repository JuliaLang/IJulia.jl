using Test
import IJulia: get_token

@testset "completion tokenizer" begin
    test0_code = "x + y + z"
    test0_expected = "xxxxyyyyz"
    test0_got = map(i -> get_token(test0_code, i), eachindex(test0_code))
    @test split(test0_expected, "") == test0_got

    test1_code      = """println("Hello world")"""
    test1_expected  = "println"
    test1_got = map(i -> get_token(test1_code, i), eachindex(test1_code))
    @test all(test1_expected .== test1_got)

    test2_code      = """println("Hello world", x)"""
    test2_expected  = "println"
    test2_got = map(i -> get_token(test2_code, i), eachindex(test2_code))
    @test all(test2_expected .== test2_got)

    test3_code      = """println("Hello world", x, y)"""
    test3_expected  = "println"
    test3_got = map(i -> get_token(test3_code, i), eachindex(test3_code))
    @test all(test3_expected .== test3_got)

    test4_code      = """println("Hello world", (x, y))"""
    test4_expected  = "println"
    test4_got = map(i -> get_token(test4_code, i), eachindex(test4_code))
    @test all(test4_expected .== test4_got)

    test5_code      = """println("Hello world", (x, y, (2 + 3 - 5)))"""
    test5_expected  = "println"
    test5_got = map(i -> get_token(test5_code, i), eachindex(test5_code))
    @test all(test5_expected .== test5_got)

    # TODO These won't work in current, "hacky" implementation.
    # Current implementation treats each token separate, returning
    # "Vector", "Int", "undef", "n" respectively
    test6_code      = """Vector{Int}(undef, n)"""
    test6_expected  = "Vector"
    test6_got = map(i -> get_token(test6_code, i), eachindex(test6_code))
    @test_broken all(test6_expected .== test6_got)

    # TODO These won't work either, mostly due to the same reason
    test7_code      = """f(g(x))"""
    test7_expected  = """fffggff"""
    test7_got = map(i -> get_token(test7_code, i), eachindex(test7_code))
    @test_broken split(test7_expected, "") == test7_got

    test8_code      = """f(x, g(x))"""
    test8_expected  = """ffffffggff"""
    test8_got = map(i -> get_token(test8_code, i), eachindex(test8_code))
    @test split(test8_expected, "") == test8_got

    # Test tokenizing partial expressions
    test9_code      = """println(x,"""
    test9_expected  = """println"""
    test9_got = map(i -> get_token(test9_code, i), eachindex(test9_code))
    @test all(test9_got .== test9_expected)
end
