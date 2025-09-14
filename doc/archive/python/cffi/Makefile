

all:
	@python3 libpd/_libpd_build.py
	@rm -rf libpd/_libpd.c libpd/_libpd.o libpd/__pycache__



.PHONY: test clean

test:
	@python3 ./tests/test_audio.py


clean:
	@rm -f *.so
	@rm -rf build
