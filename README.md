# cypd: Cython wrapper for libpd

A Cython-based Python wrapper for [libpd](https://github.com/libpd/libpd) (Pure Data as an embeddable audio library) with built-in audio support via [miniaudio](https://github.com/mackron/miniaudio).

## Features

- **Full libpd API**: Comprehensive access to libpd functionality including patches, messaging, arrays, MIDI, and callbacks
- **Built-in audio**: Integrated miniaudio backend for easy audio playback
- **Flexible architecture**: Use the built-in audio or integrate your own audio system
- **Thread-safe audio**: Audio processing runs in a separate thread with proper `nogil` handling
- **Modern build system**: Uses scikit-build-core with CMake

## Installation

### Prerequisites

- Python 3.10+
- [uv](https://github.com/astral-sh/uv) (recommended) or pip
- CMake 3.15+
- C compiler (clang/gcc)

### Build from source

```bash
# Clone the repository
git clone https://github.com/shakfu/cypd.git
cd cypd

# Build libpd and miniaudio dependencies
./scripts/setup.sh

# Install with uv
uv sync

# Or install with pip
pip install -e .
```

## Quick Start

### Using the built-in audio

```python
from cypd import audio

# Play a patch for 4 seconds
audio.play("my_patch.pd", "/path/to/patches", duration_ms=4000)
```

### Manual control

```python
import cypd
from cypd import audio

# Initialize libpd
cypd.init()
cypd.init_audio(1, 2, 44100)  # 1 input, 2 outputs, 44100 Hz

# Initialize audio backend
audio.init_audio(44100, 1, 2)

# Open a patch
patch_id = cypd.open_patch("my_patch.pd", "/path/to/patches")

# Start audio and enable DSP
audio.start()
cypd.dsp(True)

# Let it play
audio.sleep(4000)  # 4 seconds

# Cleanup
cypd.dsp(False)
audio.stop()
audio.terminate()
cypd.close_patch(patch_id)
```

### Sending messages to Pure Data

```python
import cypd

cypd.init()
patch_id = cypd.open_patch("my_patch.pd", ".")

# Send a bang
cypd.send_bang("my_receiver")

# Send a float
cypd.send_float("frequency", 440.0)

# Send a symbol
cypd.send_symbol("my_receiver", "hello")

# Send a list
cypd.send_list("my_receiver", 1, 2, 3, "foo", "bar")

# Send a typed message
cypd.send_message("my_receiver", "set", 1, 2, 3)

cypd.close_patch(patch_id)
```

### Receiving messages from Pure Data

```python
import cypd

def my_float_callback(receiver, value):
    print(f"Received float {value} from {receiver}")

def my_bang_callback(receiver):
    print(f"Received bang from {receiver}")

cypd.init()
cypd.set_float_callback(my_float_callback)
cypd.set_bang_callback(my_bang_callback)

# Subscribe to a sender
cypd.subscribe("my_sender")

# ... run your patch ...

cypd.unsubscribe("my_sender")
```

### MIDI

```python
import cypd

cypd.init()
patch_id = cypd.open_patch("my_synth.pd", ".")
cypd.init_audio(1, 2, 44100)

# Send MIDI note on (channel, pitch, velocity)
cypd.noteon(0, 60, 100)  # Middle C, velocity 100

# Send MIDI note off
cypd.noteon(0, 60, 0)  # velocity 0 = note off

# Control change
cypd.controlchange(0, 1, 64)  # Modulation wheel

# Pitch bend
cypd.pitchbend(0, 0)  # Center position

cypd.close_patch(patch_id)
```

### Array access

```python
import cypd

cypd.init()
patch_id = cypd.open_patch("with_array.pd", ".")

# Get array size
size = cypd.array_size("my_array")
print(f"Array size: {size}")

# Resize array
cypd.resize_array("my_array", 1024)

cypd.close_patch(patch_id)
```

## API Reference

### Initialization

- `init()` - Initialize libpd
- `init_audio(in_channels, out_channels, sample_rate)` - Initialize audio rendering
- `release()` - Shutdown libpd and release resources

### Patches

- `open_patch(name, dir)` - Open a patch, returns patch ID
- `close_patch(patch_id)` - Close a patch
- `add_to_search_path(path)` - Add to abstraction search path
- `clear_search_path()` - Clear the search path

### Audio

- `get_blocksize()` - Get pd's block size (always 64)
- `dsp(on)` - Enable/disable DSP processing

### Messaging

- `send_bang(receiver)` - Send a bang
- `send_float(receiver, value)` - Send a float
- `send_symbol(receiver, symbol)` - Send a symbol
- `send_list(receiver, *args)` - Send a list
- `send_message(receiver, msg, *args)` - Send a typed message
- `subscribe(source)` - Subscribe to messages from a sender
- `unsubscribe(source)` - Unsubscribe from a sender
- `exists(receiver)` - Check if a receiver exists

### Callbacks

- `set_print_callback(func)` - Set print hook
- `set_bang_callback(func)` - Set bang receive hook
- `set_float_callback(func)` - Set float receive hook
- `set_symbol_callback(func)` - Set symbol receive hook
- `set_list_callback(func)` - Set list receive hook
- `set_message_callback(func)` - Set typed message receive hook

### MIDI

- `noteon(channel, pitch, velocity)` - Send note on
- `controlchange(channel, controller, value)` - Send control change
- `programchange(channel, value)` - Send program change
- `pitchbend(channel, value)` - Send pitch bend
- `aftertouch(channel, value)` - Send aftertouch
- `polyaftertouch(channel, pitch, value)` - Send poly aftertouch

### Arrays

- `array_size(name)` - Get array size
- `resize_array(name, size)` - Resize an array

### Audio Module (`cypd.audio`)

- `init_audio(sample_rate, channels_in, channels_out)` - Initialize miniaudio
- `start()` - Start audio playback
- `stop()` - Stop audio playback
- `terminate()` - Shutdown audio
- `is_running()` - Check if audio is running
- `sleep(milliseconds)` - Sleep for duration
- `play(patch, dir, duration_ms, ...)` - Convenience function to play a patch
- `get_version()` - Get miniaudio version string

## Development

```bash
# Run tests
make test

# Build
make build

# Clean
make clean
```

## Architecture

The project consists of two Cython extension modules:

- **`_libpd`**: Core libpd wrapper providing the full API
- **`_audio`**: Miniaudio-based audio backend

The `_audio` module obtains a function pointer to `libpd_process_float` from `_libpd` at runtime, ensuring both modules share the same libpd instance (avoiding issues with static library symbol duplication).

## License

See [LICENSE](LICENSE) file.

## Acknowledgments

- [libpd](https://github.com/libpd/libpd) - Pure Data as an embeddable library
- [miniaudio](https://github.com/mackron/miniaudio) - Single-file audio playback and capture library
- [Pure Data](https://puredata.info/) - The original visual programming language for audio
