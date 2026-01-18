
## configure options
# --prefix=${PREFIX} \
# --enable-shared=yes \
# --enable-static=yes \
# --enable-libpd \
# --enable-libpd-utils \
# --enable-libpd-instance \
# --enable-libpd-extra \
# --enable-portmidi \
# --enable-fftw \
# --without-local-portaudio \
# --without-local-portmidi \


CWD=$(pwd)
BUILD=${CWD}/build
THIRDPARTY=${CWD}/thirdparty
PD_VERSION=0.56-2


get_puredata() {
	echo "update from puredata main repo"
	NAME=pure-data
	PREFIX=${THIRDPARTY}/${NAME}
	INCLUDE=${PREFIX}/include
	LIB=${PREFIX}/lib
	mkdir -p ${BUILD} ${PREFIX} && \
		cd ${BUILD} && \
		if [ ! -d "${NAME}" ]; then
			git clone -b ${PD_VERSION} --depth=1 https://github.com/pure-data/pure-data.git
		fi && \
		cd ${NAME} && \
		./autogen.sh && \
		./configure \
			--prefix=${PREFIX} \
			--enable-libpd \
			--enable-libpd-utils \
			--enable-libpd-extra \
			--enable-portmidi \
			&& \
		make install && \
		cd ${CWD}
}


remove_current() {
	echo "remove current"
	rm -rf ${BUILD} ${THIRDPARTY}/pure-data
}


main() {
	remove_current
	get_puredata
}

main
