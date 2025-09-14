
.PHONY: all build cypd libpd demo test clean reset \
		test-cypd test-libpd test-atom 

LIBPD := thirdparty/pure-data/lib/libpd.a


all: build

$(LIBPD):
	@sh scripts/setup.sh

build: $(LIBPD)
	@python3 setup.py build_ext --inplace
	@rm -rf ./build ./cypd.c ./libpd.c

cypd:
	@CYPD=1 python3 setup.py build_ext --inplace	
	@rm -rf ./build ./cypd.c

libpd:
	@LIBPD=1 python3 setup.py build_ext --inplace	
	@rm -rf ./build ./libpd.c

demo:
	@DEMO=1 python3 setup.py build_ext --inplace	
	@rm -rf ./build ./demo.c


test-libpd:
	@python3 ./tests/test_libpd_audio.py

test-cypd:
	@python3 ./tests/test_cypd_audio.py

test-atom:
	@python3 ./tests/test_atom.py

clean:
	@rm -f *.so
	@rm -f test_audio
	@rm -f minim

reset: clean
	@rm -rf thirdparty/