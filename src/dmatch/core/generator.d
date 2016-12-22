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
			return typeof(return)(immutable AST(tree.type,tree.data,children,tree.pos,tree.range,tree.require_size),condtions);
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
			return typeof(return)(immutable AST(Bind,"__tmp__"~name_1~name_2,[],tree.pos),[format("%s == %s",name_1~name_2,tree.data)]);
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

immutable(string) generate(immutable AST tree,immutable string parent,immutable string addtion) {
	final switch(tree.type) with (Type) {
	case Root:
		return generate(tree.children[0],parent,
			format("if(%s){%s}",tree.children[1].data,addtion)); //add guard to tail.
	case Bind :
		return format("auto %s=%s;%s",tree.data,parent,addtion);
	case Empty :
		return format("if(%s.empty){%s}",parent,addtion);
	case As :
		return tree.children.fold_generator!((t,a) => generate(t,parent,a))(addtion);
	case Range :
		auto saved_name = format("__%s_saved__",parent);
		return
			format("auto %s=%s.save;",saved_name,parent) ~
			tree.children[0..$-1].fold_generator!(
				(t,a) => format("if(!%s.empty){%s%s.popFront;%s}",saved_name,generate(t,saved_name~".front",""),saved_name,a)
			)(
				generate(tree.children[$-1],saved_name,addtion)
			);
	case Array :
		return format("if(%s.length>=%d){%s}",parent,tree.require_size,tree.children.fold_generator!(
			(t,a) =>	t.range.enabled   ? generate(t,format("%s[%s]",parent,t.range.toString),a) :
						t.pos.enabled ? generate(t,format("%s[%s]",parent,t.pos.toString),  a) :
						                  generate(t,                                parent,  a)
		)(addtion));
	case Array_Elem :
		return tree.children.fold_generator!(
			(t,a) => generate(t,format("%s[%s]",parent,t.pos.toString),a)
		)(addtion);
	case Record :
		return tree.children.fold_generator!(
			(t,a) => generate(t,parent,a)
		)(addtion);
	case Pair :
		return generate(tree.children[0],format("%s.%s",parent,tree.data),addtion);
	case Variant :
		auto getter = format("%s.get!(%s)",parent,tree.data);
		return format("if(%s.type==typeid(%s)){%s}",parent,tree.data,generate(tree.children[0],getter,addtion));
	case If :
	case RVal :
		assert (0);//elimitated pattern.
	}
}
unittest {
	assert("[a,b]~c".parse.analyze.generate("arg","exec();")
		== "if(arg.length>=2){auto a=arg[0];auto b=arg[1];auto c=arg[2..$-0];if(true){exec();}}");
	assert("a:int".parse.analyze.generate("arg","exec();")
		== "if(arg.type==typeid(int)){auto a=arg.get!(int);if(true){exec();}}");
	assert("a::b::c".parse.analyze.generate("arg","exec();")
		== "auto __arg_saved__=arg.save;if(!__arg_saved__.empty){auto a=__arg_saved__.front;__arg_saved__.popFront;if(!__arg_saved__.empty){auto b=__arg_saved__.front;__arg_saved__.popFront;auto c=__arg_saved__;if(true){exec();}}}");
	assert("{a=alpha,b=beta}".parse.analyze.generate("arg","exec();")
		== "auto a=arg.alpha;auto b=arg.beta;if(true){exec();}");
	assert("a::[]".parse.analyze.generate("arg","exec();") ==
		"auto __arg_saved__=arg.save;if(!__arg_saved__.empty){auto a=__arg_saved__.front;__arg_saved__.popFront;if(__arg_saved__.empty){if(true){exec();}}}");
}


immutable(string) fold_generator(alias f)(immutable AST[] forest,immutable string addtion) {
	if (forest.length == 0) return addtion;
	return f(forest[0],fold_generator!f(forest[1..$],addtion));
}
unittest {
	assert (
		[immutable AST(Type.Bind,"a",[]),immutable AST(Type.Bind,"b",[]),immutable AST(Type.Bind,"c",[])]
		.fold_generator!((t,a) => format("if(%s){%s}",t.data,a))("x")
		== "if(a){if(b){if(c){x}}}");
}
