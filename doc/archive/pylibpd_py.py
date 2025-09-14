

import array


def process_args(args):
    if libpd.libpd_start_message(len(args)):
        return -2
    for arg in args:
        if isinstance(arg, str):
            libpd.libpd_add_symbol(arg)
        else:
            if isinstance(arg, int) or isinstance(arg, float):
                libpd.libpd_add_float(arg)
            else:
                return -1
    return 0


def libpd_list(recv, *args):
    return process_args(args) or libpd.libpd_finish_list(recv)


def libpd_message(recv, symbol, *args):
    return process_args(args) or libpd.libpd_finish_message(recv, symbol)


__libpd_patches = {}


def libpd_open_patch(patchannel, dir="."):
    ptr = libpd.libpd_openfile(patchannel, dir)
    if not ptr:
        raise IOError("unable to open patch: %s/%s" % (dir, patch))
    dz = libpd.libpd_getdollarzero(ptr)
    __libpd_patches[dz] = ptr
    return dz


def libpd_close_patch(dz):
    libpd.libpd_closefile(__libpd_patches[dz])
    del __libpd_patches[dz]


__libpd_subscriptions = {}


def libpd_subscribe(recv):
    if recv not in __libpd_subscriptions:
        __libpd_subscriptions[recv] = libpd.libpd_bind(recv)


def libpd_unsubscribe(recv):
    libpd.libpd_unbind(__libpd_subscriptions[recv])
    del __libpd_subscriptions[recv]


def libpd_compute_audio(flag):
    libpd_message("pd", "dsp", flag)


def libpd_release():
    for p in __libpd_patches.values():
        libpd.libpd_closefile(p)
    __libpd_patches.clear()
    for p in __libpd_subscriptions.values():
        libpd.libpd_unbind(p)
    __libpd_subscriptions.clear()


class PdManager:
    def __init__(self, inChannels, outChannels, sampleRate, ticks):
        self.ticks = ticks
        self.outbuf = array.array(
            "b", "\x00\x00".encode() * outChannels * libpd_blocksize()
        )
        libpd_compute_audio(1)
        libpd_init_audio(inChannels, outChannels, sampleRate)

    def process(self, inBuffer):
        libpd_process_short(self.ticks, inBuffer, self.outbuf)
        return self.outbuf

