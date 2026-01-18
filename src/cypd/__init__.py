"""
cypd - A Cython wrapper for libpd (Pure Data)

This module provides Python bindings for libpd, allowing you to embed
Pure Data patches in Python applications.

Example usage (low-level):
    >>> import cypd
    >>> cypd.init()
    True
    >>> cypd.init_audio(1, 2, 44100)
    True
    >>> patch_id = cypd.open_patch("test.pd", "/path/to/patches")
    >>> cypd.dsp(True)
    >>> # ... process audio in your callback ...
    >>> cypd.close_patch(patch_id)
    >>> cypd.release()

Example usage (with built-in audio via miniaudio):
    >>> import cypd
    >>> from cypd import audio
    >>> cypd.init()
    >>> cypd.init_audio(1, 2, 44100)
    >>> audio.init_audio(44100, 1, 2)
    >>> patch_id = cypd.open_patch("test.pd", ".")
    >>> audio.start()
    >>> cypd.dsp(True)
    >>> audio.sleep(4000)  # play for 4 seconds
    >>> cypd.dsp(False)
    >>> audio.stop()
    >>> cypd.close_patch(patch_id)

Or use the convenience function:
    >>> from cypd import audio
    >>> audio.play("test.pd", ".", duration_ms=4000)
"""

from cypd._libpd import (
    # Initialization
    init,
    init_audio,
    init_hooks,
    release,

    # Patch management
    open_patch,
    close_patch,

    # Search path
    clear_search_path,
    add_to_search_path,

    # Audio processing
    get_blocksize,
    dsp,

    # Sending messages to pd
    send_bang,
    send_float,
    send_symbol,
    send_list,
    send_message,

    # Compound message building
    start_message,
    add_float,
    add_symbol,
    finish_list,
    finish_message,

    # Receiving messages from pd (subscriptions)
    subscribe,
    unsubscribe,
    exists,

    # Message callbacks
    set_print_callback,
    set_bang_callback,
    set_float_callback,
    set_double_callback,
    set_symbol_callback,
    set_list_callback,
    set_message_callback,

    # Array access
    array_size,
    resize_array,

    # MIDI output (to pd)
    noteon,
    controlchange,
    programchange,
    pitchbend,
    aftertouch,
    polyaftertouch,
    midibyte,
    sysex,
    sysrealtime,

    # MIDI callbacks (from pd)
    set_noteon_callback,
    set_controlchange_callback,
    set_programchange_callback,
    set_pitchbend_callback,
    set_aftertouch_callback,
    set_polyaftertouch_callback,
    set_midibyte_callback,

    # GUI
    start_gui,
    stop_gui,
    poll_gui,

    # Multiple instances
    num_instances,

    # Logging
    get_verbose,
    set_verbose,
    pd_version,

    # Queued API (thread-safe message passing)
    queued_init,
    queued_release,
    queued_receive_pd_messages,
    queued_receive_midi_messages,
    set_queued_print_callback,
    set_queued_bang_callback,
    set_queued_float_callback,
    set_queued_double_callback,
    set_queued_symbol_callback,
    set_queued_list_callback,
    set_queued_message_callback,
    set_queued_noteon_callback,
    set_queued_controlchange_callback,
    set_queued_programchange_callback,
    set_queued_pitchbend_callback,
    set_queued_aftertouch_callback,
    set_queued_polyaftertouch_callback,
    set_queued_midibyte_callback,
)

# Import audio module (miniaudio backend)
from cypd import _audio as audio

__all__ = [
    # Submodules
    "audio",

    # Initialization
    "init",
    "init_audio",
    "init_hooks",
    "release",

    # Patch management
    "open_patch",
    "close_patch",

    # Search path
    "clear_search_path",
    "add_to_search_path",

    # Audio
    "get_blocksize",
    "dsp",

    # Messages to pd
    "send_bang",
    "send_float",
    "send_symbol",
    "send_list",
    "send_message",
    "start_message",
    "add_float",
    "add_symbol",
    "finish_list",
    "finish_message",

    # Subscriptions
    "subscribe",
    "unsubscribe",
    "exists",

    # Message callbacks
    "set_print_callback",
    "set_bang_callback",
    "set_float_callback",
    "set_double_callback",
    "set_symbol_callback",
    "set_list_callback",
    "set_message_callback",

    # Arrays
    "array_size",
    "resize_array",

    # MIDI
    "noteon",
    "controlchange",
    "programchange",
    "pitchbend",
    "aftertouch",
    "polyaftertouch",
    "midibyte",
    "sysex",
    "sysrealtime",
    "set_noteon_callback",
    "set_controlchange_callback",
    "set_programchange_callback",
    "set_pitchbend_callback",
    "set_aftertouch_callback",
    "set_polyaftertouch_callback",
    "set_midibyte_callback",

    # GUI
    "start_gui",
    "stop_gui",
    "poll_gui",

    # Instances
    "num_instances",

    # Logging
    "get_verbose",
    "set_verbose",
    "pd_version",

    # Queued API
    "queued_init",
    "queued_release",
    "queued_receive_pd_messages",
    "queued_receive_midi_messages",
    "set_queued_print_callback",
    "set_queued_bang_callback",
    "set_queued_float_callback",
    "set_queued_double_callback",
    "set_queued_symbol_callback",
    "set_queued_list_callback",
    "set_queued_message_callback",
    "set_queued_noteon_callback",
    "set_queued_controlchange_callback",
    "set_queued_programchange_callback",
    "set_queued_pitchbend_callback",
    "set_queued_aftertouch_callback",
    "set_queued_polyaftertouch_callback",
    "set_queued_midibyte_callback",
]

__version__ = "0.1.0"
