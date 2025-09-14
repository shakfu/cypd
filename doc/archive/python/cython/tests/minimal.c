#include <errno.h>
#include <libproc.h>
#include <math.h>
#include <stdio.h>
#include <unistd.h>

#include "portaudio.h"
#include "z_libpd.h"
#include <stdlib.h>

#define SAMPLE_RATE 44100
#define N_TICKS 1
#define CHANNELS_IN 0
#define CHANNELS_OUT 2
#define BLOCKSIZE 64
#define IN_BUF (N_TICKS * CHANNELS_IN * BLOCKSIZE)
#define OUT_BUF (N_TICKS * CHANNELS_OUT * BLOCKSIZE)


int main(int argc, char** argv)
{
    // init pd
    int blcksize = libpd_blocksize();

    libpd_init();
    libpd_init_audio(1, 2, SAMPLE_RATE);
    // one channel in, one channel out


    // compute audio[; pd dsp 1]
    libpd_start_message(1);
    //one entry in list
    libpd_add_float(1.0f);
    libpd_finish_message("pd", "dsp");
    libpd_bind("foo");

    //open patch[;pd open file  folder(
    void *handle;
    handle = libpd_openfile("tests/pd/test.pd", "./");

    //t_atom v[2];

    int size = 2;
    t_atom *v = (t_atom *)malloc(size * sizeof(t_atom));

    libpd_set_float(v, 3.14);
    libpd_set_symbol(v + 1, "zzz");
    libpd_message("foo", "bar", 2, v);
    free(v);

    libpd_float("myMessage", 11001);

    libpd_closefile(handle);
    return 0;
}
