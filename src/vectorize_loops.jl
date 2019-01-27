
"""
Arguments are
@cvectorze Type UnrollFactor forloop

The default type is Float64, and default UnrollFactor is 1 (no unrolling).
"""
macro cvectorize(expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, Float64, n, body, false)
        q = LoopVectorization.vectorize_body(N, Float64, 1, n, body, SLEEFDictFast, SIMDPirates.Vec)
    # elseif @capture(expr, for n_ ∈ 1:N_ body__ end)
    #     q = vectorize_body(N, element_type(body)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = LoopVectorization.vectorize_body(:(length($A)), Float64, 1, n, body, SLEEFDictFast, SIMDPirates.Vec)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
macro cvectorize(type::Union{Symbol,DataType}, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = LoopVectorization.vectorize_body(N, type, 1, n, body, SLEEFDictFast, SIMDPirates.Vec)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = LoopVectorization.vectorize_body(:(length($A)), type, 1, n, body, SLEEFDictFast, SIMDPirates.Vec)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
macro cvectorize(unroll_factor::Integer, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = LoopVectorization.vectorize_body(N, Float64, unroll_factor, n, body, SLEEFDictFast, SIMDPirates.Vec)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = LoopVectorization.vectorize_body(:(length($A)), Float64, unroll_factor, n, body, SLEEFDictFast, SIMDPirates.Vec)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
macro cvectorize(type, unroll_factor, expr)
    if @capture(expr, for n_ ∈ 1:N_ body__ end)
        # q = vectorize_body(N, type, n, body, true)
        q = LoopVectorization.vectorize_body(N, type, unroll_factor, n, body, SLEEFDictFast, SIMDPirates.Vec)
    elseif @capture(expr, for n_ ∈ eachindex(A_) body__ end)
        q = LoopVectorization.vectorize_body(:(length($A)), type, unroll_factor, n, body, SLEEFDictFast, SIMDPirates.Vec)
    else
        throw("Could not match loop expression.")
    end
    esc(q)
end
