"""
a translation of the cpp implementation to cython
"""

#include "z_libpd.h"
#include "z_queued.h"
#include "z_print_util.h"

#include "PdTypes.hpp"
#include "PdReceiver.hpp"
#include "PdMidiReceiver.hpp"

# needed for libpd audio passing
#ifndef USEAPI_DUMMY
    #define USEAPI_DUMMY
#endif

#ifndef HAVE_UNISTD_H
    #define HAVE_UNISTD_H
#endif

import logging

ctypedef struct _atom t_atom


cdef class PdBase:
    """a Pure Data instance

    use this class directly or extend it and any of its virtual functions

    note: libpd currently does not support multiple states and it is
          suggested that you use only one PdBase-derived object at a time

          calls from multiple PdBase instances currently use a global context
          kept in a singleton object, thus only one Receiver & one MidiReceiver
          can be used within a single program

          multiple context support will be added if/when it is included within
          libpd

    """
    def __cinit__(self):
        self.clear()
        self.log = logging.getLogger(self.__name__)
        PdContext.instance().addBase()

    def __dealloc__(self):
        self.clear()
        PdContext.instance().removeBase()

# ----------------------------------------------------------------------------
# Initializing Pd


    def init(self, num_in_channels: int, num_out_channels: int,
             sample_rate: int, queued: bool = False) -> bool:
        """initialize resources and set up the audio processing

        set the audio latency by setting the libpd ticks per buffer:
        ticks per buffer * lib pd block size (always 64)

        ie 4 ticks per buffer * 64 = buffer length of 512

        you can call this again after loading patches & setting receivers
        in order to update the audio settings

        the lower the number of ticks, the faster the audio processing
        if you experience audio dropouts (audible clicks), increase the
        ticks per buffer

        set queued = True to use the built in ringbuffers for message and
        midi event passing, you will then need to call receive_messages() and
        receive_midi() in order to pass messages from the ringbuffers to your
        PdReceiver and PdMidiReceiver implementations

        the queued ringbuffers are useful when you need to receive events
        on a gui thread and don't want to use locking

        return True if setup successfully

        note: must be called before processing
        """
        PdContext.instance().clear()
        return PdContext.instance().init(num_in_channels, num_out_channels,
                                          sample_rate, queued)


    def clear(self):
        """clear resources"""
        PdContext.instance().clear()
        unsubscribe_all()

# ----------------------------------------------------------------------------
# Adding Search Paths

    def add_to_search_path(self, path: str):
        """
        Adds to the pd search path.

        takes an absolute or relative path (in data folder)
        note: fails silently if path not found
        
        :param      path:  The path
        :type       path:  str
        """
        libpd.libpd_add_to_search_path(path.encode('utf-8'))


    def clear_search_path(self):
        """clear the current pd search path."""
        libpd.libpd_clear_search_path()

# ----------------------------------------------------------------------------
# Opening Patches

    def open_patch(str patch, str path) -> Patch:
        """open a patch file (aka somefile.pd) at a specified parent dir path
        
        returns a Patch object

        use Patch::isValid() to check if a patch was opened successfully:

        Patch p1 = pd.open_patch("somefile.pd", "/some/dir/path/")
        if(!p1.isValid()):
            cout << "aww ... p1 couldn't be opened" << std::endl
        """
        # [ pd open file folder(
        cdef void *handle = libpd.libpd_openfile(patch.encode('utf-8'), path.encode('utf-8'))
        if(handle == NULL):
            return Patch() # return empty Patch
    
        cdef int dollarzero = libpd.libpd_getdollarzero(handle)
        return Patch(handle, dollarzero, patch, path)


    def open_patch(self, patch: Patch) -> Patch:
        """open a patch file using the filename and path of an existing patch

        set the filename within the patch object or use a previously opened
        object

        # open an instance of "somefile.pd"
        Patch p2("somefile.pd", "/some/path") # set file and path
        pd.open_patch(p2)
        
        # open a new instance of "somefile.pd"
        Patch p3 = pd.open_patch(p2)
        
        # p2 and p3 refer to 2 different instances of "somefile.pd"
        """
        return open_patch(patch.filename(), patch.path())


    def close_patch(self, patch: str):
        """close a patch file
            
        takes only the patch's basename (filename without extension)
        """
        # [ pd-name menuclose 1(
        str patchname = (str)"pd-" + patch
        libpd.libpd_start_message(1)
        libpd.libpd_add_float(1)
        libpd.libpd_finish_message(patchname.encode('utf-8'), "menuclose")


    def close_patch(self, patch: Patch):
        """close a patch file, takes a patch object
        
        note: clears the given Patch object
        """
        if(!patch.isValid()):
            return
    
        libpd.libpd_closefile(patch.handle())
        patch.clear()


# ----------------------------------------------------------------------------
# Audio Processing

# one of these must be called for audio dsp and message io to occur
#
# in_buffer must be an array of the right size and never null
# use in_buffer = new type[0] if no input is desired
#
# out_buffer must be an array of size outBufferSize from openAudio call
#
# note: raw does not interlace the buffers
#


    cdef bint process_float(self, int ticks, const float *in_buffer, float *out_buffer) nogil:
        """process float buffers for a given number of ticks
        
        returns False on error
        """
        return libpd.libpd_process_float(ticks, in_buffer, out_buffer) == 0


    cdef bint process_short(self, int ticks, const short *in_buffer, short *out_buffer) nogil:
        """process short buffers for a given number of ticks
        
        returns False on error
        """
        return libpd.libpd_process_short(ticks, in_buffer, out_buffer) == 0


    cdef bint process_double(self, int ticks, const double *in_buffer, double *out_buffer) nogil:
        """process double buffers for a given number of ticks
        
        returns False on error
        """
        return libpd.libpd_process_double(ticks, in_buffer, out_buffer) == 0


    cdef bint process_raw(self, float *in_buffer, float *out_buffer) nogil:
        """process one pd tick, writes raw float data to/from buffers
        
        returns False on error
        """
        return libpd.libpd_process_raw(in_buffer, out_buffer) == 0


    cdef bint process_raw_short(self, short *in_buffer, short *out_buffer) nogil:
        """process one pd tick, writes raw short data to/from buffers
        
        returns False on error
        """
        return libpd.libpd_process_raw_short(in_buffer, out_buffer) == 0


    cdef bint process_raw_double(self, double *in_buffer, double *out_buffer) nogil:
        """process one pd tick, writes raw double data to/from buffers
        
        returns False on error
        """
        return libpd.libpd_process_raw_double(in_buffer, out_buffer) == 0

# ----------------------------------------------------------------------------
# Audio Processing Control

    def compute_audio(self, state: bool):
        """start/stop audio processing

        in general, once started, you won't need to turn off audio

        shortcut for [ pd dsp 1( & [ pd dsp 0(
        """
        PdContext.instance().compute_audio(state)

# ----------------------------------------------------------------------------
# Message Receiving


    def subscribe(self, source: str):
        """subscribe to messages sent by a pd send source

        aka this like a virtual pd receive object [r source]
        """
        if(self.exists(source)):
            self.log.warn("Pd: unsubscribe: ignoring duplicate source")
            return
    
        void *pointer = libpd.libpd_bind(source.encode('utf-8'))
        if(pointer != NULL):
            std::map<str,void*> &sources =
                PdContext.instance().sources
            sources.insert(std::pair<str,void*>(source, pointer))
    


    def unsubscribe(self, source: str):
        """unsubscribe from messages sent by a pd send source"""
        std::map<str,void*> &sources = PdContext.instance().sources
        std::map<str,void*>::iterator iter
        iter = sources.find(source)
        if(iter == sources.end()):
            self.log.warning("Pd: unsubscribe: ignoring unknown source")
            return
    
        libpd.libpd_unbind(iter->second)
        sources.erase(iter)


    def exists(self, source: str) -> bool:
        """is a pd send source subscribed?"""
        std::map<str,void*> &sources = PdContext.instance().sources
        if(sources.find(source) != sources.end()):
            return True
    
        return False


    def unsubscribe_all(self):
        """receivers will be unsubscribed from *all* pd send sources"""
        std::map<str,void*> &sources = PdContext.instance().sources
        std::map<str,void*>::iterator iter
        for(iter = sources.begin() iter != sources.end() ++iter):
            libpd.libpd_unbind(iter->second)
    
        sources.clear()


# ----------------------------------------------------------------------------
# Receiving from the Message Queues

# process the internal message queue if using the ringbuffer
#
# internally, libpd will use a ringbuffer to pass messages & midi without
# needing to require locking if you call init() with queued = True
#
# call these in a loop somewhere in order to receive waiting messages
# or midi data which are then sent to your PdReceiver & PdMidiReceiver
#

    def receive_messages(self):
        """process waiting messages"""
        libpd.libpd_queued_receive_pd_messages()


    def receive_midi(self):
        """process waiting midi messages"""
        libpd.libpd_queued_receive_midi_messages()

# ----------------------------------------------------------------------------
# Event Receiving via Callbacks

    def set_receiver(self, pd::PdReceiver *receiver):
        """set the incoming event receiver, disables the event queue

        automatically receives from all currently subscribed sources

        set this to NULL to disable callback receiving and re-enable the
        event queue
        """
        PdContext.instance().receiver = receiver

# ----------------------------------------------------------------------------
# Midi Receiving via Callbacks

    def set_midi_receiver(self, pd::PdMidiReceiver *midi_receiver):
        """set the incoming midi event receiver, disables the midi queue
        
        automatically receives from all midi channels
        
        set this to NULL to disable midi events and re-enable the midi queue
        """
        PdContext.instance().midi_receiver = midi_receiver

# ----------------------------------------------------------------------------
# Send Functions

    # send a bang message
    def send_bang(str &dest):
        libpd.libpd_bang(dest.encode('utf-8'))


    # send a float
    def send_float(str &dest, float value):
        libpd.libpd_float(dest.encode('utf-8'), value)


    # send a symbol
    def sendSymbol(str &dest,
                            str &symbol):
        libpd.libpd_symbol(dest.encode('utf-8'), symbol.encode('utf-8'))

# ----------------------------------------------------------------------------
# Sending Compound Messages
#
#     pd.start_message()
#     pd.add_symbol("hello")
#     pd.add_float(1.23)
#     pd.finish_list("test") # "test" is the receiver name in pd
#
# sends [list hello 1.23( -> [r test],
# you will need to use the [list trim] object on the receiving end
#
# finishMsg sends a typed message -> [ test msg1 hello 1.23(
#
#     pd.start_message()
#     pd.add_symbol("hello")
#     pd.add_float(1.23)
#     pd.finish_message("test", "msg1")
#

    def start_message(self):
        """start a compound list or message"""
        PdContext &context = PdContext.instance()
        if(context.msg_in_progress):
            self.log.warn("Pd: cannot start message, message in progress")
            return
    
        if(libpd.libpd_start_message(context.max_message_len) == 0):
            context.msg_in_progress = True
            context.msg_type = MSG
    

    def add_float(self, float num):
        """add a float to the current compound list or message"""
        PdContext &context = PdContext.instance()
        if(!context.msg_in_progress):
            self.log.warn("Pd: cannot add float, message not in progress")
            return
    
        if(context.msg_type != MSG):
            self.log.warn("Pd: cannot add float, midi byte stream in progress")
            return
    
        if(context.current_msg_len+1 >= context.max_message_len):
            self.log.warn("Pd: cannot add float, max message length of "
                f"{context.max_message_len} reached")
            return
    
        libpd.libpd_add_float(num)
        context.current_msg_len++



    def add_symbol(self, str &symbol):
        """add a symbol to the current compound list or message"""
        PdContext &context = PdContext.instance()
        if(!context.msg_in_progress):
            self.log.warn("Pd: cannot add symbol, message not in progress"
            return
    
        if(context.msg_type != MSG):
            self.log.warn("Pd: cannot add symbol, midi byte stream in progress"
            return
    
        if(context.current_msg_len+1 >= context.max_message_len):
            self.log.warn("Pd: cannot add symbol, max message length of "
                      f"context.max_message_len reached")
            return
    
        libpd.libpd_add_symbol(symbol.encode('utf-8'))
        context.current_msg_len++


    def finish_list(self, str &dest):
        """finish and send as a list"""
        PdContext &context = PdContext.instance()
        if(!context.msg_in_progress):
            self.log.warn("Pd: cannot finish list, message not in progress")
            return
    
        if(context.msg_type != MSG):
            self.log.warn("Pd: cannot finish list, midi byte stream in progress")
            return
    
        libpd.libpd_finish_list(dest.encode('utf-8'))
        context.msg_in_progress = False
        context.current_msg_len = 0


    def finish_message(self, str &dest, str &msg):
        """finish and send as a list with a specific message name"""
        PdContext &context = PdContext.instance()
        if(!context.msg_in_progress):
            self.log.warn("Pd: cannot finish message, message not in progress")
            return
    
        if(context.msg_type != MSG):
            self.log.warn("Pd: cannot finish message, midi byte stream in progress")
            return
    
        libpd.libpd_finish_message(dest.encode('utf-8'), msg.encode('utf-8'))
        context.msg_in_progress = False
        context.current_msg_len = 0



    def send_list(self, str &dest, const pd::List &list):
        """send a list using the PdBase List type

             List list
             list.add_symbol("hello")
             list.add_float(1.23)
             pd.sstd::endlist("test", list)

         sends [list hello 1.23( -> [r test]

         stream operators work as well:

             list << "hello" << 1.23
             pd.sstd::endlist("test", list)
        """
        PdContext &context = PdContext.instance()
        if(context.msg_in_progress):
            self.log.warning("Pd: cannot send list, message in progress")
            return
    
        libpd.libpd_start_message(list.length())
        context.msg_in_progress = True
        # step through list
        for(int i = 0 i < (int)list.length() ++i):
            if(list.isFloat(i))
                add_float(list.getFloat(i))
            else if(list.isSymbol(i))
                add_symbol(list.getSymbol(i))
    
        finish_list(dest)



    def send_message(self, str dest, str msg, pd::List &list = pd::List()):
        """send a message using the PdBase List type

             pd::List list
             list.add_symbol("hello")
             list.add_float(1.23)
             pd.send_message("test", "msg1", list)

         sends a typed message -> [ test msg1 hello 1.23(

         stream operators work as well:

              list << "hello" << 1.23
             pd.send_message("test", "msg1", list)
        """
        PdContext &context = PdContext.instance()
        if(context.msg_in_progress):
            self.log.warn("Pd: cannot send message, message in progress")
            return
    
        libpd.libpd_start_message(list.length())
        context.msg_in_progress = True
        # step through list
        for(int i = 0 i < (int)list.length() ++i):
            if(list.isFloat(i))
                add_float(list.getFloat(i))
            else if(list.isSymbol(i))
                add_symbol(list.getSymbol(i))
    
        finish_message(dest, msg)


# ----------------------------------------------------------------------------
# Sending MIDI
#
# any out of range messages will be silently ignored
#
# number ranges:
# * channel             0 - 15 * dev# (dev #0: 0-15, dev #1: 16-31, etc)
# * pitch               0 - 127
# * velocity            0 - 127
# * controller value    0 - 127
# * program value       0 - 127
# * bend value          -8192 - 8191
# * touch value         0 - 127
#


    def send_noteon(self, int channel, int pitch, int velocity=64):
        """send a MIDI note on

        pd does not use note off MIDI messages, so send a note on with vel = 0
        """
        libpd.libpd_noteon(channel, pitch, velocity)


    def send_controlchange(int channel, int controller, int value):
        """send a MIDI control change"""
        libpd.libpd_controlchange(channel, controller, value)


    def send_programchange(int channel, int value):
        """send a MIDI program change"""
        libpd.libpd_programchange(channel, value)


    def send_pitchbend(int channel, int value):
        """send a MIDI pitch bend
        
        in pd: [bendin] takes 0 - 16383 while [bendout] returns -8192 - 8192
        """
        libpd.libpd_pitchbend(channel, value)


    def send_aftertouch(int channel, int value):
        """send a MIDI aftertouch"""
        libpd.libpd_aftertouch(channel, value)


    def send_polyaftertouch(int channel, int pitch, int value):
        """send a MIDI poly aftertouch"""
        libpd.libpd_polyaftertouch(channel, pitch, value)


    def send_midibyte(const int port, const int value):
        """send a raw MIDI byte

        value is a raw midi byte value 0 - 255
        port is the raw portmidi port #, similar to a channel

        for some reason, [midiin], [sysexin] & [realtimein] add 2 to the
        port num, so sending to port 1 in PdBase returns port 3 in pd

        however, [midiout], [sysexout], & [realtimeout] do not add to the
        port num, so sending port 1 to [midiout] returns port 1 in PdBase
        """
        libpd.libpd_midibyte(port, value)


    # send a raw MIDI sysex byte
    def send_sysex(const int port, const int value):
        libpd.libpd_sysex(port, value)


    # send a raw MIDI realtime byte
    def send_sysrealtime(const int port, const int value):
        libpd.libpd_sysrealtime(port, value)

# ----------------------------------------------------------------------------
# Stream Interface

# single messages
#
#     pd << Bang("test") # "test" is the receiver name in pd
#     pd << Float("test", 100)
#     pd << Symbol("test", "a symbol")
#

    # send a bang message
    PdBase& operator<<(const pd::Bang &var):
        if(PdContext.instance().msg_in_progress):
            self.log.warn("Pd: cannot send Bang, message in progress")
            return *this
    
        send_bang(var.dest.encode('utf-8'))
        return *this


    # send a float message
    PdBase& operator<<(const pd::Float &var):
        if(PdContext.instance().msg_in_progress):
            self.log.warn("Pd: cannot send Float, message in progress")
            return *this
    
        send_float(var.dest.encode('utf-8'), var.num)
        return *this


    # send a symbol message
    PdBase& operator<<(const pd::Symbol &var):
        if(PdContext.instance().msg_in_progress):
            self.log.warn("Pd: cannot send Symbol, message in progress")
            return *this
    
        sendSymbol(var.dest.encode('utf-8'), var.symbol.encode('utf-8'))
        return *this

# ----------------------------------------------------------------------------
# Stream Interface for Compound Messages

# pd << StartMessage() << 100 << 1.2 << "a symbol" << FinishList("test")
#

    # start a compound message
    PdBase& operator<<(const pd::StartMessage &var):
        start_message()
        return *this


    # finish a compound message and send it as a list
    PdBase& operator<<(const pd::FinishList &var):
        finish_list(var.dest)
        return *this


    # finish a compound message and send it as a message
    PdBase& operator<<(const pd::FinishMessage &var):
        finish_message(var.dest, var.msg)
        return *this


    # add a boolean as a float to the compound message
    PdBase& operator<<(const bool var):
        add_float((float) var)
        return *this


    # add an integer as a float to the compound message
    PdBase& operator<<(const int var):
        PdContext &context = PdContext.instance()
        switch(context.msg_type):
            case MSG:
                add_float((float) var)
                break
            case MIDI:
                send_midibyte(context.midiPort, var)
                break
            case SYSEX:
                send_sysex(context.midiPort, var)
                break
            case SYSRT:
                send_sysrealtime(context.midiPort, var)
                break
    
        return *this


    # add a float to the compound message
    PdBase& operator<<(const float var):
        add_float((float) var)
        return *this


    # add a double as a float to the compound message
    PdBase& operator<<(const double var):
        add_float((float) var)
        return *this


    # add a character as a symbol to the compound message
    PdBase& operator<<(const char var):
        str s
        s = var
        add_symbol(s)
        return *this


    # add a C-string char buffer as a symbol to the compound message
    PdBase& operator<<(const char *var):
        add_symbol((str)var)
        return *this


    # add a string as a symbol to the compound message
    PdBase& operator<<(str &var):
        add_symbol(var)
        return *this

# ----------------------------------------------------------------------------
# Stream Interface for MIDI

# pd << NoteOn(64) << NoteOn(64, 60) << NoteOn(64, 60, 1)
# pd << ControlChange(100, 64) << ProgramChange(100, 1)
# pd << Aftertouch(127, 1) << PolyAftertouch(64, 127, 1)
# pd << PitchBend(2000, 1)
#

    # send a MIDI note on
    PdBase& operator<<(const pd::NoteOn &var):
        send_noteon(var.channel, var.pitch, var.velocity)
        return *this


    # send a MIDI control change
    PdBase& operator<<(const pd::ControlChange &var):
        send_controlchange(var.channel, var.controller, var.value)
        return *this


    # send a MIDI program change
    PdBase& operator<<(const pd::ProgramChange &var):
        send_programchange(var.channel, var.value)
        return *this


    # send a MIDI pitch bend
    PdBase& operator<<(const pd::PitchBend &var):
        send_pitchbend(var.channel, var.value)
        return *this


    # send a MIDI aftertouch
    PdBase& operator<<(const pd::Aftertouch &var):
        send_aftertouch(var.channel, var.value)
        return *this


    # send a MIDI poly aftertouch
    PdBase& operator<<(const pd::PolyAftertouch &var):
        send_polyaftertouch(var.channel, var.pitch, var.value)
        return *this

# ----------------------------------------------------------------------------
# Stream Interface for Raw Bytes

# pd << StartMidi() << 0xEF << 0x45 << Finish()
# pd << StartSysex() << 0xE7 << 0x45 << 0x56 << 0x17 << Finish()
#

    # start a raw byte MIDI message
    PdBase& operator<<(const pd::StartMidi &var):
        PdContext &context = PdContext.instance()
        if(context.msg_in_progress):
            self.log.warn("Pd: cannot start MidiByte stream, msg in progress")
            return *this
    
        context.msg_in_progress = True
        context.msg_type = MIDI
        context.midiPort = var.port
        return *this


    # start a raw byte MIDI sysex message
    PdBase& operator<<(const pd::StartSysex &var):
        PdContext &context = PdContext.instance()
        if(context.msg_in_progress):
            self.log.warn("Pd: cannot start Sysex stream, msg in progress")
            return *this
    
        context.msg_in_progress = True
        context.msg_type = SYSEX
        context.midiPort = var.port
        return *this


    # start a raw byte MIDI realtime message
    PdBase& operator<<(const pd::StartSysRealTime &var):
        PdContext &context = PdContext.instance()
        if(context.msg_in_progress):
            self.log.warn("Pd: cannot start SysRealRime stream, msg in progress")
            return *this
    
        context.msg_in_progress = True
        context.msg_type = SYSRT
        context.midiPort = var.port
        return *this


    # finish and send a raw byte MIDI message
    PdBase& operator<<(const pd::Finish &var):
        PdContext &context = PdContext.instance()
        if(!context.msg_in_progress):
            self.log.warn("Pd: cannot finish midi byte stream, stream not in progress")
            return *this
    
        if(context.msg_type == MSG):
            self.log.warn("Pd: cannot finish midi byte stream, msg in progress")
            return *this
    
        context.msg_in_progress = False
        context.current_msg_len = 0
        return *this


    def is_message_in_progress() -> bool:
        """is a message or byte stream currently in progress?"""
        return PdContext.instance().msg_in_progress

# ----------------------------------------------------------------------------
# Array Access

    def array_size(str name) -> int:
        """get the size of a pd array

        returns 0 if array not found
        """
        int length = libpd.libpd_arraysize(name.encode('utf-8'))
        if(length < 0):
            self.log.warn(f"Pd: cannot get size of unknown array {name}")
            return 0
    
        return length


    def resize_array(str &name, long size) -> bool:
        """(re)size a pd array

        sizes <= 0 are clipped to 1
        returns True on success, False on failure
        """
        int ret = libpd.libpd_resize_array(name.encode('utf-8'), size)
        if(ret < 0):
            self.log.warn(f"Pd: cannot resize unknown array {name}")
            return False
        return True



    def read_array(str &name, std::vector<float> &dest, int read_len=-1, int offset=0) -> bool:
        """read from a pd array
        
        resizes given vector to read_len, checks read_len and offset
        
        returns True on success, False on failure
        
        calling without setting read_len and offset reads the whole array:
        
        vector<float> array1
        read_array("array1", array1)
        """
        int length = libpd.libpd_arraysize(name.encode('utf-8'))
        if(length < 0):
            self.log.warn("Pd: cannot read unknown array {name}")
            return False
    
        # full array length?
        if(read_len < 0):
            read_len = length
    
        # check read length
        else if(read_len > length):
            self.log.warn(
                f"Pd: given read length {read_len} > length {length} of array {name}"
            )
            return False
    
        # check offset
        if(offset + read_len > length):
            self.log.warn("Pd: given read length and offset > length {read_len} of array {name}")
            return False
    
        # resize if necessary
        if(dest.size() != read_len):
            dest.resize(read_len, 0)
    
        if(libpd.libpd_read_array(&dest[0], name.encode('utf-8'), offset, read_len) < 0):
            self.log.warn("Pd: libpd.libpd_read_array failed for array {name}")
            return False
    
        return True


    def write_array(str &name, std::vector<float> &source,
                            int write_len=-1, int offset=0) -> bool:
        """write to a pd array

        calling without setting write_len and offset writes the whole array:
        write_array("array1", array1)
        """
        int length = libpd.libpd_arraysize(name.encode('utf-8'))
        if(length < 0):
            self.log.warn("Pd: cannot write to unknown array {name}")
            return False
    

        # full array length?
        if(write_len < 0):
            write_len = length
    

        # check write length
        else if(write_len > length):
            self.log.warn("Pd: given write length {write_len} > length {length} of array {name}")
            return False
    

        # check offset
        if(offset+write_len > length):
            self.log.warn("Pd: given write length and offset > length " << write_len
                 << " of array \"" << name << "\"" << std::endl
            return False
    

        if(libpd.libpd_write_array(name.encode('utf-8'), offset,
                             &source[0], write_len) < 0):
            self.log.warn("Pd: libpd.libpd_write_array failed for array \""
                 << name << "\"" << std::endl
            return False
    
        return True


    def clear_array(str &name, int value=0):
        """clear array and set to a specific value"""
        int length = libpd.libpd_arraysize(name.encode('utf-8'))
        if(length < 0):
            self.log.warn("Pd: cannot clear unknown array \""
                 << name << "\"" << std::endl
            return
    
        std::vector<float> array
        array.resize(length, value)
        if(libpd.libpd_write_array(name.encode('utf-8'), 0, &array[0], length) < 0):
            self.log.warn("Pd: libpd.libpd_write_array failed while clearing array \""
                 << name << "\"" << std::endl
    

# ----------------------------------------------------------------------------
# Utils


    def is_inited() -> bool:
        """has the global pd instance been initialized?"""
        return PdContext.instance().is_inited()

    def is_queued() -> bool:
        """is the global pd instance using the ringerbuffer queue
        for message padding?
        """
        return PdContext.instance().is_queued()

    def blocksize() -> int:
        """get the blocksize of pd (sample length per channel)"""
        return libpd.libpd_blocksize()

    def set_max_message_len(unsigned int length):
        """set the max length of messages and lists, default: 32"""
        PdContext.instance().max_message_len = length

    def max_message_len() -> int:
        """get the max length of messages and lists"""
        return PdContext.instance().max_message_len


protected:

    # compound message status
    enum MsgType:
        MSG,
        MIDI,
        SYSEX,
        SYSRT


    # a singleton libpd instance wrapper
    class PdContext:

    public:

        # singleton data access
        # returns a reference to itself
        # note: only creates a new object on the first call
        static PdContext& instance():
            static PdBase::PdContext *singletonInstance = new PdContext
            return *singletonInstance
    

        # increments the num of pd base objects
        void addBase():numBases++}

        # decrements the num of pd base objects
        # clears if removing last base
        void removeBase():
            if(numBases > 0):
                numBases--
        
            else if(bInited): # double check clear
                clear()
        
    

        # init the pd instance
        bool init(const int numInChannels, const int numOutChannels,
                  const int sampleRate, bool queued):

            # attach callbacks
            bQueued = queued
            if(queued):
                libpd.libpd_set_queued_printhook(libpd.libpd_print_concatenator)
                libpd.libpd_set_concatenated_printhook(_print)

                libpd.libpd_set_queued_banghook(_bang)
                libpd.libpd_set_queued_floathook(_float)
                libpd.libpd_set_queued_symbolhook(_symbol)
                libpd.libpd_set_queued_listhook(_list)
                libpd.libpd_set_queued_messagehook(_message)

                libpd.libpd_set_queued_noteonhook(_noteon)
                libpd.libpd_set_queued_controlchangehook(_controlchange)
                libpd.libpd_set_queued_programchangehook(_programchange)
                libpd.libpd_set_queued_pitchbendhook(_pitchbend)
                libpd.libpd_set_queued_aftertouchhook(_aftertouch)
                libpd.libpd_set_queued_polyaftertouchhook(_polyaftertouch)
                libpd.libpd_set_queued_midibytehook(_midibyte)
                
                # init libpd, should only be called once!
                if(!bLibPdInited):
                    libpd.libpd_queued_init()
                    bLibPdInited = True
            
        
            else:
                libpd.libpd_set_printhook(libpd.libpd_print_concatenator)
                libpd.libpd_set_concatenated_printhook(_print)

                libpd.libpd_set_banghook(_bang)
                libpd.libpd_set_floathook(_float)
                libpd.libpd_set_symbolhook(_symbol)
                libpd.libpd_set_listhook(_list)
                libpd.libpd_set_messagehook(_message)

                libpd.libpd_set_noteonhook(_noteon)
                libpd.libpd_set_controlchangehook(_controlchange)
                libpd.libpd_set_programchangehook(_programchange)
                libpd.libpd_set_pitchbendhook(_pitchbend)
                libpd.libpd_set_aftertouchhook(_aftertouch)
                libpd.libpd_set_polyaftertouchhook(_polyaftertouch)
                libpd.libpd_set_midibytehook(_midibyte)

                # init libpd, should only be called once!
                if(!bLibPdInited):
                    libpd.libpd_init()
                    bLibPdInited = True
            
        

            # init audio
            if(libpd.libpd_init_audio(numInChannels,
                                numOutChannels,
                                sampleRate) != 0):
                return False
        
            bInited = True

            return bInited
    

        # clear the pd instance
        void clear():

            # detach callbacks
            if(bInited):
                compute_audio(False)
                if(bQueued):
                    libpd.libpd_set_queued_printhook(NULL)
                    libpd.libpd_set_concatenated_printhook(NULL)

                    libpd.libpd_set_queued_banghook(NULL)
                    libpd.libpd_set_queued_floathook(NULL)
                    libpd.libpd_set_queued_symbolhook(NULL)
                    libpd.libpd_set_queued_listhook(NULL)
                    libpd.libpd_set_queued_messagehook(NULL)

                    libpd.libpd_set_queued_noteonhook(NULL)
                    libpd.libpd_set_queued_controlchangehook(NULL)
                    libpd.libpd_set_queued_programchangehook(NULL)
                    libpd.libpd_set_queued_pitchbendhook(NULL)
                    libpd.libpd_set_queued_aftertouchhook(NULL)
                    libpd.libpd_set_queued_polyaftertouchhook(NULL)
                    libpd.libpd_set_queued_midibytehook(NULL)

                    libpd.libpd_queued_release()
            
                else:
                    libpd.libpd_set_printhook(NULL)
                    libpd.libpd_set_concatenated_printhook(NULL)

                    libpd.libpd_set_banghook(NULL)
                    libpd.libpd_set_floathook(NULL)
                    libpd.libpd_set_symbolhook(NULL)
                    libpd.libpd_set_listhook(NULL)
                    libpd.libpd_set_messagehook(NULL)

                    libpd.libpd_set_noteonhook(NULL)
                    libpd.libpd_set_controlchangehook(NULL)
                    libpd.libpd_set_programchangehook(NULL)
                    libpd.libpd_set_pitchbendhook(NULL)
                    libpd.libpd_set_aftertouchhook(NULL)
                    libpd.libpd_set_polyaftertouchhook(NULL)
                    libpd.libpd_set_midibytehook(NULL)
            
        
            bInited = False
            bQueued = False

            msg_in_progress = False
            current_msg_len = 0
            msgType = MSG
            midiPort = 0
    

        # turn dsp on/off
        void compute_audio(bool state):
            # [ pd dsp $1(
            libpd.libpd_start_message(1)
            libpd.libpd_add_float((float) state)
            libpd.libpd_finish_message("pd", "dsp")
    

        # is the instance inited?
        inline bool is_inited():return bInited}

        # is this instance queued?
        inline bool is_queued():return bQueued}

# ----------------------------------------------------------------------------
    # Variables

        bool msg_in_progress    #< is a compound message being constructed?
        int max_message_len     #< maximum allowed message length
        int current_msg_len     #< the length of the current message

        # compound message status
        PdBase::MsgType msgType

        int midiPort   #< target midi port

        std::map<str,void*> sources    #< subscribed sources

        pd::PdReceiver *receiver               #< the message receiver
        pd::PdMidiReceiver *midi_receiver       #< the midi receiver

    private:

        bool bLibPdInited #< has libpd.libpd_init be called?
        bool bInited      #< is this pd context inited?
        bool bQueued #< is this context using the libpd.libpd_queued ringbuffer?

        unsigned int numBases #< number of pd base objects

        # hide all the constructors, copy functions here
        PdContext():                      # cannot create
            bLibPdInited = False
            bInited = False
            bQueued = False
            numBases = False
            receiver = NULL
            midi_receiver = NULL
            clear()
            max_message_len = 32
    
        virtual ~PdContext():             # cannot destroy
            # triple check clear
            if(bInited):clear()}
    
        void operator=(PdContext &from):} # not copyable

        # libpd static callback functions
        static void _print(const char *s):
            PdContext &context = PdContext.instance()
            if(context.receiver):
                context.receiver->print((str)s)
        
    

        static void _bang(const char *source):
            PdContext &context = PdContext.instance()
            if(context.receiver):
                context.receiver->receiveBang((str)source)
        
    

        static void _float(const char *source, float value):
            PdContext &context = PdContext.instance()
            if(context.receiver):
                context.receiver->receiveFloat((str)source, value)
        
    

        static void _symbol(const char *source, const char *symbol):
            PdContext &context = PdContext.instance()
            if(context.receiver):
                context.receiver->receiveSymbol((str)source,
                                                (str)symbol)
        
    

        static void _list(const char *source, int argc, t_atom *argv):
            PdContext &context = PdContext.instance()
            pd::List list
            for(int i = 0 i < argc i++):
                t_atom a = argv[i]
                if(a.a_type == A_FLOAT):
                    float f = a.a_w.w_float
                    list.add_float(f)
            
                else if(a.a_type == A_SYMBOL):
                    const char *s = a.a_w.w_symbol->s_name
                    list.add_symbol((str)s)
            
        
            if(context.receiver):
                context.receiver->receiveList((str)source, list)
        
    

        static void _message(const char *source, const char *symbol,
                             int argc, t_atom *argv):
            PdContext &context = PdContext.instance()
            pd::List list
            for(int i = 0 i < argc i++):
                t_atom a = argv[i]
                if(a.a_type == A_FLOAT):
                    float f = a.a_w.w_float
                    list.add_float(f)
            
                else if(a.a_type == A_SYMBOL):
                    const char *s = a.a_w.w_symbol->s_name
                    list.add_symbol((str)s)
            
        
            if(context.receiver):
                context.receiver->receiveMessage((str)source,
                                                 (str)symbol, list)
        
    

        static void _noteon(int channel, int pitch, int velocity):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receiveNoteOn(channel, pitch, velocity)
        
    

        static void _controlchange(int channel, int controller, int value):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receiveControlChange(channel,
                                                           controller,
                                                           value)
        
    

        static void _programchange(int channel, int value):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receiveProgramChange(channel, value)
        
    

        static void _pitchbend(int channel, int value):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receivePitchBend(channel, value)
        
    

        static void _aftertouch(int channel, int value):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receiveAftertouch(channel, value)
        
    

        static void _polyaftertouch(int channel, int pitch, int value):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receivePolyAftertouch(channel,
                                                            pitch,
                                                            value)
        
    

        static void _midibyte(int port, int byte):
            PdContext &context = PdContext.instance()
            if(context.midi_receiver):
                context.midi_receiver->receiveMidiByte(port, byte)
        
    

cdef class Singleton:
    _instances = {}
    @classmethod
    def instance(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = cls(*args, **kwargs)
        return cls._instances[cls]

cdef class MyCythonClass(Singleton):
    cdef int apple, orange
    def __cinit__(self, int apple, int orange):
        self.apple = apple
        self.orange = orange
    pass

# usage: MyCythonClass.instance(10, 21)

