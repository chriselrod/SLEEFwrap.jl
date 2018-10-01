module SLEEFwrap

using SIMD


const __m128d, m128d = NTuple{2, Core.VecElement{Float64}}, Vec{ 2, Float64}
const __m128,  m128  = NTuple{4, Core.VecElement{Float32}}, Vec{ 4, Float32}
const __m256d, m256d = NTuple{4, Core.VecElement{Float64}}, Vec{ 4, Float64}
const __m256,  m256  = NTuple{8, Core.VecElement{Float32}}, Vec{ 8, Float32}
const __m512d, m512d = NTuple{8, Core.VecElement{Float64}}, Vec{ 8, Float64}
const __m512,  m512  = NTuple{16,Core.VecElement{Float32}}, Vec{16, Float32}

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
    (:sqrt,:sqrt,Symbol()),
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
    (:trunc,:trunc,Symbol()),
    (:floor,:floor,Symbol()),
    (:ceil,:ceil,Symbol()),
    (:fabs,:abs,Symbol())
]

const BINARY_OUT_FUNCTIONS = [
    (:sincos,:sincos,:_u10),
    (:sincos,:sincos_fast,:_u35),
    (:sincospi,:sincospi,:_u05),
    (:sincospi,:sincospi_fast,:_u35),
    (:modf,:modf,Symbol())
]
const BINARY_IN_FUNCTIONS = [
    (:pow, :pow, :_u10),
    (:atan2, :atan, :_u10),
    (:atan2, :atan_fast, :_u35),
    (:hypot,:hypot, :_05),
    (:hypot,:hypot_fast, :_35),
    (:fmod,:mod, Symbol()),
    (:copysign,:copysign, Symbol())
]

## Special cases: :round, :rint, :ldexp
for (coretype, vectype, func_suffix, suffix) ∈ SIZES
    for (SLEEF_name,Julia_name,accuracy) ∈ UNARY_OUT_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        if coretype != vectype
            @eval function ($Julia_name)(a::($vectype))
                $(vectype)(ccall(($func_name, libsleef), $coretype, ($coretype,), a))
                # $(vectype)(($Julia_name)(a.elts))
            end
        end
        @eval function ($Julia_name)(a::($coretype))
            ccall(($func_name, libsleef), $coretype, ($coretype,), a)
        end
    end

    for (SLEEF_name,Julia_name,accuracy) ∈ BINARY_OUT_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        if coretype != vectype
            @eval function ($Julia_name)(a::($vectype))
                s, c = ccall(($func_name, libsleef), $(Tuple{coretype,coretype}), ($coretype,), a.elts)
                $(vectype)(s), $(vectype)(c)
            end
        end
        @eval function ($Julia_name)(a::($coretype))
            ccall(($func_name, libsleef), $(Tuple{coretype,coretype}), ($coretype,), a)
        end
    end

    for (SLEEF_name,Julia_name,accuracy) ∈ BINARY_IN_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        if coretype != vectype
            @eval function ($Julia_name)(a::($vectype), b::($vectype))
                $(vectype)(ccall(($func_name, libsleef), $coretype, ($coretype,$coretype), a, b))
                # $(vectype)(($Julia_name)(a.elts, b.elts))
            end
        end
        @eval function ($Julia_name)(a::($coretype), b::($coretype))
            ccall(($func_name, libsleef), $coretype, ($coretype,$coretype), a, b)
        end
    end
end



end # module
