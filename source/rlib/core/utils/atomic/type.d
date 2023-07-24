module rlib.core.utils.atomic.type;
import core.atomic : atomicFetchAdd, atomicFetchSub, atomicLoad, atomicOp, atomicStore;
import std.algorithm : canFind;
import std.conv : to;
import std.string : split;
import std.traits : CommonType, isBasicType, isImplicitlyConvertible;

/** 
 * Hellper wrapper make data unshared in shared scope.
 * Warning: this wrapper is not thread safe.
 */
shared struct UnShared(T)
{
    pragma(inline, true) ref T __g__e__t__()
    {
        return *(cast(T*)&this.__d__a__t__a__);
    }

    alias __g__e__t__ this;
    private shared T __d__a__t__a__;
}

/** 
 * An atomic type wrapper for `core.atomic`.
 * Support all basic types and standart operations.
 */
shared struct Atomic(T)
if(isBasicType!T)
{   
    this(const T value)
    {
        this.data = value;
    }
    this(R)(const ref Atomic!R value)
    if(is(typeof(cast(T)(value))))
    {
        this.data = cast(T)value;
    }

    /** 
     * Assign some `value` to atomic storage.
     * Params:
     *   value = assign value.
     */
    auto opAssign(const T value)
    {
        atomicStore(this.data, value);
        return value;
    }
    /** 
     * Assign some `value` value to atomic storage.
     * Params:
     *   value = assign value.
     */
    auto opAssign(R)(const ref Atomic!R value)
    if(is(typeof(cast(T)(value))))
    {
        atomicStore(this.data, cast(T)atomicLoad(value.data));
        return value;
    }


    /** 
     * Atomic load and exchange rvalue.
     * Params:
     *   value = value for exchange.
     */
    auto opOpAssign(string op)(const T value)
    if("+ - * / % ^^ & | ^ << >> >>> ~".split.canFind(op))
    {  
        return atomicOp!(op ~ '=')(this.data, value);
    }

    /** 
     * Atomic load and exchange rvalue.
     */
    auto opUnary(string op)() const 
    if("+ - * ~".split.canFind(op))
    {
        mixin("return " ~ op ~ " atomicLoad(this.data);");
    }


    /** 
     * Atomic increment/decrement.
     */
    auto opUnary(string op)()
    if("++ --".split.canFind(op))
    {
        static if(op == "++")
        {
            return atomicFetchAdd(this.data, 1) + 1;
        }
        else
        {
            return atomicFetchSub(this.data, 1) - 1;
        }
    }

    /** 
     * Atomic load and compare.
     */
    bool opEquals(R)(const ref Atomic!R other) const
    {
        alias Type = CommonType!(T, R);
        Type left = cast(Type)this;
        Type right = cast(Type)other;
        return left == right;
    }

    /** 
     * Atomic load and compare.
     */
    bool opEquals(R)(const R other) const
    if(is(typeof(cast(T)(other))) || is(typeof(cast(R)(this))))
    {
        static if(is(typeof(cast(T)(other))))
        {
            T left = cast(T)this;
            T right = cast(T)other;
        }
        else 
        {
            T left = cast(R)this;
            T right = cast(R)other;
        }
        return left == right;
    }

    /** 
     * Atomic load and compare.
     */
    int opCmp(R)(const ref Atomic!R other) const
    {
        alias Type = CommonType!(T, R);
        Type left = cast(Type)this;
        Type right = cast(Type)other;
        return (left > right) - (left < right);
    }

    /** 
     * Atomic load and compare.
     */
    int opCmp(R)(const R other) const
    if(is(typeof(cast(T)(other))) || is(typeof(cast(R)(this))))
    {
        static if(is(typeof(cast(T)(other))))
        {
            T left = cast(T)this;
            T right = cast(T)other;
        }
        else 
        {
            R left = cast(R)this;
            R right = cast(R)other;
        }
        return (left > right) - (left < right);
    }


    /** 
     * Atomic load and exchange rvalue.
     */
    auto opBinary(string op, R)(const Atomic!R rhs) const
    if("+ - * / % ^^ & | ^ << >> >>> ~".split.canFind(op))
    {
        alias Type = CommonType!(T, R);
        Type left = cast(Type)this;
        Type right = cast(Type)rhs;
        mixin("return left " ~ op ~ " right;");
    }

    /** 
     * Atomic load and exchange rvalue.
     */
    auto opBinary(string op, R)(const R rhs) const
    if(is(typeof(cast(T)(other))) || is(typeof(cast(R)(this))))
    {
        static if(is(typeof(cast(T)(other))))
        {
            T left = cast(T)this;
            T right = cast(T)rhs;
        }
        else 
        {
            R left = cast(R)this;
            R right = cast(R)rhs;
        }

        mixin("return left " ~ op ~ " right;");
    }    

    /** 
     * Atomic load and convert to string (using `std.conv.to!string`).
     */
    string toString() const @safe pure nothrow
    {
        return atomicLoad(this.data).to!string;
    }

    /** 
     * Atomic load and convert to imlicitly convertible type.
     */
    A opCast(A)() const
    if(isImplicitlyConvertible!(T, A))
    {
        return cast(A) atomicLoad(this.data);
    }

    /** 
     * Atomic load and convert to `bool`.
     */
    bool opCast(A : bool)() const
    {
        return cast(bool) atomicLoad(this.data);
    }

    /** 
    * Unsupported operations will result in call atomicLoad for get rvalue copy (const)
    */
    alias opCast this;

    shared T data;
}