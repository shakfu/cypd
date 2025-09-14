# Embedding Pure Data as a DSP library

This page describes the low-level C API of libpd.  There are separate pages for the language wrappers: [Java](/libpd/libpd/wiki/java), [C++](/libpd/libpd/wiki/cpp), [Objective-C](/libpd/libpd/wiki/objc), etc.

_Note: As of libpd 0.12.0, API documentation is now also found in the [z_libpd.h header](https://github.com/libpd/libpd/blob/master/libpd_wrapper/z_libpd.h)._

## Introduction

Fundamentally, the heart and soul of a DSP library is a rendering callback that takes input samples and computes output samples.  Samples go in, magic happens, samples come out.  That's signal processing in its purest form.  In Pure Data, this functionality is intermingled with driver code.  The main purpose of libpd is to liberate raw audio rendering from audio drivers and MIDI drivers.

The second purpose of libpd is to allow for straightforward exchange of control and MIDI messages between Pure Data and client code.  libpd supports bang, float, and symbol messages, as well as lists and typed messages.  (In other words, pointer messages are the only messages that are not supported.)  Client code sends messages to symbols in Pure Data, i.e., messages sent to Pd are akin to those from message boxes of the form **[; foo args(**.  Client code can subscribe to messages sent to symbols in Pd, i.e., adding a subscription is akin to adding a receiver object **[r foo]** in Pd.

## Build Settings

libpd itself is "pure C" and only requires a C compiler. You will, however, need to set the following defines in your C flags in order to build it successfully:

    -DPD -DHAVE_UNISTD_H -DUSEAPI_DUMMY

* `PD`: sets defines for building libpd
* `HAVE_UNISTD_H`: the unix standard headers are available
* `USEAPI_DUMMY`: use the dummy interface instead of a sound api

### Optional

Optional build defines:

    -DHAVE_LIBDL -DLIBPD_EXTRA -DPDINSTANCE -DPDTHREADS

* `HAVE_LIBDL`: support precompiled pure data external dynamic library loading, requires linking libdl via `-ldl`
* `LIBPD_EXTRA`: init pure-data/extra externals in libpd_init(), requires building libpd with the externals source files
* `PDINSTANCE`: compile with multi-instance support
* `PDTHREADS`: compile with per-thread storage for global variables, required for multi-instance support
* `PD_LONGINTTYPE`: set the default long integer type, for Windows 64 set this to "long long"
* `PD_FLOATSIZE`: set the float precision, 32 (default) or 64, ex. `PD_FLOATSIZE=64`

*Note: Dynamic loading is not allowed on the iOS App Store, so leave HAVE_LIBDL out.*

### libpd in Xcode

If you are building libpd in Xcode manually, you will need to add `-DHAVE_ALLOCA_H` as well:

    -DPD -DHAVE_UNISTD_H -DUSEAPI_DUMMY -DHAVE_ALLOCA_H

* `HAVE_ALLOCA_H`: include alloca.h on Unixes

These flags are set in the "Other C Flags" in libpd.xcodeproj.

## Initializing Pd

* `void libpd_init()`  
Initialize libpd.  It is safe to call this more than once. Note that this function sets up signal handling so that floating point exceptions (SIGFPE) will be ignored.  The goal is to make sure that bad Pd patches cannot cause a crash by dividing by zero.  If you want to handle SIGFPE in your code, you can install a handler after calling `libpd_init()`.

* `void libpd_clear_search_path()`  
Clear the Pd search path, i.e. the path where Pd looks for abstractions and externals. Clearing the search path is usually unnecessary because libpd_init() already takes care of this.

* `void libpd_add_to_search_path(const char *path)`  
Add path to the Pd search path. Relative paths are relative to the current working directory of the program.

Noter: Unlike desktop Pd, libpd only looks at the search path; the extra path is not used.

## Opening patches

* `void *libpd_openfile(const char *name, const char *dir)`  
Open a patch and return an opaque pointer that serves as a handle to the patch; returns NULL on failure.  The handle is useful for closing the patch and for getting its $0 id.

* `void libpd_closefile(void *p)`  
Close the patch corresponding to the patch handle pointer.

* `int libpd_getdollarzero(void *p)`  
Return the $0 tag of the patch corresponding to the patch handle pointer.

## Audio processing with Pd

* `int libpd_blocksize()`  
Return the block size of Pd (default 64).  Pd computes audio in ticks of 64 frames at a time.

* `int libpd_init_audio(int inChannels, int outChannels, int sampleRate)`  
Initialize audio rendering for the given number of input/output channels and sample rate.  The return value is 0 if and only if the initialization of Pd succeeded.

* `int libpd_process_float(int ticks, const float *inBuffer, float *outBuffer)`  
Read one buffer of input samples from `inBuffer`, process them with Pd, and write one buffer of output samples to `outBuffer`.  In order to reduce the overhead of functions calls, libpd offers the option of processing more than one Pd tick per audio rendering call.  For minimal latency, choose one tick.  If you run into performance issues, try a larger number.  The size of each buffer must be the product of the number of channels, the number of ticks, and the number of samples per tick.  (The number of samples per tick is the value returned by `libpd_blocksize()`, i.e. 64.)  Samples will be interleaved in the buffer, i.e. if there are two input channels, then `inBuf[0]` is the first sample for the left channel, `inBuffer[1]` is the first sample for the right channel, `inBuffer[2]` is the second sample for the left channel, etc.  The return value is 0 if and only if the call succeeded.

* `int libpd_process_double(int ticks, const double *inBuffer, double *outBuffer)`  
Like `libpd_process_float`, but with double precision.

* `int libpd_process_short(int ticks, const short *inBuffer, short *outBuffer)`  
Like `libpd_process_float`, but with short samples.  Float samples from Pd are converted to shorts by multiplying by 32767 and casting to short.  For efficiency reasons, this method does not clip the input.  If the float samples from Pd are outside the interval [-1, 1], then the converted short samples will be garbage.  If you expect samples outside of [-1, 1], you need to clip them yourself in your Pd patch.

* `int libpd_process_raw(const float *inBuffer, float *outBuffer)`  
Process one Pd tick and copy the contents of the buffers directly to/from Pd, without striping.  In other words, the channels will be stacked rather than interleaved in inBuffer and outBuffer.

* `int libpd_process_raw_double(const double *inBuffer, double *outBuffer)`  
Like `libpd_process_raw`, but with double samples.

* `int libpd_process_raw_short(const short *inBuffer, short *outBuffer)`  
Like `libpd_process_raw`, but with short samples.

Note that libpd does not provide any timing functionality of its own.  It only keeps track of time in terms of the number of Pd ticks that have been processed.  Calling the process function at the right times is the responsibility of the client.

## Accessing arrays in Pd

libpd provides limited access to arrays in Pd.  In particular, it offers a pair of functions modeled after `memcpy` for reading from and writing to arrays in Pd.  Unlike `memcpy`, however, these functions perform as much sanity checking as possible; they will return an error code if client code attempts to reach beyond the bounds of the arrays in Pd.  Bounds of the client arrays are not checked; those are the responsibility of the client code.

* `int libpd_arraysize(const char *name)`  
Return the size of the given array, or a negative error code if the array doesn't exist.

* `int libpd_resize_array(const char *name, long size)`  
Resize the given array, or a negative error code if the array doesn't exist.

* `int libpd_read_array(float *dest, const char *name, int offset, int n)`  
Read n values of a named source array and write them to the dest, starting at offset, returns 0 on success.  Will return a negative error code if the array in Pd doesn't exist or if the range given by n and offset exceeds the range of the array.  Performs no bound checking on the float array dest.

* `int libpd_write_array(const char *name, int offset, float *src, int n)`  
Read n values from the float array src and write them to a named destination array.  Range checks and error codes as above.

## Sending messages to Pd

Messages from libpd are received by Pd at the beginning of the next tick, i.e.: at the beginning of the next call to one of the functions of the `libpd_process` family.

Simple messages (bang, float, symbol) are sent to Pd with a single function call.

* `int libpd_bang(const char *recv)`  
Send a bang to the destination receiver, i.e. `libpd_bang("foo")` acts like a bang sent
to **[s foo]** in Pd.

* `int libpd_float(const char *recv, float x)`  
Send a float to the destination receiver.  The return value is 0 if and only if the call succeeded.

* `int libpd_symbol(const char *recv, const char *symbol)`  
Send a symbol to the destination receiver.  The return value is 0 if and only if the call succeeded.

### Sending compound messages: Simple approach for wrapping

There are two ways to send compound (i.e., list or typed) messages to libpd.  The simple approach consists of a sequence of function calls that are easily wrapped for use with other languages, such as Java or Objective-C.

* `int libpd_start_message(int maxlen)`  
Initiate the composition of a new list or typed message.  The length argument indicates an upper bound for the number of elements in the compound message, and the return value is a status code that is zero on success, or nonzero if the length is too large.  Note:  You have to start each list or typed message with libpd_start_message, but you don't have to finish it; it's okay to abandon a message without further cleanup.  Also, since the length argument is an upper bound, it's okay to request more elements up front than you will actually use in the end.

* `void libpd_add_float(float x)`  
Add a float to the current message

* `void libpd_add_symbol(const char *symbol)`  
Add a symbol to the current message

* `int libpd_finish_list(const char *recv)`  
Finish a list message and send it to the destination receiver.  For instance, the behavior of **[; foo 1 2 a(** is achieved with  
```c
if (libpd_start_message(16)) { // request space for 16 elements
  // handle allocation failure, very unlikely in this case
}
libpd_add_float(1);
libpd_add_float(2);
libpd_add_symbol("a");
libpd_finish_list("foo");
```  
The return value is 0 if and only if the call succeeded.  Note that we requested 16 elements, but we used only three.  That's perfectly fine.

* `int libpd_finish_message(const char *recv, const char *symbol)`  
Finish a typed message and send it to the destination receiver, with the message name given by the symbol argument.  For instance, the effect of **[; pd dsp 1(** is achieved with  
```c  
if (libpd_start_message(16)) { // request space for 16 elements
  // handle allocation failure, very unlikely in this case
}
libpd_add_float(1); // we're actually using only one element here
libpd_finish_message("pd", "dsp");
```  
The return value is 0 if and only if the call succeeded.  Note that libpd will let you send a typed message of arbitrary length, but Pd itself will currently only handle typed messages with up to four arguments.

### Sending compound messages: Flexible approach

A slightly more flexible approach to compound messages allows client code to assemble a compound message in an array of type `t_atom[]`.  The client code is responsible for managing the array, but the libpd API protects client code from the internals of `t_atom` by providing convenience functions that manipulate instances of `t_atom`.

* `void libpd_set_float(t_atom *a, float x)`  
Write a float value to the given atom.

* `void libpd_set_symbol(t_atom *a, const char *symbol)`  
Write a symbol value to the given atom.

* `int libpd_list(const char *recv, int argc, t_atom *argv)`  
Send a list given by a length and an array of atoms to the given destination receiver.  The return value is zero on success, or a negative error code otherwise.

* `int libpd_message(const char *recv, const char *msg, int argc, t_atom *argv)`  
Send a typed message to the given destination receiver.  The return value is zero on success, or a negative error code otherwise.

For example, the typed message `[; foo bar 3.14 zzz(` would be encoded like this:  
```c  
t_atom v[2];
libpd_set_float(v, 3.14);
libpd_set_symbol(v + 1, "zzz");
libpd_message("foo", "bar", 2, v);
```

## Receiving messages from Pd

In order to receive messages from Pd, client code needs register callback functions and subscribe to messages sent to one or more symbols.

* `void *libpd_bind(const char *symbol)`  
Subscribe to messages sent to the given source receiver.  The call `libpd_bind("foo")` adds an object to the patch that behaves much like `[r foo]`, with the output being passed on to the various message hooks of libpd.  The return value is an opaque pointer to the new receiver object; save it in a variable if you want to be able to delete this object later.  
The call to `libpd_bind()` should take place _after_ the call to `libpd_init()`.

* `void libpd_unbind(void *p)`  
Delete the object referred to by the pointer `p`.  This is mostly intended for removing source receivers created by `libpd_bind`.

Once the client has subscribed to messages sent to one or more symbols, libpd will try to call the corresponding message hooks.  A subscription to print messages is automatic.  In order to receive print messages from Pd, client code must define a function with the right signature and assign its pointer to `libpd_printhook`.  In order to receive bangs, define the right kind of function and assign it to `libpd_banghook`, etc.

* `t_libpd_printhook libpd_printhook`  
Pointer to the function that is called when Pd wants to print; NULL by default.  
`typedef (*t_libpd_printhook)(const char *s)`  
Signature for print hooks; the argument s is the string to be printed.

* `t_libpd_banghook libpd_banghook`  
Pointer to the function that is called when Pd wants to send a bang to libpd; `NULL` by default.  If the client has subscribed to the symbol foo with `libpd_bind`, then a bang sent with **[s foo]** will result in the function call `libpd_banghook("foo")`.  
`typedef (*t_libpd_banghook)(const char *recv)`  
Signature for bang hooks; recv is the name of the source receiver.

* `t_libpd_floathook libpd_floathook`  
`typedef (*t_libpd_floathook)(const char *recv, float value)`

* `t_libpd_symbolhook libpd_symbolhook`  
`typedef (*t_libpd_symbolhook)(const char *recv, const char *symbol)`

* `t_libpd_listhook libpd_listhook`  
`typedef (*t_libpd_listhook)(const char *recv, int argc, t_atom *argv)`  
Signature for list hooks.  Argument argc is the length of the list, and the vector argv contains the list elements.  In order to evaluate to list for further processing, you probably want to use a loop like this one:  
```c
int i;
for (i = 0; i < argc; i++) {
  t_atom *a = &argv[n];
  if (libpd_is_float(a)) {
    float x = libpd_get_float(a);
    // do something with the float x
  } else if (libpd_is_symbol(a)) {
    char *s = libpd_get_symbol(a);
    // do something with the C string s
  }
  else {
    // pd pointer type? ignore, currently unsupported
  }
}
```  
Note that we need to check for both floats and symbols (i.e., the second if-statement is not redundant) because atoms can also be of pointer type, which is not supported by libpd.

* `t_libpd_messagehook libpd_messagehook`  
`typedef (*t_libpd_messagehook)(const char *recv, const char *symbol, int argc, t_atom *argv)`  
Signature for typed message hooks; a message like **[; foo bar 1 2 a b(** will trigger a function call like `libpd_messagehook("foo", "bar", 4, argv)`.

_Note: In general, avoid setting the various hook functions while Pd's DSP is running._

For easier access to the list elements provided by libpd_listhook and libpd_messagehook, a set of atom accessors is provided:

* `int libpd_is_float(t_atom *a)`  
Returns 1 if the atom is a float type, otherwise 0. Does *not* perform a NULL check.

* `int libpd_is_symbol(t_atom *a)`  
Returns 1 if the atom is a symbol type, otherwise 0. Does *not* perform a NULL check.

* `float libpd_get_float(t_atom *a)`  
Get the atom's float value. Does *not* perform any NULL or type checks.

* `const char *libpd_get_symbol(t_atom *a)`  
Get the atom's symbol value. Does *not* perform any NULL or type checks.

* `t_atom *libpd_next_atom(t_atom *a)`  
Increment and return the next atom in a vector or NULL, assuming the atom vector is NULL-terminated. (It should be!).

## MIDI support in libpd

libpd supports MIDI in the sense that it provides a mechanism for passing MIDI events between libpd and client code that works exactly like the message passing mechanism described above.

When dealing with MIDI messages, there is always some confusion over the meaning of argument.  For instance, channel numbers officially range from 1 to 16, while the wire format encodes channel numbers from 0 to 15.  Pitch bend values range from -8192 to 8191, but the wire format encodes pitch bend values from 0 to 16383, with 8192 corresponding to the neutral position.  Moreover, Pd has a notion of MIDI ports in addition to MIDI channels, and its bendin/bendout objects disagree on the right offset; bendin will output values between 0 and 16383, while bendout expects input values between -8192 and 8191.  libpd papers over all these subtleties by establishing the following overall conventions:

* Channel numbers start at 0.
* Channel numbers in libpd encode both Pd channels and ports in the following way: libpd_channel =  pd_channel + 16 * pd_port.  In particular, any nonnegative integer is a valid channel number as far as libpd is concerned.
* In your code that uses libpd, pitch bend values range from -8192 to 8191, for both input and output. Inside of your patch, bendin will still output values between 0 and 16383, and bendout should still receive values between -8192 and 8191.

In order to send MIDI events to Pd, use the following functions.  Each function performs range checks on its arguments and returns a nonzero error code if an argument is out of range.  If all arguments are within range, it will send the event to Pd and return 0.

* `int libpd_noteon(int channel, int pitch, int velocity)`
* `int libpd_controlchange(int channel, int controller, int value)`
* `int libpd_programchange(int channel, int program)`
* `int libpd_pitchbend(int channel, int value)`
* `int libpd_aftertouch(int channel, int value)`
* `int libpd_polyaftertouch(int channel, int pitch, int value)`
* `int libpd_midibyte(int port, int value)`
* `int libpd_sysex(int port, int value)`
* `int libpd_sysrealtime(int port, int value)`

Note that the last three functions, `libpd_midibyte`, `libpd_sysex`, and `libpd_sysrealtime`, take port numbers instead of channel numbers, and they handle one raw MIDI byte at a time, for **[midiin]**, **[sysex]**, and **[realtimein]**.

In order to receive MIDI events from Pd, implement functions matching the appropriate signatures and assign them to the desired callback hooks.  Arguments are guaranteed to be in range; if a Pd patch sends invalid arguments to a MIDI output object, libpd will clamp them to the appropriate range before invoking callback hooks.

* `t_libpd_noteonhook libpd_noteonhook`  
`typedef void (*t_libpd_noteonhook)(int channel, int pitch, int velocity)`

* `t_libpd_controlchangehook libpd_controlchangehook`  
`typedef void (*t_libpd_controlchangehook)(int channel, int controller, int value)`

* `t_libpd_programchangehook libpd_programchangehook`  
`typedef void (*t_libpd_programchangehook)(int channel, int program)`

* `t_libpd_pitchbendhook libpd_pitchbendhook`  
`typedef void (*t_libpd_pitchbendhook)(int channel, int value)`

* `t_libpd_aftertouchhook libpd_aftertouchhook`  
`typedef void (*t_libpd_aftertouchhook)(int channel, int value)`

* `t_libpd_polyaftertouchhook libpd_polyaftertouchhook`  
`typedef void (*t_libpd_polyaftertouchhook)(int channel, int pitch, int value)`

* `t_libpd_midibytehook libpd_midibytehook`  
`typedef void (*t_libpd_midibytehook)(int port, int value)`  

Note: There seems to be a slight asymmetry in the behavior of MIDI functions; incoming MIDI messages with invalid arguments are rejected, while invalid outgoing arguments are clamped to the appropriate range.  The reason is that each side is as strict as seems reasonable.  Incoming messages come from a language like C or Java where it's easy to handle error conditions, and so libpd will just return an error code if it gets bad arguments.  Outgoing messages come from a Pd patch where range and error checking is more cumbersome, and so libpd is more lenient in this case. 

### Difference in [midiin] functionality compared to Pd vanilla

Note that libpd doesn't do any internal midi byte parsing. This means that the **[midiin]** object in libpd works differently than the pd-vanilla one. For example, while in pd-vanilla **[noteon]** messages will also be received by **[notein]** *and* **[midiin]**, in libpd only data sent using `libpd_midibyte` will be received by the **[midiin]** object.

## GUI

libpd can initiate communication with a desktop Pd GUI instance in order to see and edit patches running inside a libpd instance in real time. Essentially, libpd needs to know where the desktop Pd version is installed and can then start the GUI, similar to how starting desktop Pd's core `bin/pd` executable will autostart the GUI.

* `int libpd_start_gui(char *path)`  
Open the current patches within a Pd vanilla GUI. This requires the path to Pd's main folder that contains bin/, tcl/, etc. For a macOS .app bundle, this is `/path/to/Pd-#.#-#.app/Contents/Resources`. Returns 0 on success.

* `void libpd_stop_gui(void)`  
Stops the Pd vanilla GUI currently connected with the libpd instance.

* `void libpd_poll_gui(void)`  
Call this to manually update and handle any GUI messages. This is called automatically when using a libpd_process function. Note, this also facilitates network message processing, etc so it can be useful to call repeatedly when idle for more throughput.

## Multiple Instances

libpd can support multiple instances when compiled with the PDINSTANCE and PDTHREADS defines. An "instance" is essentially an enclosed pd environment with it's own patches, audio i/o, and messaging.

Basic usage is to create an instance, then set the current instance to use when making libpd API calls. The t_pdinstance type is an instance pointer handle.

* `t_pdinstance *libpd_new_instance(void)`  
Create a new pd instance and returns an instance pointer handle or NULL when libpd is not compiled with PDINSTANCE.

* `void libpd_set_instance(t_pdinstance *p)`  
Set the current pd instance. Subsequent libpd calls will then affect this instance only. This does nothing when libpd is not compiled with PDINSTANCE.

* `void libpd_free_instance(t_pdinstance *p)`  
Free a pd instance. Does nothing when libpd is not compiled with PDINSTANCE

* `t_pdinstance *libpd_this_instance(void)`  
Get the current pd instance. Should always return a valid instance, regardless if libpd is compiled with PDINSTANCE or not.

* `t_pdinstance *libpd_get_instance(int index)`  
Get a pd instance by index. Returns NULL if the index is out of bounds or "this" instance when libpd is not compiled with PDINSTANCE.

* `int libpd_num_instances(void)`  
Get the number of pd instances. Returns 1 when libpd is not compiled with PDINSTANCE.

## Log Level

It may be useful to see the internal verbose printing from a pd instance, especially when debugging path or external loading issues.

* `void libpd_set_verbose(int verbose)`  
Set verbose print state, either 0 or 1.

* `int libpd_get_verbose(void)`  
Get the verbose print state, either 0 or 1.

###

## Using Pd in a threaded context

### libpd

As of version 0.11.0, the base libpd itself is thread-safe through the usage of Pd global lock mechanism and instance-specific data is declared "per thread" when compiled with the PDTHREADS define.

### libpd_queued

libpd_queued is a ringbuffer wrapper layer around the base libpd callbacks and is designed to be used in threaded contexts. Essentially, it intercepts messages and adds them to a ringbuffer, which you later on process manually. This adds flexibility for when to process recieved messages at the cost of some additional latency.

It is found in `libpd_wrapper/util/z_queued.h`.

The queued hook function pointer names are similar to the base libpd hook names with the addition of "queued". The function pointer types are the same as the base messaging hooks:
```c
t_libpd_printhook libpd_queued_printhook;
t_libpd_banghook libpd_queued_banghook;
... etc

t_libpd_noteonhook libpd_queued_noteonhook;
t_libpd_controlchangehook libpd_queued_controlchangehook;
... etc
```

The queued layer has additional functions for the ringbuffers:

* `int libpd_queued_init()`  
Initialize libpd and the queued ringbuffers. Use in place of `libpd_init()`.

* `void libpd_queued_release()`  
Frees the ringbuffers.

* `void libpd_queued_receive_pd_messages()`  
Process and dispatch received messages in the pd message ringbuffer, which is separate from the midi ringbuffer.

* `void libpd_queued_receive_midi_messages()`  
Process and dispatch receive midi messages in the midi message ringbuffer, which is separate form the pd message ringbuffer.

**Example usage**

Initializing libpd with the queued layer, setting our own custom hooks:
```c
libpd_queued_printhook = (t_libpd_printhook)libpd_print_concatenator;
libpd_concatenated_printhook = (t_libpd_printhook)printHook;

libpd_queued_banghook = (t_libpd_banghook)bangHook;
libpd_queued_floathook = (t_libpd_floathook)floatHook;
libpd_queued_symbolhook = (t_libpd_symbolhook)symbolHook;
libpd_queued_listhook = (t_libpd_listhook)listHook;
libpd_queued_messagehook = (t_libpd_messagehook)messageHook;

libpd_queued_noteonhook = (t_libpd_noteonhook)noteonHook;
libpd_queued_controlchangehook = (t_libpd_controlchangehook)controlChangeHook;
libpd_queued_programchangehook = (t_libpd_programchangehook)programChangeHook;
libpd_queued_pitchbendhook = (t_libpd_pitchbendhook)pitchBendHook;
libpd_queued_aftertouchhook = (t_libpd_aftertouchhook)aftertouchHook;
libpd_queued_polyaftertouchhook = (t_libpd_polyaftertouchhook)polyAftertouchHook;
libpd_queued_midibytehook = (t_libpd_midibytehook)midiByteHook;

libpd_queued_init();
```

Process the ringbuffers manually in whichever thread you want:
```c
libpd_queued_receive_pd_messages();
libpd_queued_receive_midi_messages();
```

## Concatenating Print Messages

By default, the `libpd_printhook` returns individual words and spaces:

ie. line "hello 123" is sent in 3 parts -> "hello", " ", "123\n".

libpd comes with a concatenation utility layer in `libpd_wrapper/util/z_print_util.h` that concatenates these messages and returns them as a single line with the endline char stripped.

* `t_libpd_printhook libpd_concatenated_printhook`  
Pointer to the function that is called when the concatenation layer has finished a full print line; NULL by default. The function pointer type is the same as the one called by `libpd_printhook`: `typedef (*t_libpd_printhook)(const char *s)`
 
Assign this function pointer to `libpd_printhook` or `libpd_queued_printhook`,
depending on whether you're using queued messages, to intercept and concatenate print messages. Then assign your printer handler to `libpd_concatenated_printhook`:  
```c
libpd_printhook = (t_libpd_printhook)libpd_print_concatenator;
libpd_concatenated_printhook = (t_libpd_printhook)yourPrintHandler;
```

Note: The concatenated string pointer argument returned to your print handler is only good for the duration of the print callback; if you intend to use the argument after the callback has returned, you need to make a defensive copy.
