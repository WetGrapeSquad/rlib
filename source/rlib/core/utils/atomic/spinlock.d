module rlib.core.utils.atomic.spinlock;

import core.thread;
import core.atomic;

shared struct Spinlock
{
    enum Contention
    {
        Brief,
        Medium,
        Lengthy
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

    bool tryLock()
    {
        if (cas(&mLock, false, true))
        {
            return true;
        }
        return false;
    }

    void lock()
    {
        if (cas(&mLock, false, true))
        {
            return;
        }
        while (true)
        {
            for (size_t n; atomicLoad!(MemoryOrder.raw)(mLock); n += 2)
            {
                this.yield(n);
            }
            if (cas(&mLock, false, true))
            {
                return;
            }
        }
    }

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
