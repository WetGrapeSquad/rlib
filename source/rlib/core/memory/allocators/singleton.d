module rlib.core.memory.allocators.singleton;

import std.experimental.allocator : IAllocator;
import std.traits;


template isSingletonAllocator(T)
{
    static if(!isAssignable!(IAllocator, T))
    {
        enum isSingletonAllocator = false;
    }
    else static if(!is(T == class))
    {
        enum isSingletonAllocator = false;
    }
    else static if(!is(typeof(T.instance)))
    {
        enum isSingletonAllocator = false;
    }
    else 
    {
        enum isSingletonAllocator = true;
    }
}