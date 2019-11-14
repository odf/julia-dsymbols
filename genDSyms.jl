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


function partialOrientation(ds::DSet)
    ori = zeros(int, size(ds))
    ori[1] = 1

    for D in 1 : size(ds)
        for i in 0 : dim(ds)
            Di = get(ds, i, D)
            if Di != D
                ori[Di] = -ori[D]
            end
        end
    end

    return ori
end


function isLoopless(ds::DSet)
    for i in 0 : dim(ds)
        for D in 1 : size(ds)
            if get(ds, i, D) == D
                return false
            end
        end
    end

    return true
end


function isWeaklyOriented(ds::DSet)
    ori = partialOrientation(ds)

    for i in 0 : dim(ds)
        for D in 1 : size(ds)
            Di = get(ds, i, D)
            if Di != D && ori[Di] == ori[D]
                return false
            end
        end
    end

    return true
end


function orbits(ds::DSet, i::Int)
    seen = falses(size(ds))
    result::Vector{Orbit} = []

    for D in 1 : size(ds)
        if !seen[D]
            orb = [D]
            seen[D] = true
            isChain::Bool = false

            E = D
            k = i

            while true
                Ek = get(ds, k, E)
                isChain = isChain || Ek == E
                E = Ek == 0 ? E : Ek
                k = i + i + 1 - k

                if !seen[E]
                    seen[E] = true
                    push!(orb, E)
                end

                if E == D && k == i
                    break
                end
            end

            push!(result, Orbit(i, orb, isChain))
        end
    end

    return result
end

orbits(ds::DSet) = vcat(orbits(ds, 0), orbits(ds, 1))

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
                    push!(result, DSymState(vs, curv, next + 1))
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
end


function morphism(ds::DSet, D0::Int)
    m = zeros(Int, size(ds))
    m[1] = D0
    q = [(1, D0)]

    while length(q) > 0
        D, E = popfirst!(q)

        for i in 0 : dim(ds)
            Di = get(ds, i, D)
            Ei = get(ds, i, E)

            if Di > 0 || Ei > 0
                if m[Di] == 0
                    m[Di] = Ei
                    push!(q, (Di, Ei))
                elseif m[Di] != Ei
                    return nothing
                end
            end
        end
    end

    return m
end


function automorphisms(ds::DSet)
    result::Vector{Vector{Int}} = []

    for D in 1 : size(ds)
        map = morphism(ds, D)
        if map != nothing
            push!(result, map)
        end
    end

    return result
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


for (count, ds) in enumerate(DSetGenerator(2, parse(Int, ARGS[1])))
    orbs = orbits(ds)
    vs = map(minV, orbs)
    curv = curvature(ds, orbs, vs)

    if curv < 0
        println(NumberedDSym(ds, vs, count, 1))
    else
        print(NumberedDSym(ds, vs, count, 1))
        println(" #$(curv)")

        elmMaps = automorphisms(ds)

        orbMaps = Set{Vector{Int}}()
        for m in elmMaps
            push!(orbMaps, onOrbits(m, orbs, ds))
        end
        println("# $(orbMaps)")
    end
end
