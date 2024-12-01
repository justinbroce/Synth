using JSON3
using Profile
using MIDI

include("instruments_v2.jl")
function get_global_length(midi::MIDI.MIDIFile, sample_rate::Float64=44100.0)
    ms_per_tick = MIDI.ms_per_tick(midi.tpq, MIDI.qpm(midi))
    
    # Find the latest ending note across all tracks
    max_position = 0
    for track in midi.tracks
        if !isempty(getnotes(track))
            track_max = maximum(note.position + note.duration for note in getnotes(track))
            max_position = max(max_position, track_max)
        end
    end
    
    # Convert to samples
    duration_ms = ms_per_tick * max_position
    duration_seconds = duration_ms / 1000.0
    length_samples = ceil(Int64, duration_seconds * sample_rate)
    
    return length_samples+44100# accepting up to a 1 second release
end
const SYNTH_CACHE = Dict{Tuple{String, Float64, Float64, UInt8}, Vector{Float64}}()
function synthesize_track(notes, ms_per_tick, sample_rate, array_length, instrument::Instrument)
    isempty(notes) && return zeros(Float64, array_length) # Short-circuit for empty notes

    track_output = zeros(Float64, array_length)
    precomputed_factor = ms_per_tick / 1000 * sample_rate

    for note in notes
        cache_key = (instrument.name, note.duration, note.velocity, note.pitch)
        note_samples = get!(SYNTH_CACHE, cache_key) do
            instrument.synthesize(note, ms_per_tick, instrument.name)
        end
        
        note_start = ceil(Int, note.position * precomputed_factor) 
        note_end = min(array_length, note_start + length(note_samples) - 1)
        note_start = max(note_start, 1)

        # Use faster addition with @view
        @views track_output[note_start:note_end] .+= @views note_samples[1:(note_end - note_start + 1)] 
    end
    
    return track_output
end
function synthesize_midi(midi::MIDI.MIDIFile, instrument_mapping::Dict{Int64, Instrument}=INSTRUMENTS, sample_rate::Float64=44100.0)
    ms_per_tick = MIDI.ms_per_tick(midi.tpq, MIDI.qpm(midi))
    global_length = get_global_length(midi, sample_rate)
    global_output = zeros(Float64, global_length)
   
    for (i, track) in enumerate(midi.tracks)
        notes = getnotes(track)
        if isempty(notes) continue end

        # Get instrument for this track (default to instrument 2 in the mapping
        instrument = get(instrument_mapping, i, instrument_mapping[2])

        track_output = synthesize_track(notes, ms_per_tick, sample_rate,
                                      global_length, instrument)
        #wavwrite(track_output, 44100, "outputs/test_stems/$(instrument.name)$(i).wav")
        if (instrument.name == "8-Bit Bass") ||(instrument.name == "Bass")
            track_output = 4 .* track_output    
        end
        global_output .+= track_output
    end
    
    return global_output/32
end


