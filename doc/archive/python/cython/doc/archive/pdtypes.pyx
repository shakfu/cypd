
#include <string>
#include <vector>
#include <iostream>
#include <sstream>

namespace pd:

# ----------------------------------------------------------------------------
# Pd Patch

class Patch:
    """a pd patch

    if you use the copy conclassor/operator, keep in mind the libpd void*
    pointer patch handle is copied and problems can arise if one object is used
    to close a patch that other copies may be referring to
    """

    def __cinit__(self):
        self._handle = NULL
        self._dollarzero = 0
        self._dollarstring = "0"
        self._filename = ""
        self._path = ""

    @staticmethod
    from_path(filename: str, path: str):
        _handle(NULL), _dollarZero(0), _dollarZeroStr("0"),
        _filename(filename), _path(path):

    @staticmethod
    from_handle(void *handle, int dollarZero, filename: str, path: str) :
        _handle(handle), _dollarZero(dollarZero),
        _filename(filename), _path(path):
            std::stringstream itoa
            itoa << dollarZero
            _dollarZeroStr = itoa.str()
        

    # get the raw pointer to the patch instance
    def void* handle():
        return self._handle

    # get the unqiue instance $0 ID
    def int dollarZero():
        return self._dollarZero

    # get the patch filename
    def std::string filename():
        return self._filename

    # get the parent dir path for the file
    def std::string path():
        return self._path

    # get the unique instance $0 ID as a string
    def std::string dollarZeroStr():
        return self._dollarZeroStr

    # is the patch pointer valid?
    def bool is_valid():
        return self._handle != NULL

    # clear patch pointer and dollar zero (does not close patch!)
    #
    # note: does not clear filename and path so the object can be reused
    #        for opening multiple instances
    void clear() :
       self._handle = NULL
       self._dollarZero = 0
       self._dollarZeroStr = "0"
    

    # copy conclassor
    Patch(const Patch &other):
        self._handle = other._handle
        self._dollarZero = other._dollarZero
        self._dollarZeroStr = other._dollarZeroStr
        self._filename = other._filename
        self._path = other._path
    

    # copy operator
    void operator=(const Patch &other):
        self._handle = other._handle
        self._dollarZero = other._dollarZero
        self._dollarZeroStr = other._dollarZeroStr
        self._filename = other._filename
        self._path = other._path
    

    # print info to ostream
    friend std::ostream& operator<<(std::ostream &os, const Patch &other):
        return os << "Patch: \"" << other.filename() << "\" $0: "
                  << other.dollarZeroStr() << " valid: " << other.isValid()
    

private:

    void *_handle              # patch handle pointer
    int _dollarZero            # the unique $0 patch ID
    str _dollarZeroStr # $0 as a string

    str _filename      # filename
    str _path          # full path to parent folder


# ----------------------------------------------------------------------------
# Pd stream interface message objects

# bang event
class Bang:

    dest: str # dest receiver name

    def __init__(self, dest): 
        self.dest = dest


# float value
class Float:

    str dest # dest receiver name
    float num        # the float value

    def __init__(self, str &dest, const float num) :
        dest(dest), num(num):


# symbol value
class Symbol:

    str dest   # dest receiver name
    str symbol # the symbol value

    def __init__(self, str &dest, str &symbol) :
        dest(dest), symbol(symbol):


# a compound message containing floats and symbols
class List:

public:

    List():

# ----------------------------------------------------------------------------
# Read

    # check if index is a float type
    def isFloat(int index) -> bool:
        if(index < objects.size())
            if(objects[index].type == List::FLOAT)
                return true
        return false
    

    # check if index is a symbol type
    def isSymbol(int index) -> bool:
        if(index < objects.size())
            if(objects[index].type == List::SYMBOL)
                return true
        return false
    

    # get index as a float
    def getFloat(int index) -> float:
        if(!isFloat(index)):
            std::cerr << "Pd: List object " << index << " is not a float"
                      << std::endl
            return 0
        
        return objects[index].value
    

    # get index as a symbol
    def getSymbol(int index) -> str:
        if(!isSymbol(index)):
            std::cerr << "Pd: List object " << index << " is not a symbol"
                      << std::endl
            return ""
        
        return objects[index].symbol
    

# \section Write
#
# add elements to the list
#
# List list
# list.addSymbol("hello")
# list.addFloat(1.23)
#

    # add a float to the list
    def addFloat(float num):
        MsgObject o
        o.type = List::FLOAT
        o.value = num
        objects.push_back(o)
        typeString += 'f'
    

    # add a symbol to the list
    def addSymbol(str &symbol):
        MsgObject o
        o.type = List::SYMBOL
        o.symbol = symbol
        objects.push_back(o)
        typeString += 's'
    

# \section Write Stream Interface
#
# list << "hello" << 1.23
#

    # add a float to the message
    List& operator<<(bool var):
        addFloat((float) var)
        return *this
    

    # add a float to the message
    List& operator<<(int var):
        addFloat((float) var)
        return *this
    

    # add a float to the message
    List& operator<<(float var):
        addFloat((float) var)
        return *this
    

    # add a float to the message
    List& operator<<(double var):
        addFloat((float) var)
        return *this
    

    # add a symbol to the message
    List& operator<<(char var):
        std::string s
        s = var
        addSymbol(s)
        return *this
    

    # add a symbol to the message
    List& operator<<(char *var):
        addSymbol((std::string) var)
        return *this
    

    # add a symbol to the message
    List& operator<<(str &var):
        addSymbol((std::string) var)
        return *this
    

# ----------------------------------------------------------------------------
# Util

    # return number of items
    unsigned int len() const:return (unsigned int) objects.size()

    # return OSC style type string ie "fsfs"
    str& types() const:return typeString

    # clear all objects
    void clear():
        typeString = ""
        objects.clear()
    

    # get list as a string
    std::string toString() const:
        std::string line
        std::stringstream itoa
        for(int i = 0 i < (int)objects.size() ++i):
            if(isFloat(i)):
                itoa << getFloat(i)
                line += itoa.str()
                itoa.str("")
            
            else
                line += getSymbol(i)
            line += " "
        
        return line
    

    # print to ostream
    friend std::ostream& operator<<(std::ostream &os, List &from):
        return os << from.toString()
    

private:

    std::string typeString # OSC style type string

    # object type
    enum MsgType:
        FLOAT,
        SYMBOL
    

    # object wrapper
    class MsgObject:
        MsgType type
        float value
        std::string symbol
    

    std::vector<MsgObject> objects # list objects


# start a compound message
class StartMessage:
    explicit StartMessage():


# finish a compound message as a list
class FinishList:

    str dest # dest receiver name

    explicit FinishList(str &dest) : dest(dest):


# finish a compound message as a typed message
class FinishMessage:

    str dest # dest receiver name
    str msg  # target msg at the dest

    FinishMessage(str &dest, str &msg) :
            dest(dest), msg(msg):


# ----------------------------------------------------------------------------
# Pd stream interface midi objects
# ref: http://www.gweep.net/~prefect/eng/reference/protocol/midispec.html

class NoteOn:
    """send a note on event (set vel = 0 for noteoff)"""

    int channel  # channel (0 - 15 * dev#)
    int pitch    # pitch (0 - 127)
    int velocity # velocity (0 - 127)

    NoteOn(int channel, int pitch, int velocity=64) :
        channel(channel), pitch(pitch), velocity(velocity):



class ControlChange:
    """change a control value aka send a CC message"""

    int channel    # channel (0 - 15 * dev#)
    int controller # controller (0 - 127)
    int value      # value (0 - 127)

    ControlChange(int channel, int controller, int value) :
        channel(channel), controller(controller), value(value):


class ProgramChange:
    """change a program value (ie an instrument)"""

    int channel # channel (0 - 15 * dev#)
    int value   # value (0 - 127)

    ProgramChange(int channel, int value) :
        channel(channel), value(value):



class PitchBend:
    """change the pitch bend value"""

    int channel # channel (0 - 15 * dev#)
    int value   # value (-8192 - 8192)

    PitchBend(int channel, int value) :
        channel(channel), value(value):


class Aftertouch:
    """change an aftertouch value"""

    int channel # channel (0 - 15 * dev#)
    int value   # value (0 - 127)

    Aftertouch(int channel, int value) :
        channel(channel), value(value):


class PolyAftertouch:
    """change a poly aftertouch value"""

    int channel # channel (0 - 15 * dev#)
    int pitch   # pitch (0 - 127)
    int value   # value (0 - 127)

    PolyAftertouch(int channel, int pitch, int value) :
        channel(channel), pitch(pitch), value(value):


class MidiByte:
    """a raw midi byte"""

    int port # raw portmidi port
                    # see http://en.wikipedia.org/wiki/PortMidi
    unsigned char byte # the raw midi byte value

    MidiByte(int port, unsigned char byte) : port(port), byte(byte):


class StartMidi:
    """start a raw midi byte stream"""

    int port # raw portmidi port

    explicit StartMidi(int port=0) : port(port):


class StartSysex:
    """start a raw sysex byte stream"""

    int port # raw portmidi port

    explicit StartSysex(int port=0) : port(port):


class StartSysRealTime:
    """start a sys realtime byte stream"""

    int port # raw portmidi port

    explicit StartSysRealTime(int port=0) : port(port):


class Finish:
    """finish a midi byte stream"""
    explicit Finish():


