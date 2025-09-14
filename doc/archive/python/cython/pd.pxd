
from libc.stdio cimport FILE
from libc.stdint cimport uint32_t, uint64_t

cdef extern from "../../pure-data/src/m_pd.h":
    """
    #undef T_OBJECT
    """
    ctypedef float t_float
    ctypedef struct t_pdinstance
    ctypedef float t_floatarg
    ctypedef float t_sample
    ctypedef long t_int

    ctypedef struct t_class
    ctypedef struct t_object
    ctypedef struct t_outlet
    ctypedef struct t_inlet
    ctypedef struct t_binbuf
    ctypedef struct t_clock
    ctypedef struct t_outconnect
    ctypedef struct t_gpointer
    ctypedef struct t_glist 
    ctypedef struct t_canvas
    ctypedef struct t_scalar
    ctypedef struct t_text
    ctypedef struct t_gobj
    ctypedef struct t_widgetbehavior
    ctypedef struct t_parentwidgetbehavior
    ctypedef struct t_array

    ctypedef t_class *t_pd

    ctypedef void (*t_gotfn)(void *x)
    ctypedef void (*t_method)()
    ctypedef void *(*t_newmethod)()

    ctypedef struct t_symbol:
        const char *s_name
        # struct _class **s_thing
        # struct _symbol *s_next


    ctypedef union t_word:
        t_float w_float
        t_symbol *w_symbol
        # t_gpointer *w_gpointer
        # t_array *w_array
        # struct _binbuf *w_binbuf
        # int w_index

    ctypedef enum t_atomtype:
        A_NULL
        A_FLOAT
        A_SYMBOL
        A_POINTER
        A_SEMI
        A_COMMA
        A_DEFFLOAT
        A_DEFSYM
        A_DOLLAR
        A_DOLLSYM
        A_GIMME
        A_CANT

    ctypedef struct t_atom:
        t_atomtype a_type
    #     union word a_w

    # messaging
    cdef void pd_typedmess(t_pd *x, t_symbol *s, int argc, t_atom *argv)
    cdef void pd_forwardmess(t_pd *x, int argc, t_atom *argv)
    cdef t_symbol *gensym(const char *s)
    cdef t_gotfn getfn(const t_pd *x, t_symbol *s)
    cdef t_gotfn zgetfn(const t_pd *x, t_symbol *s)
    cdef void nullfn()
    cdef void pd_vmess(t_pd *x, t_symbol *s, const char *fmt, ...)

    cdef void mess0(x, s)
    cdef void mess1(x, s, a)
    cdef void mess2(x, s, a, b)
    cdef void mess3(x, s, a, b, c)
    cdef void mess4(x, s, a, b, c, d)
    cdef void mess5(x, s, a, b, c, d, e)

    cdef void obj_list(t_object *x, t_symbol *s, int argc, t_atom *argv)
    cdef t_pd *pd_newest()

    # memory mgmt
    cdef void *getbytes(size_t nbytes)
    cdef void *getzbytes(size_t nbytes)
    cdef void *copybytes(const void *src, size_t nbytes)
    cdef void freebytes(void *x, size_t nbytes)
    cdef void *resizebytes(void *x, size_t oldsize, size_t newsize)

    # atoms
    cdef void SETSEMI(t_atom *atom)
    cdef void SETCOMMA(t_atom *atom)
    cdef void SETPOINTER(t_atom *atom, t_gpointer *gp)
    cdef void SETFLOAT(t_atom *atom, float f)
    cdef void SETSYMBOL(t_atom *atom, char *s)
    cdef void SETDOLLAR(t_atom *atom, int n)
    cdef void SETDOLLSYM(t_atom *atom, char *s)

    cdef t_float atom_getfloat(const t_atom *a)
    cdef t_int atom_getint(const t_atom *a)
    cdef t_symbol *atom_getsymbol(const t_atom *a)
    cdef t_symbol *atom_gensym(const t_atom *a)
    cdef t_float atom_getfloatarg(int which, int argc, const t_atom *argv)
    cdef t_int atom_getintarg(int which, int argc, const t_atom *argv)
    cdef t_symbol *atom_getsymbolarg(int which, int argc, const t_atom *argv)
    cdef void atom_string(const t_atom *a, char *buf, unsigned int bufsize)

    # binbuf
    cdef t_binbuf *binbuf_new()
    cdef void binbuf_free(t_binbuf *x)
    cdef t_binbuf *binbuf_duplicate(const t_binbuf *y)
    cdef void binbuf_text(t_binbuf *x, const char *text, size_t size)
    cdef void binbuf_gettext(const t_binbuf *x, char **bufp, int *lengthp)
    cdef void binbuf_clear(t_binbuf *x)
    cdef void binbuf_add(t_binbuf *x, int argc, const t_atom *argv)
    cdef void binbuf_addv(t_binbuf *x, const char *fmt, ...)
    cdef void binbuf_addbinbuf(t_binbuf *x, const t_binbuf *y)
    cdef void binbuf_addsemi(t_binbuf *x)
    cdef void binbuf_restore(t_binbuf *x, int argc, const t_atom *argv)
    cdef void binbuf_print(const t_binbuf *x)
    cdef int binbuf_getnatom(const t_binbuf *x)
    cdef t_atom *binbuf_getvec(const t_binbuf *x)
    cdef int binbuf_resize(t_binbuf *x, int newsize)
    cdef void binbuf_eval(const t_binbuf *x, t_pd *target, int argc, const t_atom *argv)
    cdef int binbuf_read(t_binbuf *b, const char *filename, const char *dirname, int crflag)
    # cdef int binbuf_read_via_canvas(t_binbuf *b, const char *filename, const t_canvas *canvas, int crflag)
    cdef int binbuf_read_via_path(t_binbuf *b, const char *filename, const char *dirname, int crflag)
    cdef int binbuf_write(const t_binbuf *x, const char *filename, const char *dir, int crflag)
    cdef void binbuf_evalfile(t_symbol *name, t_symbol *dir)
    cdef t_symbol *binbuf_realizedollsym(t_symbol *s, int ac, const t_atom *av, int tonew)

    # clock
    cdef t_clock *clock_new(void *owner, t_method fn)
    cdef void clock_set(t_clock *x, double systime)
    cdef void clock_delay(t_clock *x, double delaytime)
    cdef void clock_unset(t_clock *x)
    cdef void clock_setunit(t_clock *x, double timeunit, int sampflag)
    cdef double clock_getlogicaltime()
    cdef double clock_gettimesince(double prevsystime)
    cdef double clock_gettimesincewithunits(double prevsystime, double units, int sampflag)
    cdef double clock_getsystimeafter(double delaytime)
    cdef void clock_free(t_clock *x)

    # pure data
    cdef t_pd *pd_new(t_class *cls)
    cdef void pd_free(t_pd *x)
    cdef void pd_bind(t_pd *x, t_symbol *s)
    cdef void pd_unbind(t_pd *x, t_symbol *s)
    cdef t_pd *pd_findbyclass(t_symbol *s, const t_class *c)
    cdef void pd_pushsym(t_pd *x)
    cdef void pd_popsym(t_pd *x)
    cdef void pd_bang(t_pd *x)
    cdef void pd_pointer(t_pd *x, t_gpointer *gp)
    cdef void pd_float(t_pd *x, t_float f)
    cdef void pd_symbol(t_pd *x, t_symbol *s)
    cdef void pd_list(t_pd *x, t_symbol *s, int argc, t_atom *argv)
    cdef void pd_anything(t_pd *x, t_symbol *s, int argc, t_atom *argv)
    # cdef void pd_class(x)

    # pointers
    cdef void gpointer_init(t_gpointer *gp)
    cdef void gpointer_copy(const t_gpointer *gpfrom, t_gpointer *gpto)
    cdef void gpointer_unset(t_gpointer *gp)
    cdef int gpointer_check(const t_gpointer *gp, int headok)

    # patchable objects
    cdef t_inlet *inlet_new(t_object *owner, t_pd *dest, t_symbol *s1, t_symbol *s2)
    cdef t_inlet *pointerinlet_new(t_object *owner, t_gpointer *gp)
    cdef t_inlet *floatinlet_new(t_object *owner, t_float *fp)
    cdef t_inlet *symbolinlet_new(t_object *owner, t_symbol **sp)
    cdef t_inlet *signalinlet_new(t_object *owner, t_float f)
    cdef void inlet_free(t_inlet *x)

    cdef t_outlet *outlet_new(t_object *owner, t_symbol *s)
    cdef void outlet_bang(t_outlet *x)
    cdef void outlet_pointer(t_outlet *x, t_gpointer *gp)
    cdef void outlet_float(t_outlet *x, t_float f)
    cdef void outlet_symbol(t_outlet *x, t_symbol *s)
    cdef void outlet_list(t_outlet *x, t_symbol *s, int argc, t_atom *argv)
    cdef void outlet_anything(t_outlet *x, t_symbol *s, int argc, t_atom *argv)
    cdef t_symbol *outlet_getsymbol(t_outlet *x)
    cdef void outlet_free(t_outlet *x)
    cdef t_object *pd_checkobject(t_pd *x)

    # canvases
    cdef void glob_setfilename(void *dummy, t_symbol *name, t_symbol *dir)
    cdef void canvas_setargs(int argc, const t_atom *argv)
    cdef void canvas_getargs(int *argcp, t_atom **argvp)
    cdef t_symbol *canvas_getcurrentdir()
    cdef t_glist *canvas_getcurrent()
    cdef void canvas_makefilename(const t_glist *c, const char *file, char *result, int resultsize)
    cdef t_symbol *canvas_getdir(const t_glist *x)
    cdef char sys_font[]
    cdef char sys_fontweight[]
    cdef int sys_hostfontsize(int fontsize, int zoom)
    cdef int sys_zoomfontwidth(int fontsize, int zoom, int worstcase)
    cdef int sys_zoomfontheight(int fontsize, int zoom, int worstcase)
    cdef int sys_fontwidth(int fontsize)
    cdef int sys_fontheight(int fontsize)
    cdef void canvas_dataproperties(t_glist *x, t_scalar *sc, t_binbuf *b)
    cdef int canvas_open(const t_canvas *x, const char *name, const char *ext, char *dirresult, char **nameresult, unsigned int size, int bin)

    # widget behaviours
    cdef const t_parentwidgetbehavior *pd_getparentwidget(t_pd *x)

    # classes
    cdef t_class *class_new(t_symbol *name, t_newmethod newmethod, t_method freemethod, size_t size, int flags, t_atomtype arg1, ...)
    cdef t_class *class_new64(t_symbol *name, t_newmethod newmethod, t_method freemethod, size_t size, int flags, t_atomtype arg1, ...)
    cdef void class_free(t_class *c)
    cdef t_class *class_getfirst()
    cdef void class_addcreator(t_newmethod newmethod, t_symbol *s, t_atomtype type1, ...)
    cdef void class_addmethod(t_class *c, t_method fn, t_symbol *sel, t_atomtype arg1, ...)
    cdef void class_addbang(t_class *c, t_method fn)
    cdef void class_addpointer(t_class *c, t_method fn)
    cdef void class_doaddfloat(t_class *c, t_method fn)
    cdef void class_addsymbol(t_class *c, t_method fn)
    cdef void class_addlist(t_class *c, t_method fn)
    cdef void class_addanything(t_class *c, t_method fn)
    cdef void class_sethelpsymbol(t_class *c, t_symbol *s)
    cdef void class_setwidget(t_class *c, const t_widgetbehavior *w)
    cdef void class_setparentwidget(t_class *c, const t_parentwidgetbehavior *w)
    cdef const char *class_getname(const t_class *c)
    cdef const char *class_gethelpname(const t_class *c)
    cdef const char *class_gethelpdir(const t_class *c)
    cdef void class_setdrawcommand(t_class *c)
    cdef int class_isdrawcommand(const t_class *c)
    cdef void class_domainsignalin(t_class *c, int onset)
    cdef void class_set_extern_dir(t_symbol *s)
    # cdef void CLASS_MAINSIGNALIN(t_class *c, type, field) # what type is type? field?
    ctypedef void (*t_savefn)(t_gobj *x, t_binbuf *b)
    cdef void class_setsavefn(t_class *c, t_savefn f)
    cdef t_savefn class_getsavefn(const t_class *c)
    cdef void obj_saveformat(const t_object *x, t_binbuf *bb) # add format to bb
    ctypedef void (*t_propertiesfn)(t_gobj *x, t_glist *glist)
    cdef void class_setpropertiesfn(t_class *c, t_propertiesfn f)
    cdef t_propertiesfn class_getpropertiesfn(const t_class *c)
    ctypedef void (*t_classfreefn)(t_class *)
    cdef void class_setfreefn(t_class *c, t_classfreefn fn)

    # printing
    cdef void post(const char *fmt, ...)
    cdef void startpost(const char *fmt, ...)
    cdef void poststring(const char *s)
    cdef void postfloat(t_floatarg f)
    cdef void postatom(int argc, const t_atom *argv)
    cdef void endpost()
    cdef void bug(const char *fmt, ...)
    cdef void pd_error(const void *object, const char *fmt, ...)

    ctypedef enum t_loglevel:
        PD_CRITICAL
        PD_ERROR
        PD_NORMAL
        PD_DEBUG
        PD_VERBOSE

    cdef void logpost(const void *object, int level, const char *fmt, ...)

    # system interface routines
    cdef int sys_isabsolutepath(const char *dir)
    cdef void sys_bashfilename(const char *from_, char *to)
    cdef void sys_unbashfilename(const char *from_, char *to)
    cdef int open_via_path(const char *dir, const char *name, const char *ext, char *dirresult, char **nameresult, unsigned int size, int bin)
    cdef int sched_geteventno()
    cdef double sys_getrealtime()
    cdef int (*sys_idlehook)()   # hook to add idle time computation
    cdef int sys_open(const char *path, int oflag, ...)
    cdef int sys_close(int fd)
    cdef FILE *sys_fopen(const char *filename, const char *mode)
    cdef int sys_fclose(FILE *stream)

    # threading
    cdef void sys_lock()
    cdef void sys_unlock()
    cdef int sys_trylock()

    # signals
    ctypedef float PD_FLOATTYPE # can also be double
    ctypedef uint32_t PD_FLOATUINTTYPE # can also be uint64_t    
    # ctypedef PD_FLOATTYPE t_sample
    ctypedef union t_sampleint_union:
      t_sample f
      PD_FLOATUINTTYPE i

    cdef int MAXLOGSIG
    cdef int MAXSIGSIZE

    ctypedef struct t_signal:
        int s_n                         # number of points in the array
        t_sample *s_vec                 # the array
        t_float s_sr                    # sample rate
        int s_refcount                  # number of times used
        int s_isborrowed                # whether we're going to borrow our array
        t_signal *s_borrowedfrom        # signal to borrow it from
        t_signal *s_nextfree            # next in freelist
        t_signal *s_nextused            # next in used list
        int s_vecsize                   # allocated size of array in points

    ctypedef t_int *(*t_perfroutine)(t_int *args)


    cdef t_int *plus_perform(t_int *args)
    cdef t_int *zero_perform(t_int *args)
    cdef t_int *copy_perform(t_int *args)

    cdef void dsp_add_plus(t_sample *in1, t_sample *in2, t_sample *out, int n)
    cdef void dsp_add_copy(t_sample *in_, t_sample *out, int n)
    cdef void dsp_add_scalarcopy(t_float *in_, t_sample *out, int n)
    cdef void dsp_add_zero(t_sample *out, int n)

    cdef int sys_getblksize()
    cdef t_float sys_getsr()
    cdef int sys_get_inchannels()
    cdef int sys_get_outchannels()

    cdef void dsp_add(t_perfroutine f, int n, ...)
    cdef void dsp_addv(t_perfroutine f, int n, t_int *vec)
    cdef void pd_fft(t_float *buf, int npoints, int inverse)
    cdef int ilog2(int n)

    cdef void mayer_fht(t_sample *fz, int n)
    cdef void mayer_fft(int n, t_sample *real, t_sample *imag)
    cdef void mayer_ifft(int n, t_sample *real, t_sample *imag)
    cdef void mayer_realfft(int n, t_sample *real)
    cdef void mayer_realifft(int n, t_sample *real)

    cdef float *cos_table
    cdef int LOGCOSTABSIZE
    cdef int COSTABSIZE

    cdef int canvas_suspend_dsp()
    cdef void canvas_resume_dsp(int oldstate)
    cdef void canvas_update_dsp()
    cdef int canvas_dspstate

    ctypedef struct t_resample:
        int method            # up/downsampling method ID
        int downsample        # downsampling factor
        int upsample          # upsampling factor
        t_sample *s_vec       # here we hold the resampled data
        int      s_n 
        t_sample *coeffs      # coefficients for filtering...
        int      coefsize 
        t_sample *buffer      # buffer for filtering
        int      bufsize 

    cdef void resample_init(t_resample *x)
    cdef void resample_free(t_resample *x)
    cdef void resample_dsp(t_resample *x, t_sample *in_, int insize, t_sample *out, int outsize, int method)
    cdef void resamplefrom_dsp(t_resample *x, t_sample *in_, int insize, int outsize, int method)
    cdef void resampleto_dsp(t_resample *x, t_sample *out, int insize, int outsize, int method)


    # utility functions for signals
    cdef t_float mtof(t_float)
    cdef t_float ftom(t_float)
    cdef t_float rmstodb(t_float)
    cdef t_float powtodb(t_float)
    cdef t_float dbtorms(t_float)
    cdef t_float dbtopow(t_float)
    cdef t_float q8_sqrt(t_float)
    cdef t_float q8_rsqrt(t_float)
    cdef t_float qsqrt(t_float)  # old names kept for extern compatibility
    cdef t_float qrsqrt(t_float)

    # data
    #   graphical arrays
    ctypedef struct t_garray

    cdef t_class *garray_class
    cdef int garray_getfloatarray(t_garray *x, int *size, t_float **vec)
    cdef int garray_getfloatwords(t_garray *x, int *size, t_word **vec)
    cdef void garray_redraw(t_garray *x)
    cdef int garray_npoints(t_garray *x)
    cdef char *garray_vec(t_garray *x)
    cdef void garray_resize_long(t_garray *x, long n)
    cdef void garray_usedindsp(t_garray *x)
    cdef void garray_setsaveit(t_garray *x, int saveit)
    cdef t_glist *garray_getglist(t_garray *x)
    cdef t_array *garray_getarray(t_garray *x)
    cdef t_class *scalar_class

    cdef t_float *value_get(t_symbol *s)
    cdef void value_release(t_symbol *s)
    cdef int value_getfloat(t_symbol *s, t_float *f)
    cdef int value_setfloat(t_symbol *s, t_float f)

    # GUI interface - functions to send strings to TK
    ctypedef void (*t_guicallbackfn)(t_gobj *client, t_glist *glist)

    cdef void sys_vgui(const char *fmt, ...)
    cdef void sys_gui(const char *s)
    cdef void sys_pretendguibytes(int n)
    cdef void sys_queuegui(void *client, t_glist *glist, t_guicallbackfn f)
    cdef void sys_unqueuegui(void *client)
    #   dialog window creation and destruction */
    cdef void gfxstub_new(t_pd *owner, void *key, const char *cmd)
    cdef void gfxstub_deleteforkey(void *key)

    # pd instance
    cdef void sys_getversion(int *major, int *minor, int *bugfix)

    ctypedef struct t_instancemidi
    ctypedef struct t_instanceinter
    ctypedef struct t_instancecanvas
    ctypedef struct t_instanceugen
    ctypedef struct t_instancestuff

    cdef struct _template

    ctypedef struct t_pdinstance:
        double pd_systime                   # global time in Pd ticks
        t_clock *pd_clock_setlist           # list of set clocks
        t_canvas *pd_canvaslist             # list of all root canvases
        _template *pd_templatelist          # list of all templates
        int pd_instanceno                   # ordinal number of this instance
        t_symbol **pd_symhash               # symbol table hash table
        t_instancemidi *pd_midi             # private stuff for x_midi.c
        t_instanceinter *pd_inter           # private stuff for s_inter.c
        t_instanceugen *pd_ugen             # private stuff for d_ugen.c
        t_instancecanvas *pd_gui            # semi-private stuff in g_canvas.h
        t_instancestuff *pd_stuff           # semi-private stuff in s_stuff.h
        t_pd *pd_newest                     # most recently created object
        t_symbol  pd_s_pointer
        t_symbol  pd_s_float
        t_symbol  pd_s_symbol
        t_symbol  pd_s_bang
        t_symbol  pd_s_list
        t_symbol  pd_s_anything
        t_symbol  pd_s_signal
        t_symbol  pd_s__N
        t_symbol  pd_s__X
        t_symbol  pd_s_x
        t_symbol  pd_s_y
        t_symbol  pd_s_
        int pd_islocked

    cdef t_pdinstance *pdinstance_new();
    cdef void pd_setinstance(t_pdinstance *x);
    cdef void pdinstance_free(t_pdinstance *x);

    cdef t_symbol* s_pointer
    cdef t_symbol* s_float 
    cdef t_symbol* s_symbol
    cdef t_symbol* s_bang  
    cdef t_symbol* s_list  
    cdef t_symbol* s_anything
    cdef t_symbol* s_signal
    cdef t_symbol* s__N  
    cdef t_symbol* s__X
    cdef t_symbol* s_x
    cdef t_symbol* s_y
    cdef t_symbol* s_

    cdef t_canvas *pd_getcanvaslist()
    cdef int pd_getdspstate()

    cdef t_binbuf *text_getbufbyname(t_symbol *s) # get binbuf from text obj
    cdef void text_notifybyname(t_symbol *s)      # notify it was modified
    
    cdef void pd_undo_set_objectstate(t_canvas*canvas, t_pd*x, t_symbol*s, int undo_argc, t_atom*undo_argv, int redo_argc, t_atom*redo_argv)

