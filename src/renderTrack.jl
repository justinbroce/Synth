using MIDI
using WAV
include("Instrument.jl")
#==
Functions to render a midi track...
I was not sure the best way to do this so I am doing it by having each tick 
have an integer amount of samples, so we don't have to worry about floating point durations.
this might make effect the pitch of our final output, so a better solution might come up later
=##
mutable struct Track
    sampleRate
    msPerTick
    duration
    audio 
    instrument
end

#midi velocity(loudness) is from 0-127 so we divide by 127 to normalize
function velocity_to_amplitude(n::Note)
    n.velocity/350.0
end

function note_to_hz(n::Note)
    pitch_to_hz(n.pitch)
end

function duration_to_seconds(t::Track, n::Note)
    n.duration * t.msPerTick /1000
end

#number of samples in each tick
function samples_per_tick(t::Track)
    (t.sampleRate * t.msPerTick/1000) |> ceil |> Int
end

function position_in_samples(t::Track, n::Note)
    samples_per_tick(t)*n.position
end

function end_position_in_samples(t::Track, n::Note)
    position_in_samples(t,n) + n.duration*samples_per_tick(t)
end

#total amount of samples for the track
function samples_per_track(t::Track)
    t.duration * samples_per_tick(t)
end

#total track length in seconds
function duration_seconds(t::Track)
    t.duration *  t.msPerTick /1000
end

function samples_per_note(t::Track, n::Note)
    n.duration * samples_per_tick(t)
end
#returns total track length in ticks
function track_length(notes)
    return maximum(( n->n.duration + n.position).(notes))
end

#creates a vector of zeros, length duration in samples
function silence(t::Track)
    t |> samples_per_track |> zeros
end

#constructor for track
function T(track, ms, sr = 41000, instrument = I())
    t = Track(sr, ms, track_length(track),[],instrument) 
    t.audio = silence(t)
    t
end
function Disp(t::Track)
    print("duration: ", duration_seconds(t), " seconds\n")
    print("samples per tick: ", samples_per_tick(t), '\n')
    print("samples per track: ", samples_per_track(t), '\n')
    print("samples per track: ", length(t.audio), '\n')

end

function appendNote!(t::Track, n::Note)
    if(n.duration==0)
        return
    end
    a = velocity_to_amplitude(n)
    hz = note_to_hz(n)
    seconds = duration_to_seconds(t,n)
    samples = samples_per_note(t,n)
    start = position_in_samples(t,n)
    stop = end_position_in_samples(t,n)-1
    a*process(t.instrument,samples,seconds,hz)
    temp = t.audio[start:stop]
    temp += a*process(t.instrument,samples,seconds,hz)
    maximum(temp) <= 1 || temp -> (x->x=x/maximum(x))
    t.audio[start:stop]=temp
end
function test()
    lacrimosa = load("lacrimosa.mid")
    
    ms = ms_per_tick(lacrimosa)
    notes = getnotes(lacrimosa,1)
    
    track = T(notes, ms, 41000)
    Disp(track)
    n1 = notes[1]
    print("duration note 1 : ", duration_to_seconds(track,n1) ,'\n')
    print("samples note 1 : ", samples_per_note(track,n1), '\n')

    print("start: ", position_in_samples(track,n1), '\n')
    print("stop: ", end_position_in_samples(track,n1), '\n')
    
end
function test1()
    lacrimosa = load("lacrimosa.mid")
    
    ms = ms_per_tick(lacrimosa)
    notes = getnotes(lacrimosa,9)
    track = T(notes, ms, 41000)
    f(x) = appendNote!(track,x)
    f.(notes)
    wavwrite(track.audio,41000, "track9.wav")
    
end
function testClouds()
    clouds = load("clouds.mid")
    
    ms = ms_per_tick(clouds)
    notes = getnotes(clouds,3)
    track = T(notes, ms, 41000)
    print(notes)
    f(x) = appendNote!(track,x)
    f.(notes)
    wavwrite(track.audio,41000, "cloud3.wav")
    
end

function testPath()
    path = load("path2.mid")
    
    ms = ms_per_tick(path)
    notes = getnotes(path,1)
    track = T(notes, ms, 41000)
    print(notes)
    f(x) = appendNote!(track,x)
    f.(notes)
    wavwrite(track.audio,41000, "path1.wav")
    
end
testPath()
#testClouds()
#test1()

#test()