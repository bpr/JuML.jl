struct GroupStats{N, U, S} 
    keyvars::NTuple{N, StatVariate}
    covariate::Nullable{AbstractCovariate}
    stats::Dict{NTuple{N, U}, S}
end

function getgroupstats(factors::NTuple{N, AbstractFactor}; slicelength::Integer = SLICELENGTH) where {N}
    U = promote_type(map((s -> eltype(s)), factors)...)
    u = zero(U)
    fromobs = 1
    toobs = length(factors[1])
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    if N == 1
        slices = zip(slice(factors[1], fromobs, toobs, slicelength))
    elseif N == 2
        slices = zip(slice(factors[1], fromobs, toobs, slicelength), slice(factors[2], fromobs, toobs, slicelength))
    elseif N == 3
        slices = zip(slice(factors[1], fromobs, toobs, slicelength), slice(factors[2], fromobs, toobs, slicelength), slice(factors[3], fromobs, toobs, slicelength))
    else
        slices = zip(map((s -> slice(s, fromobs, toobs, slicelength)), factors))
    end
    dict = fold(Dict{NTuple{N, U}, Int64}(), slices) do d, slice
        if N == 1
            @inbounds for i in 1:length(slice[1])
                v = slice[i]
                d[v] = get(d, (v, ), 0) + 1
            end
        elseif N == 2
            slice1, slice2 = slice
            @inbounds for i in 1:length(slice1)
                v = oftype(u, slice1[i]), oftype(u, slice2[i])
                d[v] = get(d, v, 0) + 1
            end          
        elseif N == 3
            slice1, slice2, slice3 = slice
            @inbounds for i in 1:length(slice1)
                v = oftype(u, slice1[i]), oftype(u, slice2[i]), oftype(u, slice3[i])
                d[v] = get(d, v, 0) + 1
            end
        else
            for i in 1:length(slice[1])
                v = map((x -> oftype(u, x[i])), slice)
                d[v] = get(d, v, 0) + 1
            end
        end
        d
    end
    GroupStats{N, U, Int64}(factors, Nullable(), dict)
end

function getgroupstats(factors::AbstractFactor...; slicelength::Integer = SLICELENGTH) 
    getgroupstats(factors; slicelength = slicelength)
end

function getgroupstats(cov::AbstractCovariate{S}, factors::NTuple{N, AbstractFactor}; slicelength::Integer = SLICELENGTH) where {N} where {S<:AbstractFloat}
    U = promote_type(map((s -> eltype(s)), factors)...)
    u = zero(U)
    fromobs = 1
    toobs = length(factors[1])
    slicelength = verifyslicelength(fromobs, toobs, slicelength)  
    slices = zip(map((s -> slice(s, fromobs, toobs, slicelength)), factors))
    covslices = slice(cov, fromobs, toobs, slicelength)
    zipslices = zip(slices, covslices)
    dict = fold(Dict{NTuple{N, U}, CovariateStats}(), zipslices) do d, zipslice
        slice, covslice = zipslice
        for i in 1:length(slice[1])
            y = map((x -> oftype(u, x[i])), slice)
            v = covslice[i]
            if !(y in keys(d))
                covstats = CovariateStats(0, 0, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64, NaN64)
                d[y] = covstats
            else
                covstats = d[y]
            end
            covstats.obscount += 1
            if isnan(v)
                covstats.nancount += 1
            else
                if isnan(covstats.sum)
                    covstats.sum = v
                    covstats.sum2 = v * v
                    covstats.min = v
                    covstats.max = v
                else
                    covstats.sum += v
                    covstats.sum2 += v * v
                    if v < covstats.min
                        covstats.min = v
                    end
                    if v > covstats.max
                        covstats.max = v
                    end
                end
            end
        end
        d
    end
    for (_, stats) in dict
        stats.nanpcnt = 100.0 * stats.nancount / stats.obscount
        stats.mean = stats.sum / (stats.obscount - stats.nancount)
        stats.std = sqrt(((stats.sum2 - stats.sum * stats.sum / (stats.obscount - stats.nancount)) / (stats.obscount - stats.nancount - 1)))
    end
    GroupStats{N, U, CovariateStats}(factors, Nullable(cov), dict)
end

function getgroupstats(cov::AbstractCovariate{S}, factors::AbstractFactor...; slicelength::Integer = SLICELENGTH) where {S<:AbstractFloat}
    getgroupstats(cov, factors; slicelength = slicelength)
end
