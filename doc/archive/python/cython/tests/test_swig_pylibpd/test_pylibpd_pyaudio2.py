import pyaudio
import pylibpd
from pylibpd import *


class Patch:
    def __init__(self, path, channels=1, sample_rate=44800, 
                 has_input=True, has_output=True, 
                 ticks_per_bar=6, block_size=pylibpd.libpd_blocksize()):
        self.path = path
        self.channels = channels
        self.sample_rate = sample_rate
        self.has_input = has_input
        self.has_output = has_output
        self.ticks_per_bar = ticks_per_bar
        self.block_size = block_size
    
    def open(self, path=None):
        if not path:
            path = self.path

        audio = pyaudio.PyAudio()

        stream = audio.open(
            format = pyaudio.paInt16,
            channels = self.channels,
            rate = self.sample_rate,
            input = self.has_input,
            output = self.has_output,
            frames_per_buffer = self.block_size * self.ticks_per_bar)

        mgr = pylibpd.PdManager(inChannels=self.channels, outChannels=self.channels, 
                                sampleRate=self.sample_rate, ticks=1)

        pylibpd.libpd_open_patch(path)

        while True:
            try:
                data = stream.read(self.block_size)
                output = mgr.process(data)
                stream.write(bytes(output))
            except KeyboardInterrupt:
                break
        stream.close()
        audio.terminate()
        pylibpd.libpd_release()
        print('\ndone')

if __name__ == '__main__':
    p = Patch('mytest.pd')
    p.open()
