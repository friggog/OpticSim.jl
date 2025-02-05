module OpticSim

import Unitful
using LinearAlgebra: eigen, svd, I, qr, dot, cross, norm, det, normalize, inv
using StaticArrays
using FiniteDifferences
using BenchmarkTools
using DataFrames: DataFrame
using Images
using Base: @.
using ForwardDiff
using StringEncodings

unzip(a) = map(x -> getfield.(a, x), fieldnames(eltype(a)))

include("GlassCat/GlassCat.jl")
import OpticSim.GlassCat: plot_indices, index, polyfit_indices, absairindex, absorption, info, glassid, glassname, glassforid, isair, findglass, modelglass, glassfromMIL, GlassID

include("Matrix.jl")
include("Constants.jl")
include("Utilities.jl")
include("Geometry/Geometry.jl")
include("Optical/Optical.jl")
include("Visualization.jl")
include("TestData.jl")
include("Examples.jl")
include("Optimization/Optimizable.jl")
include("Diagnostics.jl")

include("Benchmarks.jl")
include("Data/Spectra.jl")

include("Sysimage.jl")

################################################

# This can be used to track NaN, particularly in ForwardDiff gradients, causing problems
# e.g. Diagnostics.testoptimization(lens = Examples.doubleconvex(NaNCheck{Float64}), samples = 1)

# struct NaNCheck{T<:Real} <: Real
#     val::T
#     function NaNCheck{T}(a::S) where {T<:Real, S<:Real}
#         @assert !(T <: NaNCheck)
#         new{T}(T(a))
#     end
# end
# export NaNCheck
# Base.isnan(a::NaNCheck{T}) where{T} = isnan(a.val)
# Base.isinf(a::NaNCheck{T}) where{T} = isinf(a.val)
# Base.typemin(::Type{NaNCheck{T}}) where{T} = NaNCheck{T}(typemin(T))
# Base.typemax(::Type{NaNCheck{T}}) where{T} = NaNCheck{T}(typemax(T))
# Base.eps(::Type{NaNCheck{T}}) where {T} = NaNCheck{T}(eps(T))
# Base.decompose(a::NaNCheck{T}) where {T} = Base.decompose(a.val)
# Base.round(a::NaNCheck{T}, m::RoundingMode) where {T} = NaNCheck{T}(round(a.val, m))

# struct NaNException <: Exception end

# # (::Type{Float64})(a::NaNCheck{S}) where {S<:Real} = NaNCheck{Float64}(Float64(a.val))
# (::Type{T})(a::NaNCheck{S}) where {T<:Integer,S<:Real} = T(a.val)
# (::Type{NaNCheck{T}})(a::NaNCheck{S}) where {T<:Real,S<:Real} = NaNCheck{T}(T(a.val))
# Base.promote_rule(::Type{NaNCheck{T}}, ::Type{T}) where {T<:Number} = NaNCheck{T}
# Base.promote_rule(::Type{T}, ::Type{NaNCheck{T}}) where {T<:Number} = NaNCheck{T}
# Base.promote_rule(::Type{S}, ::Type{NaNCheck{T}}) where {T<:Number, S<:Number} = NaNCheck{promote_type(T,S)}
# Base.promote_rule(::Type{NaNCheck{T}}, ::Type{S}) where {T<:Number, S<:Number} = NaNCheck{promote_type(T,S)}
# Base.promote_rule(::Type{NaNCheck{S}}, ::Type{NaNCheck{T}}) where {T<:Number, S<:Number} = NaNCheck{promote_type(T,S)}

# for op = (:sin, :cos, :tan, :log, :exp, :sqrt, :abs, :-, :atan, :acos, :asin, :log1p, :floor, :ceil, :float)
#     eval(quote
#         function Base.$op(a::NaNCheck{T}) where{T}
#             temp = NaNCheck{T}(Base.$op(a.val))
#             if isnan(temp)
#                 throw(NaNException())
#             end
#             return temp
#         end
#     end)
# end

# for op = (:+, :-, :/, :*, :^, :atan)
#     eval(quote
#         function Base.$op(a::NaNCheck{T}, b::NaNCheck{T}) where{T}
#             temp = NaNCheck{T}(Base.$op(a.val, b.val))
#             if isnan(temp)
#                 throw(NaNException())
#             end
#             return temp
#         end
#     end)
# end

# for op =  (:<, :>, :<=, :>=, :(==), :isequal)
#     eval(quote
#         function Base.$op(a::NaNCheck{T}, b::NaNCheck{T}) where{T}
#             temp = Base.$op(a.val, b.val)
#             return temp
#         end
#     end)
# end

################################################

end # module
