module rlib.core.utils.containers;
import core.atomic;
import core.lifetime;
import core.thread;
import rlib.core.memory;
import rlib.core.memory.memory;
import rlib.core.utils.atomic;
import rlib.core.utils.bitop;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.conv;
import std.digest.md;
import std.digest.sha;
import std.experimental.allocator.building_blocks;
import std.math;
import std.range.primitives;
import std.traits;
import core.exception;

// TODO: Make Refactor
template isAssignable(F, T)
{
    enum isAssignable = is(typeof((T el1 = T.init, F el2 = F.init) { el1 = el2; }()));
}
// TODO: Make Refactor
template isConstructableWith(T, Args...)
{
    static if (Args.length == 1)
    {
        enum isConstructableWith = is(typeof(T(Args.init))) || is(Unqual!T == Unqual!(Args[0]));
    }
    else
    {
        enum isConstructableWith = is(typeof(T(Args.init)));
    }
}

// FIXME: Add ref for struct's for improve prefomance.
// FIXME: Add assertions and document it.
// FIXME: Refactor opIndex and opIndexAssign
/** 
 * Implementation of a dynamic array.
 * 
 * This structure automatically reserves memory by default factor of 1.5 and reduces the size when it is reduced by 1.5 times.
 * About factor: <a href="https://github.com/facebook/folly/blob/main/folly/docs/FBVector.md#memory-handling">FBVector Memory Handling</a>
 * 
 * Does't work in CTFE, for this recommended to use standart array's like `T[]`.
 * 
 * Array use reallocate from allocator(<i>default</i> Mallocator/AlignedMallocator). 
 * AlignedMallocator on unix/posix, if `T.alignof >= max(double.sizeof, float.sizeof)` uses malloc and free!
 * Now this is not effective for large memory allocations, but unix/posix not support aligned realloc
 * Recommend non AlignedMallocator (any allocators that uses posix realloc) for large memory allocations with 
 * `T.alignof >= max(double.sizeof, float.sizeof)`.
 * 
 * This structure follow next rules:
 *  <ul>
 *      <li>For any changes to the size of the internal buffer, reallocate from allocator is used</li>
 *      <li>Minimization of constructor/destructor calls, when calling array resizing, concatenation, etc.
 *          (except for creating a new array or copying data in constructor, opAssign and etc.). In other words, if the 
 *          old data is not affected, then it is simply moved without additional calls.</li>
 *      
 *      <li>In case of a memory allocation error, one of two interfaces for processing this is provided:</li>
 *          <ul>
 *              <li>Returns false if the method returns a boolean value (nothrow).</li>
 *              <li>Throwing an `OutOfMemoryError` exception.</li>
 *          </ul>
 *      <li>Any methods that accept arrays as an argument can accept any  compatible in this context `Array!(R, alloctr)`
 *          and any InputRange(except `Infinite`).</li>
 *  </ul> 
 * ---------------
 * import rlib.core.utils.containers: Array;
 * 
 * string testMessage = "test message";
 * Array!char array1, array2; 
 * 
 * array2 = testMessage;       // Create a copy of testMessage
 * array1 = array2;            // Create a copy of array2
 * 
 * assert(array2.empty());
 * assert(array1 == testMessage);
 * assert(array1[] !is testMessage);
 * assert(array1[] !is array2[]);
 * ---------------
 * ---------------
 * array2 = array1.move;
 * assert(array1[] is null);
 * ---------------
 */
struct Array(T, allocator = PickDefaultAllocator!T, double growFactor = 1.5)
        if (CheckAllocatorForType!(T, allocator))
{
    /** 
     * Copy constructor for some Array!(R, alloc).
     *
     *  <ul>
     *      <li>This constructor only works with compatible `Array!(R,alloc)`, standard arrays, `InputRange`.</li>
     *      <li>The constructor does not care how the memory was allocated, if it is possible to read from it</li>
     *      <li>Compatible `Array!(R, alloc)` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible standard array `R[]` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible InputRange `R` is such that the expression `T(ForeachType!R.init)` is valid.</li>
     *      <li>If T is a base type or class, or struct without elaborate assign, then slices are used to copy the data.</li>
     *      <li>If T is a structure with elaborate assign, then when creating an array element, the copy constructor will 
     *          be called using `core.lifetime.emplace`</li>
     *  </ul>
     *
     * Throws: OutOfMemoryError when memory allocation fails
     */
    this(this)
    {
        void[] tmp = this._data;
        T[] array = cast(T[]) tmp[0 .. this._length * T.sizeof];

        this._data = New!(void[], allocator)(tmp.length, T.alignof);

        initBy!false(size_t(0), this._length, array);
    }

    /** 
     * Copy constructor for some Array!(R, alloc).
     *
     *  <ul>
     *      <li>This constructor only works with compatible `Array!(R,alloc)`, standard arrays, `InputRange`.</li>
     *      <li>The constructor does not care how the memory was allocated, if it is possible to read from it</li>
     *      <li>Compatible `Array!(R, alloc)` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible standard array `R[]` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible InputRange `R` is such that the expression `T(ForeachType!R.init)` is valid.</li>
     *      <li>If T is a base type or class, or struct without elaborate assign, then slices are used to copy the data.</li>
     *      <li>If T is a structure with elaborate assign, then when creating an array element, the copy constructor will 
     *          be called using `core.lifetime.emplace`</li>
     *  </ul>
     *
     * Throws: OutOfMemoryError when memory allocation fails
     */
    this(R, alloc)(ref const(Array!(R, alloc)) array)
            if (isConstructableWith!(T, R))
    {
        this.opAssign(array);
    }

    /// ditto
    this(R)(R memory) if (isInputRange!R && isConstructableWith!(T, ForeachType!R))
    {
        static assert(!isInfinite!R, "Are you serious? Do you want to say goodbye to your memory?");

        this.opAssign(memory);
    }

    /** 
     * Assign overload for some `data`.
     *
     *  <ul>
     *      <li>Assign only works with compatible `Array!(R,alloc)`, standard arrays, `InputRange`.</li>
     *      <li>The assign does not care how the memory was allocated, if it is possible to read from it</li>
     *      <li>Compatible `Array!(R, alloc)` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible standard array `R[]` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible InputRange `R` is such that the expression `T(ForeachType!R.init)` is valid.</li>
     *      <li>If T is a base type or class, or struct without elaborate assign, then slices are used to copy the data.</li>
     *      <li>If T is a structure with elaborate assign, then when creating an array element, the copy constructor will 
     *          be called using `core.lifetime.emplace`</li>
     *  </ul>
     *
     * Params:
     *   data = array to copy
     * Throws: OutOfMemoryError when memory allocation fails
     */
    ref auto opAssign(R, alloc)(ref const(Array!(R, alloc)) data)
            if (is(isConstructableWith!(T, R)))
    {
        if (this is data)
        {
            return this;
        }
        if (!this.resize_unitialized(data._length))
        {
            onOutOfMemoryError();
        }
        static if (hasElaborateDestructor!T)
        {
            foreach (ref el; this[])
            {
                destroy!false(el);
            }
        }

        this.initBy!false(0, this._length, data[]);
        return this;
    }

    /// ditto
    ref auto opAssign(R)(R data)
            if (isInputRange!R && isConstructableWith!(T, ForeachType!R))
    {
        static assert(!isInfinite!R, "Are you serious? Do you want to say goodbye to your memory?");

        static if (isArray!R)
        {
            if (checkOverlap(this[], data))
            {
                if (this._length == data.length)
                {
                    return this;
                }

                size_t start = cast(size_t) data.ptr - cast(size_t) this._data.ptr;
                size_t end = start + data.length;

                static if (hasElaborateDestructor!T)
                {
                    foreach (ref el; this[0 .. start])
                    {
                        destroy!false(el);
                    }
                    foreach (ref el; this[end .. this._length])
                    {
                        destroy!false(el);
                    }
                }

                safeMoveRaw(this[start .. end], this[0 .. data.length]);

                this.resize_unitialized!false(data.length);
            }
            else
            {
                if (!this.resize_unitialized(data.length))
                {
                    onOutOfMemoryError();
                }
                this.initBy(0, this._length, data[]);
            }
            return this;
        }
        else
        {
            static if (hasElaborateDestructor!T)
            {
                foreach (ref el; this[0 .. this._length])
                {
                    destroy!false(el);
                }
            }

            static if (hasLength!R)
            {
                if (!this.resize_unitialized!false(data.length))
                {
                    onOutOfMemoryError();
                }
            }

            size_t i;

            foreach (ref el; data)
            {
                static if (!hasLength!R)
                {
                    if (this._length < i)
                    {
                        this.resize_unitialized!false(i + 1);
                    }
                }
                this.initBy(i, el);
                i++;
            }
            if (this._length != i)
            {
                this.resize_unitialized!false(i);
            }

            return this;
        }
    }

    /** 
     * Concatenate data to this. 
     *
     *  <ul>
     *      <li>Concatenate only works with compatible `Array!(R,alloc)`, standard arrays, `InputRange`.</li>
     *      <li>The concatenate does not care how the memory was allocated, if it is possible to read from it</li>
     *      <li>Compatible `Array!(R, alloc)` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible standard array `R[]` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible InputRange `R` is such that the expression `T(ForeachType!R.init)` is valid.</li>
     *      <li>If T is a base type or class, or struct without elaborate assign, then slices are used to copy the data.</li>
     *      <li>If T is a structure with elaborate assign, then when creating an array element, the copy constructor will 
     *          be called using `core.lifetime.emplace`</li>
     *  </ul>
     *
     * Params:
     *   data = data to concatenation.
     * Throws: OutOfMemoryError when memory allocation fails
     */
    ref auto opOpAssign(string op : "~", alloctr)(ref const(Array!(T, alloctr)) data)
    {
        this.insert(this._length, data);
        return this;
    }

    /// ditto
    ref auto opOpAssign(string op : "~", R)(R data)
            if (isInputRange!R && isConstructableWith!(T, ForeachType!R))
    {
        static assert(!isInfinite!R, "Are you serious? Do you want to say goodbye to your memory?");

        this.insert(this._length, data);
        return this;
    }

    ref auto opOpAssign(string op : "~", R)(R data)
            if (!isInputRange!R && isConstructableWith!(T, R))
    {
        this.insert(this._length, (&data)[0 .. 1]);
        return this;
    }

    /** 
     * Return result of concatenation this array with data. 
     *
     *  <ul>
     *      <li>Concatenate only works with compatible `Array!(R,alloc)`, standard arrays, `InputRange`.</li>
     *      <li>Return `Array(T, alloc)` like in this</li>
     *      <li>The concatenate does not care how the memory was allocated, if it is possible to read from it</li>
     *      <li>Compatible `Array!(R, alloc)` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible standard array `R[]` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible InputRange `R` is such that the expression `T(ForeachType!R.init)` is valid.</li>
     *      <li>If T is a base type or class, or struct without elaborate assign, then slices are used to copy the data.</li>
     *      <li>If T is a structure with elaborate assign, then when creating an array element, the copy constructor will 
     *          be called using `core.lifetime.emplace`</li>
     *  </ul>
     *
     * Params:
     *   data = data to concatenation.
     * Throws: OutOfMemoryError when memory allocation fails
     */
    auto opBinary(string op : "~", alloc)(ref const(Array!(T, alloc)) data) const
    {
        Array!(T, allocator) newArray;
        newArray.resize_unitialized(this._length + data._length);
        newArray.initBy(0, this._length, this[]);
        newArray.initBy(this._length, newArray._length, data[]);

        return newArray;
    }

    /// ditto
    auto opBinary(string op : "~", R)(R data) const
    if (isInputRange!R && isConstructableWith!(T, ForeachType!R))
    {
        Array!(T, allocator) newArray;

        static if (isArray!data)
        {
            if (!newArray.resize_unitialized(this._length + data.length))
            {
                onOutOfMemoryError();
            }

            newArray.initBy(0, this._length, this[]);
            newArray.initBy(this._length, newArray.length, data[]);
        }
        else
        {
            static if (hasLength!R)
            {
                if (!newArray.resize_unitialized(this._length, data.length))
                {
                    onOutOfMemoryError();
                }
            }

            newArray.initBy(0, this._length, this[]);

            size_t i = this._length;

            foreach (ref el; data)
            {
                static if (!hasLength!R)
                {
                    newArray.resize_unitialized(i + 1);
                }
                newArray.initBy(i, el);
                i++;
            }
        }

        return newArray;
    }

    /** 
     * Compare two arrays on equality.
     */
    bool opEquals(alloctr)(ref const(Array!(T, alloctr)) array) const
    {
        return this.opCmp(array) == 0;
    }

    /// ditto
    bool opEquals(R)(R range) const
    if (isInputRange!R && is(typeof(T.init == ForeachType!R.init)))
    {
        static assert(!isInfinite!R, "Are you serious? Do you want to say goodbye to your CPU?");

        static if (is(typeof(this[] == range)))
        {
            return this[] == range;
        }
        else static if (is(typeof(range == this[])))
        {
            return range == this[];
        }
        else
        {
            return this.opCmp(range) == 0;
        }
    }

    /** 
     * Compare two arrays.
     */
    int opCmp(alloctr)(ref const(Array!(T, alloctr)) array) const
    {
        return cmp(this[], array[]);
    }

    /// ditto
    int opCmp(R)(R other) const
    if (isInputRange!R && is(typeof(T.init == ForeachType!R.init)))
    {
        static assert(!isInfinite!R, "Are you serious? Do you want to say goodbye to your CPU?");

        int cmp_v;
        size_t i = 0;
        auto obj = this[];

        static if (hasLength!R)
        {
            cmp_v = (this._length > other.length) - (this._length < other.length);
            if (cmp_v != 0)
            {
                return cmp_v;
            }
        }

        foreach (ref el; other)
        {
            cmp_v = (obj[i] > el) - (obj[i] < el);

            if (cmp_v != 0)
            {
                break;
            }
            i++;
        }
        return cmp_v;
    }

    /**
     * Get array element by index.
     * Returns: a reference to the `index` element.
     */
    ref auto opIndex(size_t index)
    {
        return *cast(T*)&this._data[index * T.sizeof];
    }

    /// ditto
    ref auto opIndex(size_t index) const
    {
        return *cast(T*)&this._data[index * T.sizeof];
    }

    /** 
     * Assigns the `value` to the `index` element of the array.
     */
    auto opIndexAssign(R)(R value, size_t index) if (isConstructableWith!(T, R))
    {
        *cast(T*)&this._data[index * T.sizeof] = value;
        return value;
    }

    /** 
     * `op` assign the `value` to the `index` element of the array.
     */
    auto opIndexOpAssign(string op, T)(T value, size_t index)
            if (is(typeof(mixin("this.mData[index] " ~ op ~ "= value"))))
    {
        return mixin("*cast(T*)&this._data[index * T.sizeof] " ~ op ~ "= value;");
        return value;
    }

    /** 
     * Implementations of foreach traversal. 
     */
    int opApply(scope int delegate(ref T) dg)
    {
        int result;
        foreach (i; 0 .. this._length)
        {
            result = dg(this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /// ditto
    int opApply(scope int delegate(ref const T) dg) const
    {
        int result;
        foreach (i; 0 .. this._length)
        {
            result = dg(this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /** 
     * Implementations of foreach traversal. 
     */
    int opApply(scope int delegate(size_t, ref T) dg)
    {
        int result;
        foreach (i; 0 .. this._length)
        {
            result = dg(i, this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /// ditto
    int opApply(scope int delegate(size_t, ref const T) dg) const
    {
        int result;
        foreach (i; 0 .. this._length)
        {
            result = dg(i, this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /** 
     * Implementations of foreach_reverse traversal. 
     */
    int opApplyReverse(scope int delegate(ref T) dg)
    {
        int result;
        foreach_reverse (i; 0 .. this._length)
        {
            result = dg(this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /// ditto
    int opApplyReverse(scope int delegate(ref const T) dg) const
    {
        int result;
        foreach_reverse (i; 0 .. this._length)
        {
            result = dg(this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /** 
     * Implementations of foreach_reverse traversal. 
     */
    int opApplyReverse(scope int delegate(size_t, ref T) dg)
    {
        int result;
        foreach_reverse (i; 0 .. this._length)
        {
            result = dg(i, this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /// ditto
    int opApplyReverse(scope int delegate(size_t, ref const T) dg) const
    {
        int result;
        foreach_reverse (i; 0 .. this._length)
        {
            result = dg(i, this[i]);

            if (result)
            {
                break;
            }
        }
        return result;
    }

    /** 
     * Implementations of array slices.
     */
    T[] opSlice(size_t start, size_t end)
    {
        if (start == end)
        {
            return null;
        }
        assert(end <= this._length, text('[', start, "..", end, "] extends past source array of length ", this
                ._length));
        return cast(T[]) this._data[start * T.sizeof .. end * T.sizeof];
    }
    /// ditto
    T[] opSlice()
    {
        return cast(T[]) this._data[0 .. this._length * T.sizeof];
    }
    /// ditto
    const(T)[] opSlice(size_t start, size_t end) const
    {
        if (start == end)
        {
            return null;
        }
        assert(end <= this._length, text('[', start, "..", end, "] extends past source array of length ", this
                ._length));
        return cast(const(T)[]) this._data[start * T.sizeof .. end * T.sizeof];
    }
    /// ditto
    const(T)[] opSlice() const
    {
        return cast(const(T)[]) this._data[0 .. this._length * T.sizeof];
    }

    /** 
    * Overload of dollar.
    * Returns: array length.
    */
    size_t opDollar()
    {
        return this.length;
    }

    /** 
     * Insert data into this. 
     *
     *  <ul>
     *      <li>Insertion only works with compatible `Array!(R,alloc)`, standard arrays, `InputRange`.</li>
     *      <li>The insert does not care how the memory was allocated, if it is possible to read from it</li>
     *      <li>Compatible `Array!(R, alloc)` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible standard array `R[]` is such that the expression `T(R.init)` is valid.</li>
     *      <li>Compatible InputRange `R` is such that the expression `T(ForeachType!R.init)` is valid.</li>
     *      <li>If T is a base type or class, or struct without elaborate assign, then slices are used to copy the data.</li>
     *      <li>If T is a structure with elaborate assign, then when creating an array element, the copy constructor will 
     *          be called using `core.lifetime.emplace`</li>
     *  </ul>
     *
     * Params:
     *   pos = insertion position.
     *   data = data to insert.
     * Throws: OutOfMemoryError when memory allocation fails
     */
    ref auto insert(alloctr)(size_t pos, ref const(Array!(T, alloctr)) data)
    {
        if (data._length == 0)
        {
            return this;
        }

        if (this is data)
        {
            return insertSelf(pos);
        }

        const oldLength = this._length;
        const toInsert = data[];
        this.resize_unitialized!false(this._length + data._length);

        safeMoveRaw(this[pos .. oldLength], this[pos + toInsert.length .. this._length]);
        this.initBy!false(pos, pos + toInsert.length, toInsert);

        return this;
    }

    /// ditto
    ref auto insert(R)(size_t pos, R data)
            if (isInputRange!R && isConstructableWith!(T, ForeachType!R))
    {
        static assert(!isInfinite!R, "Are you serious? Do you want to say goodbye to your memory?");

        static if (isArray!R)
        {
            if (data.length == 0)
            {
                return this;
            }
            auto obj = this[];

            if (checkOverlap(obj, data[]))
            {
                size_t start = data.ptr - obj.ptr;
                size_t end = start + data.length;
                return this.insertSelf(pos, start, end);
            }

            const oldLength = this._length;
            const toInsert = data[];
            this.resize_unitialized!false(this._length + data.length);

            obj = this[];

            if (pos + toInsert.length != this._length)
            {
                safeMoveRaw(obj[pos .. oldLength], obj[pos + toInsert.length .. this._length]);
            }
            this.initBy!false(pos, pos + toInsert.length, toInsert);
        }
        else
        {
            T[] obj;
            static if (hasLength!R)
            {
                const oldLength = this._length;
                this.resize_unitialized!false(this._length + data.length);
                obj = this[];

                safeMoveRaw(obj[pos .. oldLength], obj[pos + data.length .. this._length]);

                size_t i = pos;

                foreach (ref el; data)
                {
                    this.initBy!false(i++, el);
                }
            }
            else
            {
                Array!(T) tmp = data;
                this.insert(pos, tmp);
            }
        }
        return this;
        /*else
        {
            Array!(T, allocator) tmp = data;
            return this.insert(pos, tmp);
        }*/
    }
    /** 
     * Insert self into self.
     * Params:
     *   pos = position of insertion.
     */
    ref auto insertSelf(size_t pos)
    {
        const oldLength = this._length;
        this.resize_unitialized!false(oldLength + oldLength);

        auto toInsert = [this[0 .. pos], null];

        safeMoveRaw(this[pos .. oldLength], this[pos + oldLength .. this._length]);

        toInsert[1] = this[pos + oldLength .. this._length];

        this.initBy!false(pos, pos + toInsert[0].length, toInsert[0]);
        this.initBy!false(pos + toInsert[0].length, pos + oldLength, toInsert[1]);

        return this;
    }

    /** 
     * Insert self into self.
     * Params:
     *   start = start of insertion.
     *   pos = end of insertion.
     *   pos = position of insertion.
     */
    ref auto insertSelf(size_t pos, size_t start, size_t end)
    {
        const oldLength = this._length;
        const insertLength = end - start;

        assert(start <= end);
        assert(pos <= oldLength);

        if (insertLength == 0)
        {
            return this;
        }

        this.resize_unitialized!false(oldLength + insertLength);
        safeMoveRaw(this[pos .. oldLength], this[pos + insertLength .. this._length]);

        auto obj = this[];

        if (start < pos)
        {
            this.initBy!false(pos, pos + (pos - start), obj[start .. pos]);
            this.initBy!false(pos + (pos - start), pos + insertLength, obj[pos + insertLength .. insertLength + end]);
        }
        else if (end < pos)
        {
            this.initBy!false(pos, pos + insertLength, obj[start .. end]);
        }
        else
        {
            this.initBy!false(pos, pos + insertLength, obj[insertLength + start .. insertLength + end]);
        }

        return this;
    }

    ref auto remove(size_t el)
    {
        if (hasElaborateDestructor!T)
        {
            destroy!false(this[el]);
        }
        safeMoveRaw(this[el + 1 .. this._length], this[el .. this._length - 1]);
        this.resize_unitialized!false(this._length - 1);
        return this;
    }

    ref auto remove(size_t start, size_t end)
    {
        if (hasElaborateDestructor!T)
        {
            foreach (ref el; this[start .. end])
            {
                destroy!false(el);
            }
        }

        const removeLength = end - start;
        safeMoveRaw(this[end .. this._length], this[start .. this._length - removeLength]);
        this.resize_unitialized!false(this._length - removeLength);
        return this;
    }

    ref auto remove(T[] data)
    {
        assert(checkOverlap(this[], data));
        size_t start = cast(size_t) data.ptr - cast(size_t) this._data.ptr;
        size_t end = start + data.length;

        return this.remove(start, end);
    }

    /** 
     * Do nothing. Just return `ref const(typeof(this))` 
     */
    ref auto dup() const
    {
        return this;
    }

    /** 
     * Reserve size for new allocation. If `capacity < reserved`, then try to allocate new memory, 
     * else do nothing.
     * Params:
     *   capacity = reserve size
     * Returns: true, if size reserved successfull.
     */
    bool reserve(size_t capacity)
    {
        if (this._data.length >= capacity * T.sizeof)
        {
            return true;
        }
        const _goodCapacity = this.goodCapacity(capacity);

        if (Realloc!(void[], allocator)(this._data, _goodCapacity * T.sizeof, T.alignof))
        {
            this._minSize = _goodCapacity / 3;
            return true;
        }
        return false;
    }

    /** 
     * Set new size to Array.
     * Params:
     *   size = new size.
     * Returns: true if the size is changed successfully.
     */
    bool resize(size_t size)
    {
        const oldLength = this._length;

        const grow = oldLength < size;
        const resized = this.resize_unitialized(size);

        if (resized && grow)
        {
            // Initialize memory.
            T[] obj = cast(T[]) this._data[oldLength * T.sizeof .. size * T.sizeof];
            initializeAll(obj);
        }
        return resized;
    }

    /**
     * Returns: Current array size.
     */
    size_t length() const @property
    {
        return this._length;
    }

    /** 
     * Set new size to array.
     * Params:
     *   size = new size.
     * Throws: OutOfMemoryError if it was not possible to change the size.
     */
    void length(size_t size) @property
    {
        if (!this.resize(size))
        {
            onOutOfMemoryError();
        }
    }

    size_t capacity() const @property
    {
        return this._data.length / T.sizeof;
    }

    /** 
     * Check and repare reservation.
     * Returns: true if reservation in normal size.
     */
    private bool checkReservation()
    {
        if (this._length >= this._minSize)
        {
            return true;
        }
        if (!Realloc!(void[], allocator)(this._data, cast(size_t)(this._minSize * T.sizeof * growFactor)))
        {
            return false;
        }
        this._minSize = cast(size_t)(this._minSize / growFactor);
        return true;
    }

    /** 
     * Calculate good capacity for this array
     * Params:
     *   capacity = custom capacity.
     * Returns: value, what greater than `capacity`
     */
    static private size_t goodCapacity(size_t capacity)
    {
        return cast(size_t) ceil(growFactor ^^ (ceil(log2(cast(double) capacity) / log2(growFactor))));
    }

    /** 
     * Resize array without initialize new elements.
     * Params:
     *   size = new size.
     * Returns: true if the size is changed successfully.
     */
    private bool resize_unitialized(bool _destroy = true)(size_t size)
    {
        // Don't resize.
        if (this._length == size)
        {
            return true;
        }

        // Shrink at right.
        if (this._length > size)
        {
            static if (_destroy && hasElaborateDestructor!T)
            {
                T[] obj = cast(T[]) this._data[size * T.sizeof .. this._length * T.sizeof];
                foreach (ref el; obj)
                {
                    destroy!(false)(el);
                }
            }

            if (size == 0)
            {
                Delete!(void[], allocator)(this._data);
                this._data = null;
                this._length = 0;
                this._minSize = 0;

                return true;
            }

            this._length = size;
            this.checkReservation();
            return true;
        }

        // Try check size and reserve memory if needed.
        if (this._data.length < size * T.sizeof && !this.reserve(size))
        {
            return false;
        }

        this._length = size;
        return true;
    }

    /** 
     * Abstract method for initializing range elements of array by other array.
     * Params:
     *   from = init from
     *   to = init to
     *   array = init data
     */
    private void initBy(bool _destroy = true, R)(size_t from, size_t to, R[] array)
            if (isConstructableWith!(T, R))
    {
        assert((to - from) == array.length);
        static if (_destroy && hasElaborateDestructor!T)
        {
            foreach (ref el; this[from .. to])
            {
                destroy!false(el);
            }
        }

        // struct with elaborate assign
        static if (is(T == struct) && hasElaborateAssign!T && is(typeof(emplace(&this[0], array[0])))) // struct with elaborate assign
        {
                foreach (i, ref obj; this[from .. to])
                    {
                    emplace(&obj, array[i]);
                }
            }
        else // struct without elaborate assign or basic type 
        {
                // small optimization
                safeMoveRaw((cast(Unqual!R[]) array), this[from .. to]);
            }
    }

    /** 
     * Abstract method for initializing some element of array by other.
     * Params:
     *   index = index of element.
     *   el = data for initialization.
     */
    private void initBy(bool _destroy = true, R)(size_t index, ref const R el)
            if (isConstructableWith!(T, R))
    {
        static if (_destroy && hasElaborateDestructor!T)
        {
            destroy(&this[index]);
        }

        // struct with elaborate assign
        static if (is(T == struct) && hasElaborateAssign!T && is(typeof(emplace(&this[0], array[0])))) // struct with elaborate assign
        {
                emplace(&this[index], el);
            }
        else // struct without elaborate assign or basic type
        {
                // small optimization
                safeMoveRaw((cast(Unqual!R[])(&el)[0 .. 1]), this[index .. index + 1]);
            }
    }

    void clear()
    {
        static if (hasElaborateDestructor!T)
        {
            T[] obj = cast(T[]) this._data[0 .. this._length * T.sizeof];
            foreach (ref el; obj)
            {
                destroy!(false)(el);
            }
        }
        Delete!(void[], allocator)(this._data);
        this._data = null;
        this._minSize = 0;
        this._length = 0;
    }

    /** 
     * Default destructor.
     */
    ~this()
    {
        clear();
    }

    private void[] _data;
    private size_t _minSize;
    private size_t _length;
}
///
@("Array")
unittest
{
    import rlib.core.utils.containers : Array;

    string str = "Hello, World";

    Array!char test1 = str, test2, test3;
    test2 = str;
    test3 = test2;

    assert(test1 == test2);
    assert(test1 == str);
    assert(test2 == str);
    assert(test3 == str);

    test2 ~= str;
    test3 ~= test3;
    test1 = test1 ~ test1;
    str ~= str;

    assert(test1 == test2);
    assert(test1 == str);
    assert(test2 == str);
    assert(test3 == str);

    test1 = str[0 .. $ / 2];
    test2.remove(test2[$ / 2 .. $]);
    test3.remove(test3.length / 2, test3.length);

    test1.insert(test1.length, test1);
    test2.insert(test2.length, test3);
    test3.insert(test3.length, str[0 .. $ / 2]);

    assert(test1 == test2);
    assert(test1 == str);
    assert(test2 == str);
    assert(test3 == str);
}

///
@("Array")
unittest
{
    import rlib.core.utils.containers : Array;
    import std.range : iota, array;

    struct InfiniteRange
    {

        auto front() @property
        {
            return 0;
        }

        enum bool empty = false;

        void popFront()
        {
        }
    }

    Array!(int) myArray;

    // Not work with infinite InputRange.
    static assert(!is(typeof(myArray = InfiniteRange.init)));
    static assert(!is(typeof(myArray ~= InfiniteRange.init)));
    static assert(!is(typeof(myArray == InfiniteRange.init)));
    static assert(!is(typeof(myArray.insert(InfiniteRange.init))));
    static assert(!is(typeof(myArray <= InfiniteRange.init)));

    // Work with any non-infinite InputRange.

    myArray = 10.iota;
    assert(myArray == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    assert(myArray == 10.iota);

    myArray ~= 10.iota;
    auto check = 10.iota.array;
    assert(myArray == check ~ check);
}

/// 
@("Array")
unittest
{
    import rlib.core.utils.containers : Array;

    struct Counter
    {
        ~this()
        {
            ++this._counter;
        }

        static uint _counter;
    }

    {
        Array!Counter array;

        array.resize(5);
        assert(Counter._counter == 0, text("Destructed: ", Counter._counter));

        array.resize(10);
        assert(Counter._counter == 0, text("Destructed: ", Counter._counter));

        array ~= array;
        assert(Counter._counter == 0, text("Destructed: ", Counter._counter));

        array.remove(2);
        assert(Counter._counter == 1, text("Destructed: ", Counter._counter));

        array.remove(array[2 .. 5]);
        assert(Counter._counter == 4, text("Destructed: ", Counter._counter));
    }

    assert(Counter._counter == 20, text("Destructed: ", Counter._counter));
}

/**
 * Implementation of a sparseset
 *
 * <b>It is not recommended for use for large numbers.</b>
 * Two arrays sparse and dense are used for implementation. 
 * Sparse is equal to the size of the largest element (numeric value) (only growing). 
 * Danse has a size equal to the number of SparseSet elements. 
 * <ul>
 *      <li> The size of the occupied memory is O(n+i), where n is the number of elements, and i is the largest index. </li>
 *      <li> At best, adding/removing an element equals O(1), at worst O(n+i)(when dynamically resizing SparseSet). </li>
 *      <li> Checking for the presence(contain) of the O(1) element. </li>
 *      <li> Cleaning SparseSet O(1) </li>
 * </ul>
 * ---------------
 * import rlib.core.utils.containers: SparseSet;
 * 
 * SparseSet!int test;
 *
 * test.add(1);
 * test.add(2);
 * test.add(4);
 * test.add(5);
 *
 * assert(!test.has(0));
 * assert(test.has(1));
 * assert(test.has(2));
 * assert(!test.has(3));
 * assert(test.has(4));
 * assert(test.has(5));
 * assert(!test.has(6));
 *
 * test.remove(2);
 *
 * assert(!test.has(0));
 * assert(test.has(1));
 * assert(!test.has(2));
 * assert(!test.has(3));
 * assert(test.has(4));
 * assert(test.has(5));
 * assert(!test.has(6));
 *
 * test.clear();
 *
 * assert(!test.has(0));
 * assert(!test.has(1));
 * assert(!test.has(2));
 * assert(!test.has(3));
 * assert(!test.has(4));
 * assert(!test.has(5));
 * assert(!test.has(6));
 *
 * ---------------
 */
struct SparseSet(V) if (isBasicType!V)
{
    void add(V element)
    {
        if(this.contain(element))
        {
            return;
        }
        if (sparse.length <= element)
        {
            sparse.length = element + 1;
        }
        this.sparse[element] = cast(V) this.dense.length;
        this.dense ~= element;
    }

    bool contain(V element)
    {
        if (this.sparse.length <= element ||
            this.dense.length <= this.sparse[element] ||
            this.dense[this.sparse[element]] != element)
        {
            return false;
        }
        return true;
    }

    void clear()
    {
        this.sparse.clear();
        this.dense.clear();
    }

    void remove(V element)
    {
        if(!this.contain(element))
        {
            return;
        }

        const denseId = this.sparse[element];

        this.dense[denseId] = this.dense[$ - 1];
        this.sparse[this.dense[$ - 1]] = denseId;

        this.dense.length = this.dense.length - 1;
    }

    private Array!(V, PickDefaultAllocator!V, 2.25) sparse;
    private Array!(V, PickDefaultAllocator!V, 2.25) dense;
}

/// 
@("SparseSet")
unittest
{
    import io = std.stdio;

    SparseSet!int test;

    foreach (i; 0 .. 2)
    {
        test.add(1);
        test.add(2);
        test.add(3);
        test.add(4);
        test.add(5);
        test.add(6);
        test.add(7);
        test.add(8);
        test.add(9);
        test.add(10);

        assert(!test.contain(0));
        assert(test.contain(1));
        assert(test.contain(2));
        assert(test.contain(3));
        assert(test.contain(4));
        assert(test.contain(5));
        assert(test.contain(6));
        assert(test.contain(7));
        assert(test.contain(8));
        assert(test.contain(9));
        assert(test.contain(10));
        assert(!test.contain(11));
        
        test.remove(1);
        test.remove(2);
        test.remove(3);
        test.remove(4);
        test.remove(5);
        test.remove(6);
        test.remove(7);
        test.remove(8);
        test.remove(9);
        test.remove(10);

        assert(!test.contain(0));
        assert(!test.contain(1));
        assert(!test.contain(2));
        assert(!test.contain(3));
        assert(!test.contain(4));
        assert(!test.contain(5));
        assert(!test.contain(6));
        assert(!test.contain(7));
        assert(!test.contain(8));
        assert(!test.contain(9));
        assert(!test.contain(10));
        assert(!test.contain(11));

        test.add(1);
        test.add(2);
        test.add(3);
        test.add(4);
        test.add(5);
        test.add(6);
        test.add(7);
        test.add(8);
        test.add(9);
        test.add(10);

        test.clear();
        
        assert(!test.contain(0));
        assert(!test.contain(1));
        assert(!test.contain(2));
        assert(!test.contain(3));
        assert(!test.contain(4));
        assert(!test.contain(5));
        assert(!test.contain(6));
        assert(!test.contain(7));
        assert(!test.contain(8));
        assert(!test.contain(9));
        assert(!test.contain(10));
        assert(!test.contain(11));
    }
}
