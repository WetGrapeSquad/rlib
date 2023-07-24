module rlib.core.memory.allocators.common;
import core.atomic;

shared static this()
{
    import etc.linux.memoryerror;

    static if (is(typeof(registerMemoryErrorHandler)))
    {
        registerMemoryErrorHandler();
    }
}

/** 
    * A specific function that can be used for structures from scripts.
    * Params:
    *   blockSize = unaligned block size
    * Returns: 
    */
uint alignedBlockSize(uint cAlign)(uint blockSize)
{
    enum cAlign1 = cAlign - 1;
    if (blockSize < uint.sizeof)
    {
        return (uint.sizeof + (cAlign1)) & ~(cAlign1);
    }
    return (blockSize + (cAlign1)) & ~(cAlign1);
}

/** 
    * Returns the size of the memory arena that needs to be 
    * allocated to be able to allocate `requiredCount' blocks.
    * Params:
    *   promAlign = promised alignment of the external memory allocator. Default 16 (malloc alignment).
    *   blockSize = size of allocation block.
    *   requiredCount = The number of memory blocks that the BlockPool should be able to allocate after receiving memory
    * Returns: 
    */
uint arenaSize(uint cAlign, uint cPromAlign = 16)(uint blockSize, uint requiredCount)
{
    enum cAlign1 = cAlign - 1;
    enum promAlign1 = cPromAlign - 1;
    static assert((cPromAlign & promAlign1) == 0, "The Promised alignment must be a power of two (2^n).");
    assert(blockSize % cAlign == 0, "The block size must be a multiple of the alignment.");
    assert(blockSize > uint.sizeof, "The size must be larger than uint.sizeof");

    const requiredMemory = blockSize * requiredCount;

    static if ((cPromAlign & cAlign1) == 0)
    {
        const arena = requiredMemory;
    }
    else
    {
        const arena = requiredMemory + (cAlign - cPromAlign);
    }
    return arena;
}

union LFIndex
{
    this(ulong other)
    {
        this.index = other;
    }

    this(uint index, uint count)
    {
        this.i = index;
        this.c = count;
    }

    auto opAssign(ulong other)
    {
        this.index = other;
        return this;
    }

    ulong load() shared
    {
        return atomicLoad(this.index);
    }

    ulong load()
    {
        return this.index;
    }

    bool cas(ulong old, ulong newIndex) shared
    {
        return casWeak(&this.index, old, newIndex);
    }

    bool cas(ulong old, ulong newIndex)
    {
        this.index = newIndex;
        return true;
    }

    void updateIndex(uint index)
    {
        this.i = index;
    }

    void addCount()
    {
        this.c++;
    }

    ulong index = 0;
    struct
    {
        uint i;
        uint c;
    }
}

enum NoneIndex = LFIndex(-1, 0);