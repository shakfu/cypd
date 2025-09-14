
include libportaudio.mk

all: portaudio
	@python3 setup.py build_ext --inplace
	@rm -rf ./build ./cypd.c ./libpd.c

%.o : %.c
	@$(CC) -c $(PORTAUDIO_CFLAGS) $< -o $@

%.o : %.cpp
	@$(CXX) -c $(PORTAUDIO_CPPFLAGS) $< -o $@

$(PORTAUDIO_STATIC_LIB): $(PORTAUDIO_OBJS)
	@ar rcs $(PORTAUDIO_STATIC_LIB) $(PORTAUDIO_OBJS)

portaudio: $(PORTAUDIO_STATIC_LIB)
	@echo "building portaudio as static lib..."

cypd: portaudio
	@CYPD=1 python3 setup.py build_ext --inplace	
	@rm -rf ./build ./cypd.c

libpd: portaudio
	@LIBPD=1 python3 setup.py build_ext --inplace	
	@rm -rf ./build ./libpd.c

demo: portaudio
	@DEMO=1 python3 setup.py build_ext --inplace	
	@rm -rf ./build ./demo.c

audio_test: portaudio
	@echo "generating portaudio c implementation test"
	@gcc -o test_audio tests/test_audio.c ../../libs/libpd.a \
		-framework CoreServices -framework CoreFoundation \
		-framework AudioUnit -framework AudioToolbox \
		-framework CoreAudio \
		-I ../../pure-data/src -I ../../libpd_wrapper \
		-I ../../libpd_wrapper/util -lportaudio
	@echo "now run ./test_audio "


minim: portaudio
	@echo "generating minimal test"
	@gcc -o minim tests/minimal.c ../../libs/libpd.a \
		-framework CoreServices -framework CoreFoundation \
		-framework AudioUnit -framework AudioToolbox \
		-framework CoreAudio \
		-I ../../pure-data/src -I ../../libpd_wrapper \
		-I ../../libpd_wrapper/util -lportaudio
	@echo "now run ./minim"

.PHONY: test clean test_atom

test-libpd:
	@python3 ./tests/test_libpd_audio.py

test-cypd:
	@python3 ./tests/test_cypd_audio.py

test-atom:
	@python3 ./tests/test_atom.py


clean-portaudio:
	@rm -f $(PORTAUDIO_OBJS)
	@rm -f $(PORTAUDIO_STATIC_LIB)

clean: clean-portaudio
	@rm -f *.so
	@rm -f test_audio
	@rm -f minim
