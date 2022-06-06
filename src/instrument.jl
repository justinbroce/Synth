include("adaa.jl")
mutable struct Instrument
    #ADSR envelope for amplitude
    envelope 
    #a function for generating a combination of sine waves or other type of waveforms
    waveform
end
using WAV

function I()
    Instrument(crapvelope,compound_midi)

end

function process(i::Instrument,samples,seconds,hz)
    norm(i.waveform(samples,seconds,hz) .* i.envelope(samples))
end

function cursed_square(seconds, hz, fs = 20000, n =10)
    t = vibes(seconds,hz,fs,1.5,3)
    sine = (n,hz) ->
      1/(2n - 1) *sin.(2π * hz * (2n - 1) * t)
    sum(sine.(1:1:n,hz))*4/π
end
function square(seconds, hz, fs = 20000, n =10)
    t = 0.0 : inv(fs) : seconds
    sine = (n,hz) ->
      1/(2n - 1) *sin.(2π * hz * (2n - 1) * t)
    sum(sine.(1:1:n,hz))*4/π
end


function saw(seconds, hz, fs = 20000, n = 10)
    t = 0.0 : inv(fs) : seconds
    sine = (n,hz) ->
      ((-1)^n) / n * sin.(2π * hz * t * n)
    -2sum(sine.(1:1:10,hz))/π
end

function crapvelope(n_samples) #we go up then we go down ;)
    min.(vcat(LinRange(0,1,n_samples÷2), LinRange(1,0,n_samples-n_samples÷2)),.5)
end

function vibes(seconds, hz,fs, vib_amp, vib_rate)
    t = 0.0 : inv(fs) : seconds
    freq_vib = hz .+ vib_amp .* sin.(t * 2π * vib_rate)
    phase_vib = zeros(length(t))
    for i in 2:length(t)
        phase_vib[i] = phase_vib[i-1] + 2π* freq_vib[i-1] / fs
    end
    phase_vib
end
function sine_midi(samples, seconds, hz, vib_amp, vib_rate)
    t = LinRange(0, seconds, samples)
    freq_vib = hz .+ vib_amp .* sin.(t * 2π * vib_rate)
    phase_vib = zeros(length(t))
    for i in 2:length(t)
        phase_vib[i] = phase_vib[i-1] + 2π* freq_vib[i-1] / (samples/seconds)
    end
    sin.(phase_vib)
end

function sin_weird_midi(samples,seconds,amplitude,hz)
    amplitude*sine_midi(samples,seconds,hz,log2(hz*(rand()+rand()))/1+2,log2(hz*(rand()+rand()))/2+4)
end
function sine_source_midi(wave_count,n, s)
     
    freqs = 0:1:(wave_count-1)

    (samples,seconds,hz) ->  sum(s.(samples,seconds,1 ./((freqs.+1) .^ n ), hz * (2 .^ freqs)))
               
end

function norm(a)
    a/maximum(a)
end

function compound_midi(samples,seconds,hz)
    f1 = sine_source_midi(24, 1.2, sin_weird_midi)
    softClipAD2(norm(f1(samples,seconds,hz)),50)
end

#test()
#test_midi()