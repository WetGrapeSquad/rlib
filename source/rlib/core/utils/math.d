module rlib.core.utils.math;
import std.math : sqrt, acos;
import std.traits;

/// TODO: Matrix, refactor vector.

struct Vec(T, uint N)
{
    static assert(N > 0);

    this(R)(R[N] data) @trusted nothrow @property @nogc
            if (is(typeof((R r, T t) => t = cast(T) r)))
    {
        static foreach (i; 0 .. N)
        {
            this._data[i] = cast(T) data[i];
        }
    }

    this(R)(const ref Vec!(R, N) rhs) @trusted nothrow @property @nogc
            if (is(typeof((R r, T t) => t = cast(T) r)))
    {
        static foreach (i; 0 .. N)
        {
            this._data[i] = cast(T) rhs._data[i];
        }
    }

    ref auto opAssign(const ref Vec rhs) @trusted nothrow @property @nogc
    {
        static foreach (i; 0 .. N)
        {
            this._data[i] = cast(T) rhs._data[i];
        }
        return this;
    }

    ref auto opAssign(R)(R[N] rhs) @trusted nothrow @property @nogc
            if (is(typeof((R r, T t) => t = cast(T) r)))
    {
        static foreach (i; 0 .. N)
        {
            this._data[i] = cast(T) rhs[i];
        }
        return this;
    }

    ref auto opAssign(R)(const ref Vec!(R, N) rhs) @trusted nothrow @property @nogc
            if (is(typeof((R r, T t) => t = cast(T) r)))
    {
        static foreach (i; 0 .. N)
        {
            this._data[i] = cast(T) rhs._data[i];
        }
        return this;
    }

    static if (isBasicType!T)
    {
        ref auto opOpAssign(string op)(const ref Vec rhs) @trusted nothrow @property @nogc
                if (op == "+" || op == "-")
        {
            static foreach (i; 0 .. N)
            {
                this._data[i] = mixin("this._data[i] " ~ op ~ " cast(T) rhs._data[i]");
            }
            return this;
        }

        ref auto opOpAssign(string op, R)(R[N] rhs) @trusted nothrow @property @nogc
                if (is(typeof((R r, T t) => t = cast(T) r)) && (op == "+" || op == "-"))
        {
            static foreach (i; 0 .. N)
            {
                this._data[i] = mixin("this._data[i] " ~ op ~ " cast(T) rhs[i]");
            }
            return this;
        }

        ref auto opOpAssign(string op, R)(Vec!(R, N) rhs) @trusted nothrow @property @nogc
                if (is(typeof((R r, T t) => t = cast(T) r)) && (op == "+" || op == "-"))
        {
            static foreach (i; 0 .. N)
            {
                this._data[i] = mixin("this._data[i] " ~ op ~ " cast(T) rhs._data[i]");
            }
            return this;
        }

        ref auto opOpAssign(string op, R)(R rhs) @trusted nothrow @property @nogc
                if (isBasicType!R && (op == "*" || op == "/"))
        {
            static foreach (i; 0 .. N)
            {
                this._data[i] = mixin("this._data[i] " ~ op ~ " rhs");
            }
            return this;
        }

        auto opBinary(string op)(Vec rhs) const @trusted nothrow @property @nogc
        {  
            Vec tmp;
            static foreach (i; 0 .. N)
            {
                tmp._data[i] = mixin("this._data[i] " ~ op ~ " cast(T) rhs._data[i]");
            }
            return tmp;
        }

        auto opBinary(string op, R)(R[N] rhs) const @trusted nothrow @property @nogc
        {
            Vec tmp;
            static foreach (i; 0 .. N)
            {
                tmp._data[i] = mixin("this._data[i] " ~ op ~ " cast(T) rhs[i]");
            }
            return tmp;
        }

        auto opBinary(string op, R)(Vec!(R, N) rhs) const @trusted nothrow @property @nogc
        {
            Vec tmp;
            static foreach (i; 0 .. N)
            {
                tmp._data[i] = mixin("this._data[i] " ~ op ~ " cast(T) rhs._data[i]");
            }
            return tmp;
        }
        
        auto opBinary(string op, R)(R rhs) const @trusted nothrow @property @nogc
                if (isBasicType!R && (op == "*" || op == "/"))
        {
            Vec tmp;
            static foreach (i; 0 .. N)
            {
                tmp._data[i] = mixin("this._data[i] " ~ op ~ " rhs");
            }
            return tmp;
        }

        auto opBinary(string op : "*", R)(Vec!(R, N) rhs) const
        {
            CommonType!(float, T, R) sum;

            static foreach (i; 0 .. N)
            {
                sum += this._data[i] * rhs._data[i];
            }
            
            return sum;
        }

        auto opBinary(string op : "*", R)(R[N] rhs) const
        {
            CommonType!(float, T, R) sum;

            static foreach (i; 0 .. N)
            {
                sum += this._data[i] * rhs[i];
            }
            
            return sum;
        }

        auto modulus() const @trusted nothrow @property @nogc
        {
            CommonType!(float, T) sum;
            static foreach (i; 0 .. N)
            {
                sum = (cast(float) this._data[i]) * (cast(float) this._data[i]);
            }
            return sqrt(sum);
        }

        auto distance(R)(Vec!(R, N) to) const @trusted nothrow @property @nogc
        {
            alias Cmn = CommonType!(float, T, R);
            Cmn sum;

            static foreach (i; 0 .. N)
            {
                const cmn tmp = to._data[i] - this._data[i];
                sum += tmp * tmp;
            }

            return sqrt(sum);
        }

        auto normalize() const @trusted nothrow @property @nogc
        {
            Vec!(CommonType!(float, T), N) normalized = this;
            normalized /= normalized.modulus;
            return normalized;
        }

        auto angle(R)(Vec!(R, N) second) const @trusted nothrow @property @nogc
        {
            alias Cmn = CommonType!(float, T, R);
            const _cos = (cast(Cmn)this * cast(Cmn)second) / (cast(Cmn) this.modulus * cast(Cmn) second.modulus);
            return acos(_cos);
        }
    }

    uint length() const @trusted nothrow @property @nogc
    {
        return N;
    }

    auto opDispatch(string member)() const @trusted nothrow @property @nogc
    if(member.length > 1)
    {
        static assert(member.length > 0);
        T[member.length] ret;

        static foreach (i, element; member)
        {
            static if (element == 'r' || element == 'x')
            {
                ret[i] = this._data[0];
            }
            else static if (element == 'g' || element == 'y')
            {
                static assert(N > 1);
                ret[i] = this._data[1];
            }
            else static if (element == 'b' || element == 'z')
            {
                static assert(N > 2);
                ret[i] = this._data[2];
            }
            else static if (element == 'a' || element == 's')
            {
                static assert(N > 3);
                ret[i] = this._data[3];
            }
        }

        return ret;
    }
    
    ref auto opDispatch(string member)() inout @trusted nothrow @property @nogc
    if(member.length == 1)
    {
        static if (member[0] == 'r' || member[0] == 'x')
        {
            return this._data[0];
        }
        else static if (member[0] == 'g' || member[0] == 'y')
        {
            static assert(N > 1);
            return this._data[1];
        }
        else static if (member[0] == 'b' || member[0] == 'z')
        {
            static assert(N > 2);
            return this._data[2];
        }
        else static if (member[0] == 'a' || member[0] == 's')
        {
            static assert(N > 3);
            return this._data[3];
        }
    }

    T[N] _data;
}

alias BVec2 = Vec!(byte, 2);
alias BVec3 = Vec!(byte, 3);
alias BVec4 = Vec!(byte, 4);

alias UBVec2 = Vec!(ubyte, 2);
alias UBVec3 = Vec!(ubyte, 3);
alias UBVec4 = Vec!(ubyte, 4);

alias SVec2 = Vec!(short, 2);
alias SVec3 = Vec!(short, 3);
alias SVec4 = Vec!(short, 4);

alias USVec2 = Vec!(ushort, 2);
alias USVec3 = Vec!(ushort, 3);
alias USVec4 = Vec!(ushort, 4);

alias IVec2 = Vec!(int, 2);
alias IVec3 = Vec!(int, 3);
alias IVec4 = Vec!(int, 4);

alias UIVec2 = Vec!(uint, 2);
alias UIVec3 = Vec!(uint, 3);
alias UIVec4 = Vec!(uint, 4);

alias LVec2 = Vec!(long, 2);
alias LVec3 = Vec!(long, 3);
alias LVec4 = Vec!(long, 4);

alias ULVec2 = Vec!(ulong, 2);
alias ULVec3 = Vec!(ulong, 3);
alias ULVec4 = Vec!(ulong, 4);

alias FVec2 = Vec!(float, 2);
alias FVec3 = Vec!(float, 3);
alias FVec4 = Vec!(float, 4);

alias DVec2 = Vec!(double, 2);
alias DVec3 = Vec!(double, 3);
alias DVec4 = Vec!(double, 4);

alias RVec2 = Vec!(real, 2);
alias RVec3 = Vec!(real, 3);
alias RVec4 = Vec!(real, 4);


