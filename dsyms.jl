include("backTracker.jl")
include("dsets.jl")


struct Orbit
    index::Int
    elements::Vector{Int}
    isChain::Bool
end

Base.length(orb::Orbit) = length(orb.elements)

r(orb::Orbit) = orb.isChain ? length(orb) : div(length(orb) + 1, 2)

minV(orb::Orbit) = Int(ceil(3 / r(orb)))


struct DSym
    dset::DSet
    vs::Vector{Int}
end


Base.size(ds::DSym) = size(ds.dset)

dim(ds::DSym) = dim(ds.dset)

get(ds::DSym, i::Int, D::Int) = get(ds.dset, i, D)


struct NumberedDSym
    dsym::DSym
    count1::Int
    count2::Int
end


NumberedDSym(dset::DSet, vs::Vector{Int}, count1::Int, count2::Int) =
    NumberedDSym(DSym(dset, vs), count1, count2)

Base.size(ds::NumberedDSym) = size(ds.dsym)

dim(ds::NumberedDSym) = dim(ds.dsym)

get(ds::NumberedDSym, i::Int, D::Int) = get(ds.dsym, i, D)


function curvature(ds::DSet, orbs::Vector{Orbit}, vs::Vector{Int})
    result = -size(ds)//2

    for i in 1 : length(orbs)
        result += (orbs[i].isChain ? 1 : 2) // vs[i]
    end

    return result
end


orbits(ds::DSym) = orbits(ds.dset)

orbits(ds::NumberedDSym) = orbits(ds.dsym)


struct DSymState
    vs::Vector{Int}
    curv::Rational{Int}
    next::Int
end


struct DSymGenerator <: BackTracker{DSym, DSymState}
    dset::DSet
    orbs::Vector{Orbit}
    orbMaps::Set{Vector{Int}}

    function DSymGenerator(dset::DSet)
        orbs = orbits(dset)

        orbMaps = Set{Vector{Int}}()
        for m in automorphisms(dset)
            push!(orbMaps, onOrbits(m, orbs, dset))
        end

        return new(dset, orbs, orbMaps)
    end
end


function root(g::DSymGenerator)
    vs = map(minV, g.orbs)
    curv = curvature(g.dset, g.orbs, vs)
    return DSymState(vs, curv, 1)
end


function extract(g::DSymGenerator, st::DSymState)
    if st.next > length(g.orbs) && goodResult(g, st) && isCanonical(g, st)
        return DSym(g.dset, st.vs)
    end

    return nothing
end


function children(g::DSymGenerator, st::DSymState)
    result = []

    if st.next <= length(g.orbs)
        if st.curv < 0
            push!(result, DSymState(st.vs, st.curv, length(g.orbs) + 1))
        else
            orb = g.orbs[st.next]

            for v in st.vs[st.next] : 7
                vs = copy(st.vs)
                vs[st.next] = v
                curv = curvature(g.dset, g.orbs, vs)

                if curv >= 0 || isMinimallyHyperbolic(g.dset, g.orbs, vs)
                    push!(result, DSymState(vs, curv, st.next + 1))
                end

                if curv < 0
                    break;
                end
            end
        end
    end

    return result
end


function goodResult(g::DSymGenerator, st::DSymState)
    if st.curv <= 0
        return true
    else
        cones::Vector{Int} = []
        corners::Vector{Int} = []

        for orb in orbits(g.dset, 0, 2)
            if orb.isChain
                if length(orb.elements) == 1
                    push!(corners, 2)
                end
            else
                if length(orb.elements) == 2
                    push!(cones, 2)
                end
            end
        end

        for i in 1 : length(g.orbs)
            if st.vs[i] > 1
                if g.orbs[i].isChain
                    push!(corners, st.vs[i])
                else
                    push!(cones, st.vs[i])
                end
            end
        end
    end

    front = join(reverse(sort(cones)), "")
    middle = isLoopless(g.dset) ? "" : "*"
    back = join(reverse(sort(corners)), "")
    cross = isWeaklyOriented(g.dset) ? "" : "x"
    key = front * middle * back * cross

    goodKeys = [
        "", "*", "x",
        "532", "432", "332",
        "422", "322", "222",
        "44", "33", "22",
        "*532", "*432", "*332", "3*2",
        "*422", "*322", "*222", "2*4", "2*3", "2*2",
        "*44", "*33", "*22", "4*", "3*", "2*", "4x", "3x", "2x"
    ]

    return key in goodKeys
end


function isCanonical(g::DSymGenerator, st::DSymState)
    vs = st.vs

    for m in g.orbMaps
        if map(i -> vs[m[i]], 1 : length(vs)) > vs
            return false
        end
    end

    return true
end


function isMinimallyHyperbolic(ds::DSet, orbs::Vector{Orbit}, vs::Vector{Int})
    curv = curvature(ds, orbs, vs)

    if curv >= 0
        return false
    else
        for i in 1 : length(orbs)
            k = orbs[i].isChain ? 1 : 2
            v = vs[i]
            if v > minV(orbs[i]) && curv - k // v + k // (v - 1) < 0
                return false
            end
        end
    end

    return true
end


function onOrbits(map::Vector{Int}, orbs::Vector{Orbit}, ds::DSet)
    inOrb = zeros(Int, dim(ds), size(ds))

    for i in 1 : length(orbs)
        for D in orbs[i].elements
            inOrb[orbs[i].index + 1, D] = i
        end
    end

    orbMap = zeros(Int, length(orbs))

    for D in 1 : size(ds)
        for i in 0 : dim(ds) - 1
            orbMap[inOrb[i + 1, D]] = inOrb[i + 1, map[D]]
        end
    end

    return orbMap
end


function Base.show(io::IO, ds::NumberedDSym)
    print(io, "<$(ds.count1).$(ds.count2):$(size(ds))")
    if dim(ds) != 2
        print(io, " ", dim(ds))
    end
    print(io, ":")

    for i in 0 : dim(ds)
        if i > 0
            print(",")
        end
        for D in 1 : size(ds)
            E = get(ds, i, D)
            if E == 0 || E >= D
                if D > 1
                    print(io, " ")
                end
                print(io, E)
            end
        end
    end
    print(io, ":")

    orbs = orbits(ds)

    for i in 0 : dim(ds) - 1
        if i > 0
            print(",")
        end

        for k in 1 : length(orbs)
            if orbs[k].index == i
                if first(orbs[k].elements) > 1
                    print(io, " ")
                end
                print(io, r(orbs[k]) * ds.dsym.vs[k])
            end
        end
    end

    print(io, ">")
end
