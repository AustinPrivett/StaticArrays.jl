import Base: +, -, *, /, \

# TODO: more operators, like AbstractArray

# Unary ops
@inline -(a::StaticArray) = map(-, a)

# Binary ops
# Between arrays
@inline +(a::StaticArray, b::StaticArray) = map(+, a, b)
@inline +(a::AbstractArray, b::StaticArray) = map(+, a, b)
@inline +(a::StaticArray, b::AbstractArray) = map(+, a, b)

@inline -(a::StaticArray, b::StaticArray) = map(-, a, b)
@inline -(a::AbstractArray, b::StaticArray) = map(-, a, b)
@inline -(a::StaticArray, b::AbstractArray) = map(-, a, b)

# Scalar-array
@inline +(a::Number, b::StaticArray) = broadcast(+, a, b)
@inline +(a::StaticArray, b::Number) = broadcast(+, a, b)

@inline -(a::Number, b::StaticArray) = broadcast(-, a, b)
@inline -(a::StaticArray, b::Number) = broadcast(-, a, b)

@inline *(a::Number, b::StaticArray) = broadcast(*, a, b)
@inline *(a::StaticArray, b::Number) = broadcast(*, a, b)

@inline /(a::StaticArray, b::Number) = broadcast(/, a, b)
@inline \(a::Number, b::StaticArray) = broadcast(\, a, b)


# With UniformScaling
@generated function +(a::StaticMatrix, b::UniformScaling)
    n = size(a,1)
    newtype = similar_type(a, promote_type(eltype(a), eltype(b)))

    if size(a,2) != n
        error("Dimension mismatch")
    end

    exprs = [i == j ? :(a[$(sub2ind(size(a), i, j))] + b.λ) : :(a[$(sub2ind(size(a), i, j))]) for i = 1:n, j = 1:n]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function +(a::UniformScaling, b::StaticMatrix)
    n = size(b,1)
    newtype = similar_type(b, promote_type(eltype(a), eltype(b)))

    if size(b,2) != n
        error("Dimension mismatch")
    end

    exprs = [i == j ? :(a.λ + b[$(sub2ind(size(b), i, j))]) : :(b[$(sub2ind(size(b), i, j))]) for i = 1:n, j = 1:n]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function -(a::StaticMatrix, b::UniformScaling)
    n = size(a,1)
    newtype = similar_type(a, promote_type(eltype(a), eltype(b)))

    if size(a,2) != n
        error("Dimension mismatch")
    end

    exprs = [i == j ? :(a[$(sub2ind(size(a), i, j))] - b.λ) : :(a[$(sub2ind(size(a), i, j))]) for i = 1:n, j = 1:n]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function -(a::UniformScaling, b::StaticMatrix)
    n = size(b,1)
    newtype = similar_type(b, promote_type(eltype(a), eltype(b)))

    if size(b,2) != n
        error("Dimension mismatch")
    end

    exprs = [i == j ? :(a.λ - b[$(sub2ind(size(b), i, j))]) : :(-b[$(sub2ind(size(b), i, j))]) for i = 1:n, j = 1:n]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@inline *(a::UniformScaling, b::Union{StaticMatrix,StaticVector}) = a.λ * b
@inline *(a::StaticMatrix, b::UniformScaling) = a * b.λ
@inline \(a::UniformScaling, b::Union{StaticMatrix,StaticVector}) = a.λ \ b
@inline /(a::StaticMatrix, b::UniformScaling) = a / b.λ


# Transpose, conjugate, etc
# TODO different methods for v0.5, v0.6 (due to `RowVector`)
@inline conj(a::StaticArray) = map(conj, a)

@generated function transpose(v::StaticVector)
    n = length(v)
    newtype = similar_type(v, Size(1,n))
    exprs = [:(v[$j]) for j = 1:n]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function ctranspose(v::StaticVector)
    n = length(v)
    newtype = similar_type(v, Size(1,n))
    exprs = [:(conj(v[$j])) for j = 1:n]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function transpose(m::StaticMatrix)
    (s1,s2) = size(m)
    if s1 == s2
        newtype = m
    else
        newtype = similar_type(m, Size(s2,s1))
    end

    exprs = [:(m[$j1, $j2]) for j2 = 1:s2, j1 = 1:s1]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function ctranspose(m::StaticMatrix)
    (s1,s2) = size(m)
    if s1 == s2
        newtype = m
    else
        newtype = similar_type(m, Size(s2,s1))
    end

    exprs = [:(conj(m[$j1, $j2])) for j2 = 1:s2, j1 = 1:s1]

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end


@inline vcat(a::Union{StaticVector,StaticMatrix}) = a
@generated function vcat(a::Union{StaticVector, StaticMatrix}, b::Union{StaticVector,StaticMatrix})
    if size(a,2) != size(b,2)
        error("Dimension mismatch")
    end

    if a <: StaticVector && b <: StaticVector
        newtype = similar_type(a, Size(length(a) + length(b)))
        exprs = vcat([:(a[$i]) for i = 1:length(a)],
                     [:(b[$i]) for i = 1:length(b)])
    else
        newtype = similar_type(a, Size(size(a,1) + size(b,1), size(a,2)))
        exprs = [((i <= size(a,1)) ? ((a <: StaticVector) ? :(a[$i]) : :(a[$i,$j]))
                                   : ((b <: StaticVector) ? :(b[$(i-size(a,1))]) : :(b[$(i-size(a,1)),$j])))
                                   for i = 1:(size(a,1)+size(b,1)), j = 1:size(a,2)]
    end

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end
# TODO make these more efficient
@inline vcat(a::Union{StaticVector,StaticMatrix}, b::Union{StaticVector,StaticMatrix}, c::Union{StaticVector,StaticMatrix}) =
    vcat(vcat(a,b), c)
@inline vcat(a::Union{StaticVector,StaticMatrix}, b::Union{StaticVector,StaticMatrix}, c::Union{StaticVector,StaticMatrix}...) =
    vcat(vcat(a,b), c...)

@generated function hcat(a::StaticVector)
    newtype = similar_type(a, Size(length(a),1))
    exprs = [:(a[$i]) for i = 1:length(a)]
    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end
@inline hcat(a::StaticMatrix) = a
@generated function hcat(a::Union{StaticVector,StaticMatrix}, b::Union{StaticVector,StaticMatrix})
    if size(a,1) != size(b,1)
        error("Dimension mismatch")
    end

    exprs1 = [:(a[$i]) for i = 1:length(a)]
    exprs2 = [:(b[$i]) for i = 1:length(b)]

    newtype = similar_type(a, Size(size(a,1), size(a,2) + size(b,2)))

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs1..., exprs2...)))
    end
end
# TODO make these more efficient
@inline hcat(a::Union{StaticVector,StaticMatrix}, b::Union{StaticVector,StaticMatrix}, c::Union{StaticVector,StaticMatrix}) =
    hcat(hcat(a,b), c)
@inline hcat(a::Union{StaticVector,StaticMatrix}, b::Union{StaticVector,StaticMatrix}, c::Union{StaticVector,StaticMatrix}...) =
    hcat(hcat(a,b), c...)

@inline Base.zero{SA <: StaticArray}(a::SA) = zeros(SA)
@inline Base.zero{SA <: StaticArray}(a::Type{SA}) = zeros(SA)

@inline one{SM <: StaticMatrix}(::SM) = one(SM)
@generated function one{SM <: StaticArray}(::Type{SM})
    s = size(SM)
    if (length(s) != 2) || (s[1] != s[2])
        error("multiplicative identity defined only for square matrices")
    end
    T = eltype(SM)
    if T == Any
        T = Float64
    end
    e = eye(T, s...)
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, SM, Expr(:tuple, e...)))
    end
end

@inline eye{SM <: StaticMatrix}(::SM) = eye(SM)
@generated function eye{SM <: StaticArray}(::Type{SM})
    s = size(SM)
    if length(s) != 2
        error("`eye` is only defined for matrices")
    end
    T = eltype(SM)
    if T == Any
        T = Float64
    end
    e = eye(T, s...)
    return quote
        $(Expr(:meta, :inline))
        $(Expr(:call, SM, Expr(:tuple, e...)))
    end
end

@generated function diagm(v::StaticVector)
    T = eltype(v)
    exprs = [i == j ? :(v[$i]) : zero(T) for i = 1:length(v), j = 1:length(v)]
    newtype = similar_type(v, Size(length(v), length(v)))
    return quote
        $(Expr(:meta, :inline))
        @inbounds return $(Expr(:call, newtype, Expr(:tuple, exprs...)))
    end
end

@generated function cross(a::StaticVector, b::StaticVector)
    S = typeof(zero(eltype(a))*zero(eltype(b)))
    if length(a) === 3 && length(b) === 3
        if S <: Unsigned
            return quote
                $(Expr(:meta, :inline))
                similar_type(a, $(typeof(Signed(zero(eltype(a))*zero(eltype(b))))))((Signed(a[2]*b[3])-Signed(a[3]*b[2]), Signed(a[3]*b[1])-Signed(a[1]*b[3]), Signed(a[1]*b[2])-Signed(a[2]*b[1])))
            end
        else
            return quote
                $(Expr(:meta, :inline))
                similar_type(a, $S)((a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1]))
            end
        end
    elseif length(a) === 2 && length(b) === 2
        return quote
            $(Expr(:meta, :inline))
            promote_type(eltype(a), eltype(b))(a[1]*b[2]-a[2]*b[1])
        end
    elseif length(a) === 2 && length(b) === 2
        return quote
            $(Expr(:meta, :inline))
            promote_type(eltype(a), eltype(b))(a[1]*b[2]-a[2]*b[1])
        end
    else
        error("Cross product only defined for 3-vectors")
    end
end

@generated function dot(a::StaticVector, b::StaticVector)
    if length(a) == length(b)
        expr = :(conj(a[1]) * b[1])
        for j = 2:length(a)
            expr = :($expr + conj(a[$j]) * b[$j])
        end

        return quote
            $(Expr(:meta, :inline))
            @inbounds return $expr
        end
    else
        error("dot() expects vectors of same length. Got lengths $(length(a)) and $(length(b)).")
    end
end

@generated function vecdot(a::StaticArray, b::StaticArray)
    if length(a) == length(b)
        expr = :(conj(a[1]) * b[1])
        for j = 2:length(a)
            expr = :($expr + conj(a[$j]) * b[$j])
        end

        return quote
            $(Expr(:meta, :inline))
            @inbounds return $expr
        end
    else
        error("vecdot() expects arrays of same length. Got sizes $(size(a)) and $(size(b)).")
    end
end

@inline norm(v::StaticVector) = vecnorm(v)
@inline norm(v::StaticVector, p::Real) = vecnorm(v, p)

@inline Base.LinAlg.norm_sqr(v::StaticVector) = mapreduce(abs2, +, zero(real(eltype(v))), v)

@generated function vecnorm(a::StaticArray)
    if length(a) == 0
        return zero(real(eltype(a)))
    end

    expr = :(real(conj(a[1]) * a[1]))
    for j = 2:length(a)
        expr = :($expr + real(conj(a[$j]) * a[$j]))
    end

    return quote
        $(Expr(:meta, :inline))
        @inbounds return sqrt($expr)
    end
end

_norm_p0(x) = x == 0 ? zero(x) : one(x)

@generated function vecnorm(a::StaticArray, p::Real)
    if length(a) == 0
        return zero(real(eltype(a)))
    end

    expr = :(abs(a[1])^p)
    for j = 2:length(a)
        expr = :($expr + abs(a[$j])^p)
    end

    expr_p1 = :(abs(a[1]))
    for j = 2:length(a)
        expr_p1 = :($expr_p1 + abs(a[$j]))
    end

    return quote
        $(Expr(:meta, :inline))
        if p == Inf
            return mapreduce(abs, max, $(zero(real(eltype(a)))), a)
        elseif p == 1
            @inbounds return $expr_p1
        elseif p == 2
            return vecnorm(a)
        elseif p == 0
            return mapreduce(_norm_p0, +, $(zero(real(eltype(a)))), a)
        else
            @inbounds return ($expr)^(inv(p))
        end
    end
end

@inline Base.normalize(a::StaticVector) = inv(vecnorm(a))*a
@inline Base.normalize(a::StaticVector, p::Real) = inv(vecnorm(a, p))*a

@inline Base.normalize!(a::StaticVector) = (a .*= inv(vecnorm(a)))
@inline Base.normalize!(a::StaticVector, p::Real) = (a.*= inv(vecnorm(a, p)))


@generated function trace(a::StaticMatrix)
    s = size(a)
    if s[1] != s[2]
        error("matrix is not square")
    end

    if s[1] == 0
        return zero(eltype(a))
    end

    exprs = [:(a[$(sub2ind(s, i, i))]) for i = 1:s[1]]
    total = reduce((ex1, ex2) -> :($ex1 + $ex2), exprs)

    return quote
        $(Expr(:meta, :inline))
        @inbounds return $total
    end
end

@inline Size{T,SA<:StaticArray}(::Union{Symmetric{T,SA}, Type{Symmetric{T,SA}}}) = Size(SA)
@inline Size{T,SA<:StaticArray}(::Union{Hermitian{T,SA}, Type{Hermitian{T,SA}}}) = Size(SA)

# some micro-optimizations
@inline Base.LinAlg.checksquare{SM<:StaticMatrix}(::SM) = _checksquare(Size(SM))
@inline Base.LinAlg.checksquare{SM<:StaticMatrix}(::Type{SM}) = _checksquare(Size(SM))

@pure _checksquare{S}(::Size{S}) = (S[1] == S[2] || error("marix must be square"); S[1])

@inline Base.LinAlg.Symmetric(A::StaticMatrix, uplo::Char='U') = (Base.LinAlg.checksquare(A);Symmetric{eltype(A),typeof(A)}(A, uplo))
@inline Base.LinAlg.Hermitian(A::StaticMatrix, uplo::Char='U') = (Base.LinAlg.checksquare(A);Hermitian{eltype(A),typeof(A)}(A, uplo))
