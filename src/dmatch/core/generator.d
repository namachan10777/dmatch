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
		case Type.Range_Tails :
			assert(0);
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
	assert (linkGuard(tree,condtions) ==
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
	assert (min_array_size(immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Bind,"b",[]),
					immutable AST(Type.Bind,"c",[])]),
				immutable AST(Type.Bind,"d",[])]))
			== 3);
	assert (min_array_size(immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Bind,"b",[]),
					immutable AST(Type.Bind,"c",[])])]))
			== 3);
}

immutable(AST) shaveChildren(immutable AST ast) {
	return immutable AST(ast.type,ast.data,ast.children[1..$],ast.pos);
}

immutable(string) generate(immutable AST[] forest,immutable string parent,immutable string addtion) {
	import std.format;
	if (forest.length == 0) return addtion;
	auto head = forest[0];
	auto tails = forest[1..$];
	final switch(head.type) {
	case Type.Root :
		"head.children[0]".writeln;
		head.children[0].tree2str.writeln;
		return generate([head.children[0]],parent,generate(head.children[1..$],parent,addtion));
	case Type.If :
		return format("if(%s){%s}",head.data,addtion);
	case Type.Bind :
		if (head.range.begin.enabled) {
			return format("auto %s=%s[%s];%s",head.data,parent,head.range.toString,generate(tails,parent,addtion));
		}
		return format("auto %s=%s;%s",head.data,parent,generate(tails,parent,addtion));
	case Type.As :
		return generate(head.children,parent,generate(tails,parent,addtion));
	case Type.Range :
		auto shaved = immutable AST(Type.Range_Tails,head.data,head.children[1..$],head.pos,head.range,head.require_size);
		auto saved_name = format("__%s_saved__",parent);
		return format("if(!%s.empty){auto %s=%s;%s}",parent,saved_name,parent,
					generate([head.children[0]],saved_name~".front",
					generate([shaved],saved_name,
					generate(tails,parent,addtion))));
	case Type.Range_Tails :
		if (head.children.length == 1) return generate([head.children[0]],parent,generate(tails,parent,addtion));
		auto shaved = immutable AST(Type.Range_Tails,head.data,head.children[1..$],head.pos,head.range,head.require_size);
		return format("if(!%s.empty){%s}",parent,generate([head.children[0]],parent~".front",parent~".popFront;"~generate(shaved~tails,parent,addtion)));
	case Type.Array :
		return format("if(%s.length>=%d){%s}",parent,head.require_size,head.children.generate(parent,addtion));
	case Type.Array_Elem :
		auto s = head.children.map!(a => generate([a],format("%s[%s]",parent,a.pos.toString),"%s")).fold!((a,b) => format(a,b));
		return format(s,generate(tails,parent,addtion));
	case Type.Record :
		return head.children.generate(parent,generate(tails,parent,addtion));
	case Type.Pair :
		return head.children.generate(parent~"."~head.data,generate(tails,parent,addtion));
	case Type.Variant :
		return format("if(%s.type==typeid(%s)){%s}",parent,head.data,head.children.generate(format("%s.get!(%s)"),generate(tails,parent,addtion)));
	case Type.Empty :
	case Type.RVal :
		return "";
	}
}

unittest {
}
