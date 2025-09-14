#include <errno.h>
#include <libproc.h>
#include <math.h>
#include <stdio.h>
#include <unistd.h>

#include "portaudio.h"
#include "z_libpd.h"

#define SAMPLE_RATE 44100
#define N_TICKS 1
#define CHANNELS_IN 0
#define CHANNELS_OUT 2
#define BLOCKSIZE 64
#define IN_BUF (N_TICKS * CHANNELS_IN * BLOCKSIZE)
#define OUT_BUF (N_TICKS * CHANNELS_OUT * BLOCKSIZE)


typedef struct {
    // buffersize = ticks * libpd_blocksize() * (in/out)channels
    double inbuf[IN_BUF];
    // one input channel, two output channels
    //      block   size    64, one tick per buffer
    double outbuf[OUT_BUF];
    // stereo outputs are interlaced, s[0] = RIGHT, s[1] =
    // LEFT, etc..

} UserAudioData;

// globals
static UserAudioData data;
float fooFloat = 0;

/*
 * This routine will be called by the PortAudio engine when audio is needed. *
 * It may called at interrupt level on some machines so don't do anything *
 * that could mess up the system like calling malloc() or free().
 */
static int patestCallback(const void* inputBuffer, void* outputBuffer,
    unsigned long framesPerBuffer,
    const PaStreamCallbackTimeInfo* timeInfo,
    PaStreamCallbackFlags statusFlags, void* userData)
{
    /* Cast data passed through stream to our structure. */
    UserAudioData* data = (UserAudioData*)userData;
    float* out = (float*)outputBuffer;
    unsigned int i;

    (void)inputBuffer; /* Prevent unused variable warning. */

    /*
    If this is not exactly called here, either no audio
    or audio becomes higher pitched
    */
    libpd_process_double(1, data->inbuf, data->outbuf);

    // dsp perform routine
    for (i = 0; i < framesPerBuffer * CHANNELS_OUT; i++) {
        if (i % 2)
            *out++ = data->outbuf[i];
        // right channel
        else
            *out++ = data->outbuf[i];
        // left channel
    }

    return 0;
}

// use with libpd_printhook to print to console
void pdprint(const char* s) { printf("libpd print: %s", s); }

// use with libpd_noteonhook to print to console
void pdnoteon(int ch, int pitch, int vel)
{
    printf("noteon: %d %d %d\n", ch, pitch, vel);
}

// use with libpd_floathook to get data from[s foo]
void pdfloat(const char* source, float f)
{
    printf("(%s): %f\n", source, f);
    fooFloat = f;
}

int main(int argc, char** argv)
{
    printf("PortAudio Test: with libpd.\n");

    // init pd
    int blcksize = libpd_blocksize();
    printf("libpd blocksize: %d\n", blcksize);


    libpd_set_printhook(pdprint);
    // libpd_set_noteonhook(pdnoteon);

    libpd_set_floathook(pdfloat);
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


    PaStream *  stream; //opens the audio stream
    PaError err;

    libpd_float("myMessage", 11001);

    /* Initialize our data for use by callback. */
    for (int i = 0; i < blcksize; i++)
        data.outbuf[i] = 0;

    /* Initialize library before making any other calls. */
    err = Pa_Initialize();
    if (err != paNoError)
        goto error;

    /* Open an audio I/O stream. */
    err = Pa_OpenDefaultStream(
        &stream, 
        CHANNELS_IN,    /* input channels */
        CHANNELS_OUT,   /* output channels */
        paFloat32, /* 32 bit floating point
        * output */
        SAMPLE_RATE, 
        (long)blcksize,   /* frames per buffer */
        patestCallback,
        &data);
    if (err != paNoError)
        goto error;

    err = Pa_StartStream(stream);
    if (err != paNoError)
        goto error;

    Pa_Sleep(2000);
    //sleeps for 2 seconds, then ends.

    err = Pa_StopStream(stream);
    if (err != paNoError)
        goto error;
    
    err = Pa_CloseStream(stream);
    if (err != paNoError)
        goto error;
    
    Pa_Terminate();

    return err;

error:
    Pa_Terminate();
    fprintf(stderr, "An error occured while using the portaudio stream\n");
    fprintf(stderr, "Error number: %d\n", err);
    fprintf(stderr, "Error message: %s\n", Pa_GetErrorText(err));

    libpd_closefile(handle);
    return 0;
}
