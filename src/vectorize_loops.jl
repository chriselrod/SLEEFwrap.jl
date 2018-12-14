
mask_expr(W, r) = :($(Expr(:tuple, [i > r ? Core.VecElement{Bool}(false) : Core.VecElement{Bool}(true) for i ∈ 1:W]...)))

"""
Returns the strides necessary to iterate across rows.
Needs `@inferred` testing / that the compiler optimizes it away
whenever size(A) is known at compile time. Seems to be the case for Julia 1.1.
"""
@inline stride_row(A::AbstractArray) = sizeof(eltype(A)) * size(A,1)
@inline function num_row_strides(A::AbstractArray)
    s = size(A)
    N = s[2]
    for i ∈ 3:length(s)
        N *= s[i]
    end
    N
end
@inline function stride_row_iter(A::AbstractArray)
    N = num_row_strides(A)
    stride = stride_row(A)
    ntuple(i -> (i-1) * stride, Val(N))
end

"""
N is length of the vectors.
T is the type of the index.
n is the index.
body is the body of the function.
"""
function vectorize_body(N::Integer, T::DataType, unroll_factor, n, body)
    T_size = sizeof(T)
    W = REGISTER_SIZE ÷ T_size
    while W > 2N
        W >>= 1
    end
    WT = W * T_size
    Q, r = divrem(N, W) #Assuming Mₖ is a multiple of W
    QQ, Qr = divrem(Q, unroll_factor)
    if r > 0
        if unroll_factor == 1
            QQ += 1
        else
            Qr += 1
        end
        Q += 1
    end
    # unroll the remainder iteration
    # so that whenever Q >= unroll_factor, we will always have at least
    # unroll_factor operations scheduled at a time.
    if QQ > 0 && Qr > 0 && Qr < unroll_factor # if r > 0, Qr may equal 4
        QQ -= 1
        Qr += unroll_factor
    end
    V = SVec{W,T}


    # body = _pirate(body)

    # indexed_expressions = Dict{Symbol,Expr}()
    indexed_expressions = Dict{Symbol,Symbol}() # Symbol, gensymbol
    reduction_expressions = Dict{Symbol,Symbol}() # ParamSymbol,
    # itersym = esc(gensym(:iter))
    # itersym = esc(:iter)
    itersym = :iter
    isym = gensym(:i)
    # walk the expression, searching for all get index patterns.
    # these will be replaced with
    # Plan: definition of q will create vectorizables
    main_body = quote end
    reduction_symbols = Symbol[]
    loaded_exprs = Dict{Expr,Symbol}()

    for b ∈ body
        ## body preamble must define indexed symbols
        ## we only need that for loads.
        push!(main_body.args,
            _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, b;
                            itersym = itersym, declared_iter_sym = n)
        )# |> x -> (@show(x), _pirate(x)))
    end

    ### now we walk the body to look for reductions
    if length(reduction_symbols) > 0
        reductions = true
    else
        reductions = false
    end

    q = quote end
    for (sym, psym) ∈ indexed_expressions
        push!(q.args, :( $psym = SLEEFwrap.vectorizable($sym) ))
    end


    # @show QQ, Qr, Q, r
    loop_body = [:($itersym = $isym), main_body]
    for unroll ∈ 1:unroll_factor-1
        push!(loop_body, :($itersym = $isym + $(unroll*W*sizeof(T))))
        push!(loop_body, main_body)
    end

    if QQ > 0
        push!(q.args,
        quote
            for $isym ∈ 0:$(unroll_factor*W*sizeof(T)):$((QQ-1)*unroll_factor*W*sizeof(T))
                $(loop_body...)
            end
        end)
    end
    for qri ∈ 0:Qr-1
        push!(q.args,
        quote
            $itersym = $(QQ*unroll_factor*W*sizeof(T) + qri*W*sizeof(T))
            $main_body
        end)
    end
    if r > 0
        throw("Need to work on mask!")
        mask = mask_expr(W, r)
        iter = Q * W * sizeof(T)
        r_body = quote end
        for b ∈ body
            push!(r_body.args, _spirate(prewalk(b) do x
                if @capture(x, A_[i_] = B_)
                    if A ∉ keys(indexed_expressions)
                        # pA = esc(gensym(A))
                        # pA = esc(Symbol(:p,A))
                        pA = Symbol(:p,A)
                        indexed_expressions[A] = pA
                    else
                        pA = indexed_expressions[A]
                    end
                    if i == n
                        return :(vstore($B, $pA, $iter + 1, $mask))
                    else
                        return :(vstore($B, $pA, $i*sizeof(eltype($A)) + 1, $mask))
                    end
                elseif @capture(x, A_[i_])
                    if A ∉ keys(indexed_expressions)
                        # pA = esc(gensym(A))
                        # pA = esc(Symbol(:p,A))
                        pA = Symbol(:p,A)
                        indexed_expressions[A] = pA
                    else
                        pA = indexed_expressions[A]
                    end
                    if i == n
                        return :(vload($V, $pA, $iter + 1, $mask))
                    else
                        # when loading something not indexed by the loop variable,
                        # we assume that the intension is to broadcast
                        return :(vbroadcast($V, unsafe_load($pA + $i*sizeof(eltype($A)), $mask)))
                    end
                else
                    return x
                end
            end, SLEEFDictFast, false)) # macro_escape = false
        end
        push!(q.args, r_body)
    end
    q
end
function vectorize_body(N, Tsym::Symbol, uf, n, body)
    if Tsym == :Float32
        vectorize_body(N, Float32, uf, n, body)
    elseif Tsym == :Float64
        vectorize_body(N, Float64, uf, n, body)
    elseif Tsym == :ComplexF32
        vectorize_body(N, ComplexF32, uf, n, body)
    elseif Tsym == :ComplexF64
        vectorize_body(N, ComplexF64, uf, n, body)
    else
        throw("Type $Tsym is not supported.")
    end
end
function vectorize_body(N::Union{Symbol, Expr}, T::DataType, unroll_factor, n, body)
    T_size = sizeof(T)
    W = REGISTER_SIZE ÷ T_size
    # @show W, REGISTER_SIZE, T_size
    # @show T
    WT = W * T_size
    V = SVec{W,T}

    # @show body

    # body = _pirate(body)

    # indexed_expressions = Dict{Symbol,Expr}()
    indexed_expressions = Dict{Symbol,Symbol}() # Symbol, gensymbol
    reduction_expressions = Dict{Symbol,Symbol}() # ParamSymbol,
    # itersym = esc(gensym(:iter))
    # itersym = esc(:iter)
    # itersym = :iter
    itersym = gensym(:iter)
    isym = gensym(:i)
    # walk the expression, searching for all get index patterns.
    # these will be replaced with
    # Plan: definition of q will create vectorizables
    main_body = quote end
    reduction_symbols = Symbol[]
    loaded_exprs = Dict{Expr,Symbol}()

    for b ∈ body
        ## body preamble must define indexed symbols
        ## we only need that for loads.
        push!(main_body.args,
            _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, b;
                            itersym = itersym, declared_iter_sym = n)
        )# |> x -> (@show(x), _pirate(x)))
    end
    # @show main_body

    ### now we walk the body to look for reductions
    if length(reduction_symbols) > 0
        reductions = true
    else
        reductions = false
    end

    q = quote
        QQ, Qr = divrem(Q, $unroll_factor)
        if r > 0
            # $(unroll_factor == 1 ? :QQ : :Qr) += 1
            Qr += 1
            Q += 1
        end
    end
    pushfirst!(q.args, :((Q, r) = $(num_vector_load_expr(:SLEEFwrap, N, W))))
    for (sym, psym) ∈ indexed_expressions
        push!(q.args, :( $psym = SLEEFwrap.vectorizable($sym) ))
    end
    # @show QQ, Qr, Q, r
    loop_body = [:($itersym = $isym), :($main_body)]
    for unroll ∈ 1:unroll_factor-1
        push!(loop_body, :($itersym = $isym + $(unroll*W*sizeof(T))))
        push!(loop_body, :($main_body))
    end
    push!(q.args,
    quote
        for $isym ∈ 0:$(unroll_factor*W*sizeof(T)):((QQ-1)*$(unroll_factor*W*sizeof(T)))
            $(loop_body...)
        end
    end)
    if unroll_factor > 1
        push!(q.args,
        quote
            for $isym ∈ 0:Qr-1
                $itersym = QQ*$(unroll_factor*WT) + $isym*$WT
                $main_body
            end
        end)
    end
    push!(q.args,
    quote
        for $n ∈ $N-r+1:$N
            $(body...)
        end
    end)
    q
end

function _vectorloads(V, expr; itersym = :iter, declared_iter_sym = nothing)


    # body = _pirate(body)

    # indexed_expressions = Dict{Symbol,Expr}()
    indexed_expressions = Dict{Symbol,Symbol}() # Symbol, gensymbol
    reduction_expressions = Dict{Symbol,Symbol}() # ParamSymbol,

    main_body = quote end
    reduction_symbols = Symbol[]
    loaded_exprs = Dict{Expr,Symbol}()

    push!(main_body.args,
        _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, expr;
            itersym = itersym, declared_iter_sym = declared_iter_sym)
    )
    main_body
end

function _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, expr;
                            itersym = :iter, declared_iter_sym = nothing)
    _spirate(prewalk(expr) do x
        # @show x
        if @capture(x, A_[i_] = B_)
            if A ∉ keys(indexed_expressions)
                # pA = esc(gensym(A))
                # pA = esc(Symbol(:p,A))
                pA = gensym(Symbol(:p,A))
                indexed_expressions[A] = pA
            else
                pA = indexed_expressions[A]
            end
            if i == declared_iter_sym
                return :(vstore($B, $pA, $itersym + 1))
            else
                return :(vstore($B, $pA, $i*sizeof(eltype($A)) + 1))
            end
        elseif @capture(x, A_[i_,j_] = B_)
            if A ∉ keys(indexed_expressions)
                pA = gensym(Symbol(:p, A))
                indexed_expressions[A] = pA
            else
                pA = indexed_expressions[A]
            end
            sym = gensym(Symbol(pA, :_, i))
            if i == declared_iter_sym
                ej = isa(j, Number) ? j - 1 : :($j - 1)
                # assignment = :($pA + $itersym + $ej*SLEEFwrap.stride_row($A))
                return :(vstore($B, $pA, $itersym + $ej*SLEEFwrap.stride_row($A) + 1))
            else
                throw("Indexing columns with vectorized loop variable is not supported.")
            end
        elseif (@capture(x, A += B_) || @capture(x, A -= B_) || @capture(x, A *= B_) || @capture(x, A /= B_)) && A ∉ reduction_symbols
            push!(reduction_symbols, A)
        elseif @capture(x, A_[i_])
            if A ∉ keys(indexed_expressions)
                # pA = esc(gensym(A))
                # pA = esc(Symbol(:p,A))
                pA = gensym(Symbol(:p,A))
                indexed_expressions[A] = pA
            else
                pA = indexed_expressions[A]
            end

            ## check to see if we are to do a vector load or a broadcast
            if i == declared_iter_sym
                load_expr = :(vload($V, $pA, $itersym + 1))
            else
                load_expr = :(vbroadcast($V, unsafe_load($pA + $i*sizeof(eltype($A)))))
            end
            if load_expr ∈ keys(loaded_exprs)
                sym = loaded_exprs[load_expr]
            else
                sym = gensym(Symbol(pA, :_, i))
                loaded_exprs[load_expr] = sym
                push!(main_body.args, :($sym = $load_expr))
            end
            return sym
        elseif @capture(x, A_[i_, j_])
            if A ∉ keys(indexed_expressions)
                # pA = esc(gensym(A))
                # pA = esc(Symbol(:p,A))
                pA = gensym(Symbol(:p,A))
                indexed_expressions[A] = pA
            else
                pA = indexed_expressions[A]
            end


            ej = isa(j, Number) ?  j - 1 : :($j - 1)
            if i == declared_iter_sym
                load_expr = :(vload($V, $pA, $itersym + $ej*SLEEFwrap.stride_row($A) + 1))
            elseif j == declared_iter_sym
                throw("Indexing columns with vectorized loop variable is not supported.")
            else
                # when loading something not indexed by the loop variable,
                # we assume that the intension is to broadcast
                load_expr = :(vbroadcast($V, unsafe_load($pA + $i*sizeof(eltype($A)) + $ej*SLEEFwrap.stride_row($A))))
            end
            if load_expr ∈ keys(loaded_exprs)
                sym = loaded_exprs[load_expr]
            else
                sym = gensym(Symbol(pA, :_, i))
                loaded_exprs[load_expr] = sym
                push!(main_body.args, :($sym = $load_expr))
            end
            return sym
        elseif @capture(x, A_[i_,:] .= B_)
            ## Capture if there are multiple assignments...
            if A ∉ keys(indexed_expressions)
                # pA = esc(gensym(A))
                # pA = esc(Symbol(:p,A))
                pA = gensym(Symbol(:p,A))
                indexed_expressions[A] = pA
            else
                pA = indexed_expressions[A]
            end
            if i == declared_iter_sym
                isym = itersym
            else
                isym = :($i*sizeof(eltype($A)))
            end

            br = gensym(:B)
            br2 = gensym(:B)
            coliter = gensym(:j)
            numiter = gensym(:numiter)
            stridesym = gensym(:stride)

            pushexpr = quote
                $numiter = SLEEFwrap.num_row_strides($A)
                $stridesym = SLEEFwrap.stride_row($A)
                $br = SLEEFwrap.extract_data.($B)
                # $br2 = ntuple(b -> SLEEFwrap.extract_data(getindex($br,b)), Val(length($br)))
                # $br2 = SLEEFwrap.extract_data.($br)
                for $coliter ∈ 0:$numiter-1
                    SIMDPirates.vstore(getindex($br,1+$coliter), $pA, $isym + $stridesym * $coliter + 1)
                end
            end

            return pushexpr
        elseif @capture(x, @nexprs N_ ex_)
            # println("Macroexpanding x:", x)
            # @show ex
            # mx = Expr(:escape, Expr(:block, Any[ Base.Cartesian.inlineanonymous(ex,i) for i = 1:N ]...))
            mx = Expr(:block, Any[ Base.Cartesian.inlineanonymous(ex,i) for i = 1:N ]...)
            # println("Macroexpanded x:", mx)
            return mx
        else
            # println("Returning x:", x)
            return x
        end
    end, SLEEFDictFast, false) # macro_escape = false
end


"""
Arguments are
@vectorze Type UnrollFactor forloop

The default type is Float64, and default UnrollFactor is 1 (no unrolling).
"""
macro vectorize(expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, Float64, n, body, false)
        q = vectorize_body(N, Float64, 1, n, body)
    # elseif @capture(expr, for n_ ∈ 1:N_ body__ end)
    #     q = vectorize_body(N, element_type(body)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = vectorize_body(:(length($A)), Float64, 1, n, body)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
macro vectorize(type::Union{Symbol,DataType}, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = vectorize_body(N, type, 1, n, body)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = vectorize_body(:(length($A)), type, 1, n, body)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
macro vectorize(unroll_factor::Integer, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = vectorize_body(N, Float64, unroll_factor, n, body)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = vectorize_body(:(length($A)), Float64, unroll_factor, n, body)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
macro vectorize(type, unroll_factor, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = vectorize_body(N, type, unroll_factor, n, body)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = vectorize_body(:(length($A)), type, unroll_factor, n, body)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
