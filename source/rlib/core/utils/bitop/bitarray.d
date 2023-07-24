module rlib.core.utils.bitop.bitarray;
import std.traits;

/** 
 * BitSlice - a simple structure that implements an abstraction for working with array bits.
 */
struct BitSlice
{
    this(T)(T[] buffer) if (isBasicType!T)
    {
        this.mBuffer = cast(ubyte[]) buffer;
    }

    auto opAssign(T)(T[] value) if (isBasicType!T)
    {
        this.mBuffer = cast(ubyte[]) value;
        return this;
    }

    bool opEquals(R)(const R[] other) const
    if (isBasicType!R)
    {
        ubyte[] right = cast(ubyte[]) other;
        if (right.length != this.mBuffer.length)
        {
            return false;
        }
        foreach (i, bright; right)
        {
            if (this.mBuffer[i] != bright)
            {
                return false;
            }
        }
        return true;
    }

    bool opEquals(const BitSlice other) const
    {
        if (other.mBuffer.length != this.mBuffer.length)
        {
            return false;
        }
        foreach (i, bright; other.mBuffer)
        {
            if (this.mBuffer[i] != bright)
            {
                return false;
            }
        }
        return true;
    }

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

    auto opIndex(size_t index)
    {
        const byteIndex = index / 8;
        const bitIndex = index % 8;
        const bitShift = (7 - bitIndex);

        return (this.mBuffer[byteIndex] & (1 << bitShift)) > 0;
    }

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

void bitWriteln(T)(T[] data) if (isBasicType!T)
{
    import io = std.stdio;

    bitWrite(data);
    io.writeln;
}
