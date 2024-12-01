using DSP
using WAV
using Random
using JSON3
file = JSON3.read("parameters.json")

function exp_map(x::UInt8)
    a = 0.5
    b = 4 / (108 - 21)  # Controls the decay rate
    c = 0.5
    return a * exp(-b * (x - 21)) + c
end

# Utility functions

function time_to_samples(time::Float64, fs::Float64; round_method::Function = round)
    return round_method(Int, time * fs)
end

function normalize_signal(signal)
    return signal ./= maximum(abs, signal)
end

function create_time_range(seconds, fs)
    return range(0, stop=seconds, length=time_to_samples(seconds,fs))
end

function get_noise(seconds, fs)
    rng = MersenneTwister(1234)
    count = time_to_samples(seconds,fs)
    return rand!(rng, zeros(count)) .* 2 .- 1
end



# Base save function
function save_drum(signal, output_path, fs)
    mkpath(dirname(output_path))
    wavwrite(normalize_signal(signal), output_path, Fs=fs)
    println("Saved drum sound to $output_path")
end



function create_adsr_envelope(length::Int, fs::Float64, params::Dict{String, Any})
    # Get ADSR parameters with defaults
    attack_samples = time_to_samples(get(params, "attack", 0.01), fs)
    decay_samples = time_to_samples(get(params, "decay", 0.1), fs)
    sustain_level = get(params, "sustain", 0.7)
    release_samples = time_to_samples(get(params, "release", 0.2), fs)
    sustain_samples = time_to_samples(get(params, "sustain_time", 0.0), fs)
    

    # Create envelope array
    envelope = zeros(length)
    sample_counts = [attack_samples, decay_samples, sustain_samples, release_samples]
    levels = [0, 1, sustain_level, 0]  # Start and end at 0 for release

    current_sample = 1
    for i in 1:4
        n_samples = sample_counts[i]
        if n_samples > 0 && current_sample <= length
            end_sample = min(current_sample + n_samples - 1, length)
            if i == 4 # Release phase: exponential decay
                envelope[current_sample:end_sample] = envelope[current_sample-1] * exp.(-LinRange(0, 5, end_sample - current_sample + 1))

            else # other phases: linear change
                envelope[current_sample:end_sample] = LinRange(levels[i], levels[min(i+1,end)], end_sample - current_sample + 1)
            end
            current_sample = end_sample + 1
        end
    end

    return envelope
end

function synthesize_drum(params::Dict{String, Any}; seconds=0.5, fs=44100.0)
    # Create time range
    t = range(0, stop=seconds, length=time_to_samples(seconds,fs))
    signal = zeros(Float64, length(t))
    
    # Generate oscillator components using frequencies and weights
    if haskey(params, "frequencies")
        freqs = params["frequencies"]
        weights = get(params, "weights", ones(length(freqs)) ./ length(freqs)) # Default to equal weights
        sin_cache = Dict{Float64, Float64}() # Or use an array if frequencies are integers

# Inside the oscillator loop:
        twoPi = 2π .* t
        for i in eachindex(freqs)
            @inbounds signal .+= weights[i] .* sin.( freqs[i] .*  twoPi)
        end
    end
    
    # Add noise component if specified
    if haskey(params, "noise_level")
        noise = get_noise(seconds, fs) * params["noise_level"]
        if haskey(params, "noise_cutoff")
            filter_order = get(params, "filter_order", 4)
            highpass_filter = digitalfilter(Highpass(params["noise_cutoff"], fs=fs), Butterworth(filter_order))
            noise = filt(highpass_filter, noise)
        end
        signal += noise
    end
    
    # Apply ADSR envelope
    envelope = create_adsr_envelope(length(signal), fs, params)
    signal .*= envelope
    
    return normalize_signal(signal)
end







function load_drum_presets(file_path::String)::Dict{String, Dict{String, Any}}
    # Parse the JSON file into a Julia data structure
    raw_data = JSON3.read(file_path)
    
    # Convert the raw_data into the desired dictionary format
    drum_presets = Dict{String, Dict{String, Any}}()
    for (key, value) in raw_data
        parameters = Dict{String, Any}([String(k) => v for (k, v) in value[:parameters]])
        drum_presets[String(key)] = parameters # Use the numeric key as a string
    end
    
    return drum_presets
end

struct Instrument
    name::String
    synthesize::Function
end


const DRUM_PRESETS = load_drum_presets("parameters.json")
function synthesize_drum_pad(note,ms_per_tick, name::String = "Trombone", presets = DRUM_PRESETS::Dict{String, Dict{String, Any}},fs = 44100.0)
    
    preset = presets[string(note.pitch)]
    velocity = note.velocity/(127)
    return velocity.*synthesize_drum(preset,seconds =.5) # drums are a bit overpowering!
end 

function synthesize_melodic_instrument(note, ms_per_tick, name = "Trombone", fs=44100.0)
    # Create a copy of the dictionary to avoid modifying the original
    
    params = deepcopy(DRUM_PRESETS[name])
    
    hz = pitch_to_hz(note.pitch)
    note_duration = note.duration * ms_per_tick / 1000
    sustain_time = note_duration -  get(params, "attack", 0.0) - get(params,"decay", 0.0) 
    note_duration += get(params, "release", 0.0) # Adding release time

    # Adjust the frequencies in the copied dictionary
    if haskey(params, "frequencies")
       
        params["frequencies"] = [hz * mult for mult in params["frequencies"]]
    end

    # Add sustain time to the dictionary
    params["sustain_time"] = sustain_time
    
    velocity = exp_map(note.pitch)*note.velocity/ 127 # scaling based on pitch since low hz are harder to hear
    
    # Pass the dictionary directly to synthesize_drum
    return  velocity.* synthesize_drum(params; seconds=note_duration) 
end

const INSTRUMENTS = Dict{Int64, Instrument}(
    
    1 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
    2 => Instrument(
        "Flute",
        synthesize_melodic_instrument,
    ),
    3 => Instrument(
        "Mallet",
        synthesize_melodic_instrument,
    ),
    4 => Instrument(
        "Glass Harp",
        synthesize_melodic_instrument,
    ),
    5 => Instrument(
        "Violin",
        synthesize_melodic_instrument,
    ),
 
)


function save_drum_presets(file_path::String, output_dir::String, fs::Float64=44100.0)
    # Load and parse the JSON file
    raw_data = JSON3.read(file_path)
    
    # Process each drum instrument
    for (pitch, drum_data) in raw_data
        if haskey(drum_data, "name") && !isempty(drum_data["name"])
            drum_name = drum_data["name"]
            signal = synthesize_drum(Dict{String, Any}([String(k) => v for (k, v) in drum_data[:parameters]]); fs)  # Use parameters for signal generation
            output_path = joinpath(output_dir, "$(drum_name).wav")
            save_drum(signal, output_path, fs)
        else
            println("Skipping pitch $(pitch) due to missing or empty name.")
        end
    end
end




