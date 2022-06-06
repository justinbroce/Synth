include("adaa.jl")

function chebyshev(x,order)
    if order == 0 
        return 0
    elseif  order == 1 
        return x 
    elseif order < 21
        Tn_0 = Float64(1)
        Tn_1 = x
        Tn = Float64(0)
        for n in 2:1:order
            Tn = 2*x*Tn_1-Tn_0
            Tn_0 = Tn_1
            Tn_1= Tn
        end
        return Tn
    else
        return cos(order*acos(x))
    end
end