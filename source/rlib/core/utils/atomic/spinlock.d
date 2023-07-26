module rlib.core.utils.atomic.spinlock;

import core.thread;
import core.atomic;

/** 
 * A synchronization primitive that ensures mutual exclusion of execution of critical code sections
 */
shared struct Spinlock
{
    enum Contention
    {
        Brief,
        Medium,
        Lengthy
    }

    this(Contention contention)
    {
        this.mContention = contention;
    }

    private void yield(size_t k)
    {
        import core.time;

        if (k < pauseThread)
        {
            return core.atomic.pause();
        }
        else if (k < 32)
        {
            return Thread.yield();
        }
        Thread.sleep(1.msecs);
    }

    /** 
    * Try to puts spinlock in an blocked state
    * Returns: true, if operation was success
    */
    bool tryLock()
    {
        if (cas(&mLock, false, true))
        {
            return true;
        }
        return false;
    }

    /** 
    * Puts spinlock in an blocked state
    */
    void lock()
    {
        if (cas(&mLock, false, true))
        {
            return;
        }

        immutable pause = 1 << this.mContention;

        while (true)
        {
            for (size_t n; atomicLoad!(MemoryOrder.raw)(mLock); n += pause)
            {
                this.yield(n);
            }
            if (cas(&mLock, false, true))
            {
                return;
            }
        }
    }

    /** 
    * Puts spinlock in an unblocked state
    */
    void unlock()
    {
        atomicStore!(MemoryOrder.rel)(mLock, false);
    }

    version (X86)
    {
        enum X86 = true;
    }
    else version (X86_64)
    {
        enum X86 = true;
    }
    else
    {
        enum X86 = false;
    }
    static if (X86)
    {
        immutable pauseThread = 16;
    }
    else
    {
        immutable pauseThread = 16;
    }

    private Contention mContention;
    private shared bool mLock;
}

/** 
 * Spinlock aligned by cash-line (64)
 */
align(64)
struct AlignedSpinlock
{
    Spinlock __lock__;
    alias __lock__ this;
}

///
@("Spinlock")
unittest
{
    int a = 0;
    Spinlock sl;

    foreach (_; 0 .. 1_000)
    {
        sl.lock();
        a++;
        sl.unlock();
    }

    assert(a == 1_000);
}
