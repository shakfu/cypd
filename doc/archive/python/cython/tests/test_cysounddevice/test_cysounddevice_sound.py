import time
import numpy as np

from cysounddevice import PortAudio
from cysounddevice import types
from cysounddevice.types import SampleTime
from cysounddevice.utils import PortAudioError

from pd import PatchManager

N_TICKS = 1
SAMPLE_RATE = 44100
CHANNELS_IN = 0
CHANNELS_OUT = 2
BLOCKSIZE = 64

DURATION = 2

class Patch(PatchManager):
    def __init__(self, name='test2.pd', dir='.', 
            sample_rate=44100, ticks=1,
            in_channels=0, out_channels=2):
        self.name = name.encode('UTF-8')
        self.dir = dir.encode('UTF-8')
        self.sample_rate = sample_rate
        self.ticks = ticks
        self.in_channels = in_channels
        self.out_channels = out_channels

    def config_stream(self, stream, play_duration):
        block_size = stream.frames_per_buffer
        start_time = SampleTime(0, 0, block_size, stream.stream_info.sample_rate)
        # self.center_freq = 1000.0

        self.stream = stream
        self.start_time = start_time
        self.current_time = start_time.copy()

        end_time = start_time.copy()
        while end_time.pa_time < play_duration:
            end_time.block += 1
        self.end_time = end_time
        self.play_duration = end_time.pa_time
        print('start_time={}, end_time={}'.format(start_time, end_time))

        stream.stream_info.input_channels = self.in_channels
        nchannels = stream.stream_info.output_channels
        nblocks = end_time.block + 1
        self.nchannels = nchannels
        self.nblocks = nblocks
        self.complete = False

    def run(self):
        # libpd part
        self.init()
        self.init_audio() #one channel in, one channel out

        # audio
        st_info = self.stream.stream_info
        assert not self.stream.active
        assert st_info.output_channels > 0
        assert self.stream.check() == 0

        r = False

        start_ts = time.time()
        end_ts = start_ts + self.play_duration + 2

        with self.stream:
            print('stream opened')
            while not self.complete:
                if not self.stream.active:
                    raise Exception('stream aborted')
                r = self.fill_buffer()
                if self.complete:
                    print('playback complete')
                    break
                if time.time() >= end_ts:
                    print('playback timeout')
                    break
                if not r:
                    time.sleep(.1)
            print('closing stream')
        print('stream closed')

    def fill_buffer(self):
        bfr = self.stream.output_buffer
        if not bfr.ready():
            return False
        data = self.generate()
        r = bfr.write_output_sf32(data)
        if not r:
            return False
        self.current_time.block += 1

        if self.current_time >= self.end_time:
            self.complete = True
            return False
        return True

    def generate(self):

        block_size = self.stream.frames_per_buffer
        fs = self.stream.sample_rate

        inbuf = np.zeros((self.in_channels, block_size), dtype='float32')
        outbuf = np.zeros((self.out_channels, block_size), dtype='float32')
        self.process_audio(self.ticks, inbuf, outbuf)

        sig = np.zeros((self.out_channels, block_size), dtype='float32')
        # dsp perform routine
        for i in range(block_size * self.out_channels):
            if (i % 2):
                sig[i] = outbuf[i]
            else:
                sig[i] = outbuf[i]

        # for i in range(self.out_channels):
        #     data[i,:] = sig
        return sig


def test_playback():
    p = Patch()
    port_audio = PortAudio()
    sample_rate = p.sample_rate
    sample_format = types.get_sample_formats()['sf_float32']
    block_size = p.blocksize()
    print(f'fs={sample_rate}, sample_format={sample_format} block_size={block_size}')
    port_audio.open() # have to open to enable get_host_api_by_name
    hostapi = port_audio.get_host_api_by_name('Core Audio')
    device = hostapi.devices[1]
    stream_kw = dict(
        sample_rate=sample_rate,
        block_size=block_size,
        sample_format=sample_format['name'].decode(),
        output_channels=p.out_channels,
    )
    stream = device.open_stream(**stream_kw)
    try:
        stream.check()
    except PortAudioError as exc:
        if exc.error_msg == 'Invalid sample rate':
            print(exc)
            return
    p.config_stream(stream, DURATION)
    p.run()
    assert p.complete
    # gen = Generator(stream, DURATION)
    # gen.run()
    # assert gen.complete

test_playback()
