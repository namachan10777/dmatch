module dmatch.core.type;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.comparison;
import std.range;
import std.format;

enum Type {
	Root,
	Bind,
	RVal,
	As,
	Array,
	Array_Elem,
	Range,
	Record,
	Pair,
	Variant,
	If,
	Empty
}

struct Range {
	immutable Index begin;
	immutable Index end;
	string toString() inout {
		if (begin == end) return begin.toString;
		return begin.nor(end);
	}
}

struct Index {
	immutable size_t index;
	immutable bool reverse;
	immutable bool enabled = false;
	this(size_t index,bool reverse)  {
		this(index,reverse,true);
	}
	this(size_t index,bool reverse,bool enabled)  {
		this.index = index;
		this.reverse = reverse;
		this.enabled = enabled;
	}
	static Index disabled() {
		return Index(0,false,false);
	}
	string toString() inout {
		if (reverse)
			return format("$-%s",index + 1);
		else
			return format("%s",index);
	}
	string otherSide() inout {
		if (reverse)
			return format("0..$-%s",index+1);
		else
			return format("%s..$",index+1);
	}
	string nor(inout Index idx) inout {
		if (idx.reverse == reverse) {
			if (!reverse) {
				return format("%d..$",  max(index,idx.index));
			}
			else {
				return format("0..$-%d",max(index,idx.index));
			}
		}
		else {
			auto l  = !reverse ? this : idx;
			auto r =  reverse ? this : idx;
			return format("%s..$-%s",l.toString,r.index); 
		}
	}
	inout(Index) opAdd(inout size_t x) const{
		if (!reverse)
			return Index(index + x,reverse);
		else
			return Index(index - x,reverse);
	}
	inout(Index) opSub(inout size_t x) const{
		if (!reverse)
			return Index(index - x,reverse);
		else
			return Index(index + x,reverse);
	}
}
unittest {
	static assert(Index(2,false).toString == "2");
	static assert(Index(1,true).toString == "$-2");
	static assert(Index(2,false).otherSide == "3..$");
	static assert(Index(1,true).otherSide == "0..$-2");
	enum idx1 = Index(2,false);
	enum idx2 = Index(4,false);
	static assert(idx1.nor(idx2) == "4..$");
	static assert(idx2.nor(idx1) == "4..$");
	enum idx3 = Index(2,true);
	enum idx4 = Index(4,true);
	static assert(idx3.nor(idx4) == "0..$-4");
	static assert(idx4.nor(idx3) == "0..$-4");
	static assert(idx1.nor(idx3) == "2..$-2");
	static assert(idx4.nor(idx2) == "4..$-4");
}


struct AST {
public:
	immutable Type type;
	immutable string data;
	immutable AST[] children;
	immutable Index pos;
	immutable Range range;
	this(immutable Type type,immutable string data,immutable AST[] children,immutable Index pos = Index.disabled,immutable Range range = Range(Index.disabled,Index.disabled)) immutable {
		this.type = type;
		this.data = data;
		this.children = children;
		this.pos = pos;
		this.range = range;
	}
	string toString() immutable {
		import std.string;
		return format("AST( %s, %s, [%s], %s, %s)",type,'\"'~data~'\"',children.map!(a => a.toString).join(","),range,pos);
	}
	bool opEquals(immutable AST ast) immutable{
		return	type == ast.type &&
				data == ast.data &&
				pos  == ast.pos  &&
				range == ast.range &&
				children.length == ast.children.length &&
				zip(children,ast.children)
				.all!(a => a[0] == a[1]);
	}
}
unittest {
	enum a1 = immutable AST(Type.Bind,"a",[]);
	enum a2 = immutable AST(Type.Bind,"a",[]);
	enum b1 = immutable AST(Type.RVal,"1",[]);
	enum b2 = immutable AST(Type.RVal,"1",[]);
	enum r1 = immutable AST(Type.Root,"",[a1,b1]);
	enum r2 = immutable AST(Type.Root,"",[a2,b2]);
	static assert (r1 == r2);
	enum c1= immutable AST(Type.Bind,"c",[]);
	enum r3 = immutable AST(Type.Root,"",[a1,c1]);
	static assert (r1 != r3);
}
