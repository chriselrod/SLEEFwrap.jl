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
    :sqrt => :(SLEEFwrap.sqrt),
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
    :pow => :(SLEEFwrap.pow),
    :hypot => :(SLEEFwrap.hypot_fast),
    :mod => :(SLEEFwrap.mod)
)
const SLEEFDictFast = Dict{Symbol,Expr}(
    :sin => :(SLEEFwrap.sin_fast),
    :sinpi => :(SLEEFwrap.sinpi_fast),
    :cos => :(SLEEFwrap.cos_fast),
    :cospi => :(SLEEFwrap.cospi_fast),
    :tan => :(SLEEFwrap.tan_fast),
    :log => :(SLEEFwrap.log_fast),
    :log10 => :(SLEEFwrap.log10),
    :log2 => :(SLEEFwrap.log2),
    :log1p => :(SLEEFwrap.log1p),
    :exp => :(SLEEFwrap.exp),
    :exp2 => :(SLEEFwrap.exp2),
    :exp10 => :(SLEEFwrap.exp10),
    :expm1 => :(SLEEFwrap.expm1),
    :sqrt => :(SIMDPirates.sqrt), # faster than sqrt_fast
    :cbrt => :(SLEEFwrap.cbrt_fast),
    :asin => :(SLEEFwrap.asin_fast),
    :acos => :(SLEEFwrap.acos_fast),
    :atan => :(SLEEFwrap.atan_fast),
    :sinh => :(SLEEFwrap.sinh_fast),
    :cosh => :(SLEEFwrap.cosh_fast),
    :tanh => :(SLEEFwrap.tanh_fast),
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
    :pow => :(SLEEFwrap.pow),
    :hypot => :(SLEEFwrap.hypot_fast),
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
        elseif @capture(x, a_ * b_ + c_ - c_) || @capture(x, c_ + a_ * b_ - c_) || @capture(x, a_ * b_ - c_ + c_) || @capture(x, - c_ + a_ * b_ + c_)
            return :(SIMDPirates.vmul($a, $b))
        elseif @capture(x, a_ * b_ + c_ - d_) || @capture(x, c_ + a_ * b_ - d_) || @capture(x, a_ * b_ - d_ + c_) || @capture(x, - d_ + a_ * b_ + c_) || @capture(x, SIMDPirates.vsub(SIMDPirates.vmuladd(a_, b_, c_), d_))
            return :(SIMDPirates.vmuladd($a, $b, SIMDPirates.vsub($c, $d)))
        elseif @capture(x, a_ += b_)
            ea = isa(a, Symbol) ? esc(a) : a
            eb = isa(b, Symbol) ? esc(b) : b
            return :($ea = $(esc(SIMDPirates.vadd))($ea, $eb))
        elseif @capture(x, a_ -= b_)
            ea = isa(a, Symbol) ? esc(a) : a
            eb = isa(b, Symbol) ? esc(b) : b
            return :($ea = $(esc(SIMDPirates.vsub))($ea, $eb))
        elseif @capture(x, a_ *= b_)
            ea = isa(a, Symbol) ? esc(a) : a
            eb = isa(b, Symbol) ? esc(b) : b
            return :($ea = $(esc(SIMDPirates.vmul))($ea, $eb))
        elseif @capture(x, a_ /= b_)
            ea = isa(a, Symbol) ? esc(a) : a
            eb = isa(b, Symbol) ? esc(b) : b
            return :($ea = $(esc(SIMDPirates.vdiv))($ea, $eb))
        # elseif isa(x, Symbol)
        #     if occursin("@", string(x))
        #         if macro_escape && (x != :@spirate) && (x != :@restrict_simd)
        #             return esc(x)
        #         else
        #             return x
        #         end
        #     else
        #         return get(VECTOR_SYMBOLS, x, get(dict, x, macro_escape ? esc(x) : x))
        #     end
        elseif isa(x, Symbol) && !occursin("@", string(x))
            return get(VECTOR_SYMBOLS, x, get(dict, x, macro_escape ? esc(x) : x))
        else
            return x
        end
    end
end

macro spirate(ex) _spirate(ex, SLEEFDict) end
macro spiratef(ex) _spirate(ex, SLEEFDictFast) end
