module SLEEFwrap

const Vec{N, T} = NTuple{N,Core.VecElement{T}}

const __m128d = Vec{ 2, Float64}
const __m128  = Vec{ 4, Float32}
const __m256d = Vec{ 4, Float64}
const __m256  = Vec{ 8, Float32}
const __m512d = Vec{ 8, Float64}
const __m512  = Vec{16, Float32}

include(joinpath("..", "deps", "deps.jl"))
include("vector_sizes.jl")

const PREFIX = :Sleef_

# pattern is SLEEF name, Julia name, accuracy
const UNARY_OUT_FUNCTIONS = [
    (:sin,:sin,:_u10),
    (:sin,:sin_fast,:_u35),
    (:sinpi,:sinpi,:_u05),
    (:sinpi,:sinpi_fast,:_u35),
    (:cos,:cos,:_u10),
    (:cos,:cos_fast,:_u35),
    (:cospi,:cospi,:_u05),
    (:cospi,:cospi_fast,:_u35),
    (:tan,:tan,:_u10),
    (:tan,:tan_fast,:_u35),
    (:log,:log,:_u10),
    (:log,:log_fast,:_u35),
    (:log10,:log10,:_u10),
    (:log2,:log2,:_u10),
    (:log1p,:log1p,:_u10),
    (:exp,:exp,:_u10),
    (:exp2,:exp2,:_u10),
    (:exp10,:exp10,:_u10),
    (:expm1,:expm1,:_u10),
    (:sqrt,:sqrt,:_),
    (:sqrt,:sqrt_fast,:_u35),
    (:cbrt,:cbrt,:_u10),
    (:cbrt,:cbrt_fast,:_u35),
    (:asin,:asin,:_u10),
    (:asin,:asin_fast,:_u35),
    (:acos,:acos,:_u10),
    (:acos,:acos_fast,:_u35),
    (:atan,:atan,:_u10),
    (:atan,:atan_fast,:_u35),
    (:sinh,:sinh,:_u10),
    (:sinh,:sinh_fast,:_u35),
    (:cosh,:cosh,:_u10),
    (:cosh,:cosh_fast,:_u35),
    (:tanh,:tanh,:_u10),
    (:tanh,:tanh_fast,:_u35),
    (:asinh,:asinh,:_u10),
    (:acosh,:acosh,:_u10),
    (:atanh,:atanh,:_u10),
    (:erf,:erf,:_u10),
    (:erfc,:erfc,:_u15),
    (:tgamma,:gamma,:_u10),
    (:lgamma,:lgamma,:_u10),
    (:trunc,:trunc,:_),
    (:floor,:floor,:_),
    (:ceil,:ceil,:_),
    (:fabs,:abs,:_)
]

const BINARY_OUT_FUNCTIONS = [
    (:sincos,:sincos,:_u10),
    (:sincos,:sincos_fast,:_u35),
    (:sincospi,:sincospi,:_u05),
    (:sincospi,:sincospi_fast,:_u35),
    (:modf,:modf,:_)
]
const BINARY_IN_FUNCTIONS = [
    (:pow, :pow, :_u10),
    (:atan2, :atan, :_u10),
    (:atan2, :atan_fast, :_u35),
    (:hypot,:hypot, :_05),
    (:hypot,:hypot_fast, :_35),
    (:fmod,:mod, :_),
    (:copysign,:copysign, :_)
]

## Special cases: :round, :rint, :ldexp
for (vectype, func_suffix, suffix) ∈ SIZES
    for (SLEEF_name,Julia_name,accuracy) ∈ UNARY_OUT_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        @eval function ($Julia_name)(a::($vectype))
            ccall(($func_name, libsleef), $vectype, ($vectype,), a)
        end
    end

    for (SLEEF_name,Julia_name,accuracy) ∈ BINARY_OUT_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        @eval function ($Julia_name)(a::($vectype))
            ccall(($func_name, libsleef), $(Tuple{vectype,vectype}), ($vectype,), a)
        end
    end

    for (SLEEF_name,Julia_name,accuracy) ∈ BINARY_IN_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        @eval function ($Julia_name)(a::($vectype), b::($vectype))
            ccall(($func_name, libsleef), $vectype, ($vectype,$vectype), a, b)
        end
    end
end



end # module
