const SLEEFDict = Dict{Symbol,Expr}(
    :sin => :(SLEEFwrap.sin),
    :sinpi => :(SLEEFwrap.sinpi),
    :cos => :(SLEEFwrap.cos),
    :cospi => :(SLEEFwrap.cospi),
    :tan => :(SLEEFwrap.tan),
    :log => :(SLEEFwrap.log),
    :log10 => :(SLEEFwrap.log10),
    :log2 => :(SLEEFwrap.log2),
    :log1p => :(SLEEFwrap.log1p),
    :exp => :(SLEEFwrap.exp),
    :exp2 => :(SLEEFwrap.exp2),
    :exp10 => :(SLEEFwrap.exp10),
    :expm1 => :(SLEEFwrap.expm1),
    :sqrt => :(SIMDPirates.sqrt),
    :cbrt => :(SLEEFwrap.cbrt),
    :asin => :(SLEEFwrap.asin),
    :acos => :(SLEEFwrap.acos),
    :atan => :(SLEEFwrap.atan),
    :sinh => :(SLEEFwrap.sinh),
    :cosh => :(SLEEFwrap.cosh),
    :tanh => :(SLEEFwrap.tanh),
    :asinh => :(SLEEFwrap.asinh),
    :acosh => :(SLEEFwrap.acosh),
    :atanh => :(SLEEFwrap.atanh),
    :erf => :(SLEEFwrap.erf),
    :erfc => :(SLEEFwrap.erfc),
    :gamma => :(SLEEFwrap.gamma),
    :lgamma => :(SLEEFwrap.lgamma),
    :trunc => :(SLEEFwrap.trunc),
    :floor => :(SLEEFwrap.floor),
    :ceil => :(SLEEFwrap.ceil),
    :abs => :(SLEEFwrap.abs),
    :sincos => :(SLEEFwrap.sincos),
    :sincospi => :(SLEEFwrap.sincospi),
    :pow => :(SLEEFwrap.pow),
    :hypot => :(SLEEFwrap.hypot_fast),
    :mod => :(SLEEFwrap.mod)
)
const SLEEFDictFast = Dict{Symbol,Expr}(
    :sin => :(Base.FastMath.sin_fast),
    :sinpi => :(SLEEFwrap.sinpi_fast),
    :cos => :(Base.FastMath.cos_fast),
    :cospi => :(SLEEFwrap.cospi_fast),
    :tan => :(Base.FastMath.tan_fast),
    :log => :(Base.FastMath.log_fast),
    :log10 => :(SLEEFwrap.log10),
    :log2 => :(SLEEFwrap.log2),
    :log1p => :(SLEEFwrap.log1p),
    :exp => :(SLEEFwrap.exp),
    :exp2 => :(SLEEFwrap.exp2),
    :exp10 => :(SLEEFwrap.exp10),
    :expm1 => :(SLEEFwrap.expm1),
    :sqrt => :(SIMDPirates.sqrt), # faster than sqrt_fast
    :cbrt => :(Base.FastMath.cbrt_fast),
    :asin => :(Base.FastMath.asin_fast),
    :acos => :(Base.FastMath.acos_fast),
    :atan => :(Base.FastMath.atan_fast),
    :sinh => :(Base.FastMath.sinh_fast),
    :cosh => :(Base.FastMath.cosh_fast),
    :tanh => :(Base.FastMath.tanh_fast),
    :asinh => :(SLEEFwrap.asinh),
    :acosh => :(SLEEFwrap.acosh),
    :atanh => :(SLEEFwrap.atanh),
    :erf => :(SLEEFwrap.erf),
    :erfc => :(SLEEFwrap.erfc),
    :gamma => :(SLEEFwrap.gamma),
    :lgamma => :(SLEEFwrap.lgamma),
    :trunc => :(SLEEFwrap.trunc),
    :floor => :(SLEEFwrap.floor),
    :ceil => :(SLEEFwrap.ceil),
    :abs => :(SLEEFwrap.abs),
    :sincos => :(Base.FastMath.sincos_fast),
    :sincospi => :(SLEEFwrap.sincospi_fast),
    :pow => :(SLEEFwrap.pow),
    :hypot => :(Base.FastMath.hypot_fast),
    :mod => :(SLEEFwrap.mod)
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
function horner(x, p...)
    t = gensym(:t)
    ex = p[end]
    for i ∈ length(p)-1:-1:1
        ex = :(SIMDPirates.vmuladd($t, $ex, $(p[i])))
    end
    Expr(:block, :($t = $x), ex)
end

function _spirate(ex, dict, macro_escape = true)
    ex = postwalk(ex) do x
        # @show x
        if @capture(x, SIMDPirates.vadd(SIMDPirates.vmul(a_, b_), c_)) || @capture(x, SIMDPirates.vadd(c_, SIMDPirates.vmul(a_, b_)))
            return :(SIMDPirates.vmuladd($a, $b, $c))
        elseif @capture(x, SIMDPirates.vadd(SIMDPirates.vmul(a_, b_), SIMDPirates.vmul(c_, d_), e_)) || @capture(x, SIMDPirates.vadd(SIMDPirates.vmul(a_, b_), e_, SIMDPirates.vmul(c_, d_))) || @capture(x, SIMDPirates.vadd(e_, SIMDPirates.vmul(a_, b_), SIMDPirates.vmul(c_, d_)))
            return :(SIMDPirates.vmuladd($a, $b, SIMDPirates.vmuladd($c, $d, $e)))
        elseif @capture(x, a_ * b_ + c_ - c_) || @capture(x, c_ + a_ * b_ - c_) || @capture(x, a_ * b_ - c_ + c_) || @capture(x, - c_ + a_ * b_ + c_)
            return :(SIMDPirates.vmul($a, $b))
        elseif @capture(x, a_ * b_ + c_ - d_) || @capture(x, c_ + a_ * b_ - d_) || @capture(x, a_ * b_ - d_ + c_) || @capture(x, - d_ + a_ * b_ + c_) || @capture(x, SIMDPirates.vsub(SIMDPirates.vmuladd(a_, b_, c_), d_))
            return :(SIMDPirates.vmuladd($a, $b, SIMDPirates.vsub($c, $d)))
        elseif @capture(x, a_ += b_)
            return :($a = SIMDPirates.vadd($a, $b))
        elseif @capture(x, a_ -= b_)
            return :($a = SIMDPirates.vsub($a, $b))
        elseif @capture(x, a_ *= b_)
            return :($a = SIMDPirates.vmul($a, $b))
        elseif @capture(x, a_ /= b_)
            return :($a = SIMDPirates.vdiv($a, $b))
        elseif @capture(x, @horner a__)
            return horner(a...)
        elseif @capture(x, Base.Math.muladd(a_, b_, c_))
            return :( SIMDPirates.vmuladd($a, $b, $c) )
        elseif isa(x, Symbol) && !occursin("@", string(x))
            return get(VECTOR_SYMBOLS, x, get(dict, x, x))
        else
            return x
        end
    end
    macro_escape ? esc(ex) : ex
end

macro spirate(ex) _spirate(ex, SLEEFDict) end
macro spiratef(ex) _spirate(ex, SLEEFDictFast) end
