"""
    BackTracker{R, S}

Supertype for tree-based enumeration algorithms, a.k.a. backtracking.

A tree-based enumeration algorithm relies on an implicit enumeration tree of
which only a small portion is made explicit in storage at any given time.
Nodes are labelled by instances of the parameter type `S` (the node state).
The tree itself is then specified by the state assigned to the root as
produced by the `root` function, and a function `children` that for a given
node state computes the list of corresponding child node states.

The enumeration itself is performed by traversing this tree. For each node
visited during the traversal, the `extract` function determines whether it
corresponds to a finished result or an intermediate, unfinished state.  In
the former case, `extract` then produces a result of type `R` from the node
state of type `S`.

See also: [`extract`](@ref) [`root`](@ref) [`children`](@ref)

# Example

    # A backtracking enumerator for integer partitions.

    struct PState
        xs::Vector{Int}
        left::Int
        top::Int
    end

    struct Partitions <: BackTracker{Vector{Int}, PState}
        n::Int
    end

    extract(p::Partitions, st::PState) = st.left == 0 ? st.xs : nothing

    root(p::Partitions) = PState([], p.n, 1)

    children(p::Partitions, st::PState) = map(
        i -> PState(vcat(st.xs, [i]), st.left - i, max(st.top, i)),
        st.top : st.left
    )

    # Print the partitions of the number 10.

    for p in Partitions(10)
        println(p)
    end
"""
abstract type BackTracker{R, S} end


"""
    extract(bt::BackTracker{R, S}, st::S) -> R

Return the result for the state `st`, if available, otherwise `nothing`.

The state `st` in the context of the backtracker `bt` may correspond to a
finished enumeration result, which is then returned, or a partial result, in
which case `nothing` is returned.

See also: [`BackTracker`](@ref) [`root`](@ref) [`children`](@ref)
"""
function extract(bt::BackTracker{R, S}, st::S)::R where {R, S}
    return R()
end


"""
    root(bt::BackTracker{R, S}) -> S

Return the root state of the enumeration tree for the backtracker `bt`.

See also: [`BackTracker`](@ref) [`extract`](@ref) [`children`](@ref)
"""
function root(bt::BackTracker{R, S})::S where {R, S}
    return S()
end


"""
    children(bt::BackTracker{R, S}, st::S) -> Vector{S}

Return the list of child states for the node state `st`.

See also: [`BackTracker`](@ref) [`extract`](@ref) [`root`](@ref)
"""
function children(bt::BackTracker{R, S}, st::S)::Vector{S} where {R, S}
    return []
end


"""
    iterate(bt::BackTracker{R, S} [, stack::Vector{Vector{S}}]) ->
        Union{Nothing, Tuple{R, Vector{Vector{S}}}}

Return the next result as according to Julia's iteration protocol.

The implicit enumeration tree defined by the backtracker `bt` is traversed
depth-first until either the next result is produced, in which case it is
returned together with the current tree position, or the traversal
terminates, in which case `nothing` is returned.

The tree position is stored as a vector representing the path from the root
to the current node, where for each node in the path, the children not yet
visited in the traversal are listed in reverse order.  This representation
is thus of type `Vector{Vector{S}}`, and functions effectively as a stack of
stacks.

It is important to note that in this particular implementation, the stack
representing the tree position is modified in place, so that in order to save
the current tree position and reuse it elsewhere, a deep copy will have to be
made.

See also: [`BackTracker`](@ref)
"""
function Base.iterate(
    bt::BackTracker{R, S},
    stack::Vector{Vector{S}}=[[root(bt)]]
)::Union{Nothing, Tuple{R, Vector{Vector{S}}}} where {R, S}

    # Keep going until we find a result or the traversal is complete.
    while length(stack) > 0

        # Grab the current node and compute its value and children.
        current::S = last(last(stack))
        value::Union{Nothing, R} = extract(bt, current)
        next::Vector{S} = children(bt, current)

        # Does the current node have children?
        if length(next) > 0
            # Yes, hop up onto the next level.
            push!(stack, reverse(next))
        else
            # No, drop down to the highest level with unvisited children.
            while length(stack) > 0 && length(last(stack)) < 2
                pop!(stack)
            end

            # Remove the entry for the branch we just dropped down from.
            if length(stack) > 0
                pop!(last(stack))
            end
        end

        # If we have found a result, return it with our new position.
        if value != nothing
            return (value, stack)
        end
    end

    # If we get here, the traversal, and thus the enumeration, is complete.
    return nothing
end


"""
    eltype(::Type{BackTracker{R, S}})

Return the element type of the given backtracker type, i.e. `R`.

This is as specified in Julia's iterator protocol and can help with type
inference.

See also: [`BackTracker`](@ref)
"""
Base.eltype(::Type{BackTracker{R, S}}) where {R, S} = R
