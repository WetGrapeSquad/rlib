module rlib.core.utils.ranges;
import std.traits;
import core.internal.spinlock;
debug import std.format: format;
import std.math : approxEqual;

/** 
 * Range relation.
 */
enum RangeRelation
{
    NoOverlap = 16, // 0b10000 
    Overlap = 1,    // 0b00001
    Nested = 3,     // 0b00011 Nested => Overlapping
    Includes = 5,   // 0b00101 Includes => Overlapping
    Equal = 15,     // 0b01111 Equal => Overlap, Nested, Includes
}

/** 
 * Number range type. 
 */
@nogc
nothrow
struct NumberRange(T) if (isScalarType!T)
{
    /** 
     * Construct a range by start and end.
     * Params:
     *   start = start of the range
     *   end = start of the range
     */
    this(F, S)(F start, S end) if (isScalarType!F && isScalarType!S)
    {
        const first = cast(T) start;
        const second = cast(T) end;

        if (first <= second)
        {
            this.mStart = first;
            this.mEnd = second;
        }
        else
        {
            this.mStart = second;
            this.mEnd = first;
        }
    }

    /** 
     * Copy constructor
     * Params:
     *   range = range to copy
     */
    this(R)(NumberRange!R range)
    {
        this.mStart = cast(T) arg.start;
        this.mEnd = cast(T) arg.end;
    }

    /** 
     * Assign a range by a start and an end.
     * Params:
     *   start = start of the range
     *   end = end of the range
     */
    ref auto opCall(F, S)(F start, S end)
    {
        const first = cast(T) start;
        const second = cast(T) end;

        if (first <= second)
        {
            this.mStart = first;
            this.mEnd = second;
        }
        else
        {
            this.mStart = second;
            this.mEnd = first;
        }

        return this;
    }

    /** 
     * Assign a range
     * Params:
     *   range = range to assign
     */
    ref auto opAssign(R)(const NumberRange!R range)
    {
        this.mStart = cast(T) range.mStart;
        this.mEnd = cast(T) range.mEnd;

        return this;
    }

    /** 
     * Compare on identity two ranges. For floating point ranges use approxEqual with 
     * maxRelDiff = 1e-2 and maxAbsDiff = 1e-5.
     * Params:
     *   other = other range to check equality
     * Returns: true if the two ranges are identical
     */
    bool opEquals(R)(const NumberRange!R other) const pure
    {
        alias commonType = CommonType!(T, R);

        const r1 = cast(commonType) other.mStart;
        const r2 = cast(commonType) other.mEnd;
        const l1 = cast(commonType) this.mStart;
        const l2 = cast(commonType) this.mEnd;

        static if (isFloatingPoint!(commonType))
        {
            return approxEqual(l1, r1, 1e-2, 1e-5) && approxEqual(l2, r2, 1e-2, 1e-5);
        }
        else
        {
            return l1 == r1 && l2 == r2;
        }
    }

    /** 
     * Compare two ranges by their length.
     * Params:
     *   other = other range to compare
     * Returns: the relation between the two ranges
     */
    int opCmp(R)(const NumberRange!R other) const pure
    {
        alias commonType = CommonType!(T, R);

        const l1 = cast(commonType) this.mStart;
        const l2 = cast(commonType) this.mEnd;
        const r1 = cast(commonType) other.mStart;
        const r2 = cast(commonType) other.mEnd;

        const lLength = l2 - l1;
        const rLength = r2 - r1;

        return lLength - rLength;
    }
    
    /** 
     * Slice a range.
     * Params:
     *   start = relative start of the range
     *   end = relative end of the range
     * Returns: subrange of this range
     */
    auto opSlice(F, S)(F start, S end)
    {
        alias commonType = CommonType!(T, F, S);

        const first = cast(commonType) start;
        const second = cast(commonType) end;
        const thisFirst = cast(commonType) this.mStart;
        const thisSecond = cast(commonType) this.mEnd;

        assert(first <= second, "Invalid range. %s > %s".format(first, second));
        assert(first + thisFirst < thisSecond && thisFirst + second <= thisSecond, 
            "Out of range. [%s..%s] not included in [%s..%s]".format(first, second, 0, thisSecond - thisFirst));

        static if (isFloatingPoint!commonType)
        {
            if (approxEqual(first, second, 1e-2, 1e-5))
            {
                return NumberRange!commonType();
            }
        }

        return NumberRange!commonType(first + thisFirst, second + thisFirst);
    }

    /** 
     * Slice a range.
     * Returns: copy of this range
     */
    auto opSlice()
    {
        return this;
    }

    /** 
     * Index of a range
     * Params:
     *   index = index inner the range
     * Returns: relative number of the range
     */
    auto opIndex(Arg)(Arg index) if (isScalarType!Arg)
    {
        alias commonType = CommonType!(Arg, T);

        const sum = cast(commonType) this.mStart + cast(commonType) index;
        assert(sum < cast(commonType) this.mEnd,
            "Index out of range: [%s] bigger than [%s].".format(index, this.mEnd - this.mStart));

        return sum;
    }

    /** 
     * Length of a range
     */
    T length() const pure @property
    {
        return this.mEnd - this.mStart;
    }
    /** 
     * Length of a range
     * Params:
     *   length = new length
     */
    void length(T length) @property
    {
        assert(this.mStart + length <= this.mEnd, "New length exceeds range length. %s > %s".format(length, this.length));
        this.mEnd = this.mStart + length;
    }

    /** 
     * Check the relative position between the two ranges
     * Params:
     *   first = first range to check relationship
     *   second = second range to check relationship
     * Returns: the relation between the two ranges
     */
    pure
    static RangeRelation checkRelation(Arg)(const ref NumberRange!Arg first, const ref NumberRange!Arg second)
    {
        if (first == second)
        {
            return RangeRelation.Equal;
        }
        if (first.mStart >= second.mStart && first.mStart <= second.mEnd)
        {
            if (first.mEnd <= second.mEnd)
            {
                return RangeRelation.Nested;
            }
            return RangeRelation.Overlap;
        }

        if (second.mStart >= first.mStart && second.mStart <= first.mEnd)
        {
            if (second.mEnd <= first.mEnd)
            {
                return RangeRelation.Includes;
            }
            return RangeRelation.Overlap;
        }
        return RangeRelation.NoOverlap;
    }

    /** 
     * Check the relative position between this range and another
     * Params:
     *   other = another range to check relationship
     * Returns: the relation between the two ranges
     */
    pure
    RangeRelation checkRelation(R)(const NumberRange!R other) const
    {
        alias commonType = CommonType!(T, R);
        NumberRange!commonType left = this, right = other;
        return this.checkRelation(left, right);
    }
    
    private T mStart, mEnd;
}

///
@("NumberRange") unittest
{
    NumberRange!int test1, test2;
    test1(10, 15);
    test2 = test1;

    assert(test1.checkRelation(test2) & RangeRelation.Equal);
    assert(test1.checkRelation(test2) & RangeRelation.Includes);
    assert(test1.checkRelation(test2) & RangeRelation.Nested);
    assert(test1.checkRelation(test2) & RangeRelation.Overlap);
    assert((test1.checkRelation(test2) & RangeRelation.NoOverlap) == 0);

    test2 = test2[1..4];

    assert(test1.length() == 5);
    assert(test2.length() == 3);

    assert(test1.checkRelation(test2) & RangeRelation.Includes);
    assert(test1.checkRelation(test2) & RangeRelation.Overlap);
    assert((test1.checkRelation(test2) & RangeRelation.NoOverlap) == 0);

    assert(test2.checkRelation(test1) & RangeRelation.Nested);
    assert(test2.checkRelation(test1) & RangeRelation.Overlap);
    assert((test2.checkRelation(test1) & RangeRelation.NoOverlap) == 0);

    assert(test1.checkRelation(test1) & RangeRelation.Equal);
    assert(test1.checkRelation(test1) & RangeRelation.Includes);
    assert(test1.checkRelation(test1) & RangeRelation.Nested);
    assert(test1.checkRelation(test1) & RangeRelation.Overlap);
    assert((test1.checkRelation(test1) & RangeRelation.NoOverlap) == 0);

    assert(test2[2] == 13);
    assert(test2[2.5] == 13.5);
}
///
@("NumberRange") unittest
{
    import rlib.core.utils.ranges: NumberRange;

    auto test1 = NumberRange!int(3, 1), test2 = NumberRange!int(1, 3);

    assert(test1 == test2);

    test1(10, 15);
    test2(15, 10);

    assert(test1 == test2);

    test1.length = 5;
    
    assert(test1 == test2);

    test1.length = 4;
    
    assert(test1 != test2);
    assert(test1 < test2);
}