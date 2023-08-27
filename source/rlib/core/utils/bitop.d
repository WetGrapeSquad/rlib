module rlib.core.utils.bitop;
import std.traits;
import core.bitop : bsr;

/** 
 * BitSlice - a simple structure that implements an abstraction for working with array bits.
 */
struct BitSlice
{
    /** 
     * Initialize a bit slice by a buffer slice.
     * Params:
     *   buffer = buffer of bits
     */
    this(T)(T[] buffer) if (isBasicType!T)
    {
        this.mBuffer = cast(ubyte[]) buffer;
    }

    /**
     * Assign a buffer slice.
     */
    auto opAssign(T)(T[] value) if (isBasicType!T)
    {
        this.mBuffer = cast(ubyte[]) value;
        return this;
    }

    /**
     * Compare this buffer with other slice by data equality.
     */
    bool opEquals(R)(const R[] other) const
    if (isBasicType!R)
    {
        ubyte[] right = cast(ubyte[]) other;
        return this.mBuffer == right;
    }

    /**
     * Compare this bit slice with other bit slice
     */
    bool opEquals(const BitSlice other) const
    {
        return this.mBuffer == other.mBuffer;
    }

    /** 
     * Set `index` bit by `value`.
     * Params:
     *   value = bit value
     *   index = bit index
     */
    auto opIndexAssign(bool value, size_t index)
    {
        const byteIndex = index / 8;
        const bitIndex = index % 8;
        const bitShift = (7 - bitIndex);

        if (value)
        {
            this.mBuffer[byteIndex] |= (1 << bitShift);
        }
        else
        {
            this.mBuffer[byteIndex] &= ~(1 << bitShift);
        }
        return value;
    }

    /** 
     * Set slice [`start` .. `end`] bits by `value`.
     * Params:
     *   value = bit values
     *   start = start slice index
     *   end = end slice index
     */
    auto opSliceAssign(bool value, size_t start, size_t end)
    {
        assert(start < end);

        const firstByte = (start + 7) / 8;
        const lastByte = end / 8;

        if (value)
        {
            if (firstByte <= lastByte)
            {
                this.mBuffer[firstByte .. lastByte] = ubyte.max;

                if (start % 8 != 0)
                {
                    const bitIndex = start % 8;
                    const bitShift = (8 - bitIndex);

                    this.mBuffer[firstByte - 1] |= (1 << bitShift) - 1;
                }
                if (end % 8 != 0)
                {
                    const bitIndex = end % 8;
                    const bitShift = (8 - bitIndex);

                    this.mBuffer[lastByte] |= ~((1 << bitShift) - 1);
                }
            }
            else
            {
                ubyte tmp;
                {
                    const bitIndex = start % 8;
                    const bitShift = (8 - bitIndex);

                    tmp = (1 << bitShift) - 1;
                }
                {
                    const bitIndex = end % 8;
                    const bitShift = (8 - bitIndex);

                    tmp &= ~((1 << bitShift) - 1);
                }
                this.mBuffer[lastByte] |= tmp;
            }
        }
        else
        {
            if (firstByte <= lastByte)
            {
                this.mBuffer[firstByte .. lastByte] = 0;

                if (start % 8 != 0)
                {
                    const bitIndex = start % 8;
                    const bitShift = (8 - bitIndex);

                    this.mBuffer[firstByte - 1] &= ~((1 << bitShift) - 1);
                }
                if (end % 8 != 0)
                {
                    const bitIndex = end % 8;
                    const bitShift = (8 - bitIndex);

                    this.mBuffer[lastByte] &= (1 << bitShift) - 1;
                }
            }
            else
            {
                ubyte tmp;
                {
                    const bitIndex = start % 8;
                    const bitShift = (8 - bitIndex);

                    tmp = (1 << bitShift) - 1;
                }
                {
                    const bitIndex = end % 8;
                    const bitShift = (8 - bitIndex);

                    tmp &= ~((1 << bitShift) - 1);
                }
                this.mBuffer[lastByte] &= ~tmp;
            }
        }
        return value;
    }
    
    /** 
     * Set all bits by `value`.
     * Params:
     *   value = bit value
     */
    auto opSliceAssign(bool value)
    {
        if(value)
        {
            this.mBuffer[] = ubyte.max;
        }
        else 
        {
            this.mBuffer[] = 0;
        }
        return value;
    }

    /** 
     * Get `index` bit.
     * Params:
     *   index = bit index
     */
    auto opIndex(size_t index)
    {
        const byteIndex = index / 8;
        const bitIndex = index % 8;
        const bitShift = (7 - bitIndex);

        return (this.mBuffer[byteIndex] & (1 << bitShift)) > 0;
    }

    /** 
     * Foreach all bits.
     * Params:
     *   dg = foreach delegate
     */
    int opApply(scope int delegate(bool item) dg)
    {
        int result = 0;

        foreach (i; 0 .. (mBuffer.length * 8))
        {
            result = dg(this.opIndex(i));
            if (result)
                break;
        }

        return result;
    }

    /** 
     * Foreach all bits.
     * Params:
     *   dg = foreach delegate
     */
    int opApply(scope int delegate(size_t index, ref bool item) dg)
    {
        int result = 0;

        foreach (i; 0 .. (mBuffer.length * 8))
        {
            bool current = this.opIndex(i);
            bool newValue = current;

            result = dg(i, newValue);
            if (result)
                break;

            if (newValue != current)
            {
                this.opIndexAssign(newValue, i);
            }
        }

        return result;
    }

    ubyte[] mBuffer;
}

///
@("BitArray") public unittest
{
    import rlib.core.utils.bitop: BitSlice;

    ubyte[4] data1 = 0;
    ubyte[4] data2 = ubyte.max;
    ubyte[4] check = [0b10000000, 0b00000111, 0b10000000, 0b00000001];

    BitSlice bitSlice1 = cast(void[]) data1[];
    BitSlice bitSlice2 = cast(void[]) data2[];

    bitSlice1[0] = true;
    bitSlice1[13 .. 17] = true;
    bitSlice1[31] = true;

    bitSlice2[1 .. 13] = false;
    bitSlice2[17 .. 31] = false;

    assert(check == data1 && check == data2);
}

/** 
 * Formated write bit array to console
 * Params:
 *   data = buffer of bit's to write
 */
void bitWrite(T)(T[] data) if (isBasicType!T)
{
    import io = std.stdio;

    BitSlice tmp = data;

    foreach (i, bool el; tmp)
    {
        if ((i + 1) % 8 == 0)
        {
            io.write(cast(int) el, ' ');
        }
        else
        {
            io.write(cast(int) el);
        }
    }
}

/** 
 * Formated write bit array to console
 * Params:
 *   data = buffer of bit's to write
 */
void bitWriteln(T)(T[] data) if (isBasicType!T)
{
    import io = std.stdio;

    bitWrite(data);
    io.writeln;
}


/** 
 * Calculates the number of bits needed to write the number `x`
 * Params:
 *   x = number for calculation
 * Returns: number of bits.
 */
pragma(inline, true)
int bitWidth(uint x)
{
    if (x <= 1)
    {
        return 1;
    }
    return bsr(x) + 1;
}
/// ditto
pragma(inline, true)
long bitWidth(ulong x)
{
    if (x <= 1)
    {
        return 1;
    }
    return bsr(x) + 1;
}
///
@("bitWidth")
unittest
{
    import rlib.core.utils.bitop: bitWidth;

    assert(bitWidth(0) == 1); //0b0
    assert(bitWidth(1) == 1); //0b1
    assert(bitWidth(2) == 2); //0b10
    assert(bitWidth(3) == 2); //0b11
    assert(bitWidth(4) == 3); //0b100
    assert(bitWidth(5) == 3); //0b101
    assert(bitWidth(6) == 3); //0b110
    assert(bitWidth(7) == 3); //0b111
    assert(bitWidth(8) == 4); //0b1000
    assert(bitWidth(9) == 4); //0b1001
}

/** 
 * The nearest upper power of two 
 * Returns: the minimum number `i >= x` is such that there exists `i = 2^^N'. Exceptions `x = 0 => i = 0`.
 */
pragma(inline, true)
int bitCeil(uint x)
{
    if ((x & (x - 1)) == 0)
    {
        return x;
    }
    return 1 << bitWidth(x - 1);
}
/// ditto
pragma(inline, true)
long bitCeil(ulong x)
{
    if ((x & (x - 1)) == 0)
    {
        return x;
    }
    return 1 << bitWidth(x - 1);
}
///
@("bitCeil")
unittest
{
    import rlib.core.utils.bitop: bitCeil;
    
    assert(bitCeil(0) == 0); // exceptions
    assert(bitCeil(1) == 1); // 2^0
    assert(bitCeil(2) == 2); // 2^1
    assert(bitCeil(3) == 4); // 2^2
    assert(bitCeil(4) == 4); // 2^2
    assert(bitCeil(5) == 8); // 2^3
    assert(bitCeil(6) == 8); // 2^3
    assert(bitCeil(7) == 8); // 2^3
    assert(bitCeil(8) == 8); // 2^3
    assert(bitCeil(9) == 16); // 2^4
}

/** 
 * The nearest lower power of two 
 * Returns: the maximum number `i <= x` is such that there exists `i = 2^^N'. Exceptions `x = 0 => i = 0`.
 */
pragma(inline, true)
int bitFloor(uint x)
{
    if (x == 0)
    {
        return 0;
    }
    return 1 << (bitWidth(x) - 1);
}
/// ditto
pragma(inline, true)
long bitFloor(ulong x)
{
    if (x == 0)
    {
        return 0;
    }
    return 1 << (bitWidth(x) - 1);
}
///
@("bitFloor")
unittest
{
    import rlib.core.utils.bitop: bitFloor;
    
    assert(bitFloor(0) == 0); // exceptions
    assert(bitFloor(1) == 1); // 2^0
    assert(bitFloor(2) == 2); // 2^1
    assert(bitFloor(3) == 2); // 2^1
    assert(bitFloor(4) == 4); // 2^2
    assert(bitFloor(5) == 4); // 2^2
    assert(bitFloor(6) == 4); // 2^2
    assert(bitFloor(7) == 4); // 2^2
    assert(bitFloor(8) == 8); // 2^3
    assert(bitFloor(9) == 8); // 2^3
}
