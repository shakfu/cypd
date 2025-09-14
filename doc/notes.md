# Dev Notes


## Portaudio Notes

Steps to writing a PortAudio application using the callback technique:

1. Write a callback function that will be called by PortAudio when audio processing is needed.

2. Initialize the PA library and open a stream for audio I/O.

3. Start the stream. Your callback function will be now be called repeatedly by PA in the background.

4. In your callback you can read audio data from the inputBuffer and/or write data to the outputBuffer.

5. Stop the stream by returning 1 from your callback, or by calling a stop function.

6. Close the stream and terminate the library.


## Cython exceptoins

This is correct way to raise for cdefs

```python
cdef public int baz() except -1:
    raise ValueError
```


## Links


### cython array variants

- [Cython for NumPy users — Cython 0.29.30 documentation](https://cython.readthedocs.io/en/stable/src/userguide/numpy_tutorial.html)

- [Working with NumPy — Cython 0.29.30 documentation](https://cython.readthedocs.io/en/stable/src/tutorial/numpy.html)

- [Typed Memoryviews — Cython 0.29.30 documentation](http://docs.cython.org/en/stable/src/userguide/memoryviews.html)

- [Working with Python arrays — Cython 0.29.30 documentation](https://cython.readthedocs.io/en/stable/src/tutorial/array.html)

- [cython-__init__.pxd at master · cython-cython](https://github.com/cython/cython/blob/master/Cython/Includes/numpy/__init__.pxd)

- [array — Efficient arrays of numeric values — Python 3.10.5 documentation](https://docs.python.org/3/library/array.html)

- [python - Cython typed memoryviews- what they really are? - Stack Overflow](https://stackoverflow.com/questions/37432076/cython-typed-memoryviews-what-they-really-are)

- [python - Passing-Returning Cython Memoryviews vs NumPy Arrays - Stack Overflow](https://stackoverflow.com/questions/49803899/passing-returning-cython-memoryviews-vs-numpy-arrays)

- [python - What is the recommended way of allocating memory for a typed memory view? - Stack Overflow](https://stackoverflow.com/questions/18462785/what-is-the-recommended-way-of-allocating-memory-for-a-typed-memory-view)

- [python - convert numpy array to cython pointer - Stack Overflow](https://stackoverflow.com/questions/10718699/convert-numpy-array-to-cython-pointer)

- [python - float64 to float32 Cython Error - Stack Overflow](https://stackoverflow.com/questions/18985395/float64-to-float32-cython-error)

- [How do I convert Cython array to Python object so I can return the result? - Stack Overflow](https://stackoverflow.com/questions/44640094/how-do-i-convert-cython-array-to-python-object-so-i-can-return-the-result)

- [How to convert python array to cython array? - Stack Overflow](https://stackoverflow.com/questions/11689967/how-to-convert-python-array-to-cython-array)

- [c - Return a 2D Cython pointer to Python array - Stack Overflow](https://stackoverflow.com/questions/62084515/return-a-2d-cython-pointer-to-python-array)



### concurrency and parallelism

- [Structured Concurrency - Lucian Radu Teodorescu - ACCU 2022](https://www.youtube.com/watch?v=Xq2IMOPjPs0)

- [std::execution, the proposed C++ framework for asynchronous and parallel programming](https://github.com/brycelelbach/wg21_p2300_std_execution)

- [Working with Asynchrony Generically: A Tour of C++ Executors (part 1/2) - Eric Niebler - CppCon 21](https://www.youtube.com/watch?v=xLboNIf7BTg)

- [Working with Asynchrony Generically: A Tour of C++ Executors (part 2/2) - Eric Niebler - CppCon 21](https://www.youtube.com/watch?v=6a0zzUBUNW4)


### Threading

- [Calling C Posix Threads from Python Through Cython - Minimatech](https://minimatech.org/calling-c-posix-threads-from-python-through-cython/)

- [PortAudio Wiki](https://github.com/PortAudio/portaudio/wiki)

- [Multithreading in C - GeeksforGeeks](https://www.geeksforgeeks.org/multithreading-c-2/)

- [NN-Python-CythonFuncs.py at master · Philip-Bachman-NN-Python](https://github.com/Philip-Bachman/NN-Python/blob/master/nlp/CythonFuncs.py)

- [Parallel computing in Cython - threads | Neal Hughes](https://nealhughes.net/parallelcomp2/)

- [So how would you do multithreaded apps with cython while avoiding stuff like the... | Hacker News](https://news.ycombinator.com/item?id=8484335)

- [[Portaudio] Best Practice- number of open streams and threads](https://portaudio.music.columbia.narkive.com/h3qe0KPG/best-practice-number-of-open-streams-and-threads)

- [c - PortAudio callbacks, and changing a variable elsewhere - Stack Overflow](https://stackoverflow.com/questions/38341423/portaudio-callbacks-and-changing-a-variable-elsewhere)

- [c - PortAudio real-time audio processing for continuous input stream - Stack Overflow](https://stackoverflow.com/questions/44645466/portaudio-real-time-audio-processing-for-continuous-input-stream)

- [c - Safe operations on PortAudio's PaStreamFinishedCallback - Stack Overflow](https://stackoverflow.com/questions/48014791/safe-operations-on-portaudios-pastreamfinishedcallback)

- [cpenny42-Pd-for-LibPd- A collection of Pure-Data patches to provide extra functionality while also b…](https://github.com/cpenny42/Pd-for-LibPd)

- [cython class inheritance with python threading · Issue #2834 · cython-cython](https://github.com/cython/cython/issues/2834)

- [threading — Thread-based parallelism — Python 3.10.5 documentation](https://docs.python.org/3/library/threading.html)


### Implementation Variants

- [funkerresch-audioappdemo- An example of binding qt, libpd and portaudio together.](https://github.com/funkerresch/audioappdemo)

- [lukexi-pd-hs- Self-contained cross-platform Haskell bindings to LibPd and PortAudio](https://github.com/lukexi/pd-hs)

- [myQwil-luapd- libpd bindings for lua](https://github.com/myQwil/luapd)

- [pierreguillot-juce_libpd- A Juce module that integrates libpd](https://github.com/pierreguillot/juce_libpd)

- [synthcastle-main.cpp at main · aparks5-synthcastle](https://github.com/aparks5/synthcastle/blob/main/src/main.cpp)


- [xlab-libpd-go- Package libpd provides an idiomatic Go-lang wrapper for Pure Data embeddable audio sy…](https://github.com/xlab/libpd-go)


### Audio Threads

- [Audio Toolbox | Apple Developer Documentation](https://developer.apple.com/documentation/audiotoolbox)

- [Best practice for timing (Audio thread) - Getting Started - JUCE](https://forum.juce.com/t/best-practice-for-timing-audio-thread/31337/2)

- [Four common mistakes in audio development](https://atastypixel.com/four-common-mistakes-in-audio-development/)

- [Real-Time Multi-Threading in an Audio Application - Development - JUCE](https://forum.juce.com/t/real-time-multi-threading-in-an-audio-application/44268/4)

- [Sending signal-events from audio to GUI thread? - General JUCE discussion - JUCE](https://forum.juce.com/t/sending-signal-events-from-audio-to-gui-thread/27792)

- [Thread Safety - Page 2 - DSP and Plug-in Development Forum - KVR Audio](https://www.kvraudio.com/forum/viewtopic.php?t=195050&start=15)

- [Using locks in real-time audio processing, safely – timur.audio](https://timur.audio/using-locks-in-real-time-audio-processing-safely)

- [c++ - Audio threading - Stack Overflow](https://stackoverflow.com/questions/26680789/audio-threading)

- [c++ - Multithreaded Realtime audio programming - To block or Not to block - Stack Overflow](https://stackoverflow.com/questions/27738660/multithreaded-realtime-audio-programming-to-block-or-not-to-block)

- [multithreading - Audio producer threads with OSX AudioComponent consumer thread and callback in C - …](https://stackoverflow.com/questions/29355364/audio-producer-threads-with-osx-audiocomponent-consumer-thread-and-callback-in-c)


### Dynamic Allocation in PD

- [allocation example](https://github.com/pure-data/pure-data/blob/master/src/x_text.c)
- [forum question](https://www.mail-archive.com/pd-dev@lists.iem.at/msg02689.html)


### Cython singleton

- [how to make a cython singletone](https://stackoverflow.com/questions/51263233/singleton-in-cython-handled-by-classmethod)

