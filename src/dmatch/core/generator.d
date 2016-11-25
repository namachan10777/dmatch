module dmatch.core.generator;

import std.stdio;
import std.algorithm.iteration;
import std.range;
import std.random;
import std.conv;
import std.format;
import std.typecons;

import dmatch.core.parser;
import dmatch.core.analyzer;

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

unittest{
	
}
