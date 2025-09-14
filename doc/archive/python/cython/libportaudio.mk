# portaudio as a static convenience library

#########################################
##### Defaults & Paths #####
UNAME_S := $(shell uname -s)

PUREDATA := ../../pure-data
PORTAUDIO := $(PUREDATA)/portaudio/portaudio

PORTAUDIO_CFLAGS = -DNEWBUFFER \
	-I$(PORTAUDIO)/include \
	-I$(PORTAUDIO)/src/common

PORTAUDIO_CPPFLAGS += \
	-I$(PORTAUDIO)/include \
	-I$(PORTAUDIO)/src/common

PORTAUDIO_LDFLAGS = -lportaudio \
	-framework CoreAudio \
	-framework AudioToolbox \
	-framework AudioUnit \
	-framework CoreFoundation \
	-framework CoreServices

# windows options
ASIO = 0
MINGW = 0

#########################################
##### Files, Binaries, & Libs #####

PORTAUDIO_STATIC_LIB = ../../libs/libportaudio.a

PORTAUDIO_SOURCES = \
	$(PORTAUDIO)/src/common/pa_allocation.c \
	$(PORTAUDIO)/src/common/pa_converters.c \
	$(PORTAUDIO)/src/common/pa_cpuload.c \
	$(PORTAUDIO)/src/common/pa_debugprint.c \
	$(PORTAUDIO)/src/common/pa_dither.c \
	$(PORTAUDIO)/src/common/pa_front.c \
	$(PORTAUDIO)/src/common/pa_process.c \
	$(PORTAUDIO)/src/common/pa_ringbuffer.c \
	$(PORTAUDIO)/src/common/pa_stream.c \
	$(PORTAUDIO)/src/common/pa_trace.c

ifeq ($(UNAME_S),Linux)
PORTAUDIO_CPPFLAGS += -I$(PORTAUDIO)/src/os/unix
PORTAUDIO_SOURCES += \
	$(PORTAUDIO)/src/os/unix/pa_unix_hostapis.c \
	$(PORTAUDIO)/src/os/unix/pa_unix_util.c \
	$(PORTAUDIO)/src/hostapi/alsa/pa_linux_alsa.c
endif

ifeq ($(UNAME_S),Darwin)
PORTAUDIO_CFLAGS += -DPA_USE_COREAUDIO
PORTAUDIO_CPPFLAGS += -I$(PORTAUDIO)/src/os/unix
PORTAUDIO_SOURCES += \
	$(PORTAUDIO)/src/os/unix/pa_unix_hostapis.c \
	$(PORTAUDIO)/src/os/unix/pa_unix_util.c \
	$(PORTAUDIO)/src/hostapi/coreaudio/pa_mac_core.c \
	$(PORTAUDIO)/src/hostapi/coreaudio/pa_mac_core_blocking.c \
	$(PORTAUDIO)/src/hostapi/coreaudio/pa_mac_core_utilities.c
# required for PortAudio to build on newer versions of macOS as it
# disables deprecation warnings stopping the build
PORTAUDIO_CFLAGS += -Wno-error -Wno-deprecated
endif


ifeq ($(OS),Windows_NT)
PORTAUDIO_CFLAGS += -DPA_USE_WMME
PORTAUDIO_CPPFLAGS += -I$(PORTAUDIO)/src/os/win
PORTAUDIO_SOURCES += \
    $(PORTAUDIO)/src/os/win/pa_win_coinitialize.c \
    $(PORTAUDIO)/src/os/win/pa_win_hostapis.c \
    $(PORTAUDIO)/src/os/win/pa_win_util.c \
    $(PORTAUDIO)/src/os/win/pa_win_waveformat.c \
    $(PORTAUDIO)/src/hostapi/wmme/pa_win_wmme.c
ifeq ($(ASIO),1)
PORTAUDIO_CFLAGS += -DPA_USE_ASIO
ifeq ($(MINGW),1)
# hack for /asio/ASIOSDK/common/combase.h
PORTAUDIO_CPPFLAGS += -DWINVER=0x0502 -D_WIN32_WINNT=0x0502
endif
PORTAUDIO_CPPFLAGS += \
    -I$(PUREDATA)/asio/ASIOSDK/common -I$(PUREDATA)/asio/ASIOSDK/host \
	-I$(PUREDATA)/asio/ASIOSDK/host/pc
PORTAUDIO_SOURCES += \
    $(PORTAUDIO)/src/hostapi/asio/iasiothiscallresolver.cpp \
    $(PORTAUDIO)/src/hostapi/asio/pa_asio.cpp
endif
endif


PORTAUDIO_HEADERS = \
	$(PORTAUDIO)/include/pa_asio.h \
	$(PORTAUDIO)/include/pa_jack.h \
	$(PORTAUDIO)/include/pa_linux_alsa.h \
	$(PORTAUDIO)/include/pa_mac_core.h \
	$(PORTAUDIO)/include/pa_win_waveformat.h \
	$(PORTAUDIO)/include/pa_win_wmme.h \
	$(PORTAUDIO)/include/portaudio.h \
	$(PORTAUDIO)/src/common/pa_allocation.h \
	$(PORTAUDIO)/src/common/pa_converters.h \
	$(PORTAUDIO)/src/common/pa_cpuload.h \
	$(PORTAUDIO)/src/common/pa_debugprint.h \
	$(PORTAUDIO)/src/common/pa_dither.h \
	$(PORTAUDIO)/src/common/pa_endianness.h \
	$(PORTAUDIO)/src/common/pa_gitrevision.h \
	$(PORTAUDIO)/src/common/pa_hostapi.h \
	$(PORTAUDIO)/src/common/pa_memorybarrier.h \
	$(PORTAUDIO)/src/common/pa_process.h \
	$(PORTAUDIO)/src/common/pa_ringbuffer.h \
	$(PORTAUDIO)/src/common/pa_stream.h \
	$(PORTAUDIO)/src/common/pa_trace.h \
	$(PORTAUDIO)/src/common/pa_types.h \
	$(PORTAUDIO)/src/common/pa_util.h \
	$(PORTAUDIO)/src/hostapi/asio/iasiothiscallresolver.h \
	$(PORTAUDIO)/src/hostapi/coreaudio/pa_mac_core_blocking.h \
	$(PORTAUDIO)/src/hostapi/coreaudio/pa_mac_core_internal.h \
	$(PORTAUDIO)/src/hostapi/coreaudio/pa_mac_core_utilities.h \
	$(PORTAUDIO)/src/os/unix/pa_unix_util.h \
	$(PORTAUDIO)/src/os/win/pa_win_coinitialize.h


PORTAUDIO_OBJS := $(addsuffix .o,$(basename $(PORTAUDIO_SOURCES)))

