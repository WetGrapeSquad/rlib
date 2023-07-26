module rlib.core.memory.allocators.common;
import core.atomic;

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
    *   cAlign = required alignment.
    *   cPromAlign = promised alignment of the external memory allocator. Default 16 (malloc alignment).
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
/** 
 * Helper union for the BlockPool. 
 * Contains the 32 bit index and 32 bit operation counter in 64 bit atomic integer.
 */
union LFIndex
{
    static assert(size_t.sizeof == 8, "This union work only on 64 bit platforms.");

    /** 
     * Initialize by 64 bit integer (first 32 bit - index, second 32 bit - operation counter).
     * Params:
     *   other = 64 bit integer
     */
    this(ulong other)
    {
        this.index = other;
    }
    /** 
     * Initialize by first 32 bit index and second 32 bit operation counter.
     * Params:
     *   index = 32 bit index
     *   count = 32 bit operation counter
     */
    this(uint index, uint count)
    {
        this.i = index;
        this.c = count;
    }

    /** 
     * Assign 64 bit integer (first 32 bit - index, second 32 bit - operation counter).
     * Params:
     *   other = 64 bit integer
     */
    auto opAssign(ulong other)
    {
        this.index = other;
        return this;
    }

    /**
     * Atomic load 64 bit integer.
     */
    ulong load() shared
    {
        return atomicLoad(this.index);
    }
    /** 
     * Non-atomic load 64 bit integer (just return integer).
     * Returns: 
     */
    ulong load()
    {
        return this.index;
    }

    /** 
     * Atomic compare and swap 64 bit integer.
     * Params:
     *   old = old value of 64 bit integer
     *   newIndex = new value of 64 bit integer
     * Returns: true, if the value was changed
     */
    bool cas(ulong old, ulong newIndex) shared
    {
        return casWeak(&this.index, old, newIndex);
    }

    /** 
     * Non-atomic compare and swap 64 bit integer.
     * Params:
     *   old = old value of 64 bit integer
     *   newIndex = new value of 64 bit integer
     * Returns: true, if the value was changed
     */
    bool cas(ulong old, ulong newIndex)
    {
        this.index = newIndex;
        return true;
    }

    /** 
     * Changes the index.
     * Params:
     *   index = new index.
     */
    void updateIndex(uint index)
    {
        this.i = index;
    }

    /** 
     * Add 1 to the operation counter.
     */
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

/// A meaningless index (like null for pointers).
enum NoneIndex = LFIndex(-1, 0);
