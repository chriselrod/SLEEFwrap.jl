
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
macro_escape is for whether or not we need to escape variables for calling this
    inside of a macro.
"""
function vectorize_body(N::Integer, T, n, body, macro_escape = true, define_pointers = true)
    T_size = sizeof(T)
    W = REGISTER_SIZE ÷ T_size
    while W > 2N
        W >>= 1
    end
    WT = W * T_size
    Q, r = divrem(N, W) #Assuming Mₖ is a multiple of W
    QQ, Qr = divrem(Q, 4)
    if r > 0
        Qr += 1
        Q += 1
    end
    # unroll the remainder iteration
    # so that whenever Q >= 4, we will always have at least
    # 4 operations scheduled at a time.
    if QQ > 0 && Qr > 0 && Qr < 4 # if r > 0, Qr may equal 4
        QQ -= 1
        Qr += 4
    end
    V = Vec{W,T}


    # body = _pirate(body)

    # indexed_expressions = Dict{Symbol,Expr}()
    indexed_expressions = Dict{Symbol,Symbol}() # Symbol, gensymbol
    reduction_expressions = Dict{Symbol,Symbol}() # ParamSymbol,
    # itersym = esc(gensym(:iter))
    # itersym = esc(:iter)
    itersym = :iter
    # walk the expression, searching for all get index patterns.
    # these will be replaced with
    # Plan: definition of q will create pointers
    main_body = quote end
    reduction_symbols = Symbol[]
    loaded_exprs = Dict{Expr,Symbol}()

    for b ∈ body
        ## body preamble must define indexed symbols
        ## we only need that for loads.
        push!(main_body.args,
            _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, b;
                            itersym = itersym, macro_escape = macro_escape, oldindex = n)
        )# |> x -> (@show(x), _pirate(x)))
    end

    ### now we walk the body to look for reductions
    if length(reduction_symbols) > 0
        reductions = true


    else
        reductions = false
    end

    q = quote end
    if define_pointers
        for (sym, psym) ∈ indexed_expressions
            if macro_escape
                push!(q.args, :( $(esc(psym)) = $(esc(Base.pointer))($(esc(sym))) ))
            else
                push!(q.args, :( $psym = pointer($sym) ))
            end
        end
    end
    # @show QQ, Qr, Q, r
    itersym2 = macro_escape ? esc(itersym) : itersym
    if QQ > 0
        push!(q.args,
        quote
            for i ∈ 0:$(4W*sizeof(T)):$((QQ-1)*4W*sizeof(T))
                $itersym2 = i
                $main_body
                $itersym2 = i + $(W*sizeof(T))
                $main_body
                $itersym2 = i + $(2W*sizeof(T))
                $main_body
                $itersym2 = i + $(3W*sizeof(T))
                $main_body
            end
        end)
    end
    for i ∈ 0:Qr-1
        push!(q.args,
        quote
            $itersym2 = $(QQ*4W*sizeof(T) + i*W*sizeof(T))
            $main_body
        end)
    end
    if r > 0
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
                    eB = (macro_escape && isa(B, Symbol)) ? esc(B) : B
                    if i == n
                        return :(vstore($eB, $pA + $iter, $mask))
                    else
                        ei = (macro_escape && isa(i, Symbol)) ? esc(i) : i
                        eA = (macro_escape && isa(A, Symbol)) ? esc(A) : A
                        return :(vstore($eB, $pA + $ei*sizeof(eltype($eA)), $mask))
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
                        return :(vload($V, $pA + $iter, $mask))
                    else
                        # when loading something not indexed by the loop variable,
                        # we assume that the intension is to broadcast
                        ei = (macro_escape && isa(i, Symbol)) ? esc(i) : i
                        return :(vbroadcast($V, unsafe_load($pA + $ei*sizeof(eltype($A)), $mask)))
                    end
                else
                    return x
                end
            end, SLEEFDictFast, macro_escape))
        end
        push!(q.args, r_body)
    end
    q
end
function vectorize_body(N::Union{Symbol, Expr}, Tsym::Symbol, n, body, macro_escape = true, define_pointers = true)
    if Tsym == :Float32
        vectorize_body(N, Float32, n, body, macro_escape, define_pointers)
    elseif Tsym == :Float64
        vectorize_body(N, Float64, n, body, macro_escape, define_pointers)
    elseif Tsym == :ComplexF32
        vectorize_body(N, ComplexF32, n, body, macro_escape, define_pointers)
    elseif Tsym == :ComplexF64
        vectorize_body(N, ComplexF64, n, body, macro_escape, define_pointers)
    else
        throw("Type $Tsym is not supported.")
    end
end
function vectorize_body(N::Union{Symbol, Expr}, T, n, body, macro_escape = true, define_pointers = true)
    T_size = sizeof(T)
    W = REGISTER_SIZE ÷ T_size
    # @show W, REGISTER_SIZE, T_size
    # @show T
    WT = W * T_size
    V = Vec{W,T}

    # @show body

    # body = _pirate(body)

    # indexed_expressions = Dict{Symbol,Expr}()
    indexed_expressions = Dict{Symbol,Symbol}() # Symbol, gensymbol
    reduction_expressions = Dict{Symbol,Symbol}() # ParamSymbol,
    # itersym = esc(gensym(:iter))
    # itersym = esc(:iter)
    # itersym = :iter
    itersym = gensym(:iter)
    i = gensym(:i)
    # walk the expression, searching for all get index patterns.
    # these will be replaced with
    # Plan: definition of q will create pointers
    main_body = quote end
    reduction_symbols = Symbol[]
    loaded_exprs = Dict{Expr,Symbol}()

    for b ∈ body
        ## body preamble must define indexed symbols
        ## we only need that for loads.
        push!(main_body.args,
            _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, b;
                            itersym = itersym, macro_escape = macro_escape, oldindex = n)
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
        QQ, Qr = divrem(Q, 4)
        if r > 0
            Qr += 1
            Q += 1
        end
    end
    macro_escape ? pushfirst!(q.args, :((Q, r) = divrem($(esc(N)), $W))) : pushfirst!(q.args, :((Q, r) = divrem($N, $W)))
    if define_pointers
        for (sym, psym) ∈ indexed_expressions
            if macro_escape
                push!(q.args, :( $(esc(psym)) = $(esc(Base.pointer))($(esc(sym))) ))
            else
                push!(q.args, :( $psym = pointer($sym) ))
            end
        end
    end
    # @show QQ, Qr, Q, r
    itersym2 = macro_escape ? esc(itersym) : itersym
    push!(q.args,
    quote
        for $i ∈ 0:$(4W*sizeof(T)):((QQ-1)*$(4W*sizeof(T)))
            $itersym2 = $i
            $main_body
            $itersym2 = $i + $(W*sizeof(T))
            $main_body
            $itersym2 = $i + $(2W*sizeof(T))
            $main_body
            $itersym2 = $i + $(3W*sizeof(T))
            $main_body
        end
        for $i ∈ 0:Qr-1
            $itersym2 = QQ*$(4WT) + $i*$WT
            $main_body
        end
    end)
    if macro_escape
        push!(q.args,
        quote
            for $(esc(n)) ∈ $(esc(N))-r+1:$(esc(N))
                $(esc.(body)...)
            end
        end)
    else
        push!(q.args,
        quote
            for $n ∈ $N-r+1:$N
                $(body...)
            end
        end)
    end
    q
end

function _vectorloads(V, expr; itersym = :iter, macro_escape = false, oldindex = nothing)


    # body = _pirate(body)

    # indexed_expressions = Dict{Symbol,Expr}()
    indexed_expressions = Dict{Symbol,Symbol}() # Symbol, gensymbol
    reduction_expressions = Dict{Symbol,Symbol}() # ParamSymbol,
    # itersym = esc(gensym(:iter))
    # itersym = esc(:iter)
    # walk the expression, searching for all get index patterns.
    # these will be replaced with
    # Plan: definition of q will create pointers
    main_body = quote end
    reduction_symbols = Symbol[]
    loaded_exprs = Dict{Expr,Symbol}()

    push!(main_body.args,
        _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, expr;
            itersym = itersym, macro_escape = macro_escape, oldindex = oldindex)
    )
    main_body
end

function _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, loaded_exprs, V, expr;
                            itersym = :iter, macro_escape = false, oldindex = nothing)
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
            eB = (macro_escape && isa(B, Symbol)) ? esc(B) : B
            if i == oldindex
                return :(vstore($eB, $pA + $itersym))
            else
                ei = (macro_escape && isa(i, Symbol)) ? esc(i) : i
                eA = (macro_escape && isa(A, Symbol)) ? esc(A) : A
                return :(vstore($eB, $pA + $ei*sizeof(eltype($eA))))
            end
        elseif @capture(x, A_[i_,j_] = B_)
            if A ∉ keys(indexed_expressions)
                pA = gensym(Symbol(:p,A))
                indexed_expressions[A] = pA
            else
                pA = indexed_expressions[A]
            end
            sym = gensym(Symbol(pA, :_, i))
            if i == oldindex
                if isa(j, Number)
                    ej = j - 1
                elseif macro_escape && isa(j, Symbol)
                    ej = :($(esc(j))-1)
                else
                    ej = :($j-1)
                end
                assignment = :($pA + $itersym + $ej*SLEEFwrap.stride_row($A))
            else
                throw("Indexing columns with vectorized loop variable is not supported.")
            end
            eB = (macro_escape && isa(B, Symbol)) ? esc(B) : B
            return :(vstore($eB, $assignment))
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
            # @show pA
            # if string(pA)[1] == "#"
            #     sym = Symbol(pA, :_, i)
            # else
            #     sym = gensym(Symbol(pA, :_, i))
            # end
            if i == oldindex
                load_expr = :(vload($V, $pA + $itersym))
            else
                ei = (macro_escape && isa(i, Symbol)) ? esc(i) : i
                load_expr = :(vbroadcast($V, unsafe_load($pA + $ei*sizeof(eltype($A)))))
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
            # @show pA
            # if string(pA)[1] == "#"
            #     sym = Symbol(pA, :_, i)
            # else
            #     sym = gensym(Symbol(pA, :_, i))
            # end
            if i == oldindex
                if isa(j, Number)
                    ej = j - 1
                elseif macro_escape && isa(j, Symbol)
                    ej = :($(esc(j))-1)
                else
                    ej = :($j-1)
                end
                if macro_escape
                    load_expr = :(vload($V, $(esc(pA)) + $(esc(itersym)) + $ej*SLEEFwrap.stride_row($(esc(A)))))
                    # push!(main_body.args, :($(esc(sym)) = vload($V, $(esc(pA)) + $(esc(itersym)) + $ej*SLEEFwrap.stride_row($(esc(A))))))
                else
                    load_expr = :(vload($V, $pA + $itersym + $ej*SLEEFwrap.stride_row($A)))
                    # push!(main_body.args, :($sym = vload($V, $pA + $itersym + $ej*SLEEFwrap.stride_row($A))))
                end
            elseif j == oldindex
                throw("Indexing columns with vectorized loop variable is not supported.")
            else
                # when loading something not indexed by the loop variable,
                # we assume that the intension is to broadcast
                ei = (macro_escape && isa(i, Symbol)) ? esc(i) : i
                if macro_escape
                    load_expr = :(vbroadcast($V, unsafe_load($pA + $ei*sizeof(eltype($(esc(A)))))))
                    # push!(main_body.args, :($sym = vbroadcast($V, unsafe_load($pA + $ei*sizeof(eltype($(esc(A))))))))
                else
                    load_expr = :(vbroadcast($V, unsafe_load($pA + $ei*sizeof(eltype($A)))))
                    # push!(main_body.args, :($sym = vbroadcast($V, unsafe_load($pA + $ei*sizeof(eltype($A))))))
                end
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
            # if isa(B, Symbol)
            #     if macro_escape
            #         eb = esc(B)
            #     else
            #         eb = B
            #     end
            # else
            #     eB = _vectorloads!(main_body, indexed_expressions, reduction_expressions, reduction_symbols, V, B;
            #                 itersym = itersym, macro_escape = macro_escape, oldindex = oldindex)
            # end
            eB = (macro_escape && isa(B, Symbol)) ? esc(B) : B
            if i == oldindex
                isym = itersym
            else
                ei = (macro_escape && isa(i, Symbol)) ? esc(i) : i
                eA = (macro_escape && isa(A, Symbol)) ? esc(A) : A
                isym = :($ei*sizeof(eltype($eA)))
            end
            # pushexpr = :( # broadcast over strides.
            #     vstore.($eB, $pA .+ $isym .+ stride_row_iter($A))
            # )
            # if macro_escape
            #
            # else
            #
            # end
            ebr = gensym(:eB)
            coliter = gensym(:j)
            numiter = gensym(:numiter)
            stridesym = gensym(:stride)
            bindA = (isa(A, Symbol) && macro_escape) ? esc(A) : A
            pushexpr = quote
                # $numiter = SLEEFwrap.num_row_strides($bindA)
                # $stridesym = SLEEFwrap.stride_row($bindA)
                $numiter = SLEEFwrap.num_row_strides($A)
                $stridesym = SLEEFwrap.stride_row($A)
                $ebr = $eB
                for $coliter ∈ 0:$numiter-1
                    SIMDPirates.vstore(getindex($ebr,1+$coliter), $pA + $isym + $stridesym * $coliter)
                end
            end

            # @show pushexpr
            # push!(main_body.args, :( # broadcast over strides.
            #     vstore.($eB, $pA .+ $isym .+ stride_row_iter($A))
            # ))
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
    end, SLEEFDictFast, macro_escape)
end



macro restrict_simd(expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, Float64, n, body, false)
        q = vectorize_body(N, Float64, n, body, true)
    # elseif @capture(expr, for n_ ∈ 1:N_ body__ end)
    #     q = vectorize_body(N, element_type(body)
    else
        throw("Could not match loop expression.")
    end
    q
end
macro restrict_simd(type, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = vectorize_body(N, type, n, body, false)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
