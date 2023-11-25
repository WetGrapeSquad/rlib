/** 
 * This module implements a wrapper over std.experimental.allocator to simplify memory allocation for arrays, objects, etc.
 * 
 * Does't work in CTFE, for this recommended to use built-in new.
 *
 * To allocate and free memory, a memory allocator is used, passed through a template argument. 
 * the allocator must fit the type requirements. The absence of aligned memory allocation is allowed 
 * if the size of the required type alignment is less than or equal to 16 (standard malloc alignment). 
 * Otherwise, the allocator must provide the `alignedAllocate` and `alignedReallocate` methods to 
 * allocate aligned memory. By default, a suitable allocator is selected to allocate memory specifically 
 * (Mallocator or AlignedMallocator).
 *
 * ---------------
 * import rlib.core.memory.memory: New, Delete;
 * 
 * class Test1
 * {
 * }
 * struct Test2
 * {
 * }
 * 
 * Test test1 = New!Test1; // Allocate an object of the `Test` class.
 * Delete(test1); // Destroy an object of the `Test` class and free memory.
 * 
 * int[] test2 = New!(int[])(123) // It also works with arrays.
 * assert(test2.length == 123)
 * Delete(test2);
 *
 * double* test3 = New!double; 
 * Delete(test3);
 *
 * Test2* test4 = New!Test2; 
 * Delete(test4);
 * 
 * ---------------
 */
module rlib.core.memory.memory;
import core.lifetime: emplace;
import std.algorithm.mutation;
import std.algorithm.comparison;
import std.traits;
import std.experimental.allocator.building_blocks;
import std.math;
import rlib.core.memory.allocators.common;
import core.exception;


template CheckAllocator(T)
{
    //check instance
    static if (!is(typeof(T.instance)))
    {
        enum CheckAllocator = false;
    }

    //check allocate method
    else static if (!is(typeof(T.instance.allocate(123)) == U[], U))
    {
        enum CheckAllocator = false;
    }

    // check reallocate method
    else static if (!is(ReturnType!((void[] r) => T.instance.reallocate(r, 123)) == bool))
    {
        enum CheckAllocator = false;
    }

    //check deallocate method
    else static if (!is(ReturnType!((void[] r) => T.instance.deallocate(r)) == bool))
    {
        enum CheckAllocator = false;
    }
    else
    {
        enum CheckAllocator = true;
    }
}

template CheckAlignedAllocator(T)
{
    // check all basic methods
    static if (!CheckAllocator!T)
    {
        enum CheckAlignedAllocator = false;
    }

    // check aligned allocate
    else static if (!is(typeof(T.instance.alignedAllocate(123, 16)) == U[], U))
    {
        enum CheckAlignedAllocator = false;
    }

    // check aligned reallocate
    else static if (!is(ReturnType!((void[] r) => T.instance.alignedReallocate(r, 123, 16)) == bool))
    {
        enum CheckAlignedAllocator = false;
    }
    else
    {
        enum CheckAlignedAllocator = true;
    }
}

template CheckAllocatorForType(T, allocator)
{
    static if (T.alignof <= max(double.sizeof, real.sizeof))
    {
        enum CheckAllocatorForType = CheckAllocator!allocator;
    }
    else
    {
        enum CheckAllocatorForType = CheckAlignedAllocator!allocator;
    }
}

template PickDefaultAllocator(T)
{
    static if (T.alignof <= max(double.sizeof, real.sizeof))
    {
        alias PickDefaultAllocator = Mallocator;
    }
    else
    {
        alias PickDefaultAllocator = AlignedMallocator;
    }
}

// dfmt off
Unqual!Type New(Type, alloctr = PickDefaultAllocator!Type)() 
    if (CheckAllocatorForType!(Unqual!Type, alloctr) && isPointer!Type)
{
    alias instance = alloctr.instance;
    alias T = PointerTarget!(Unqual!Type);

    enum uint objectSize = T.sizeof;
    enum uint objectAlign = cast(uint) T.alignof;

    static if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        T[] obj = cast(T[]) instance.allocate(objectSize);
    }
    else
    {
        T[] obj = cast(T[]) instance.alignedAllocate(objectSize, objectAlign);
    }
    
    if(obj is null)
    {
        onOutOfMemoryError();
    }

    initializeAll(obj);
    return obj.ptr;
}

Unqual!Type New(Type, alloctr = PickDefaultAllocator!Type, Args...)(Args args)
        if (CheckAllocatorForType!(Unqual!Type, alloctr) && is(Type == class))
{
    alias instance = alloctr.instance;
    alias T = Unqual!Type;

    enum uint objectSize = __traits(classInstanceSize, T);
    enum uint objectAlign = cast(uint) classInstanceAlignment!T;

    static if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        T obj = cast(T)(instance.allocate(objectSize)).ptr;
    }
    else
    {
        T obj = cast(T)(instance.alignedAllocate(objectSize, objectAlign)).ptr;
    }
    
    if(obj is null)
    {
        onOutOfMemoryError();
    }

    emplace(obj, args);
    return obj;
}

Unqual!Type New(Type, alloctr = PickDefaultAllocator!Type)(size_t length)
        if (CheckAllocatorForType!(Unqual!Type, alloctr) && isDynamicArray!Type && !is(Unqual!Type == void[]))
{
    alias instance = alloctr.instance;
    static if(is(Unqual!Type == void[]))
    {
        alias T = void;
    }
    else 
    {
        alias T = ForeachType!(Unqual!Type);
    }

    enum uint objectSize = T.sizeof;
    enum uint objectAlign = cast(uint) T.alignof;

    assert(length != 0);

    static if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        T[] obj = cast(T[]) instance.allocate(objectSize * length);
    }
    else
    {
        T[] obj = cast(T[]) instance.alignedAllocate(objectSize * length, objectAlign);
    }
    
    if(obj is null)
    {
        onOutOfMemoryError();
    }

    static if(!is(T == void))
    {
        initializeAll(obj);
    }

    return obj;
}

Unqual!Type New(Type, alloctr = PickDefaultAllocator!Type)(size_t length, uint alignOf = 1)
        if (CheckAllocator!alloctr && is(Unqual!Type == void[]))
{
    alias instance = alloctr.instance;
    alias T = void;

    enum uint objectSize = T.sizeof;
    uint objectAlign = alignOf;

    assert(length != 0);

    T[] obj;
    if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        obj = cast(T[]) instance.allocate(objectSize * length);
    }
    else
    {
        static if(CheckAlignedAllocator!alloctr)
        {
            obj = cast(T[]) instance.alignedAllocate(objectSize * length, objectAlign);
        }
        else 
        {
            assert(0);
        }
    }
    
    if(obj is null)
    {
        onOutOfMemoryError();
    }

    return obj;
}

Unqual!Type* New(Type, alloctr = PickDefaultAllocator!Type)()
        if (CheckAllocatorForType!(Unqual!Type, alloctr) && (isBasicType!Type || is(Type == struct)))
{
    alias instance = alloctr.instance;
    alias T = Unqual!Type;

    enum uint objectSize = T.sizeof;
    enum uint objectAlign = cast(uint) T.alignof;

    static if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        T[] obj = cast(T[]) instance.allocate(objectSize);
    }
    else
    {
        T[] obj = cast(T[]) instance.alignedAllocate(objectSize, objectAlign);
    }
    
    if(obj is null)
    {
        onOutOfMemoryError();
    }

    initializeAll(obj);
    return obj.ptr;
}

bool Realloc(Type, alloctr = PickDefaultAllocator!Type)(ref Unqual!Type array, size_t newLength, uint alignOf = 1)
        if (CheckAllocator!alloctr && is(Unqual!Type == void[]))
{
    if(array is null)
    {
        array = New!(Type, alloctr)(newLength, alignOf);
        return true;
    }

    alias instance = alloctr.instance;
    alias T = void;

    enum uint objectSize = T.sizeof;
    uint objectAlign = alignOf;

    if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        void[] obj = cast(void[])array;
        if(!instance.reallocate(obj, objectSize * newLength))
        {
            return false;
        }
        array = cast(T[])obj;
    }
    else
    {
        static if(CheckAlignedAllocator!alloctr)
        {
            void[] obj = cast(void[])array;
            if(!instance.alignedReallocate(obj, objectSize * newLength, objectAlign))
            {
                return false;
            }
            array = cast(T[])obj;
        }
        else 
        {
            assert(0);
        }
    }

    return true;
}

bool Realloc(Type, alloctr = PickDefaultAllocator!Type)(ref Unqual!Type array, size_t newLength)
        if (CheckAllocatorForType!(Unqual!Type, alloctr) && isDynamicArray!Type  &&!is(Unqual!Type == void[]))
{
    if(array is null)
    {
        array = New!(Type, alloctr)(newLength);
        return true;
    }

    alias instance = alloctr.instance;
    static if(is(Unqual!Type == void[]))
    {
        alias T = void;
    }
    else 
    {
        alias T = ForeachType!(Unqual!Type);
    }

    enum uint objectSize = T.sizeof;
    enum uint objectAlign = cast(uint) T.alignof;
    const oldLength = array.length;

    static if (objectAlign <= max(double.sizeof, real.sizeof))
    {
        void[] obj = cast(void[])array;
        if(!instance.reallocate(obj, objectSize * newLength))
        {
            return false;
        }
        array = cast(T[])obj;
    }
    else
    {
        void[] obj = cast(void[])array;
        if(!instance.alignedReallocate(obj, objectSize * newLength, objectAlign))
        {
            return false;
        }
        array = cast(T[])obj;
    }
    static if(!is(T == void))
    {
        initializeAll(array[oldLength..$]);
    }
    
    return true;
}

//dfmt on

bool Delete(Type)(Type obj)
if(is(Unqual!Type == Type))
{
    return Delete!(Type, PickDefaultAllocator!Type)(obj);
}

bool Delete(Type, alloctr)(Type obj)
        if (CheckAllocatorForType!(Unqual!Type, alloctr) && isPointer!Type)
{   
    alias instance = alloctr.instance;
    alias T = Unqual!(PointerTarget!Type);

    T[] data = obj[0..1];

    static if(is(T == struct) && hasElaborateDestructor!T)
    {
        destroy!false(obj);
    }

    return instance.deallocate(cast(void[])data);
}

bool Delete(Type, alloctr)(Type obj)
        if (CheckAllocatorForType!(Unqual!Type, alloctr) && is(Type == class))
{
    alias instance = alloctr.instance;

    // .m_init.length gives size in bytes of class
    // https://dlang.org/library/object/type_info__class.m_init.html
    uint objectSize = cast(uint) obj.classinfo.m_init.length;
    void[] data = (cast(void*)obj)[0..objectSize];

    destroy!false(obj);

    return instance.deallocate(data);
}

bool Delete(Type, alloctr)(Type obj)
        if (CheckAllocatorForType!(Type, alloctr) && isDynamicArray!Type)
{
    alias instance = alloctr.instance;
    static if(is(Unqual!Type == void[]))
    {
        alias T = void;
    }
    else 
    {
        alias T = ForeachType!(Unqual!Type);
    }
    
    static if(is(T == struct) && hasElaborateDestructor!T)
    {
        foreach(ref el; obj)
        {
            destroy!false(el);
        }
    }
    
    return instance.deallocate(cast(void[])obj);
}

@("New/Delete")
unittest
{
    {
        class Test
        {
            this(string* data)
            {
                this.mData = data;
                *this.mData = "constructed";
            }

            ~this()
            {
                *this.mData = "destructed";
            }

            string* mData;
        }

        string* str = New!(string*);
        Test test = New!Test(str);

        assert(*str == "constructed");

        assert(Delete!Test(test));
        assert(*str == "destructed");
    }

    {
        int* test = New!int;

        assert(test !is null);
        assert(*test == int.init);

        assert(Delete!(int*)(test));
    }

    {
        void[] buffer = New!(void[])(15);

        assert(buffer !is null);

        assert(Delete!(void[])(buffer));
    }
}

/** 
 * Just move all data from source to target. Without calling destructor or constructors.
 * Without filling source by T.init.
 * Params:
 *   source = slice of initialized data 
 *   target = slice of unitialized data target.
 */
void safeMoveRaw(T)(T[] source, T[] target)
{
    if(source.length != target.length)
    {
        assert(0);
    }
    if(source.length == 0)
    {
        return;
    }

    ubyte[] source_ubyte = cast(ubyte[])source;
    ubyte[] target_ubyte = cast(ubyte[])target;
    
    if(source.ptr < target.ptr && source.ptr + source.length > target.ptr)
    {
        foreach_reverse(i, ref el; source_ubyte)
        {
            target_ubyte[i] = el;
        }
        return;
    }
    
    foreach(i, ref el; source_ubyte)
    {
        target_ubyte[i] = el;
    }
}

@("safeMoveRaw")
unittest
{
    char[] str = "Hello, World!\n".dup;

    safeMoveRaw(str[0..3], str[2..5]);
    assert(str == "HeHel, World!\n");

    safeMoveRaw(str[2..5], str[0..3]);
    assert(str == "Helel, World!\n");
}

//dfmt off
bool checkOverlap(T, R)(T[] first, R[] second)
{
    void[] _first = cast(void[]) first;
    void[] _second = cast(void[]) second;

    if (
            (_second.ptr >= _first.ptr && _second.ptr < _first.ptr + first.length) ||
            (_first.ptr >= _second.ptr && _first.ptr < _second.ptr + _second.length)
        )
    {
        return true;
    }
    return false;
}
//dfmt on

@("checkOverlap")
unittest
{
    ubyte[23] test1 = ubyte.min;
    ubyte[23] test2 = ubyte.max;
    assert(checkOverlap(test1[1 .. 15], test1[14 .. 23]));
    assert(checkOverlap(test1[14 .. 23], test1[1 .. 15]));
    assert(checkOverlap(test1[], test1[]));
    assert(!checkOverlap(test1[], test2[]));
    assert(!checkOverlap(test2[1 .. 15], test2[15 .. 23]));
    assert(!checkOverlap(test2[15 .. 23], test2[1 .. 15]));
}
