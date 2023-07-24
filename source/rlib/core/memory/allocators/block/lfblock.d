module rlib.core.memory.allocators.block.lfblock;
import rlib.core.memory.allocators.blockpool.lfblockpool;
import rlib.core.utils.containers.sharedmap;
import std.experimental.allocator.mmap_allocator;
import std.traits;
import core.lifetime;
import core.internal.spinlock;
import core.memory : pageSize;
import core.sys.linux.termios;
import rlib.core.memory.allocators.blockpool.blockpool;

shared class LfBlock(uint cAlign)
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

    }


    const uint mBlockSize;
    immutable(void)[] mInitValue;
    alias allocator = MmapAllocator.instance;
    
    Map!(uint, BlockPool!cAlign) mBlocks;
}