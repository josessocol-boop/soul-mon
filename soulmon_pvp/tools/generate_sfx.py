"""Generates placeholder sound effects (stdlib only) into assets/audio/*.wav.
Run from the project root:  python3 tools/generate_sfx.py
Replace any file with real audio of the same name; Sfx (sfx.gd) picks it up."""
import wave, struct, math, random, os
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
random.seed(5)

def noise(n, k):                      # one-pole lowpassed noise (k small = darker)
    y, out = 0.0, []
    for _ in range(n):
        y += k * (random.uniform(-1, 1) - y)
        out.append(y)
    return out

def sweep(n, f0, f1, decay):
    ph, out = 0.0, []
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-t * decay))
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] * g for p, g in parts if i < len(p)) for i in range(n)]

def env(sig, decay, attack=0.004):
    return [s * min(1.0, (i / SR) / attack) * math.exp(-(i / SR) * decay) for i, s in enumerate(sig)]

def save(name, samples, gain=0.8):
    peak = max(abs(s) for s in samples) or 1.0
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * gain * 32767)) for s in samples))

n = lambda d: int(SR * d)
save("hit_light", mix((sweep(n(0.09), 200, 90, 40), 1.0), (env(noise(n(0.09), 0.5), 60), 0.6)))
save("hit_heavy", mix((sweep(n(0.25), 120, 40, 12), 1.0), (env(noise(n(0.25), 0.4), 22), 0.9)))
save("hit_ko", mix((sweep(n(0.6), 140, 35, 7), 1.0), (env(noise(n(0.5), 0.3), 10), 0.8), (sweep(n(0.55), 520, 90, 6), 0.4)))
save("hit_super", mix((sweep(n(0.25), 1320, 1320, 16), 0.6), (sweep(n(0.25), 1760, 1760, 20), 0.4)), 0.5)
save("swing", [s * math.sin(math.pi * i / n(0.12)) for i, s in enumerate(noise(n(0.12), 0.18))], 0.5)
save("swing_special", mix(([s * math.sin(math.pi * i / n(0.22)) for i, s in enumerate(noise(n(0.22), 0.1))], 0.8),
                          (env(sweep(n(0.22), 300, 800, 6), 6), 0.5)), 0.6)
save("ultimate", mix((sweep(n(0.55), 180, 1300, 3), 0.7), (env(noise(n(0.55), 0.2), 3), 0.4),
                     ([math.sin(i / SR * 40) * 0.5 + 0.5 for i in range(n(0.55))], 0.0)), 0.7)
save("dash", [s * math.sin(math.pi * i / n(0.2)) for i, s in enumerate(noise(n(0.2), 0.07))], 0.6)
save("jump", sweep(n(0.1), 280, 540, 18), 0.5)
save("shot", mix((sweep(n(0.14), 900, 350, 14), 1.0), (sweep(n(0.14), 1800, 700, 18), 0.3)), 0.5)
save("trap_set", mix((sweep(n(0.1), 520, 200, 22), 1.0), (env(noise(n(0.08), 0.4), 50), 0.4)), 0.6)
print("wrote", len(os.listdir(OUT)), "sounds")