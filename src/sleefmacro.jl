const SLEEFDict = Dict{Symbol,Symbol}(
    :sin => :sin,
    :sinpi => :sinpi,
    :cos => :cos,
    :cospi => :cospi,
    :tan => :tan,
    :log => :log,
    :log10 => :log10,
    :log2 => :log2,
    :log1p => :log1p,
    :exp => :exp,
    :exp2 => :exp2,
    :exp10 => :exp10,
    :expm1 => :expm1,
    :sqrt => :sqrt,
    :cbrt => :cbrt,
    :asin => :asin,
    :acos => :acos,
    :atan => :atan,
    :sinh => :sinh,
    :cosh => :cosh,
    :tanh => :tanh,
    :asinh => :asinh,
    :acosh => :acosh,
    :atanh => :atanh,
    :erf => :erf,
    :erfc => :erfc,
    :gamma => :gamma,
    :lgamma => :lgamma,
    :trunc => :trunc,
    :floor => :floor,
    :ceil => :ceil,
    :abs => :abs,
    :pow => :pow,
    :hypot => :hypot_fast,
    :mod => :mod
)
const SLEEFDictFast = Dict{Symbol,Symbol}(
    :sin => :sin_fast,
    :sinpi => :sinpi_fast,
    :cos => :cos_fast,
    :cospi => :cospi_fast,
    :tan => :tan_fast,
    :log => :log_fast,
    :log10 => :log10,
    :log2 => :log2,
    :log1p => :log1p,
    :exp => :exp,
    :exp2 => :exp2,
    :exp10 => :exp10,
    :expm1 => :expm1,
    :sqrt => :sqrt, # faster than sqrt_fast
    :cbrt => :cbrt_fast,
    :asin => :asin_fast,
    :acos => :acos_fast,
    :atan => :atan_fast,
    :sinh => :sinh_fast,
    :cosh => :cosh_fast,
    :tanh => :tanh_fast,
    :asinh => :asinh,
    :acosh => :acosh,
    :atanh => :atanh,
    :erf => :erf,
    :erfc => :erfc,
    :gamma => :gamma,
    :lgamma => :lgamma,
    :trunc => :trunc,
    :floor => :floor,
    :ceil => :ceil,
    :abs => :abs,
    :pow => :pow,
    :hypot => :hypot_fast,
    :mod => :mod
    # :copysign => :copysign
)

function _sleef(expr, d)
    prewalk(x -> begin
        if isa(x, Symbol) && !occursin("@", string(x))
            return get(d, x, esc(x))
        else
            return x
        end
    end, expr)
end

macro sleef(expr) _sleef(expr, SLEEFDict) end
macro fastsleef(expr) _sleef(expr, SLEEFDictFast) end

const VECTOR_SYMBOLS = Dict{Symbol,Expr}(
    :(==) => :(SIMDPirates.vequal),
    :(!=) => :(SIMDPirates.vnot_equal),
    :(<) => :(SIMDPirates.vless),
    :(<=) => :(SIMDPirates.vless_or_equal),
    :(>) => :(SIMDPirates.vgreater),
    :(>=) => :(SIMDPirates.vgreater_or_equal),
    :(<<) => :(SIMDPirates.vleft_bitshift),
    :(>>) => :(SIMDPirates.vright_bitshift),
    :(>>>) => :(SIMDPirates.vuright_bitshift),
    :(&) => :(SIMDPirates.vand),
    :(|) => :(SIMDPirates.vor),
    :(⊻) => :(SIMDPirates.vxor),
    :(+) => :(SIMDPirates.vadd),
    :(-) => :(SIMDPirates.vsub),
    :(*) => :(SIMDPirates.vmul),
    :(/) => :(SIMDPirates.vfdiv),
    :(÷) => :(SIMDPirates.vidiv),
    :(%) => :(SIMDPirates.vrem),
    :div => :(SIMDPirates.vdiv),
    :rem => :(SIMDPirates.vrem),
    :(~) => :(SIMDPirates.vbitwise_not),
    :(!) => :(SIMDPirates.vnot),
    :(^) => :(SIMDPirates.vpow),
    :abs => :(SIMDPirates.vabs),
    :floor => :(SIMDPirates.vfloor),
    :ceil => :(SIMDPirates.vceil),
    :round => :(SIMDPirates.vround),
    # :sin => :vsin,
    # :cos => :vcos,
    # :exp => :vexp,
    # :exp2 => :vexp2,
    # :exp10 => :vexp10,
    :inv => :(SIMDPirates.vinv),
    # :log => :vlog,
    # :log10 => :vlog10,
    # :log2 => :vlog2,
    :sqrt => :(SIMDPirates.vsqrt),
    :trunc => :(SIMDPirates.vtrunc),
    :sign => :(SIMDPirates.vsign),
    :copysign => :(SIMDPirates.vcopysign),
    :flipsign => :(SIMDPirates.vflipsign),
    :max => :(SIMDPirates.vmax),
    :min => :(SIMDPirates.vmin),
    :fma => :(SIMDPirates.vfma),
    :muladd => :(SIMDPirates.vmuladd),
    :all => :(SIMDPirates.vall),
    :any => :(SIMDPirates.vany),
    :maximum => :(SIMDPirates.vmaximum),
    :minimum => :(SIMDPirates.vminimum),
    :prod => :(SIMDPirates.vprod),
    :sum => :(SIMDPirates.vsum),
    :reduce => :(SIMDPirates.vreduce),
    :isfinite => :(SIMDPirates.visfinite),
    :isinf => :(SIMDPirates.visinf),
    :isnan => :(SIMDPirates.visnan),
    :issubnormal => :(SIMDPirates.vissubnormal)
)


function _spirate(ex, dict, macro_escape = true)
    # @show ex
    # ex = postwalk(ex) do x
    #     if @capture(x, vadd(vmul(a_, b_), c_)) || @capture(x, vadd(c_, vmul(a_, b_)))
    #         ea = (macro_escape && isa(a, Symbol)) ? esc(a) : a
    #         eb = (macro_escape && isa(b, Symbol)) ? esc(b) : b
    #         ec = (macro_escape && isa(c, Symbol)) ? esc(c) : c
    #         return :(vmuladd($ea, $eb, $ec))
    #     elseif @capture(x, vadd(vmul(a_, b_), vmul(c_, d_), e_)) || @capture(x, vadd(vmul(a_, b_), e_, vmul(c_, d_))) || @capture(x, vadd(e_, vmul(a_, b_), vmul(c_, d_)))
    #         ea = (macro_escape && isa(a, Symbol)) ? esc(a) : a
    #         eb = (macro_escape && isa(b, Symbol)) ? esc(b) : b
    #         ec = (macro_escape && isa(c, Symbol)) ? esc(c) : c
    #         ed = (macro_escape && isa(d, Symbol)) ? esc(d) : d
    #         ee = (macro_escape && isa(e, Symbol)) ? esc(e) : e
    #         return :(vmuladd($ea, $eb, vmuladd($ec, $ed, $ee)))
    #     elseif isa(x, Symbol) && !occursin("@", string(x))
    #         return get(VECTOR_SYMBOLS, x, get(dict, x, macro_escape ? esc(x) : x))
    #     else
    #         return x
    #     end
    # end
    # @show ex
    ex = postwalk(ex) do x
        # @show x
        if @capture(x, SIMDPirates.vadd(SIMDPirates.vmul(a_, b_), c_)) || @capture(x, SIMDPirates.vadd(c_, SIMDPirates.vmul(a_, b_)))
            ea = (macro_escape && isa(a, Symbol)) ? esc(a) : a
            eb = (macro_escape && isa(b, Symbol)) ? esc(b) : b
            ec = (macro_escape && isa(c, Symbol)) ? esc(c) : c
            return :(SIMDPirates.vmuladd($ea, $eb, $ec))
        elseif @capture(x, SIMDPirates.vadd(SIMDPirates.vmul(a_, b_), SIMDPirates.vmul(c_, d_), e_)) || @capture(x, SIMDPirates.vadd(SIMDPirates.vmul(a_, b_), e_, SIMDPirates.vmul(c_, d_))) || @capture(x, SIMDPirates.vadd(e_, SIMDPirates.vmul(a_, b_), SIMDPirates.vmul(c_, d_)))
            ea = (macro_escape && isa(a, Symbol)) ? esc(a) : a
            eb = (macro_escape && isa(b, Symbol)) ? esc(b) : b
            ec = (macro_escape && isa(c, Symbol)) ? esc(c) : c
            ed = (macro_escape && isa(d, Symbol)) ? esc(d) : d
            ee = (macro_escape && isa(e, Symbol)) ? esc(e) : e
            return :(SIMDPirates.vmuladd($ea, $eb, SIMDPirates.vmuladd($ec, $ed, $ee)))
        elseif isa(x, Symbol) && !occursin("@", string(x))
            return get(VECTOR_SYMBOLS, x, get(dict, x, macro_escape ? esc(x) : x))
        else
            return x
        end
    end
end

macro spirate(ex) _spirate(ex, SLEEFDict) end
macro spiratef(ex) _spirate(ex, SLEEFDictFast) end
