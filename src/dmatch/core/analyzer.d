module dmatch.core.analyzer;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.mutation;
import std.range;
import std.format;
import std.stdio;
import std.conv;

import dmatch.core.parser : AST,Type,tree2str,Index;

static class ValidPatternException : Exception {
	this(string msg,string file = __FILE__,int line = __LINE__) {
		super(msg,file,line);
	}
}

immutable(AST) analyze(immutable AST tree,Index pos = Index.disabled,string tag = "") {
	final switch(tree.type) {
	case Type.Bind :
		assert (tree.children.length == 0);
		return tree;

	case Type.RVal :
		assert (tree.children.length == 0);
		return tree;

	case Type.If :
		return tree;

	case Type.Empty :
		return  tree;

	case Type.As :
		return immutable AST(Type.As,tree.data,tree.children.map!(a => analyze(a)).array);

	case Type.Pair :
		assert (tree.children.length == 1);
		return immutable AST(Type.Pair,tree.data,tree.children.map!(a => analyze(a)).array);

	case Type.Record :
		assert (tree.children.all!(a => a.type == Type.Pair));
		return immutable AST(Type.Record,tree.data,tree.children.map!(a => analyze(a)).array,pos,tag);

	case Type.Array :
		assert (tree.children.length > 1);
		return tree.normalizeArrayPattern.addIndex;

	case Type.Array_Elem :
		if (tree.children.length == 0)
			return immutable AST(Type.Empty,"",[]);
		else
			return immutable AST(Type.Array_Elem,"",tree.children.map!(a => analyze(a)).array);

	case Type.Range :
		return immutable AST(Type.Range,tree.data,tree.children.map!(a => analyze(a)).array);

	case Type.Root :
		return immutable AST(Type.Root,"",tree.children.map!(a => analyze(a)).array);
	case Type.Variant :
		assert (tree.children.length > 0);
		return immutable AST(Type.Variant,tree.data,tree.children.map!(a => analyze(a)).array);
	}
}
unittest {
	import dmatch.core.parser;
	import std.exception : assertThrown;
	static assert ("{a@e = e,x::(y::xs)@h=g}".parse.analyze == "{a@e = e,x::(y::xs)@h=g}".parse);
	static assert ("[a]~[b]~c".parse.analyze ==
		immutable AST(Type.Root,"",[
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[],Index(0,false),""),
					immutable AST(Type.Bind,"b",[],Index(1,false),"")]),
				immutable AST(Type.Bind,"c",[])])]));
	static assert ("a~[b]~[c]".parse.analyze ==
		immutable AST(Type.Root,"",[
			immutable AST(Type.Array,"",[
				immutable AST(Type.Bind,"a",[]),
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"b",[],Index(1,true),""),
					immutable AST(Type.Bind,"c",[],Index(0,true),"")])])]));
	static assert((){assertThrown!ValidPatternException(
		"a~[b]~c".parse.analyze,
		"cannot decison range of bind pattern inarray");return true;}());
}

immutable(AST) addIndex(immutable AST array_p)
in {
	assert (array_p.type == Type.Array);
	assert (array_p.children.length <= 3 && array_p.children.count!(a => a.type != Type.Array_Elem) <= 1);
}
body {
	immutable(AST)[] impl(immutable AST[] forest) {
		//一番前のものにインデックスを付けていく
		if (forest.length >= 1 && forest[0].type == Type.Array_Elem) {
			immutable index = forest[0].children.length.iota.array;
			immutable indexed = zip(index,forest[0].children)
								.map!(a => immutable AST(a[1].type,a[1].data,a[1].children,Index(a[0],false)))
								.array;
			return immutable AST(Type.Array_Elem,"",indexed) ~ impl(forest[1..$]);
		}
		//一番後ろのものにインデックスを付けていく
		else if (forest.length >= 1 && forest[$-1].type == Type.Array_Elem) {
			immutable index = forest[$-1].children.length.iota.retro.array;
			immutable indexed = zip(index,forest[$-1].children)
								.map!(a => immutable AST(a[1].type,a[1].data,a[1].children,Index(a[0],true)))
								.array;
			return impl(forest[0..$-1]) ~ immutable AST(Type.Array_Elem,"",indexed);
		}
		//両端がArray_Elemでない、又は残りが無い = インデックスを付けられないなら終了
		else {
			return forest;
		}
	}
	return immutable AST(Type.Array,"",impl(array_p.children));
}
unittest {
	import dmatch.core.parser : parse;
	static assert("[a,b,c]".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[],Index(0,false)),
					immutable AST(Type.Bind,"b",[],Index(1,false)),
					immutable AST(Type.Bind,"c",[],Index(2,false))])]));

	static assert ("[a,b]~c".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
						immutable AST(Type.Bind,"a",[],Index(0,false)),
						immutable AST(Type.Bind,"b",[],Index(1,false))]),
					immutable AST(Type.Bind,"c",[])]));

	static assert ("a~[b,c]".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Array_Elem,"",[
						immutable AST(Type.Bind,"b",[],Index(1,true)),
						immutable AST(Type.Bind,"c",[],Index(0,true))])]));
}

immutable(AST) normalizeArrayPattern(immutable AST array_p)
in{
	assert (array_p.type == Type.Array);
}
body{
	if (array_p.children.count!(a => a.type != Type.Array_Elem) > 1)
		throw new ValidPatternException("cannot decison range of bind pattern inarray");
	immutable(AST[]) merge(immutable AST[] forest) {
		if (forest.length <= 1) return forest;
		//Array_Elemが連続で並んでいればそれを畳み込む
		else if (forest[0].type == Type.Array_Elem && forest[1].type == Type.Array_Elem) {
			return merge(immutable AST(Type.Array_Elem,"",forest[0].children~forest[1].children) ~ forest[2..$]);
		}
		//Array_Elemが一つだけ、又はArray_Elem以外ならスキップ
		else {
			return [forest[0]]~merge(forest[1..$]);
		}
	}
	return immutable AST(Type.Array,"",merge(array_p.children));
}
unittest {
	static assert ((immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Bind,"b",[])]),
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"c",[]),
					immutable AST(Type.Bind,"d",[])]),
				immutable AST(Type.Bind,"d",[])]))
			.normalizeArrayPattern
			==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Bind,"b",[]),
					immutable AST(Type.Bind,"c",[]),
					immutable AST(Type.Bind,"d",[])]),
				immutable AST(Type.Bind,"d",[])]));

	static assert ((immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[])]),
				immutable AST(Type.Bind,"b",[])]))
			.normalizeArrayPattern
			==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[])]),
				immutable AST(Type.Bind,"b",[])]));
}
