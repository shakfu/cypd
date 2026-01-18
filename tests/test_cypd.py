"""Tests for cypd - libpd Cython wrapper."""

import cypd


def test_version():
    """Test version is accessible."""
    assert cypd.__version__ == "0.1.0"


def test_pd_version():
    """Test pd version returns a valid version string."""
    version = cypd.pd_version()
    assert isinstance(version, str)
    parts = version.split(".")
    assert len(parts) == 3
    # Should be something like "0.56.1"
    assert all(p.isdigit() for p in parts)


def test_blocksize():
    """Test blocksize returns pd's fixed block size."""
    blocksize = cypd.get_blocksize()
    assert blocksize == 64  # pd's blocksize is always 64


def test_init():
    """Test libpd initialization."""
    # First init should succeed
    result = cypd.init()
    # Subsequent inits return False (already initialized)
    # but this is expected behavior
    assert isinstance(result, bool)


def test_init_audio():
    """Test audio initialization."""
    cypd.init()
    result = cypd.init_audio(1, 2, 44100)
    assert result is True


def test_verbose():
    """Test verbose getter/setter."""
    cypd.init()
    original = cypd.get_verbose()
    cypd.set_verbose(1)
    assert cypd.get_verbose() == 1
    cypd.set_verbose(0)
    assert cypd.get_verbose() == 0
    cypd.set_verbose(original)


def test_num_instances():
    """Test num_instances returns at least 1."""
    cypd.init()
    assert cypd.num_instances() >= 1


def test_exists_nonexistent():
    """Test exists returns False for non-existent receiver."""
    cypd.init()
    assert cypd.exists("nonexistent_receiver_12345") is False


def test_send_to_nonexistent():
    """Test sending to non-existent receiver returns False."""
    cypd.init()
    assert cypd.send_bang("nonexistent_receiver_12345") is False
    assert cypd.send_float("nonexistent_receiver_12345", 1.0) is False
    assert cypd.send_symbol("nonexistent_receiver_12345", "test") is False


def test_message_building():
    """Test compound message building functions."""
    cypd.init()
    # start_message should succeed
    assert cypd.start_message(10) is True
    cypd.add_float(1.0)
    cypd.add_float(2.0)
    cypd.add_symbol("test")
    # finish_list to nonexistent receiver returns False
    assert cypd.finish_list("nonexistent_receiver_12345") is False


def test_subscribe_unsubscribe():
    """Test subscribe and unsubscribe."""
    cypd.init()
    cypd.subscribe("test_receiver")
    assert cypd.exists("test_receiver") is True
    cypd.unsubscribe("test_receiver")


def test_array_size_nonexistent():
    """Test array_size returns negative for non-existent array."""
    cypd.init()
    size = cypd.array_size("nonexistent_array_12345")
    assert size < 0


def test_midi_to_nonexistent():
    """Test MIDI functions don't crash (no patches loaded)."""
    cypd.init()
    # These should return True even with no patch loaded
    # as they just queue the messages
    assert cypd.noteon(0, 60, 100) is True
    assert cypd.controlchange(0, 1, 64) is True
    assert cypd.programchange(0, 1) is True
    assert cypd.pitchbend(0, 0) is True
    assert cypd.aftertouch(0, 64) is True


def test_callbacks():
    """Test setting callbacks doesn't crash."""
    cypd.init()

    received = []

    def my_print(s):
        received.append(("print", s))

    def my_bang(recv):
        received.append(("bang", recv))

    def my_float(recv, f):
        received.append(("float", recv, f))

    # Set callbacks
    cypd.set_print_callback(my_print)
    cypd.set_bang_callback(my_bang)
    cypd.set_float_callback(my_float)

    # Clear callbacks
    cypd.set_print_callback(None)
    cypd.set_bang_callback(None)
    cypd.set_float_callback(None)


def test_dsp():
    """Test DSP toggle doesn't crash."""
    cypd.init()
    cypd.init_audio(1, 2, 44100)
    cypd.dsp(True)
    cypd.dsp(False)


def test_release():
    """Test release cleans up properly."""
    cypd.init()
    cypd.subscribe("test_receiver_release")
    cypd.release()
    # After release, receiver should not exist
    # (need to re-init first)
    cypd.init()
    assert cypd.exists("test_receiver_release") is False


# ============================================================================
# Audio module tests
# ============================================================================

def test_audio_module_import():
    """Test audio module can be imported."""
    from cypd import audio
    assert audio is not None


def test_audio_version():
    """Test miniaudio version is accessible."""
    from cypd import audio
    version = audio.get_version()
    assert isinstance(version, str)
    # Should be something like "0.11.24"
    assert "." in version


def test_audio_init():
    """Test audio initialization."""
    from cypd import audio
    cypd.init()
    cypd.init_audio(1, 2, 44100)
    result = audio.init_audio(44100, 1, 2)
    assert result is True
    # Cleanup
    audio.terminate()


def test_audio_start_stop():
    """Test audio start/stop cycle."""
    from cypd import audio
    cypd.init()
    cypd.init_audio(1, 2, 44100)
    audio.init_audio(44100, 1, 2)

    assert audio.is_running() is False
    assert audio.start() is True
    assert audio.is_running() is True
    assert audio.stop() is True
    assert audio.is_running() is False

    audio.terminate()


def test_audio_terminate():
    """Test audio termination doesn't crash when not initialized."""
    from cypd import audio
    # Should not crash even if not initialized
    audio.terminate()


def test_audio_sleep():
    """Test audio sleep function."""
    import time
    from cypd import audio

    start = time.time()
    audio.sleep(100)  # 100ms
    elapsed = time.time() - start

    # Should have slept for approximately 100ms
    assert elapsed >= 0.09  # Allow some tolerance
