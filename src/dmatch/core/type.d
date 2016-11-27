module dmatch.core.type;

import std.algorithm.iteration;
import std.algorithm.searching;
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

struct Index {
	immutable size_t index;
	immutable bool reverse;
	immutable bool enabled = false;
	this(size_t index,bool reverse) {
		this(index,reverse,true);
	}
	this(size_t index,bool reverse,bool enabled) {
		this.index = index;
		this.reverse = reverse;
		this.enabled = enabled;
	}
	static Index disabled() {
		return Index(0,false,false);
	}
	string toString() {
		if (reverse)
			return format("$-%s",index + 1);
		else
			return format("%s",index);
	}
	string otherSide() {
		if (reverse)
			return format("0..$-%s",index+1);
		else
			return format("%s..$",index+1);
	}
}
unittest {
	static assert(Index(2,false).toString == "2");
	static assert(Index(1,true).toString == "$-2");
	static assert(Index(2,false).otherSide == "3..$");
	static assert(Index(1,true).otherSide == "0..$-2");
}

struct AST {
public:
	immutable Type type;
	immutable string data;
	immutable AST[] children;
	immutable Index pos;
	this(immutable Type type,immutable string data,immutable AST[] children,immutable Index pos = Index.disabled) immutable {
		this.type = type;
		this.data = data;
		this.children = children;
		this.pos = pos;
	}
	string toString() immutable {
		import std.string;
		return format("AST( %s, %s, [%s])",type,'\"'~data~'\"',children.map!(a => a.toString).join(","));
	}
	bool opEquals(immutable AST ast) immutable{
		return	type == ast.type &&
				data == ast.data &&
				pos  == ast.pos  &&
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
