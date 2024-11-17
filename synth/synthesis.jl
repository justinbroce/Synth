include("instruments.jl")
using MIDI

function global_max_concurrent_notes(midi::MIDI.MIDIFile)
    events = Tuple{Int64, Int8}[]
    
    # Collect events from all tracks
    for track in midi.tracks
        for note in getnotes(track)
            push!(events, (note.position, 1))
            push!(events, (note.position + note.duration, -1))
        end
    end
    
    sort!(events, by = first)
    
    current_notes = 0
    max_notes = 0
    
    for (_, event_type) in events
        current_notes += event_type
        max_notes = max(max_notes, current_notes)
    end
    
    return max_notes
end
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
    
    return length_samples
end


function synthesize_track(notes, ms_per_tick, sample_rate, max_amplitude, array_length, instrument::Instrument)
    if isempty(notes)
        return zeros(Float64, array_length)
    end

    track_output = zeros(Float64, array_length)
    
    for note in notes
        # Generate the basic waveform
        note_samples = note.velocity * instrument.waveform(note, ms_per_tick) / (max_amplitude * 127)
        
        # Calculate note duration in seconds
        note_duration = note.duration * ms_per_tick / 1000
        
        # Generate ADSR envelope
        envelope = generate_adsr_envelope(note_duration, sample_rate, instrument.adsr)
        
        # Apply envelope to note samples
        note_samples = note_samples[1:length(envelope)] .* envelope
        
        # Calculate start and end positions
        note_start = ceil(Int, note.position * ms_per_tick / 1000 * sample_rate)
        note_end = min(array_length, note_start + length(note_samples) - 1)
        
        note_start = max(note_start, 1)
        track_output[note_start:note_end] += note_samples[1:(note_end - note_start + 1)]
    end
    
    return track_output
end

function synthesize_midi(midi::MIDI.MIDIFile, instrument_mapping::Dict{Int64, Instrument}=INSTRUMENTS, sample_rate::Float64=44100.0)
    ms_per_tick = MIDI.ms_per_tick(midi.tpq, MIDI.qpm(midi))
    max_amplitude = global_max_concurrent_notes(midi)
    global_length = get_global_length(midi, sample_rate)
    global_output = zeros(Float64, global_length)
    
    for (i, track) in enumerate(midi.tracks)
        notes = getnotes(track)
        if isempty(notes)
            continue
        end

        # Get instrument for this track (default to Piano if not specified)
        instrument = get(instrument_mapping, i, instrument_mapping[1])
        track_output = synthesize_track(notes, ms_per_tick, sample_rate, max_amplitude, 
                                      global_length, instrument)
        
        global_output .+= track_output
    end
    
    return global_output
end