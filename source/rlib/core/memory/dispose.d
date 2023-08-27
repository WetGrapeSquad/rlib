module rlib.core.memory.dispose;

alias DisposeEvent = void delegate(Object);
extern (C) void rt_attachDisposeEvent(Object obj, DisposeEvent evt);
extern (C) void rt_detachDisposeEvent(Object obj, DisposeEvent evt);