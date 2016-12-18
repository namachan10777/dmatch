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
	final switch(tree.type) with(Type) {
		case Root:
		case If:
		case As:
		case Bind:
		case Array:
		case Array_Elem :
		case Record :
		case Pair:
		case Empty:
		case Variant:
		case Range:
			auto result = tree.children.map!(a => nameAssign(a));
			immutable string[] base;
			immutable condtions = result.map!(a => a[1]).fold!"a~b"(base);
			immutable children = result.map!(a => a[0]).array;
			return typeof(return)(immutable AST(tree.type,tree.data,children,tree.pos),condtions);
		case RVal:
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
			return typeof(return)(immutable AST(Bind,name_1~name_2,[],tree.pos),[format("%s == %s",name_1~name_2,tree.data)]);
		case Range_Tails :
			assert(0);
	}
}

//analyzeを通ってるはず
immutable(AST) linkGuard(immutable AST tree,immutable string[] condtions)
in{
	assert (tree.type == Type.Root);
}
body{
	immutable guard = condtions.length > 0 ?
					immutable AST(Type.If,tree.children[1].data ~ "&&" ~ condtions.join("&&"),[]) :
					immutable AST(Type.If,tree.children[1].data                              ,[]);
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

immutable(AST) rmRVal(immutable AST ast) {
	auto r = ast.nameAssign;
	return linkGuard(r[0],r[1]);
}

immutable(AST) shaveChildren(immutable AST ast) {
	return immutable AST(ast.type,ast.data,ast.children[1..$],ast.pos);
}

immutable(string) generate(immutable AST[] forest,immutable string parent,immutable string addtion) {
	import std.format;
	if (forest.length == 0) return addtion;
	auto head = forest[0];
	auto tails = forest[1..$];
	final switch(head.type) with (Type){
	case Root :
		return generate([head.children[0]],parent,generate(head.children[1..$],parent,addtion));
	case If :
		return format("if(%s){%s}",head.data,addtion);
	case Bind :
		if (head.range.begin.enabled) {
			return format("auto %s=%s[%s];%s",head.data,parent,head.range.toString,generate(tails,parent,addtion));
		}
		return format("auto %s=%s;%s",head.data,parent,generate(tails,parent,addtion));
	case As :
		return generate(head.children,parent,generate(tails,parent,addtion));
	case Range :
		auto shaved = immutable AST(Range_Tails,head.data,head.children[1..$],head.pos,head.range,head.require_size);
		auto saved_name = format("__%s_saved__",parent);
		return format("if(!%s.empty){auto %s=%s.save;%s}",parent,saved_name,parent,
					generate([head.children[0]],saved_name~".front",
					saved_name~".popFront;"~
					generate([shaved],saved_name,
					generate(tails,parent,addtion))));
	case Range_Tails :
		if (head.children.length == 1) return generate([head.children[0]],parent,generate(tails,parent,addtion));
		auto shaved = immutable AST(Range_Tails,head.data,head.children[1..$],head.pos,head.range,head.require_size);
		return format("if(!%s.empty){%s}",parent,generate([head.children[0]],parent~".front",parent~".popFront;"~generate(shaved~tails,parent,addtion)));
	case Array :
		return format("if(%s.length>=%d){%s}",parent,head.require_size,head.children.generate(parent,addtion));
	case Array_Elem :
		auto s = head
					.children
					.map!(a => generate([a],format("%s[%s]",parent,a.pos.toString),"%s"))
					.fold!((a,b) => format(a,b))("%s");
		return format(s,generate(tails,parent,addtion));
	case Record :
		return head.children.generate(parent,generate(tails,parent,addtion));
	case Pair :
		return head.children.generate(parent~"."~head.data,generate(tails,parent,addtion));
	case Variant :
		return format("if(%s.type==typeid(%s)){%s}",parent,head.data,head.children.generate(format("%s.get!(%s)"),generate(tails,parent,addtion)));
	case Empty :
	case RVal :
		return "";
	}
}

unittest {
}
