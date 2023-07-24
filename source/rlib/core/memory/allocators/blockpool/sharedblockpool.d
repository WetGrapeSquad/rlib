module rlib.core.memory.allocators.blockpool.sharedblockpool;
public import rlib.core.memory.allocators.common;
import core.lifetime : emplace;
import core.stdc.stdlib : free, malloc;
import io = std.stdio;
import std.format : format;
import std.functional : toDelegate;

/** 
 * Non-shared block pool allocator. 
 * Params: 
 *      cAlign = BlockPool block align. 
 */

@nogc
nothrow
//@trusted
shared class SharedBlockPool(uint cAlign)
{
    enum cAlign1 = cAlign - 1;
    static assert((cAlign & cAlign1) == 0, "The alignment of the block must be a power of two (2^n).");
    static assert(cAlign != 0, "The alignment cannot be equal 0");

    alias Free = void delegate(void[]) @nogc nothrow;
    static void noFree(void[]) @nogc nothrow
    {
    }
    
    /** 
     * Initialization constructor.
     * Params:
     *   blockSize = block size
     *   rawMemory = raw memory
     *   initValue = block init value. Default null (i.e. allocated memory not will be initialized)
     *   free = delegate to free memory. Default noFree (i.e. no memory will be freed)
     */
    this(in uint blockSize, void[] rawMemory, immutable(void)[] initValue = null, Free free = toDelegate(
            &noFree))
    {
        assert(rawMemory.length < uint.max, "The raw memory must be less than uint.max");
        assert(initValue is null || initValue.length == blockSize);
        assert(rawMemory !is null, "The rawMemory must be non null");
        assert(free !is null, "The free delegate must be non null");
        assert(blockSize > uint.sizeof, "The size must be larger than uint.sizeof");
        assert(blockSize % cAlign == 0, "The block size must be a multiple of the alignment");

        auto startPtr = cast(void*)((cast(size_t) rawMemory.ptr + cAlign1) & ~(cast(size_t) cAlign1));
        const length = cast(uint)(rawMemory.length - (startPtr - rawMemory.ptr));

        assert(length > blockSize, "Raw memory is not enough even for one block.");

        this.mSync = cast(shared Object) malloc(__traits(classInstanceSize, shared Object));
        this.mSync = emplace(this.mSync);

        this.mBlockSize = blockSize;
        this.mInitValue = initValue;

        this.mRawMemory = cast(shared void[]) rawMemory;

        this.mBlockCount = length / blockSize;
        this.mMemory = cast(shared void[]) startPtr[0 .. this.mBlockCount * blockSize];
        this.mFree = free;
    }

    /** 
     * Get data from the memory by index
     * Params:
     *   index = block index
     * Returns: block memory
     */
    private void[] getData(size_t index)
    {
        assert(index < this.mBlockCount);

        const rawIndex = index * this.mBlockSize;

        return cast(void[]) this.mMemory[rawIndex .. rawIndex + this.mBlockSize];
    }

    /** 
     * Next free block
     * Params:
     *   index = block index.
     * Returns: return next free block after block index
     */
    private ref uint getNextFree(uint index)
    {
        assert(index < this.mBlockCount, "The index must be less than the block count. %d >= %d".format(index, this
                .mBlockCount));

        const rawIndex = index * this.mBlockSize;

        return (cast(uint[]) this.mMemory[rawIndex .. rawIndex + uint.sizeof])[0];
    }

    /** 
     * Get of the block index.
     * Params:
     *   data = block memory
     * Returns: index of the block memory
     */
    private uint getIndex(void[] data)
    {
        assert(cast(size_t) data.ptr % cAlign == 0 && data.length == this.mBlockSize, "Invalid memory block");
        assert(data.ptr >= this.mMemory.ptr && data.ptr < this.mMemory.ptr + this.mMemory.length,
            "Alien memory block");

        const rawIndex = (cast(size_t) data.ptr - cast(size_t) this.mMemory.ptr);
        const index = cast(uint)(rawIndex / this.mBlockSize);
        return index;
    }

    /** 
     * Try to rent a free block.
     * Returns: rented block or null.
     */
    void[] tryRent()
    {
        if (this.mRawMemory is null)
        {
            return null;
        }
        synchronized (this.mSync)
        {
            if (this.mInited < this.mBlockCount)
            {
                ++(*cast(uint*)&this.mAllocated);

                ubyte[] data = cast(ubyte[]) this.getData((*cast(uint*)&this.mInited)++);
                if (this.mInitValue !is null)
                {
                    data[] = (cast(ubyte[]) this.mInitValue)[];
                }
                return data;
            }

            if (this.mFirstFree == -1)
            {
                return null;
            }

            ++(*cast(uint*)&this.mAllocated);
            const firstFree = this.mFirstFree;
            this.mFirstFree = this.getNextFree(firstFree);

            ubyte[] data = cast(ubyte[]) this.getData(firstFree);
            if (this.mInitValue !is null)
            {
                data[] = (cast(ubyte[]) this.mInitValue)[];
            }
            return data;
        }
    }

    /**
     * Recyle a block.
     * Params:
     *   data = block memory for recyle
     */
    void recycle(void[] data)
    {
        synchronized (this.mSync)
        {
            if (this.mRawMemory is null)
            {
                return;
            }

            if (data is null)
            {
                return;
            }

            --(*cast(uint*)&this.mAllocated);
            assert(this.mRawMemory !is null, "BlockPool must be initialized");

            const index = this.getIndex(data);
            this.getNextFree(index) = this.mFirstFree;
            this.mFirstFree = index;
        }
    }

    /**
     * Get the number of allocated blocks.
     */
    uint allocated()
    {
        return this.mAllocated;
    }

    /**
     * Get the number of free blocks.
     */
    uint avaliable()
    {
        return this.mBlockCount - this.mAllocated;
    }

    /**
     * Get the size of the block.
     */
    uint blockSize()
    {
        return this.mBlockSize;
    }

    /**
     * Get the number of blocks.
     */
    uint blockCount()
    {
        return this.mBlockCount;
    }

    /** 
     * Clear the memory. Thread safe?
     */
    void clear()
    {
        if (this.mRawMemory !is null)
        {
            this.mFree(cast(void[]) this.mRawMemory);
            this.mRawMemory = null;

            destroy!(false)(this.mSync);
            free(cast(void*) this.mSync);

            this.mInited = 0;
            this.mAllocated = 0;
            this.mBlockSize = 0;
            this.mBlockCount = 0;

            this.mFirstFree = -1;
            this.mMemory = null;
        }
    }

    ~this()
    {
        if (this.mRawMemory !is null)
        {
            this.mFree(cast(void[]) this.mRawMemory);
            this.mRawMemory = null;

            destroy!(false)(this.mSync);
            free(cast(void*) this.mSync);
        }
    }

    private Object mSync;
    private uint mInited = 0;
    private uint mAllocated = 0;
    private uint mFirstFree = -1;

    private uint mBlockCount = 0;
    private uint mBlockSize = 0;

    private Free mFree;

    private immutable(void)[] mInitValue;
    private void[] mRawMemory;
    private void[] mMemory;
}
///
@("SharedBlockPool") unittest
{
    void freeDel(void[] ptr)
    {
        free(ptr.ptr);
    }

    const blockSize = alignedBlockSize!16(15);
    const arenaSize = arenaSize!(16)(blockSize, 128);
    auto pool = new SharedBlockPool!16(16, malloc(arenaSize)[0 .. arenaSize], null, &freeDel);

    ubyte[][] ptr = new ubyte[][pool.blockCount()];

    foreach (_; 0 .. 100)
    {
        foreach (i, ref el; ptr)
        {
            el = cast(ubyte[]) pool.tryRent();
            assert(el !is null, "Block allocation failed: %d".format(i));
            el[] = cast(ubyte) i;
        }

        pool.recycle(null);

        assert(pool.tryRent() is null, "Unfair block allocator");

        foreach (i, ref el; ptr)
        {
            ubyte[16] cmp;
            cmp[] = cast(ubyte) i;
            assert(el[] == cmp[]);

            pool.recycle(el);
            el = null;
        }
    }
}
///
@("SharedBlockPool.parallel") unittest
{
    import std.parallelism;
    import std.concurrency;

    void freeDel(void[] ptr)
    {
        free(ptr.ptr);
    }

    const blockSize = alignedBlockSize!16(15);
    const arenaSize = arenaSize!(16)(blockSize, 128 * 100);
    auto pool = new SharedBlockPool!16(16, malloc(arenaSize)[0 .. arenaSize], null, &freeDel);

    ubyte[][][10] threadPtr;

    foreach (ref ptr; threadPtr)
    {
        ptr = new ubyte[][pool.blockCount() / 10];
    }

    foreach (_; 0 .. 100)
    {
        foreach (ref ptr; threadPtr[].parallel(2))
        {
            foreach (i, ref el; ptr)
            {
                el = cast(ubyte[]) pool.tryRent();
                assert(el !is null, "Block allocation failed: %d".format(i));
                el[] = cast(ubyte) i;
            }

            pool.recycle(null);

            foreach (i, ref el; ptr)
            {
                ubyte[16] cmp;
                cmp[] = cast(ubyte) i;
                assert(el[] == cmp[]);

                pool.recycle(el);
                el = null;
            }
        }
    }
    assert(pool.avaliable == pool.blockCount);
    assert(pool.allocated == 0);
}