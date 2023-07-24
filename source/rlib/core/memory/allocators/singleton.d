module rlib.core.memory.allocators.singleton;

import std.experimental.allocator : IAllocator;
import std.traits;

/** 
 * Check if T is an instance of IAllocator, and have method of getting instance.
 * Params:
 *   T = allocator to check.
 */
template isSingletonAllocator(T)
{
    static if (!isAssignable!(IAllocator, T))
    {
        enum isSingletonAllocator = false;
    }
    else static if (!is(T == class))
    {
        enum isSingletonAllocator = false;
    }
    else static if (!is(typeof(T.instance())))
    {
        enum isSingletonAllocator = false;
    }
    else
    {
        enum isSingletonAllocator = true;
    }
}
