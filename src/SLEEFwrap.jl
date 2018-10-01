module SLEEFwrap

using SIMD
import jBLAS: REGISTER_SIZE


const __m128d = Vec{ 2, Float64}
const __m128  = Vec{ 4, Float32}
const __m256d = Vec{ 4, Float64}
const __m256  = Vec{ 8, Float32}
const __m512d = Vec{ 8, Float64}
const __m512  = Vec{16, Float64}

include("vector_sizes.jl")

const PREFIX = :Sleef_
# const BASE_ACCURACIES = [
#     :_u10,
#     :_u35
# ]


# pattern is SLEEF name, Julia name
const UNARY_OUT_FUNCTIONS = [
    (:sin,:sin),
    (:sinpi,:sinpi),
    (:cos,:cos),
    (:cospi,:cospi),
    (:tan,:tan),
    (:log,:log),
    (:log10,:log10),
    (:log2,:log2),
    (:log1p,:log1p),
    (:exp,:exp),
    (:exp2,:exp2),
    (:exp10,:exp10),
    (:expm1,:expm1),
    (:cbrt,:cbrt),
    (:asin,:asin),
    (:acos,:acos),
    (:atan,:atan),
    (:sinh,:sinh),
    (:cosh,:cosh),
    (:tanh,:tanh),
    (:asinh,:asinh),
    (:acosh,:acosh),
    (:atanh,:atanh),

]
const UNARY_SPECIFIC_ACCURACIES = [
    (:erf,:erf,:_u10)
    (:erfc,:erfc,:_u15)
    (:tgamma,:gamma,:_u10),
    (:lgamma,:lgamma,:_u10)
]
const UNARY_NO_ERROR_TERM = [
    (:sqrt,:sqrt),
    (:trunc,:trunc),
    (:floor,:floor),
    (:ceil,:ceil),
    (:fabs,:abs)
]
const BINARY_OUT_FUNCTIONS = [
    (:sincos,:sincos),
    (:sincospi,:sincospi)
]
const BINARY_OUT_NO_ERROR_TERM = [
    (:modf,:modf)
]
# const BINARY_IN_FUNCTIONS = [
#     :pow,
# ]
const BINARY_IN_FUNCTIONS = [
    (:pow, :pow, :_u10),
    (:atan2, :atan, :_u10),
    (:atan2, :atan, :_u35),
    (:hypot,:hypot, :_05),
    (:hypot,:hypot, :_35),
    (:fmod,:mod, Symbol()),
    (:copysign,:copysign, Symbol())
]

## Special cases: :round, :rint, :ldexp
for (type, func_suffix, suffix) ∈ SIZES
    for (SLEEF_name,Julia_name) ∈ UNARY_OUT_FUNCTIONS
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, :_u10, suffix)
        @eval function ($Julia_name)(a::($type))
            ccall(($func_name, libsleef), $type, ($type,), a)
        end
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, :_u35, suffix)
        @eval function ($(Symbol(Julia_name,:_fast))(a::($type))
            ccall(($func_name, libsleef), $type, ($type,), a)
        end
    end

    for (SLEEF_name,Julia_name,accuracy) ∈ UNARY_SPECIFIC_ACCURACIES
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix)
        @eval function ($Julia_name)(a::($type))
            ccall(($func_name, libsleef), $type, ($type,), a)
        end
    end

    for (SLEEF_name,Julia_name) ∈ UNARY_NO_ERROR_TERM
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, suffix)
        @eval function ($Julia_name)(a::($type))
            ccall(($func_name, libsleef), $type, ($type,), a)
        end
    end

    for (SLEEF_name,Julia_name) ∈ BINARY_OUT_FUNCTIONS
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, :_u10, suffix)
        @eval function ($Julia_name)(a::($type))
            ccall(($func_name, libsleef), $(Tuple{type,type}), ($type,), a)
        end
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, :_u35, suffix)
        @eval function ($(Symbol(Julia_name,:_fast))(a::($type))
            ccall(($func_name, libsleef), $(Tuple{type,type}), ($type,), a)
        end
    end

    for (SLEEF_name,Julia_name) ∈ BINARY_OUT_NO_ERROR_TERM
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, suffix)
        @eval function ($Julia_name)(a::($type))
            ccall(($func_name, libsleef), $(Tuple{type,type}), ($type,), a)
        end
    end

    for (SLEEF_name,Julia_name,accuracy) ∈ BINARY_IN_FUNCTIONS
        func_name = Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix)
        @eval function ($Julia_name)(a::($type))
            ccall(($func_name, libsleef), $type, ($type,$type), a)
        end
    end
end



end # module
