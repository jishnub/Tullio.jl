
#========== backward gradient using ForwardDiff ==========#

function insert_forward_gradient(create, apply!, store)
    store.verbose && @info "using ForwardDiff for $create ~ $(store.right[])"

    dZ = Symbol(DEL, ZED)
    ∇apply! = Symbol(:∇, apply!)
    gradarrays = map(A -> Symbol(DEL, A), store.arrays)
    gradarrays = map(A -> Symbol(DEL, A), store.arrays)
    # gradscalars = map(A -> Symbol(DEL, A), store.scalars)
    nonshared = setdiff(vcat(store.leftind, store.redind), store.sharedind)
    axislist = map(i -> Symbol(AXIS, i), vcat(store.sharedind, nonshared))

    epsilondict = Dict{Symbol,Expr}()

    epsilonright = MacroTools_postwalk(epsilonwalk(epsilondict), store.right[])
    # epsilonright = MacroTools_postwalk(epsilonwalk(epsilondict, store.scalars), store.right[])

    defineepsilons, readepsilons = [], []
    for (d, (Aepsilon, Aex)) in enumerate(epsilondict)
        basis = [i==d ? :(one($TYP)) : :(zero($TYP)) for i in 1:length(epsilondict)]
        push!(defineepsilons, :($Aepsilon = ForwardDiff.Dual(zero($TYP), ($(basis...),))))
        push!(readepsilons, :($Aex = $Aex + ForwardDiff.partials($ZED, $d) * $dZ[$(store.leftraw...)]))
    end

    ex_iter = :($ZED = $(epsilonright); $(readepsilons...))

    make_many_workers(∇apply!,
        vcat(gradarrays, :($dZ::AbstractArray{$TYP}), store.arrays, store.scalars, axislist),
        # vcat(gradarrays, gradscalars, :($dZ::AbstractArray{$TYP}), store.arrays, store.scalars, axislist),
        :(($(defineepsilons...);)), store.sharedind, nothing, nonshared, ex_iter, nothing, store)

end

epsilonwalk(dict) = ex -> begin
# epsilonwalk(dict, scalars) = ex -> begin
#         ex isa Symbol && ex in scalars && return scalarplusepsilon(ex, dict)
        @capture_(ex, A_[inds__]) || return ex
        return arrayplusepsilon(A, inds, dict)
    end

arrayplusepsilon(A::Symbol, inds, dict) = begin # the same array may occur twice!
    Aepsilon = Symbol(EPS, A)
    while haskey(dict, Aepsilon)
        Aepsilon = Symbol(Aepsilon, "′")
    end
    dict[Aepsilon] = :( $(Symbol(DEL, A))[$(inds...)] )
    :(( $A[$(inds...)] + $Aepsilon ))
end
arrayplusepsilon(A, inds, dict) = begin
    @debug "expression ", string(A), " is why you can't use ForwardDiff here"
    :🐳
end

# scalarplusepsilon(A::Symbol, dict) = begin
#     Aepsilon = Symbol(EPS, A)
#     dict[Aepsilon] = Symbol(DEL, A)
#     :(( $A + $Aepsilon ))
# end

#========== the end ==========#