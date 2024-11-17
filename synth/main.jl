include("synthesis.jl")
using WAV

function test()
    midi_files = ["../midi/Plantasia.mid", "../midi/henry-avril_14th.mid"]
    
    # Custom instrument mapping for specific tracks
    custom_instruments = Dict{Int64, Instrument}(
        1 => INSTRUMENTS[1],  
        2 => INSTRUMENTS[2],  
        3 => INSTRUMENTS[3],   
        4 => INSTRUMENTS[4], 
        5 => INSTRUMENTS[5], 
        6 => INSTRUMENTS[6]  
    )
    
    for path in midi_files
        println("Processing: $path")
        midi_data = MIDI.load(path)
        
        synth_time = @elapsed begin
            audio_data = synthesize_midi(midi_data, custom_instruments)
        end

        wav_filename = replace(path, r"\.mid$" => ".wav")
        wavwrite(audio_data, 44100, wav_filename)
        
        println("Synthesis time: $(round(synth_time, digits=2)) seconds")
        println("Saved as: $wav_filename")
        println("----------")
    end
end



# Create a C major scale MIDI file for testing
function create_scale_midi()
    midi = MIDIFile()
    track = MIDITrack()

    
    
    # C major scale notes (C4 to C5)
    c_major_pitches = [60, 62, 64, 65, 67, 69, 71, 72]  # C D E F G A B C
    
    notes = Notes()
    position = 0
    velocity = 100
    
    # First note: whole note (4 beats = 3840 ticks)
    note = Note(c_major_pitches[1], velocity, position, 3840)
    push!(notes, note)
    position += 3840
    
    # Rest of the scale with swing pattern
    for (i, pitch) in enumerate(c_major_pitches[2:end])
        # Alternate between longer (dotted quarter = 1440) and shorter (eighth = 480) notes
        duration = i % 2 == 1 ? 1440 : 480
        note = Note(pitch, velocity, position, duration)
        push!(notes, note)
        position += duration
    end
    
    addnotes!(track, notes)
    addtrackname!(track, "Test Scale")
    push!(midi.tracks, track)
    
    mkpath("test_output")
    save("test_output/test_scale.mid", midi)
    return midi
end




# Run all tests
function run_all_tests()
    println("Starting synthesizer tests...")
    println("==============================")
    
    
    test_plantasia_combinations()
    
    println("\nTests completed!")
end

# Run the tests
test()