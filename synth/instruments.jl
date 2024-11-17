# instruments.jl
using MIDI
struct ADSRParams
    attack_time::Float64
    decay_time::Float64
    sustain_level::Float64
    release_time::Float64
end
function generate_adsr_envelope(note_duration_seconds::Float64, sample_rate::Float64, params::ADSRParams)
    # Convert times to samples
    attack_samples = floor(Int, params.attack_time * sample_rate)
    decay_samples = floor(Int, params.decay_time * sample_rate)
    release_samples = floor(Int, params.release_time * sample_rate)
    
    # Total duration in samples
    total_samples = floor(Int, note_duration_seconds * sample_rate)
    
    # Initialize envelope array
    envelope = zeros(Float64, total_samples)
    
    # Attack phase - linear ramp from 0 to 1
    attack_end = min(attack_samples, total_samples)
    if attack_end > 0
        envelope[1:attack_end] = range(0, 1, length=attack_end)
    end
    
    # Decay phase - exponential decay from 1 to sustain_level
    decay_end = min(attack_samples + decay_samples, total_samples)
    if decay_end > attack_end
        decay_range = exp.(range(0, -5, length=decay_end-attack_end+1))
        decay_range = @. 1 + (params.sustain_level - 1) * (1 - decay_range/decay_range[1])
        envelope[attack_end+1:decay_end] = decay_range[1:decay_end-attack_end]
    end
    
    # Sustain phase - constant at sustain_level
    sustain_end = max(1, total_samples - release_samples)
    if sustain_end > decay_end
        envelope[decay_end+1:sustain_end] .= params.sustain_level
    end
    
    # Release phase - exponential decay from sustain_level to 0
    if total_samples > sustain_end
        release_range = exp.(range(0, -5, length=total_samples-sustain_end+1))
        release_range = @. params.sustain_level * release_range/release_range[1]
        envelope[sustain_end+1:end] = release_range[1:total_samples-sustain_end]
    end
    
    return envelope
end

function square_wave(note, ms_per_tick, harmonics=5)
    hz = pitch_to_hz(note.pitch)
    t = 0.0 : inv(44100) : (note.duration * ms_per_tick / 1000)
    # Fourier series for square wave
    sine_term = (n, hz) -> sin.(2π * hz * t * n) / n
    (4 / π * sum(sine_term(n, hz) for n in 1:2:2harmonics))/4 # Use only odd harmonics
end

function triangle_wave(note, ms_per_tick, harmonics=5)
    hz = pitch_to_hz(note.pitch)
    t = 0.0 : inv(44100) : (note.duration * ms_per_tick / 1000)
    # Fourier series for triangle wave
    sine_term = (n, hz) -> ((-1)^((n - 1) ÷ 2)) * sin.(2π * hz * t * n) / n^2
    8 / π^2 * sum(sine_term(n, hz) for n in 1:2:2harmonics)/3 # Use only odd harmonics
end

function saw_wave(note, ms_per_tick, harmonics=5)
    hz = pitch_to_hz(note.pitch)
    t = 0.0 : inv(44100) : (note.duration * ms_per_tick / 1000)
    # Fourier series for saw wave
    sine_term = (n, hz) -> ((-1)^n) * sin.(2π * hz * t * n) / n
    -2 / π * sum(sine_term(n, hz) for n in 1:harmonics)/2
end

function getSine(note, ms_per_tick,  vib_amp = 1.6, vib_rate = 5)
    hz = pitch_to_hz(note.pitch) 
    t = 0.0 : inv(44100) : (note.duration * ms_per_tick / 1000)
    
    freq_vib = hz .+ vib_amp * sin.(2π * vib_rate * t)
    
    phase_vib = zeros(length(t))
    for i in 2:length(t)
        phase_vib[i] = phase_vib[i-1] + 2π* freq_vib[i-1] / (44100) 
    end
    sin.(phase_vib)
end

struct Instrument
    name::String
    waveform::Function
    adsr::ADSRParams

end
getSineWarmVibrato(note, ms_per_tick) = getSine(note, ms_per_tick, 3.0, 2.0)
# Some preset instruments
const INSTRUMENTS = Dict{Int64, Instrument}(
    
    1 => Instrument(
        "Piano",
        getSine,
        ADSRParams(0.02, 0.1, 0.2, 0.4)
    ),
    
    2 => Instrument(
        "Plant LEad",
        getSineWarmVibrato,
        ADSRParams(0.3, 0.4, 0.8, 0.5)
    ),
  
    3 => Instrument(
        "Bass",
        square_wave,
        ADSRParams(0.05, 0.1, 0.9, 0.1)
    ),
    4 => Instrument(
        "Piano",
        triangle_wave,
        ADSRParams(0.005, 0.1, 0.7, 0.3)
    ),
    
    5 => Instrument(
        "Synth Pad",
        getSine,
        ADSRParams(0.1, 0.1, 0.2, 0.1)
    ),
    
    6 => Instrument(
        "Bass",
        square_wave,
        ADSRParams(0.01, 0.1, 0.9, 0.9)
    )

)