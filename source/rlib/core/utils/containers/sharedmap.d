module rlib.core.utils.containers.sharedmap;
import std.traits;
import core.thread;
import core.atomic;
import rlib.core.utils.atomic.spinlock;

//TODO: Refactor and rewrite

shared class Map(K, V, uint cShards = 31) if (isIntegral!K)
{
    shared struct Shard
    {
        shared V[K] map;
        shared AlignedSpinlock mSpinlock;
    }
    
    this()
    {
    }

    /** 
    * Get `value` by `key` 
    * Throws: RangeError if the `key` entry does not exist
    */
    ref auto opIndex(K key) 
    {
        auto shard = key % cShards;

        this.mShards[shard].mSpinlock.lock();
        scope (exit)
        {
            this.mShards[shard].mSpinlock.unlock();
        }

        return (cast(V[K]) this.mShards[shard].map)[key];
    }

    /** 
    * Set `value` to element by `key` 
    * Returns: `value`
    */
    ref auto opIndexAssign(V value, K key)
    {
        auto shard = key % cShards;

        this.mShards[shard].mSpinlock.lock();
        scope (exit)
        {
            this.mShards[shard].mSpinlock.unlock();
        }

        return (cast(V[K]) this.mShards[shard].map)[key] = value;
    }

    /** 
     * Remove an item by `key`.
     */
    void remove(K key)
    {
        auto shard = key % cShards;

        this.mShards[shard].mSpinlock.lock();
        scope (exit)
        {
            this.mShards[shard].mSpinlock.unlock();
        }

        (cast(V[K]) this.mShards[shard].map).remove(key);
    }

    /** 
     * Get some element by `key` and return this.
     * The shard remains in the locked state after the end of 
     * the call until the moment of call `unlock`
     */
    ref auto lockAndGet(K key)
    {
        auto shard = key % cShards;

        this.mShards[shard].mSpinlock.lock();
        return (cast(V[K]) this.mShards[shard].map)[key];
    }

    /** 
     * Add/set some element by `key` to `value` and return this.
     * The shard remains in the locked state after the end of 
     * the call until the moment of call `unlock`
     */
    ref auto lockAndSet(K key, V value)
    {
        auto shard = key % cShards;

        this.mShards[shard].mSpinlock.lock();
        return (cast(V[K]) this.mShards[shard].map)[key] = value;
    }

    /** 
     * Remove an item by `key` without attempting to lock it.
     * Use it only if the lock has already been executed
     */
    void lockedRemove(K key)
    {
        auto shard = key % cShards;
        (cast(V[K]) this.mShards[shard].map).remove(key);
    }

    /** 
     * Unlock associative shard by key. 
     * the key is used to calculate the estimated location, i.e. 
     * the existence of an element of the associative key is 
     * not necessarily necessary
     * 
     * It is not recommended to unlock by key if the lock was not 
     * performed by this very key in this thread/context before
     * Params:
     *   key = some key for element.
     */
    void unlock(K key)
    {
        auto shard = key % cShards;
        this.mShards[shard].mSpinlock.unlock();
    }

    /** 
     * Completely clears all shards to init state.
     */
    void clear()
    {
        foreach(ref shard; this.mShards)
        {
            shard.mSpinlock.lock();
            shard.map = null;
            shard.mSpinlock.unlock();
        }
    }

    shared Shard[31] mShards;
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
    
    // TODO:
    /*foreach (_; 10.iota.parallel(1))
    {
        foreach (key, value; map)
        {
            assert(key == value);
        }
    }*/
}