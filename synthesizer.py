import numpy as np
import json
import os
from scipy.io import wavfile
from scipy import signal as sig
import math
from dataclasses import dataclass
from typing import Callable, Dict, Any
import copy
import pretty_midi

# Data Structures

@dataclass
class Instrument:
    name: str
    # The function signature is: note, instrument_name, fs -> signal_array
    synthesize_func: Callable[[pretty_midi.Note, str, float], np.ndarray]

# Data Loading

def load_instrument_presets(file_path="parameters.json") -> Dict[str, Dict[str, Any]]:
    """Loads instrument presets from a JSON file."""
    try:
        with open(file_path, 'r') as f:
            raw_data = json.load(f)
    except FileNotFoundError:
        print(f"Error: {file_path} not found. Make sure it's in the same directory.")
        return {}

    instrument_presets = {}
    for key, value in raw_data.items():
        if "parameters" in value:
            instrument_presets[key] = value["parameters"]
    return instrument_presets

# Global presets, loaded once.
INSTRUMENT_PRESETS = load_instrument_presets()

# This will be populated later with Instrument objects
INSTRUMENTS: Dict[int, Instrument] = {}


# Note Synthesis

def synthesize_drum_pad(note: pretty_midi.Note, name: str = "Drumset", fs: float = 44100.0) -> np.ndarray:
    """Synthesizes a drum sound from a MIDI note."""
    preset_key = str(note.pitch)
    if preset_key not in INSTRUMENT_PRESETS:
        print(f"Warning: Drum patch for pitch {note.pitch} not found. Skipping.")
        return np.array([], dtype=np.float64)

    preset = INSTRUMENT_PRESETS[preset_key]
    velocity_scaling = note.velocity / 127.0

    # Drum sounds have a fixed duration in this implementation
    signal = synthesize(preset, seconds=0.5, fs=fs)
    return velocity_scaling * signal

def synthesize_melodic_instrument(note: pretty_midi.Note, name: str, fs: float = 44100.0) -> np.ndarray:
    """Synthesizes a melodic instrument sound from a MIDI note."""
    if name not in INSTRUMENT_PRESETS:
        print(f"Warning: Instrument preset for '{name}' not found. Skipping.")
        return np.array([], dtype=np.float64)

    params = copy.deepcopy(INSTRUMENT_PRESETS[name])

    hz = pitch_to_hz(note.pitch)
    note_duration = note.end - note.start

    attack_time = params.get("attack", 0.0)
    decay_time = params.get("decay", 0.0)
    release_time = params.get("release", 0.0)

    sustain_time = max(0, note_duration - attack_time - decay_time)
    total_duration = note_duration + release_time

    if "frequencies" in params:
        # The frequencies in the preset are harmonic multipliers
        params["frequencies"] = [hz * mult for mult in params.get("frequencies", [])]

    params["sustain_time"] = sustain_time

    velocity_scaling = exp_map(note.pitch) * (note.velocity / 127.0)

    signal = synthesize(params, seconds=total_duration, fs=fs)
    return velocity_scaling * signal

# Default instrument mapping (can be overridden by user)
# The keys correspond to track numbers (starting from 1, as in the Julia code's enumerate)
INSTRUMENTS.update({
    1: Instrument("Drumset", synthesize_drum_pad),
    2: Instrument("Flute", synthesize_melodic_instrument),
    3: Instrument("Mallet", synthesize_melodic_instrument),
    4: Instrument("Glass Harp", synthesize_melodic_instrument),
    5: Instrument("Violin", synthesize_melodic_instrument),
    6: Instrument("Piano", synthesize_melodic_instrument),
    7: Instrument("Trumpet", synthesize_melodic_instrument),
    8: Instrument("Trombone", synthesize_melodic_instrument),
    9: Instrument("Synth Bell", synthesize_melodic_instrument),
   10: Instrument("Electric Guitar", synthesize_melodic_instrument),
   11: Instrument("Bass", synthesize_melodic_instrument),
   12: Instrument("Chiptune Lead", synthesize_melodic_instrument),
})


# Global cache for synthesized notes to improve performance
SYNTH_CACHE = {}


# MIDI Synthesis

def synthesize_track(p_instrument: pretty_midi.Instrument, synth_instrument: Instrument, total_samples: int, fs: float) -> np.ndarray:
    """Synthesizes a single track from a pretty_midi instrument object."""
    track_output = np.zeros(total_samples, dtype=np.float64)

    for note in p_instrument.notes:
        # Use a cache for identical notes to speed up synthesis
        cache_key = (synth_instrument.name, note.end - note.start, note.velocity, note.pitch)
        if cache_key in SYNTH_CACHE:
            note_samples = SYNTH_CACHE[cache_key]
        else:
            note_samples = synth_instrument.synthesize_func(note, name=synth_instrument.name, fs=fs)
            SYNTH_CACHE[cache_key] = note_samples

        if note_samples.size == 0:
            continue

        note_start_sample = time_to_samples(note.start, fs)
        note_end_sample = note_start_sample + len(note_samples)

        if note_start_sample >= total_samples:
            continue

        # Ensure we don't write past the end of the track_output array
        end_index = min(note_end_sample, total_samples)
        samples_to_add = note_samples[:end_index - note_start_sample]

        track_output[note_start_sample:end_index] += samples_to_add

    return track_output

def synthesize_midi(midi_path: str, instrument_mapping: Dict[int, Instrument] = None, fs: float = 44100.0):
    """Synthesizes a MIDI file into an audio signal."""
    if instrument_mapping is None:
        instrument_mapping = INSTRUMENTS

    try:
        midi_data = pretty_midi.PrettyMIDI(midi_path)
        print(f"Successfully loaded MIDI file: {midi_path}")
    except Exception as e:
        print(f"Error loading MIDI file {midi_path}: {e}")
        return np.array([])

    # Add a buffer for release tails
    total_time_sec = midi_data.get_end_time() + 2.0
    total_samples = time_to_samples(total_time_sec, fs)

    global_output = np.zeros(total_samples, dtype=np.float64)

    for i, p_instrument in enumerate(midi_data.instruments):
        track_num = i + 1  # Use 1-based indexing for tracks

        synth_instrument = instrument_mapping.get(track_num)

        # Fallback logic if no specific instrument is mapped for the track
        if synth_instrument is None:
            if p_instrument.is_drum:
                synth_instrument = instrument_mapping.get(1)  # Default to Drumset
            else:
                synth_instrument = instrument_mapping.get(2)  # Default to Flute

        if synth_instrument is None:
            print(f"Warning: Could not find a suitable instrument for track {track_num}. Skipping.")
            continue

        print(f"Synthesizing track {track_num}: {p_instrument.name} with {synth_instrument.name}")

        track_output = synthesize_track(p_instrument, synth_instrument, total_samples, fs)

        # Special scaling for bass instruments, as in the Julia code
        if synth_instrument.name in ["8-Bit Bass", "Bass"]:
            track_output *= 4.0

        global_output += track_output

    # Final scaling to prevent clipping, as in the Julia code
    final_output = global_output / 32.0
    return normalize_signal(final_output)


# Core Synthesis Engine

def create_adsr_envelope(total_samples, fs, params):
    """Creates an ADSR envelope."""
    attack_time = params.get("attack", 0.01)
    decay_time = params.get("decay", 0.1)
    sustain_level = params.get("sustain", 0.7)
    sustain_time = params.get("sustain_time", 0.0)
    release_time = params.get("release", 0.2)

    attack_samples = time_to_samples(attack_time, fs)
    decay_samples = time_to_samples(decay_time, fs)
    sustain_samples = time_to_samples(sustain_time, fs)
    release_samples = time_to_samples(release_time, fs)

    envelope = np.zeros(total_samples)

    # Attack
    attack_end = min(attack_samples, total_samples)
    if attack_end > 0:
        envelope[:attack_end] = np.linspace(0, 1, attack_end)

    # Decay
    decay_start = attack_samples
    decay_end = min(decay_start + decay_samples, total_samples)
    if decay_end > decay_start:
        envelope[decay_start:decay_end] = np.linspace(1, sustain_level, decay_end - decay_start)

    # Sustain
    sustain_start = decay_end
    sustain_end = min(sustain_start + sustain_samples, total_samples)
    if sustain_end > sustain_start:
        envelope[sustain_start:sustain_end] = sustain_level

    # Release
    release_start = sustain_end
    release_end = min(release_start + release_samples, total_samples)
    if release_end > release_start:
        start_level = sustain_level
        if release_start > 0:
            start_level = envelope[release_start - 1]

        decay_curve = np.exp(-np.linspace(0, 5, release_end - release_start))
        envelope[release_start:release_end] = start_level * decay_curve

    return envelope

def synthesize(params, seconds=0.5, fs=44100.0):
    """Synthesizes a sound based on parameters. Renamed from synthesize_drum for clarity."""
    t = create_time_range(seconds, fs)
    signal = np.zeros_like(t, dtype=np.float64)
    total_samples = len(t)

    # Oscillators
    if "frequencies" in params:
        freqs = params.get("frequencies", [])
        if freqs: # Ensure freqs is not empty
            weights = params.get("weights", np.ones(len(freqs)) / len(freqs))
            for i, freq in enumerate(freqs):
                signal += weights[i] * np.sin(2 * np.pi * freq * t)

    # Noise
    if params.get("noise_level", 0) > 0:
        noise = get_noise(seconds, fs) * params["noise_level"]
        if "noise_cutoff" in params:
            filter_order = params.get("filter_order", 4)
            nyquist = fs / 2
            cutoff = params["noise_cutoff"]
            if cutoff < nyquist:
                b, a = sig.butter(filter_order, cutoff, btype='high', fs=fs)
                noise = sig.lfilter(b, a, noise)
        signal += noise

    # Envelope
    if total_samples > 0:
        envelope = create_adsr_envelope(total_samples, fs, params)
        signal *= envelope

    return normalize_signal(signal)


# Utility functions

def exp_map(x):
    """Exponential mapping function similar to the Julia implementation."""
    a = 0.5
    b = 4 / (108 - 21)  # Controls the decay rate
    c = 0.5
    return a * np.exp(-b * (x - 21)) + c

def time_to_samples(time_s, fs, round_method=np.round):
    """Converts time in seconds to number of samples."""
    return int(round_method(time_s * fs))

def normalize_signal(signal):
    """Normalizes a signal to the range [-1, 1]."""
    max_abs_val = np.max(np.abs(signal))
    if max_abs_val > 0:
        return signal / max_abs_val
    return signal

def create_time_range(seconds, fs):
    """Creates a time vector."""
    return np.linspace(0, seconds, time_to_samples(seconds, fs), endpoint=False)

def get_noise(seconds, fs, seed=1234):
    """Generates white noise."""
    rng = np.random.default_rng(seed)
    count = time_to_samples(seconds, fs)
    return rng.uniform(-1, 1, count)

def save_wav(signal, output_path, fs):
    """Saves a signal to a WAV file."""
    directory = os.path.dirname(output_path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    # Julia's wavwrite normalizes by default, so we do the same.
    # Also, convert to 16-bit PCM format.
    normalized_signal = normalize_signal(signal) * 32767
    wavfile.write(output_path, int(fs), normalized_signal.astype(np.int16))
    print(f"Saved sound to {output_path}")

def pitch_to_hz(pitch):
    """Converts a MIDI pitch number to frequency in Hz."""
    return 440.0 * (2.0 ** ((pitch - 69.0) / 12.0))

if __name__ == '__main__':
    import time

    # --- Example 1: Synthesize a MIDI file with default instrument mapping ---
    print("--- Running Example 1: Synthesizing with default instruments ---")
    start_time = time.time()

    # Assumes 'midi/roygbiv.mid' exists from the user's file listing
    midi_file_path = 'midi/roygbiv.mid'
    output_wav_path = 'roygbiv_py.wav'

    # Check if the MIDI file exists before trying to synthesize
    if not os.path.exists(midi_file_path):
        print(f"Error: MIDI file not found at {midi_file_path}")
        print("Skipping Example 1.")
    else:
        audio_data = synthesize_midi(midi_file_path)

        if audio_data.size > 0:
            save_wav(audio_data, output_wav_path, fs=44100.0)
            end_time = time.time()
            print(f"Synthesis complete for {midi_file_path}.")
            print(f"Output saved to {output_wav_path}")
            print(f"Synthesis time: {end_time - start_time:.2f} seconds")
        else:
            print(f"Synthesis failed for {midi_file_path}.")

    print("\n" + "="*50 + "\n")

    # --- Example 2: Synthesize with a custom instrument mapping ---
    # This mapping is similar to the 'police' function in the Julia code.
    print("--- Running Example 2: Synthesizing with a custom mapping ---")

    brooklyn99_mapping = {
        1: Instrument("Mallet", synthesize_melodic_instrument),
        2: Instrument("Bass", synthesize_melodic_instrument),
        3: Instrument("Trumpet", synthesize_melodic_instrument),
        4: Instrument("Trumpet", synthesize_melodic_instrument),
        5: Instrument("Flute", synthesize_melodic_instrument),
        6: Instrument("Flute", synthesize_melodic_instrument),
        7: Instrument("Flute", synthesize_melodic_instrument),
        8: Instrument("Glass Harp", synthesize_melodic_instrument),
        9: Instrument("Mallet", synthesize_melodic_instrument),
       10: Instrument("Violin", synthesize_melodic_instrument),
       11: Instrument("Drumset", synthesize_drum_pad),
       12: Instrument("Mallet", synthesize_melodic_instrument),
       13: Instrument("Violin", synthesize_melodic_instrument),
       15: Instrument("Drumset", synthesize_drum_pad),
    }

    start_time = time.time()
    midi_file_path_2 = 'midi/police.mid'
    output_wav_path_2_dry = 'police_dry_py.wav'
    output_wav_path_2_fx = 'police_fx_py.wav'

    if not os.path.exists(midi_file_path_2):
        print(f"Error: MIDI file not found at {midi_file_path_2}")
        print("Skipping Example 2.")
    else:
        audio_data_2 = synthesize_midi(midi_file_path_2, instrument_mapping=brooklyn99_mapping)

        if audio_data_2.size > 0:
            # Save the dry version first
            save_wav(audio_data_2, output_wav_path_2_dry, fs=44100.0)
            print(f"Dry synthesis complete for {midi_file_path_2}. Output saved to {output_wav_path_2_dry}")

            # Create "The Police" effects chain
            from pedalboard import Pedalboard, Chorus, Delay
            the_police_board = Pedalboard([
                Chorus(rate_hz=1.2, depth=0.25, mix=0.5),
                Delay(delay_seconds=0.4, feedback=0.3, mix=0.25)
            ])

            print("Applying 'The Police' effects...")
            processed_audio_2 = the_police_board(audio_data_2.astype(np.float32), sample_rate=44100.0)

            save_wav(processed_audio_2, output_wav_path_2_fx, fs=44100.0)
            end_time = time.time()
            print(f"Effects version saved to {output_wav_path_2_fx}")
            print(f"Total time for Example 2: {end_time - start_time:.2f} seconds")
        else:
            print(f"Synthesis failed for {midi_file_path_2}.")

    print("\n" + "="*50 + "\n")

    # --- Example 3: Synthesize the "salsa" song with its specific mapping ---
    print("--- Running Example 3: Synthesizing the salsa track ---")

    salsa_mapping = {
        1: Instrument("Drumset", synthesize_drum_pad),
        2: Instrument("Drumset", synthesize_drum_pad),
        3: Instrument("Trumpet", synthesize_melodic_instrument),
        4: Instrument("Mallet", synthesize_melodic_instrument),
        5: Instrument("Bass", synthesize_melodic_instrument),
        6: Instrument("Trombone", synthesize_melodic_instrument),
        7: Instrument("Trombone", synthesize_melodic_instrument),
    }

    start_time = time.time()
    midi_file_path_3 = 'midi/Lloraras.mid'
    output_wav_path_3 = 'lloraras_py.wav'

    if not os.path.exists(midi_file_path_3):
        print(f"Error: MIDI file not found at {midi_file_path_3}")
        print("Skipping Example 3.")
    else:
        audio_data_3 = synthesize_midi(midi_file_path_3, instrument_mapping=salsa_mapping)

        if audio_data_3.size > 0:
            from pedalboard import Pedalboard, Compressor, Reverb

            # Create a subtle effects chain for the salsa track
            salsa_board = Pedalboard([
                Compressor(threshold_db=-10, ratio=2.5),
                Reverb(room_size=0.6, wet_level=0.2, dry_level=0.8)
            ])

            print("Applying salsa effects...")
            processed_audio_3 = salsa_board(audio_data_3.astype(np.float32), sample_rate=44100.0)

            save_wav(processed_audio_3, output_wav_path_3, fs=44100.0)
            end_time = time.time()
            print(f"Synthesis complete for {midi_file_path_3}.")
            print(f"Output saved to {output_wav_path_3}")
            print(f"Total time: {end_time - start_time:.2f} seconds")
        else:
            print(f"Synthesis failed for {midi_file_path_3}.")

    print("\n" + "="*50 + "\n")

    # --- Example 4: Apply audio effects using pedalboard ---
    print("--- Running Example 4: Applying reverb effect ---")

    # Check if the audio data from example 1 exists
    if 'audio_data' in locals() and audio_data.size > 0:
        from pedalboard import Pedalboard, Reverb

        # Create a pedalboard with a reverb effect
        board = Pedalboard([
            Reverb(room_size=0.75, damping=0.5, wet_level=0.33, dry_level=0.4)
        ])

        print("Applying reverb...")
        # The process call requires the sample rate
        processed_audio = board(audio_data.astype(np.float32), sample_rate=44100.0)

        output_wav_path_4 = 'roygbiv_reverb_py.wav'
        save_wav(processed_audio, output_wav_path_4, fs=44100.0)
        print(f"Effect processing complete. Output saved to {output_wav_path_4}")
    else:
        print("Skipping Example 4 because the audio from Example 1 was not generated.")

    print("\n" + "="*50 + "\n")

    # --- Example 5: Create a psychedelic version of Plantasia ---
    print("--- Running Example 5: Creating psychedelic Plantasia ---")

    start_time = time.time()
    midi_file_path_5 = 'midi/Plantasia.mid'
    output_wav_path_5 = 'plantasia_psychedelic_py.wav'

    if not os.path.exists(midi_file_path_5):
        print(f"Error: MIDI file not found at {midi_file_path_5}")
        print("Skipping Example 5.")
    else:
        # 1. Synthesize the MIDI file first
        plantasia_audio = synthesize_midi(midi_file_path_5)

        if plantasia_audio.size > 0:
            from pedalboard import Pedalboard, Phaser, Delay, Reverb

            # 2. Create the "psychedelic" effects board
            psychedelic_board = Pedalboard([
                Phaser(rate_hz=1.0, depth=0.5),
                Delay(delay_seconds=0.5, feedback=0.4, mix=0.5),
                Reverb(room_size=0.8, wet_level=0.5, dry_level=0.6)
            ])

            print("Applying psychedelic effects...")
            # 3. Process the audio through the board, passing the sample rate here
            processed_audio_5 = psychedelic_board(plantasia_audio.astype(np.float32), sample_rate=44100.0)

            # 4. Save the final output
            save_wav(processed_audio_5, output_wav_path_5, fs=44100.0)
            end_time = time.time()
            print(f"Psychedelic synthesis complete for {midi_file_path_5}.")
            print(f"Output saved to {output_wav_path_5}")
            print(f"Total time: {end_time - start_time:.2f} seconds")
        else:
            print(f"Synthesis failed for {midi_file_path_5}.")
