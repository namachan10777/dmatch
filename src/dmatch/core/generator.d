module dmatch.core.generator;

import std.stdio;
import std.algorithm.iteration;
import std.range;
import std.random;
import std.conv;
import std.format;
import std.typecons;
import std.compiler;

import dmatch.core.parser;
import dmatch.core.analyzer;
import dmatch.core.type;
import dmatch.core.util;

alias Tp = Tuple;

Tp!(immutable(AST),immutable(string[])) nameAssign(immutable AST tree) {
	final switch(tree.type) {
		case Type.Root:
		case Type.If:
		case Type.As:
		case Type.Bind:
		case Type.Array:
		case Type.Array_Elem :
		case Type.Record :
		case Type.Pair:
		case Type.Empty:
		case Type.Variant:
		case Type.Range:
			auto result = tree.children.map!(a => nameAssign(a));
			immutable string[] base;
			immutable condtions = result.map!(a => a[1]).fold!"a~b"(base);
			immutable children = result.map!(a => a[0]).array;
			return typeof(return)(immutable AST(tree.type,tree.data,children,tree.pos),condtions);
		case Type.RVal:
			uint hash_1;
			foreach(c;__DATE__ ~ __TIME__ ~ __FILE__ ~ tree.data ~ (&tree).to!string) {
				hash_1 = hash_1 * 9 + c;
			}
			uint hash_2;
			foreach(c;__DATE__ ~ __TIME__ ~ (&tree).to!string ~ tree.data ~ __FILE__) {
				hash_2 = hash_2 * 7 + c;
			}
			Mt19937 gen;
			gen.seed(hash_1);
			immutable name_1 = uniform(0,uint.max,gen).to!string;
			gen.seed(hash_2);
			immutable name_2 = uniform(0,uint.max,gen).to!string;
			return typeof(return)(immutable AST(Type.Bind,name_1~name_2,[],tree.pos),[format("%s == %s",name_1~name_2,tree.data)]);
	}
}

immutable(AST) linkGuard(immutable AST tree,immutable string[] condtions)
in{
	assert (tree.type == Type.Root);
}
body{
	immutable guard = tree.children.length == 2 ?
					immutable AST(Type.If,tree.children[1].data ~ "&&" ~ condtions.join("&&"),[]) :
					immutable AST(Type.If,                        	     condtions.join("&&"),[]);
	return immutable AST(Type.Root,"",[tree.children[0],guard]);
}
unittest {
	enum tree = immutable AST(Type.Root,"",[
							immutable AST(Type.Bind,"a",[]),
							immutable AST(Type.If,"a < 10",[])]);
	enum condtions = ["a > -10","a % 3 == 0"];
	static assert (linkGuard(tree,condtions) ==
			immutable AST(Type.Root,"",[
				immutable AST(Type.Bind,"a",[]),
				immutable AST(Type.If,"a < 10&&a > -10&&a % 3 == 0",[])]));
}

size_t min_array_size(immutable AST tree) 
in {
	assert (tree.type == Type.Array);
}
body{
	return tree.children.map!(a => a.type == Type.Array_Elem ? a.children.length : 0).fold!"a+b"(0LU);
}
unittest {
	static assert (min_array_size(immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Bind,"b",[]),
					immutable AST(Type.Bind,"c",[])]),
				immutable AST(Type.Bind,"d",[])]))
			== 3);
	static assert (min_array_size(immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Bind,"b",[]),
					immutable AST(Type.Bind,"c",[])])]))
			== 3);
}

immutable(string) generate(immutable AST tree,immutable string parent,immutable string code = "") {
	import std.format;
	final switch(tree.type) {
	case Type.Bind :
		return format("auto %s = %s;",tree.data,parent);
	case Type.Record :
		return tree.children.map!(a => a.generate(parent)).join;
	case Type.Pair :
		return tree.children[0].generate(format("%s.%s",parent,tree.data));
	case Type.Root :
		return tree.children.map!(a => a.generate(parent,code)).join;
	case Type.If :
		return format("if(%s){%s}",tree.data,code);
	case Type.As :
		return tree.children.map!(a => a.generate(parent,code)).join;	
	case Type.Array :
		if (tree.children.length == 1) {
			return tree.children[0].generate(parent);
		}
		else {
			if (tree.children[0].type == Type.Bind) {
				immutable otherSide = tree.children[0].generate(parent ~ format("[%s]",tree.children[1].children[0].pos.otherSide));
				return otherSide ~ tree.children[1].generate(parent);
			}
			else {
				immutable otherSide = tree.children[1].generate(parent ~ format("[%s]",tree.children[0].children[$-1].pos.otherSide));
				return otherSide ~ tree.children[0].generate(parent);
			}
		}
	case Type.Array_Elem :
		return tree.children.map!(a => generate(a,parent ~ format("[%s]",a.pos))).join;
	case Type.Range :
	case Type.Empty :
	case Type.Variant :
		return "";
	case Type.RVal:
		assert(false);
	}
}

unittest {
	static assert ("x".parse.generate("arg") == "auto x = arg;");
	static assert ("{{x=b}=a,y=b}".parse.generate("arg") == "auto x = arg.a.b;auto y = arg.b;");
	static assert ("x if (x > 10)".parse.generate("arg","return x;") == "auto x = arg;if(x > 10){return x;}");
	static assert ("{a=b} @ c".parse.generate("arg") == "auto a = arg.b;auto c = arg;");
	static assert ("[a,b,c]~d".parse.analyze.generate("arg") == "auto d = arg[3..$];auto a = arg[0];auto b = arg[1];auto c = arg[2];if(true){}");
}
