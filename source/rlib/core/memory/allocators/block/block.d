module rlib.core.memory.allocators.block.block;
import rlib.core.memory.allocators.blockpool.blockpool;
import std.experimental.allocator.mmap_allocator;
import std.traits;
import core.lifetime;
import core.memory : pageSize;

class Block(uint cAlign)
{
    enum cAlign1 = cAlign - 1;

    static assert((cAlign & cAlign1) == 0,
        "The alignment of the block must be a power of two (2^n).");
    static assert(cAlign != 0,
        "The alignment cannot be equal 0");
    static assert(cAlign <= 4096,
        "The alignment must be less/equal 4096");
    static assert(!is(T == interface),
        "Interface cannot be allocated.");

    this(in uint blockSize, immutable(void)[] initValue)
    {
        this.mBlockSize = blockSize;
        this.mInitValue = initValue;
    }

    private BlockPool!cAlign allocateNewPool()
    {
        void[] arena = allocator.allocate(pageSize);

        assert(arena !is null);

        auto pFree = cast(BlockPool!cAlign.Free)&allocator.deallocate;
        auto pool = new BlockPool!cAlign(mBlockSize, arena, this.mInitValue, pFree);
        this.mBlocks[cast(uint)(cast(ulong)arena.ptr / pageSize)] = pool;

        return pool;
    }

    void[] rent()
    {
        foreach(pool; this.mBlocks.byValue)
        {
            void[] data = pool.tryRent();
            if(data !is null)
            {
                return data;
            }
        }
        auto pool = this.allocateNewPool();
        return pool.tryRent();
    }

    void recycle(void[] data)
    {
        if(data is null)
        {
            return;
        }
        auto pool = (cast(uint)(cast(ulong)data.ptr / pageSize)) in this.mBlocks;
        assert(pool !is null, "Alien memory");
        pool.recycle(data);
    }

    const uint mBlockSize;
    immutable(void)[] mInitValue;
    alias allocator = MmapAllocator.instance;
    BlockPool!cAlign[uint] mBlocks;
}
///
@("Block") unittest
{
    import rlib.core.memory.allocators.block.block: Block;
    import core.stdc.stdlib;
    import std.format;

    ubyte[][] ptr = new ubyte[][1_000]; 

    Block!16 pool = new Block!16(16, null);

    foreach (_; 0 .. 100)
    {
        foreach (i, ref el; ptr)
        {
            el = cast(ubyte[]) pool.rent();
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