"""Original small synthesized sound effects. Python standard library only."""
import math, random, struct, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'game/assets/audio'
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
rng = random.Random(42)

def save(name, duration, sample):
    data = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        value = max(-1, min(1, sample(t, duration)))
        data.append(struct.pack('<h', int(value * 25000)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b''.join(data))

save('jump', .20, lambda t,d: math.sin(2*math.pi*(340*t+950*t*t))*math.sin(math.pi*t/d)**1.5*.45)
save('splash', .55, lambda t,d: (rng.uniform(-1,1)*.45+math.sin(2*math.pi*(130*t-60*t*t))*.2)*math.sin(math.pi*t/d)**.65*(1-t/d))
notes = [523.25,659.25,783.99,1046.5]
def victory(t,d):
    v=0
    for n,f in enumerate(notes):
        u=t-n*.13
        if 0 <= u < .52:
            env=min(u/.012,1)*math.exp(-u*6)
            v+=(math.sin(2*math.pi*f*u)+.15*math.sin(4*math.pi*f*u))*env*.24
    return v
save('victory',1.05,victory)
save('swing', .20, lambda t,d: rng.uniform(-1,1)*math.sin(math.pi*t/d)**2*.18)
save('bonk', .22, lambda t,d: (math.sin(2*math.pi*(210*t-260*t*t))*.65+rng.uniform(-1,1)*.08)*math.exp(-t*18)*min(t/.005,1))
save('poison', .60, lambda t,d: (math.sin(2*math.pi*(260*t-140*t*t))+.25*math.sin(2*math.pi*390*t))*math.sin(math.pi*t/d)**1.5*.35)
save('firefly', .38, lambda t,d: (math.sin(2*math.pi*1046.5*t)+.45*math.sin(2*math.pi*1568*t))*min(t/.008,1)*math.exp(-t*12)*.30)
print('Generated jump.wav, splash.wav, victory.wav, swing.wav, bonk.wav, poison.wav, firefly.wav')
