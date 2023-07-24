module rlib.core.memory.allocators.malloc;
import std.experimental.allocator;
import std.typecons : Ternary;
import core.stdc.stdlib : malloc, free, realloc;

import rlib.core.memory.allocators.singleton;

class MallocAllocator : IAllocator
{
nothrow:

    /** 
     * Private default constructor.
     */

    private this()
    {
    }

    /** 
     * Gets the singleton allocator instance.
     * Returns: instance.
     */
    static public MallocAllocator instance()
    {
        if (!this.mInstanced)
        {
            try
            {
                synchronized (this.classinfo)
                {
                    if (this.mInstance is null)
                    {
                        this.mInstance = new MallocAllocator;
                    }
                }
                this.mInstanced = true;
            }
            catch (Exception exc)
            {
                return null;
            }
        }
        return this.mInstance;
    }

    /**
    * Returns the alignment offered (always 16).
    */
    @property uint alignment()
    {
        return 16u;
    }

    /**
    * Returns the good allocation size that guarantees zero internal
    * fragmentation (mutliple of 16).
    */
    size_t goodAllocSize(size_t s)
    {
        return (s + 15) & (~15);
    }

    /**
    * Allocates `n` bytes of memory.
    * If uses TypeInfo ti, the alignment must be less/equal 16.
    */
    void[] allocate(size_t n, TypeInfo ti = null)
    {
        if (ti is null || ti.talign() <= 16u)
        {
            return malloc(n)[0 .. n];
        }
        return null;
    }

    /**
    * Allocates `n` bytes of memory with specified alignment `a`. Implementations
    * Alignment must be less/equal 16.
    */
    void[] alignedAllocate(size_t n, uint a)
    {
        if (a > 16u)
        {
            return null;
        }
        return malloc(n)[0 .. n];
    }

    /**
    * Return `null` (BlackHole).
    */
    void[] allocateAll()
    {
        return null;
    }

    /**
    * Return `false`(BlackHole). Use `realocate` instead.
    */
    bool expand(ref void[] block, size_t newSize)
    {
        return false;
    }

    /**
    * Reallocates a memory block.
    */
    bool reallocate(ref void[] block, size_t newSize)
    {
        auto tmp = realloc(block.ptr, newSize)[0 .. newSize];
        if (tmp !is null)
        {
            block = tmp;
            return true;
        }
        return false;
    }

    /**
    * Reallocates a memory block with specified alignment. Alignment must be less/equal than 16.
    */
    bool alignedReallocate(ref void[] b, size_t size, uint alignment)
    {
        if (alignment <= 16u)
        {
            auto tmp = realloc(b.ptr, size)[0 .. size];
            if (tmp !is null)
            {
                b = tmp;
                return true;
            }
        }
        return false;
    }

    /**
    * Return `Ternary.unknown` (BlackHole).
    */
    Ternary owns(void[] b)
    {
        return Ternary.unknown;
    }

    /**
    * Return `Ternary.unknown` (BlackHole).
    */
    Ternary resolveInternalPointer(const void* p, ref void[] result)
    {
        return Ternary.unknown;
    }

    /**
    * Deallocates a memory block. Always return `true`.
    */
    bool deallocate(void[] b)
    {
        if (b !is null)
        {
            free(b.ptr);
        }
        return true;
    }

    /**
    * Return `false` (BlackHole).
    */
    bool deallocateAll()
    {
        return false;
    }

    /**
    * Return `Ternary.unknown` (BlackHole).
    */
    Ternary empty()
    {
        return Ternary.unknown;
    }

    /**
    * Do nothing (BlackHole).
    */
    @safe @nogc pure
    void incRef()
    {
    }

    /**
    * Return true (BlackHole).
    */
    @safe @nogc pure
    bool decRef()
    {
        return true;
    }

    __gshared MallocAllocator mInstance;
    static bool mInstanced;
}

static assert(isSingletonAllocator!(MallocAllocator));
