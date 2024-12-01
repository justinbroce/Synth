include("synthesis_v2.jl")



function test_instruments()
    # Ensure output directory exists
    mkpath("output/instruments")

    # Load the MIDI file and get track 2
    midi = load("test_midi.mid")
    track = midi.tracks[2]
    notes = getnotes(track)
    
    # Calculate timing parameters once
    sample_rate = 44100.0
    ms_per_tick = MIDI.ms_per_tick(midi.tpq, MIDI.qpm(midi))
    global_length = get_global_length(midi, sample_rate)

    # Define the instruments to test
    test_instruments = Dict(
        1 => Instrument("Violin", synthesize_melodic_instrument),
        2 => Instrument("Piano", synthesize_melodic_instrument),
        3 => Instrument("Trumpet", synthesize_melodic_instrument),
        4 => Instrument("Trombone", synthesize_melodic_instrument),
        6 => Instrument("Flute", synthesize_melodic_instrument),
        7 => Instrument("Glass Harp", synthesize_melodic_instrument),
        8 => Instrument("Wind Chimes", synthesize_melodic_instrument),
        9 => Instrument("Synth Bell", synthesize_melodic_instrument),
        10 => Instrument("Ethereal Pad", synthesize_melodic_instrument),
        11 => Instrument("Plucked String", synthesize_melodic_instrument),
        12 => Instrument("Bass", synthesize_melodic_instrument),
        13 => Instrument("Electric Guitar", synthesize_melodic_instrument),
        
        15 => Instrument("Muted Guitar", synthesize_melodic_instrument),
        
    )

    # Iterate through each instrument
    for (track_num, instrument) in test_instruments
        # Synthesize the track with the current instrument
        track_output = synthesize_track(
            notes, 
            ms_per_tick, 
            sample_rate, 
            global_length, 
            instrument
        )
        
        # Write to WAV file
        output_filename = "output/instruments/$(instrument.name)_track.wav"
        wavwrite(track_output, sample_rate, output_filename)
        
        println("Generated $(instrument.name) track: $output_filename")
    end
end


function test()
  
    
    file2 = load("../midi/Vordhosbn.mid")
    synth_time = @elapsed begin
        audio_data = synthesize_midi(file2)
    end
    wavwrite(audio_data, 44100, "Vordhosbn.wav")
    print("Synthesis time: $(round(synth_time, digits=2)) seconds")
end

function testDay()
    beatles = Dict{Int64, Instrument}(
    
    2 => Instrument(
        "Electric Guitar",
        synthesize_melodic_instrument,
    ),
    3 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
    4 => Instrument(
        "Mallet",
        synthesize_melodic_instrument,
    ),
    5 => Instrument(
        "Trumpet",
        synthesize_melodic_instrument,
    ),
    6 => Instrument(
      "Bass",
        synthesize_melodic_instrument,
    ),
    7 => Instrument(
        "Flute",
        synthesize_melodic_instrument,
    ),
    8 => Instrument(
        "Violin",
        synthesize_melodic_instrument,
    ),
    9 => Instrument(
        "Trombone",
        synthesize_melodic_instrument,
    ),
    10 => Instrument(
        "Flute",
        synthesize_melodic_instrument,
    ),
    11 => Instrument(
      "Drumset",
        synthesize_drum_pad,
    ),
    12 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
    13 => Instrument(
        "Trombone",
        synthesize_drum_pad,
    ),
    14 => Instrument(
        "Trumpet",
        synthesize_melodic_instrument,
    ),
    15 => Instrument(
        "Trumpet",
        synthesize_melodic_instrument,
    ),
)
     
    file2 = load("../midi/day.mid")
    
    synth_time = @elapsed begin
        audio_data = synthesize_midi(file2, beatles)
    end
   
    wavwrite(audio_data, 44100, "day.wav")
    print("Synthesis time: $(round(synth_time, digits=2)) seconds")
    
end
function police()
    brooklyn99 = Dict{Int64, Instrument}(
    
    1 => Instrument(
        "Mallet",
        synthesize_melodic_instrument,
    ),
    2 => Instrument(
        "Bass",
        synthesize_melodic_instrument
    ),
    3 => Instrument(
        "Trumpet",
        synthesize_melodic_instrument,
    ),
    4 => Instrument(
        "Trumpet",
        synthesize_melodic_instrument,
    ),
    5 => Instrument(
        "Flute",
        synthesize_melodic_instrument,
    ),
    6 => Instrument(
        "Flute",
        synthesize_melodic_instrument,
    ),
    7 => Instrument(
        "Flute",
        synthesize_melodic_instrument,
    ),
    8 => Instrument(
        "Glass Harp",
        synthesize_melodic_instrument,
    ),
    9 => Instrument(
        "Mallet",
        synthesize_melodic_instrument,
    ),
    10 => Instrument(
        "Violin",
        synthesize_melodic_instrument,
    ),
    11 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
    12 => Instrument(
        "Mallet",
        synthesize_melodic_instrument,
    ),
    13 => Instrument(
        "Violin",
        synthesize_melodic_instrument,
    ),
    15 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
)
    file2 = load("../midi/police.mid")
    synth_time = @elapsed begin
        audio_data = synthesize_midi(file2, brooklyn99)
    end
    wavwrite(audio_data, 44100, "police.wav")
    print("Synthesis time: $(round(synth_time, digits=2)) seconds")
end
function salsa()
   
    LLORARAS = Dict{Int64, Instrument}(
    
    1 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
    2 => Instrument(
        "Drumset",
        synthesize_drum_pad,
    ),
    3 => Instrument(
        "Trumpet",
        synthesize_melodic_instrument,
    ),
    4 => Instrument(
        "Mallet",
        synthesize_melodic_instrument,
    ),
    5 => Instrument(
        "Bass",
        synthesize_melodic_instrument,
    ),
    6 => Instrument(
        "Trombone",
        synthesize_melodic_instrument,
    ),
    7 => Instrument(
        "Trombone",
        synthesize_melodic_instrument,
    ),
 
)
    
    file2 = load("../midi/Lloraras.mid")
    audio_data = synthesize_midi(file2, LLORARAS)
    
    wavwrite(audio_data, 44100, "lloraras.wav")
  
    
end

# Example instrument mapping based on provided instruments
function get_instrument_mapping(tracks)
    # Define mapping rules: keywords and their corresponding instruments
    mapping_rules = Dict(
        "Contrabass" => Instrument("8-Bit Bass", synthesize_melodic_instrument),
        "Bass" => Instrument("8-Bit Bass", synthesize_melodic_instrument),
        "Piano" => Instrument("Chiptune Lead", synthesize_melodic_instrument),
        "Synthesizer" => Instrument("Retro Synth Pad", synthesize_melodic_instrument),
        "Brass" => Instrument("Square Wave Arp", synthesize_melodic_instrument),
        "Drum" => Instrument("Drumset", synthesize_drum_pad),
        "Guitar" => Instrument("Chiptune Lead", synthesize_melodic_instrument),
        "Voice" => Instrument("Square Wave Arp", synthesize_melodic_instrument),
        "Boy Soprano" => Instrument("Square Wave Arp", synthesize_melodic_instrument)
    )

    # Initialize a dictionary to store the track-to-instrument mapping
    mapping = Dict{Int, Instrument}()

    # Map tracks to instruments based on their names
    for (i, track) in enumerate(tracks)
        track_name = trackname(track)
        instrument_assigned = false

        # Check track name for keywords
        for (keyword, instrument) in mapping_rules
            if occursin(keyword, track_name)
                mapping[i] = instrument
                instrument_assigned = true
                break
            end
        end

        # Assign a default instrument if no match is found
        if !instrument_assigned
            mapping[i] = Instrument("Default", synthesize_melodic_instrument)
        end
    end

    return mapping
end

function process_midi_to_wav(file_path, output_file)
    # Load MIDI file
    midi_file = load(file_path)
    tracks = midi_file.tracks

    # Generate track-to-instrument mapping
    mapping = get_instrument_mapping(tracks)

    # Synthesize audio and write to a WAV file
    audio_data = synthesize_midi(midi_file, mapping)
    wavwrite(audio_data, 44100, output_file)

    println("Synthesis complete. Saved to $output_file.")
end



# Process the Roygbiv MIDI file
process_midi_to_wav("../midi/roygbiv.mid", "roygbiv.wav")
salsa()
police()
test()
testDay()
#test_instruments()