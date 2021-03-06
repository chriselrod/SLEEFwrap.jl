module SLEEFwrap

using SIMDPirates, VectorizationBase, SpecialFunctions, Base.FastMath, LoopVectorization
import MacroTools: @capture, postwalk, prewalk
using VectorizationBase: AbstractStructVec

export @sleef, @fastsleef, @spirate, @spiratef, @vectorize, @cvectorize

# const Vec{N, T} = NTuple{N,Core.VecElement{T}}

const __m64    = Vec{ 2, Float32}
const __m128d  = Vec{ 2, Float64}
const __m128   = Vec{ 4, Float32}
const __m256d  = Vec{ 4, Float64}
const __m256   = Vec{ 8, Float32}
const __m512d  = Vec{ 8, Float64}
const __m512   = Vec{16, Float32}
const __m1024d = Vec{16, Float64}
const __m1024  = Vec{32, Float32}

# const NEXT = Dict{DataType,DataType}(
#     Float64 => __m128d,
#     __m128d => __m256d,
#     __m256d => __m512d,
#     __m512d => __m1024d,
#     Float32 => __m64,
#     __m128  => __m256,
#     __m256  => __m512,
#     __m512  => __m1024
# )
const NEXT = Dict{DataType,DataType}(
    Float64 => NTuple{2,Float64},
    __m128d => NTuple{2,__m128d},
    __m256d => NTuple{2,__m256d},
    __m512d => __m1024d,
    Float32 => NTuple{2,Float32},
    __m128  => NTuple{2,__m128},
    __m256  => NTuple{2,__m256},
    __m512  => __m1024
)

include(joinpath("..", "deps", "deps.jl"))
include("vector_sizes.jl")
include("wrap_sleef_functions.jl")
# include("utilities.jl")
include("sleefmacro.jl")
include("vectorize_loops.jl")



end # module
