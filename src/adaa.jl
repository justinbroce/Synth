
#=
this code is based on this post
https://jatinchowdhury18.medium.com/practical-considerations-for-antiderivative-anti-aliasing-d5847167f510

this is very similar reworking of his code for my purposes
=#

#anti derivative anti aliasing order 1
function processAD1(signal::Vector{Float64},f,f1, tolerance = 1.0e-5)

    x1 = 0.0
    returnSignal = Float64[]

    for s in signal
        if abs(s - x1) < tolerance
            push!(returnSignal, f((s + x1) / 2))
        else
            push!(returnSignal, (f1(s) - f1(x1)) / (s-x1)) 
            x1 = s  
        end
    end
    returnSignal
end
#anti derivative anti aliasing order 2
function processAD2(signal, f, f1, f2, ε=1.0e-5)
    
    returnSignal = Float64[]
    calcD(x0, x1) = abs(x0-x1) < ε ? f1((x0+x1)/2) : (f2(x0) - f2(x1)) / (x0-x1) 
    x₁ = 0.0
    x₂ = 0.0 

    for x₀ in signal
        if abs(x₀ - x₁) < ε
            x̄ = (x₀ + x₂)/2
            Δ = x̄ - x₀
            if Δ < ε
                push!(returnSignal,  f((x̄  + x₀) / 2.0))
            else    
                push!(returnSignal,  (2/Δ) * (f1(x̄) + (f2(x₀) - f2(x̄)) / Δ))
            end
        else
           push!(returnSignal, (2.0 / (x₀ - x₂)) * (calcD(x₀, x₁) - calcD(x₁, x₂)) )
           x₂ = x₁ 
           x₁ = x₀
        end
    end
    
    returnSignal
end



sc(x::Float64)::Float64 = 2*atan(x)/pi
#softClip first order anti derivative
sc1(x::Float64)::Float64 = (2x*atan(x)-log(x^2+1))/pi
#softClip second order anti derivatie
sc2(x::Float64)::Float64=(x*(-log(x^2+1))+(x^2-1)*(atan(x))+x)/pi

function softClipAD1(signal::Vector{Float64}, gain)::Vector{Float64}
    processAD2(gain*signal, sc,sc1)
end
function softClipAD2(signal::Vector{Float64}, gain)::Vector{Float64}
    processAD2(gain*signal, sc,sc1,sc2)
end
hc(x)  = abs(x) < 1 ? x : sign(x) 
hc1(x) = abs(x) < 1 ? x^2/2 : x*sign(x) - .5
hc2(x) = abs(x) < 1 ? x^3/6 : (x^2/2 + 1/6) * sign(x) - x/2 

function hardC(signal::Vector{Float64}, gain)::Vector{Float64}
    c(x,y) = (abs(x*y) < 1 && return x*y)  || return sign(x) 
    c.(signal,gain)
end    
function hardClipAD1(signal::Vector{Float64}, gain)::Vector{Float64}
    processAD1(gain*signal, hc,hc1)
end
function hardClipAD2(signal::Vector{Float64}, gain)::Vector{Float64}
    processAD2(gain*signal, hc,hc1,hc2)
end







function AD_chebyshev(order,x)
    -(x*cos(order*acos(x))+order*sqrt(1-x^2)*sin(order*acos(x)))/(-1+order^2)
end
