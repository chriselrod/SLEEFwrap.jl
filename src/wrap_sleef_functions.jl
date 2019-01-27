const PREFIX = :Sleef_

# pattern is SLEEF name, Julia name, accuracy
const UNARY_OUT_FUNCTIONS = [
    (:Base,:sin,:sin,:_u10),
    (:FastMath,:sin,:sin_fast,:_u35),
    (:Base,:sinpi,:sinpi,:_u05),
    (:SLEEFwrap,:sinpi,:sinpi_fast,:_u35),
    (:Base,:cos,:cos,:_u10),
    (:FastMath,:cos,:cos_fast,:_u35),
    (:Base,:cospi,:cospi,:_u05),
    (:SLEEFwrap,:cospi,:cospi_fast,:_u35),
    (:Base,:tan,:tan,:_u10),
    (:FastMath,:tan,:tan_fast,:_u35),
    (:Base,:log,:log,:_u10),
    (:FastMath,:log,:log_fast,:_u35),
    (:Base,:log10,:log10,:_u10),
    (:Base,:log2,:log2,:_u10),
    (:Base,:log1p,:log1p,:_u10),
    (:Base,:exp,:exp,:_u10),
    (:Base,:exp2,:exp2,:_u10),
    (:Base,:exp10,:exp10,:_u10),
    (:Base,:expm1,:expm1,:_u10),
    # (:Base,:sqrt,:sqrt,:_),
    # (:sqrt,:sqrt_fast,:_u35),
    (:Base,:cbrt,:cbrt,:_u10),
    (:FastMath,:cbrt,:cbrt_fast,:_u35),
    (:Base,:asin,:asin,:_u10),
    (:FastMath,:asin,:asin_fast,:_u35),
    (:Base,:acos,:acos,:_u10),
    (:FastMath,:acos,:acos_fast,:_u35),
    (:Base,:atan,:atan,:_u10),
    (:FastMath,:atan,:atan_fast,:_u35),
    (:Base,:sinh,:sinh,:_u10),
    (:FastMath,:sinh,:sinh_fast,:_u35),
    (:Base,:cosh,:cosh,:_u10),
    (:FastMath,:cosh,:cosh_fast,:_u35),
    (:Base,:tanh,:tanh,:_u10),
    (:FastMath,:tanh,:tanh_fast,:_u35),
    (:Base,:asinh,:asinh,:_u10),
    (:Base,:acosh,:acosh,:_u10),
    (:Base,:atanh,:atanh,:_u10),
    (:SpecialFunctions,:erf,:erf,:_u10),
    (:SpecialFunctions,:erfc,:erfc,:_u15),
    (:SpecialFunctions,:tgamma,:gamma,:_u10),
    (:SpecialFunctions,:lgamma,:lgamma,:_u10),
    (:Base,:trunc,:trunc,:_),
    (:Base,:floor,:floor,:_),
    (:Base,:ceil,:ceil,:_),
    (:Base,:fabs,:abs,:_)
]

const BINARY_OUT_FUNCTIONS = [
    (:Base,:sincos,:sincos,:_u10),
    (:FastMath,:sincos,:sincos_fast,:_u35),
    (:SLEEFwrap,:sincospi,:sincospi,:_u05),
    (:SLEEFwrap,:sincospi,:sincospi_fast,:_u35),
    (:Base,:modf,:modf,:_)
]
const BINARY_IN_FUNCTIONS = [
    (:SLEEFwrap, :pow, :pow, :_u10),
    (:Base, :atan2, :atan, :_u10),
    (:FastMath, :atan2, :atan_fast, :_u35),
    (:Base, :hypot,:hypot, :_05),
    (:FastMath, :hypot,:hypot_fast, :_35),
    (:Base, :fmod,:mod, :_),
    (:Base, :copysign,:copysign, :_)
]

## Special cases: :round, :rint, :ldexp
for (vectype, func_suffix, suffix) ∈ SIZES
    for (mod,SLEEF_name,Julia_name,accuracy) ∈ UNARY_OUT_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        @eval @inline function ($Julia_name)(a::($vectype))
            ccall(($func_name, libsleef), $vectype, ($vectype,), a)
        end
    end

    for (mod,SLEEF_name,Julia_name,accuracy) ∈ BINARY_OUT_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        @eval @inline function ($Julia_name)(a::($vectype))
            ccall(($func_name, libsleef), $(NEXT[vectype]), ($vectype,), a)
        end
    end

    for (mod,SLEEF_name,Julia_name,accuracy) ∈ BINARY_IN_FUNCTIONS
        func_name = QuoteNode(Symbol(PREFIX, SLEEF_name, func_suffix, accuracy, suffix))
        @eval @inline function ($Julia_name)(a::($vectype), b::($vectype))
            ccall(($func_name, libsleef), $vectype, ($vectype,$vectype), a, b)
        end
    end
end

function split_quote(func, args, outs, W, T, ::Type{VT}) where VT
    R = W
    current_vec_size = REGISTER_SIZE ÷ sizeof(T)
    repetitions = Pair{Int,Int}[]
    while R != 0
        N, R = divrem(W, current_vec_size)
        push!(repetitions, N => current_vec_size)
        current_vec_size >>= 1
    end
    eargs = [gensym(arg) for arg ∈ args]
    outputs = [gensym(out) for out ∈ outs]
    finaloutputs = [Expr(:tuple) for i ∈ eachindex(outputs)]
    q = quote
        $(Expr(:meta, :inline))
    end
    for i ∈ eachindex(eargs)
        push!(q.args, :($(eargs[i]) = extract_data($(args[i]))))
    end
    ind = 0
    for (reps, vec_size) ∈ repetitions
        # arg_quote = quote end
        for k ∈ 1:reps
            targs = Vector{Symbol}(undef, length(args))
            for (i,arg) ∈ enumerate(eargs)
                targ = gensym(:arg)
                targs[i] = targ
                push!(q.args, :( $targ = $(Expr(:tuple, [:($arg[$(ind + j)]) for j ∈ 1:vec_size]...)) ))
            end
            touts = Vector{Symbol}(undef, length(outputs))
            for (i,out) ∈ enumerate(outputs)
                tout = gensym(out)
                touts[i] = tout
                texpr = finaloutputs[i]
                for j ∈ 1:vec_size
                    push!(texpr.args, :(($tout)[$j]) )
                end
            end
            ind += vec_size
            if length(outputs) == 1
                push!(q.args, :($(touts[1]) =  $(Expr(:call, func, targs...)) ))
            else
                push!(q.args, :($(Expr(:tuple, touts...)) =  $(Expr(:call, func, targs...)) ))
            end
        end
    end
    struct_wrap = VT <: VectorizationBase.AbstractStructVec
    if length(outputs) == 1
        if struct_wrap
            push!(q.args, :(SIMDPirates.SVec($(finaloutputs[1]))))
        else
            push!(q.args, finaloutputs[1])
        end
    else
        if struct_wrap
            push!(q.args, Expr(:tuple, [:(SIMDPirates.SVec($fo)) for fo ∈ finaloutputs]...))
        else
            push!(q.args, Expr(:tuple, finaloutputs...))
        end
    end
    q
end

for (mod,SLEEF_name,Julia_name,accuracy) ∈ UNARY_OUT_FUNCTIONS
    func_name = :($mod.$Julia_name)
    sleef_name = :(SLEEFwrap.$Julia_name)
    W = REGISTER_SIZE ÷ sizeof(Float32)
    while W >= 2
        @eval @inline $func_name(a::AbstractStructVec{$W,Float32}) = SVec($sleef_name(extract_data(a)))
        if mod != :SLEEFwrap
            @eval @inline $sleef_name(a::AbstractStructVec{$W,Float32}) = SVec($sleef_name(extract_data(a)))
        end
        W >>= 1
        @eval @inline $func_name(a::AbstractStructVec{$W,Float64}) = SVec($sleef_name(extract_data(a)))
        if mod != :SLEEFwrap
            @eval @inline $sleef_name(a::AbstractStructVec{$W,Float64}) = SVec($sleef_name(extract_data(a)))
        end
    end
    @eval @generated function $sleef_name(a::AbstractSIMDVector{W,T}) where {W,T}
        split_quote($sleef_name, (:a, ), (:c,), W, T, a)
    end
    if mod != :SLEEFwrap
        @eval @generated function $func_name(a::AbstractSIMDVector{W,T}) where {W,T}
            split_quote($sleef_name, (:a, ), (:c,), W, T, a)
        end
    end
end

for (mod,SLEEF_name,Julia_name,accuracy) ∈ BINARY_OUT_FUNCTIONS
    func_name = :($mod.$Julia_name)
    sleef_name = :(SLEEFwrap.$Julia_name)
    W = REGISTER_SIZE ÷ sizeof(Float32)
    while W >= 2
        @eval @inline $func_name(a::AbstractStructVec{$W,Float32}) = SVec($sleef_name(extract_data(a)))
        if mod != :SLEEFwrap
            @eval @inline $sleef_name(a::AbstractStructVec{$W,Float32}) = SVec($sleef_name(extract_data(a)))
        end
        W >>= 1
        @eval @inline $func_name(a::AbstractStructVec{$W,Float64}) = SVec($sleef_name(extract_data(a)))
        if mod != :SLEEFwrap
            @eval @inline $sleef_name(a::AbstractStructVec{$W,Float64}) = SVec($sleef_name(extract_data(a)))
        end
    end
    @eval @generated function $sleef_name(a::AbstractSIMDVector{W,T}) where {W,T}
        split_quote($sleef_name, (:a, ), (:b, :c,), W, T, a)
    end
    if mod != :SLEEFwrap
        @eval @generated function $func_name(a::AbstractSIMDVector{W,T}) where {W,T}
            split_quote($sleef_name, (:a, ), (:b, :c,), W, T, a)
        end
    end
end


@inline function Base.:^(a::AbstractStructVec, b::AbstractStructVec)
    SVec(pow(extract_data(a),extract_data(b)))
end
for (mod,SLEEF_name,Julia_name,accuracy) ∈ BINARY_IN_FUNCTIONS#[2:end]
    func_name = :($mod.$Julia_name)
    sleef_name = :(SLEEFwrap.$Julia_name)
    W = REGISTER_SIZE ÷ sizeof(Float32)
    while W >= 2
        @eval @inline function $func_name(a::AbstractStructVec{$W,Float32}, b::AbstractStructVec{$W,Float32})
            SVec($sleef_name(extract_data(a),extract_data(b)))
        end
        @eval @inline function $func_name(a::AbstractStructVec{$W,Float32}, b::Float32)
            SVec($sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float32}, b)))
        end
        @eval @inline function $func_name(a::Float32, b::AbstractStructVec{$W,Float32})
            SVec($sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float32}, a), extract_data(b)))
        end
        @eval @inline function $func_name(a::AbstractSIMDVector{$W,Float32}, b::Float32)
            $sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float32}, b))
        end
        @eval @inline function $func_name(a::Float32, b::AbstractSIMDVector{$W,Float32})
            $sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float32}, a), extract_data(b))
        end
        if mod != :SLEEFwrap
            @eval @inline function $sleef_name(a::AbstractStructVec{$W,Float32}, b::AbstractStructVec{$W,Float32})
                SVec($sleef_name(extract_data(a),extract_data(b)))
            end
            @eval @inline function $sleef_name(a::AbstractStructVec{$W,Float32}, b::Float32)
                SVec($sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float32}, b)))
            end
            @eval @inline function $sleef_name(a::Float32, b::AbstractStructVec{$W,Float32})
                SVec($sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float32}, a), extract_data(b)))
            end
            @eval @inline function $sleef_name(a::AbstractSIMDVector{$W,Float32}, b::Float32)
                $sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float32}, b))
            end
            @eval @inline function $sleef_name(a::Float32, b::AbstractSIMDVector{$W,Float32})
                $sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float32}, a), extract_data(b))
            end
        end
        W >>= 1
        @eval @inline function $func_name(a::AbstractStructVec{$W,Float64}, b::AbstractStructVec{$W,Float64})
            SVec($sleef_name(extract_data(a),extract_data(b)))
        end
        @eval @inline function $func_name(a::AbstractStructVec{$W,Float64}, b::Float64)
            SVec($sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float64}, b)))
        end
        @eval @inline function $func_name(a::Float64, b::AbstractStructVec{$W,Float64})
            SVec($sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float64}, a), extract_data(b)))
        end
        @eval @inline function $func_name(a::AbstractSIMDVector{$W,Float64}, b::Float64)
            $sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float64}, b))
        end
        @eval @inline function $func_name(a::Float64, b::AbstractSIMDVector{$W,Float64})
            $sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float64}, a), extract_data(b))
        end
        if mod != :SLEEFwrap
            @eval @inline function $sleef_name(a::AbstractStructVec{$W,Float64}, b::AbstractStructVec{$W,Float64})
                Vec($sleef_name(extract_data(a),extract_data(b)))
            end
            @eval @inline function $sleef_name(a::AbstractStructVec{$W,Float64}, b::Float64)
                SVec($sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float32}, b)))
            end
            @eval @inline function $sleef_name(a::Float64, b::AbstractStructVec{$W,Float64})
                SVec($sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float32}, a), extract_data(b)))
            end
            @eval @inline function $sleef_name(a::AbstractSIMDVector{$W,Float64}, b::Float64)
                $sleef_name(extract_data(a),SIMDPirates.vbroadcast(Vec{$W,Float32}, b))
            end
            @eval @inline function $sleef_name(a::Float64, b::AbstractSIMDVector{$W,Float64})
                $sleef_name(SIMDPirates.vbroadcast(Vec{$W,Float32}, a), extract_data(b))
            end
        end
    end

    @eval @generated function $sleef_name(a::V, b::V) where {W,T, V <: AbstractSIMDVector{W,T}}
        split_quote($sleef_name, (:a, :b), (:c,), W, T, V)
    end
    if mod != :SLEEFwrap
        @eval @generated function $func_name(a::V, b::V) where {W,T, V <: AbstractSIMDVector{W,T}}
            split_quote($sleef_name, (:a, :b), (:c,), W, T, V)
        end
    end
end
