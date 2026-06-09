import wave
import struct
import math
import os

def make_wav(filename, base_freq, sweep_freq, duration, vol=0.5):
    sample_rate = 44100
    n_samples = int(sample_rate * duration)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setparams((1, 2, sample_rate, n_samples, 'NONE', 'not compressed'))
        for i in range(n_samples):
            t = float(i) / sample_rate
            # Pitch sweep
            f = base_freq + (sweep_freq - base_freq) * (t / duration)
            # Envelope (fast attack, exponential decay)
            envelope = math.exp(-5.0 * t / duration)
            if t < 0.01:
                envelope = t / 0.01
            
            value = math.sin(2.0 * math.pi * f * t) * envelope * vol
            value = max(-1.0, min(1.0, value))
            wav_file.writeframes(struct.pack('h', int(value * 32767.0)))

# "Pop" for sending
make_wav('d:/open/classifieds-app/frontend/assets/sounds/send.wav', 600, 1200, 0.15, 0.5)

# High pitch for mic start
make_wav('d:/open/classifieds-app/frontend/assets/sounds/mic_start.wav', 1000, 1500, 0.15, 0.4)

# Low pitch for mic stop
make_wav('d:/open/classifieds-app/frontend/assets/sounds/mic_stop.wav', 1500, 1000, 0.15, 0.4)

print("Sounds generated!")
