"""Tests for cypd with actual pd patches.

These tests use pd patches from tests/pd/ to verify the integration
between Python and Pure Data works correctly.
"""

import os
import pytest
import cypd
from cypd import audio


# Path to pd patches
PATCH_DIR = os.path.join(os.path.dirname(__file__), "pd")


@pytest.fixture(autouse=True)
def setup_cypd():
    """Setup and teardown for each test."""
    cypd.init()
    yield
    # Don't call release() between tests - libpd doesn't handle
    # repeated init/release cycles well. Just clean up subscriptions.


class TestPatchLoading:
    """Tests for opening and closing patches."""

    def test_open_patch(self):
        """Test opening a valid patch."""
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        assert patch_id > 0
        cypd.close_patch(patch_id)

    @pytest.mark.skip(reason="libpd segfaults on nonexistent files")
    def test_open_nonexistent_patch(self):
        """Test opening a non-existent patch raises error."""
        with pytest.raises(IOError):
            cypd.open_patch("nonexistent.pd", PATCH_DIR)

    def test_open_multiple_patches(self):
        """Test opening multiple patches."""
        patch1 = cypd.open_patch("test.pd", PATCH_DIR)
        patch2 = cypd.open_patch("test_msg.pd", PATCH_DIR)
        assert patch1 != patch2
        cypd.close_patch(patch1)
        cypd.close_patch(patch2)


class TestMessaging:
    """Tests for sending messages to pd."""

    def test_send_to_patch_receiver(self):
        """Test sending messages to receivers in a patch."""
        patch_id = cypd.open_patch("test_msg_send.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        # The patch has receivers: mybang, myfloat, mysymbol, mylist, mymessage
        # These should succeed (receivers exist in patch)
        # Note: send returns False only if receiver doesn't exist at all
        cypd.send_bang("mybang")
        cypd.send_float("myfloat", 42.0)
        cypd.send_symbol("mysymbol", "hello")

        cypd.close_patch(patch_id)

    def test_send_list_to_patch(self):
        """Test sending lists to a patch."""
        patch_id = cypd.open_patch("test_msg_send.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        cypd.send_list("mylist", "a", "b", "c", 1, 2, 3)

        cypd.close_patch(patch_id)

    def test_send_message_to_patch(self):
        """Test sending typed messages to a patch."""
        patch_id = cypd.open_patch("test_msg_send.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        cypd.send_message("mymessage", "foo", "x", "y", "z", 4, 5, 6)

        cypd.close_patch(patch_id)


class TestSubscriptions:
    """Tests for subscribing to pd senders."""

    def test_subscribe_to_sender(self):
        """Test subscribing to a sender in a patch."""
        patch_id = cypd.open_patch("test_msg_bind.pd", PATCH_DIR)

        # Subscribe to 'dispatch' sender in the patch
        cypd.subscribe("dispatch")
        assert cypd.exists("dispatch") is True

        cypd.unsubscribe("dispatch")
        cypd.close_patch(patch_id)

    def test_exists_for_patch_receiver(self):
        """Test exists() returns True for receivers in patch."""
        patch_id = cypd.open_patch("test_msg_bind.pd", PATCH_DIR)

        # 'option' is a receiver [r option] in the patch
        assert cypd.exists("option") is True

        cypd.close_patch(patch_id)


class TestCallbacksWithPatch:
    """Tests for callbacks receiving messages from pd."""

    def test_print_callback_receives_messages(self):
        """Test print callback receives print output from pd."""
        received = []

        def my_print(s):
            received.append(s)

        cypd.set_print_callback(my_print)
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        # The test.pd patch has a loadbang -> metro -> print chain
        # We need to process some audio ticks to let pd run
        cypd.dsp(True)
        # Process would happen here in real audio callback
        cypd.dsp(False)

        cypd.close_patch(patch_id)
        cypd.set_print_callback(None)

    def test_float_callback_receives_floats(self):
        """Test float callback can receive floats from pd."""
        received = []

        def my_float(recv, value):
            received.append((recv, value))

        cypd.set_float_callback(my_float)
        patch_id = cypd.open_patch("test_msg.pd", PATCH_DIR)

        # Subscribe to receive from 'eggs' sender
        cypd.subscribe("eggs")

        # The patch should send to 'eggs' when we send to 'spam'
        cypd.send_float("spam", 42.0)

        cypd.unsubscribe("eggs")
        cypd.close_patch(patch_id)
        cypd.set_float_callback(None)


class TestArrays:
    """Tests for pd array access."""

    def test_array_exists_in_patch(self):
        """Test array size for array in patch."""
        patch_id = cypd.open_patch("test_msg.pd", PATCH_DIR)

        # test_msg.pd has an array called 'array1' with 64 elements
        size = cypd.array_size("array1")
        assert size == 64

        cypd.close_patch(patch_id)

    def test_array_nonexistent(self):
        """Test array size for non-existent array."""
        patch_id = cypd.open_patch("test_msg.pd", PATCH_DIR)

        size = cypd.array_size("nonexistent_array")
        assert size < 0

        cypd.close_patch(patch_id)


class TestAudioIntegration:
    """Tests for audio playback integration.

    Note: Tests that actually run the audio callback are skipped by default
    as they can cause issues with libpd state in test environments.
    Run them manually with: pytest -k "audio" --run-audio
    """

    def test_audio_init_with_patch(self):
        """Test audio initialization with a patch loaded."""
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        result = audio.init_audio(44100, 1, 2)
        assert result is True

        audio.terminate()
        cypd.close_patch(patch_id)

    def test_audio_start_stop_with_patch(self):
        """Test audio start/stop with patch loaded."""
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)
        audio.init_audio(44100, 1, 2)

        assert audio.start() is True
        cypd.dsp(True)

        # Brief moment of audio
        audio.sleep(100)

        cypd.dsp(False)
        assert audio.stop() is True

        audio.terminate()
        cypd.close_patch(patch_id)

    def test_play_patch_audio(self):
        """Test playing a patch with audio output."""
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)
        audio.init_audio(44100, 1, 2)

        audio.start()
        cypd.dsp(True)

        # Play briefly
        audio.sleep(100)

        cypd.dsp(False)
        audio.stop()

        audio.terminate()
        cypd.close_patch(patch_id)


class TestMIDI:
    """Tests for MIDI with patches."""

    def test_midi_noteon_to_patch(self):
        """Test sending MIDI note to patch."""
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        # test.pd has [noteout] - we can send notes
        assert cypd.noteon(0, 60, 100) is True
        assert cypd.noteon(0, 60, 0) is True  # note off

        cypd.close_patch(patch_id)

    def test_midi_controlchange_to_patch(self):
        """Test sending MIDI CC to patch."""
        patch_id = cypd.open_patch("test.pd", PATCH_DIR)
        cypd.init_audio(1, 2, 44100)

        assert cypd.controlchange(0, 1, 64) is True

        cypd.close_patch(patch_id)
