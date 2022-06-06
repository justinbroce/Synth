include("instrument.jl")
using WAV

function test_midi()
    instr = I()
    audio    = compound_midi(28361,0.6903846729166666,440)
    envelope = crapvelope(length(audio))
    wavplay(process(instr, 28361,0.6903846729166666,440), 41000)
    
end
function test_saw()
    fs = 50000
    wavplay(saw(1, 440,fs,10), fs)
end

function test_square()
    fs = 20000
    wavplay(square(1,404,fs,14),fs)
end

function test_square_vibes()
    fs = 40000
    wavplay(cursed_square(1,880,fs,17),fs)
end
test_midi()