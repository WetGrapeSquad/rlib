module rlib.core.memory.signals;

version (linux)  : import core.sys.posix.signal;

nothrow @nogc @system
extern (C) void handleAbrt(int)
{
    assert(0, "Abnormal termination");
}

nothrow @nogc @system
extern (C) void handleSegv(int)
{
    assert(0, "Segmentation fault");
}

nothrow @nogc @system
extern (C) void handleTermination(int)
{
    assert(0, "Termination.");
} // TODO: REFACTOR.

nothrow @nogc @system
extern (C) void handleInt(int)
{
    assert(0, "Terminal interrupt character.");
}

nothrow @nogc @system
extern (C) void handleFpe(int)
{
    assert(0, "Floating-point error");
}

nothrow @nogc @system
extern (C) void handleIll(int)
{
    assert(0, "Illegal hardware instruction");
}

shared static this()
{
    signal(SIGABRT, &handleAbrt);
    signal(SIGFPE, &handleFpe);
    signal(SIGILL, &handleIll);
    signal(SIGINT, &handleInt);
    signal(SIGSEGV, &handleSegv);
    signal(SIGTERM, &handleTermination);
}