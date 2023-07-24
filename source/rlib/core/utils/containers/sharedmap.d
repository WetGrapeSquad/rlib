module rlib.core.utils.containers.sharedmap;
import std.traits;
import core.thread;
import core.atomic;

//TODO: Refactor and rewrite

shared class Map(K, V, uint cShards = 31) if (isIntegral!K)
{
    shared struct Shard
    {
        shared V[K] map;
        shared bool lock;
    }

    this()
    {
    }

    private void yield(size_t k)
    {
        import core.time;

        if (k < pauseThresh)
        {
            return core.atomic.pause();
        }
        else if (k < 32)
        {
            return Thread.yield();
        }
        Thread.sleep(1.msecs);
    }

    private bool tryLock(ref shared Shard shard)
    {
        if (cas(&shard.lock, false, true))
        {
            return true;
        }
        return false;
    }

    private void lock(ref shared Shard shard)
    {
        if (cas(&shard.lock, false, true))
        {
            return;
        }
        immutable step = 1 << 1;
        while (true)
        {
            for (size_t n; atomicLoad!(MemoryOrder.raw)(shard.lock); n += step)
            {
                this.yield(n);
            }
            if (cas(&shard.lock, false, true))
            {
                return;
            }
        }
    }

    private void unlock(ref shared Shard shard)
    {
        atomicStore!(MemoryOrder.rel)(shard.lock, false);
    }

    ref auto opIndex(K key)
    {
        auto shard = key % cShards;

        this.lock(this.mShards[shard]);
        scope (exit)
        {
            this.unlock(this.mShards[shard]);
        }

        return (cast(V[K]) this.mShards[shard].map)[key];
    }

    ref auto opIndexAssign(V value, K key)
    {
        auto shard = key % cShards;

        this.lock(this.mShards[shard]);
        scope (exit)
        {
            this.unlock(this.mShards[shard]);
        }

        return (cast(V[K]) this.mShards[shard].map)[key] = value;
    }

    int opApply(scope int delegate(ref const(K), ref V) dg)
    {
        int result = 0;

        uint index;
        size_t[31] buffer;
        size_t[] locked;

        foreach (i, ref shard; this.mShards)
        {
            if (!this.tryLock(shard))
            {
                buffer[index] = i;
                ++index;
                locked = buffer[0 .. index];
                continue;
            }
            scope (exit)
            {
                this.unlock(shard);
            }
            foreach (ref key, ref value; cast(V[K]) shard.map)
            {
                result = dg(key, value);
                if (result)
                {
                    return result;
                }
            }
        }

        foreach (size_t i; locked)
        {
            this.lock(this.mShards[i]);
            scope (exit)
            {
                this.unlock(this.mShards[i]);
            }
            foreach (ref key, ref value; cast(V[K]) this.mShards[i].map)
            {
                result = dg(key, value);
                if (result)
                {
                    return result;
                }
            }
        }

        return result;
    }

    shared Shard[31] mShards;

    version (D_InlineAsm_X86)
        enum X86 = true;
    else version (D_InlineAsm_X86_64)
        enum X86 = true;
    else
        enum X86 = false;

    static if (X86)
        enum pauseThresh = 16;
    else
        enum pauseThresh = 4;
}

@("SharedMap")
unittest
{
    import std.parallelism;
    import io = std.stdio;
    import std.array, std.range;

    auto map = new Map!(int, int);

    foreach (i; 1_000.iota.parallel)
    {
        map[i] = i;
    }
    foreach (_; 10.iota.parallel(1))
    {
        foreach (key, value; map)
        {
            assert(key == value);
        }
    }
}
