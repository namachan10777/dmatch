module dmatch.core.analyzer;

import std.algorithm.iteration : map, sum;
import std.algorithm.searching : count;
import std.range : iota, zip, array, retro;

import dmatch.core.type : Type, AST, Index, Range;
import dmatch.core.parser : parse, tree2str;

static class ValidPatternException : Exception {
	this(string msg,string file = __FILE__,int line = __LINE__) {
		super(msg,file,line);
	}
}

immutable(AST) analyze(immutable AST tree,Index pos = Index.disabled) {
	final switch(tree.type) with(Type){
	case Bind :
	case RVal :
	case If :
	case Empty :
		return  tree;

	case As :
	case Range :
	case Pair :
	case Record :
	case Variant :
		return immutable AST(tree.type,tree.data,tree.children.map!(a => analyze(a)).array);
	case Root :
		if (tree.children.length == 1)
			return immutable AST(Root,"",[tree.children[0].analyze,immutable AST(Type.If,"true",[])]);
		else
			return immutable AST(Root,"",[tree.children[0].analyze,tree.children[1]]);
	case Array :
		if (tree.children.length == 0) {
			return immutable AST(Empty,"",[],tree.pos);
		}
		else{
			return tree.normalizeArrayPattern.addIndex.addSlice.addRequiredSize;
		}

	case Array_Elem :
		if (tree.children.length == 0)
			return immutable AST(Empty,"",[]);
		else
			return immutable AST(Array_Elem,"",tree.children.map!(a => analyze(a)).array);
	}
}
unittest {
	import dmatch.core.parser;
	import std.exception : assertThrown;
	assert ("{a@e = e,x::(y::xs)@h=g}".parse.analyze == "{a@e = e,x::(y::xs)@h=g}if(true)".parse);
	assert ("[a]~[b]~c".parse.analyze ==
		immutable AST(Type.Root,"",[
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[],Index(0,false)),
					immutable AST(Type.Bind,"b",[],Index(1,false))]),
				immutable AST(Type.Bind,"c",[],Range(Index(2,false),Index(0,true)))],2),
			immutable AST(Type.If,"true",[])]));
	assert ("a~[b]~[c]".parse.analyze ==
		immutable AST(Type.Root,"",[
			immutable AST(Type.Array,"",[
				immutable AST(Type.Bind,"a",[],Range(Index(0,false),Index(1,true))),
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"b",[],Index(1,true)),
					immutable AST(Type.Bind,"c",[],Index(0,true))])],2),
			immutable AST(Type.If,"true",[])]));
	assert((){assertThrown!ValidPatternException(
		"a~[b]~c".parse.analyze,
		"cannot decison range of bind pattern inarray");return true;}());
}

immutable(AST) addRequiredSize(immutable AST array_p) in{
	assert (array_p.type == Type.Array);
}
body {
	auto size = array_p.children.map!(a => a.type == Type.Array_Elem ? a.children.length : 0).sum;
	return immutable AST(Type.Array,"",array_p.children,size);
}
unittest {
	import dmatch.core.parser : parse;
	assert ("a~[b,c,d]".parse.children[0].addRequiredSize ==
		immutable AST(Type.Array,"",[
			immutable AST(Type.Bind,"a",[]),
			immutable AST(Type.Array_Elem,"",[
				immutable AST(Type.Bind,"b",[]),
				immutable AST(Type.Bind,"c",[]),
				immutable AST(Type.Bind,"d",[])])],
			3));
}

//addIndexされてると言う前提
immutable(AST) addSlice(immutable AST array_p)
in {
	assert (array_p.type == Type.Array);
	assert (array_p.children.length <= 3 && array_p.children.count!(a => a.type != Type.Array_Elem) <= 1);
}
body {
	switch (array_p.children.length) {
	case 1:
		return array_p;
	case 2:
		if (array_p.children[0].type == Type.Array_Elem) {
			immutable bind = array_p.children[1];
			auto slice = immutable AST(bind.type,bind.data,bind.children,Range(array_p.children[0].children[$-1].pos + 1,Index(0,true)));
			return immutable AST(Type.Array,array_p.data,[array_p.children[0],slice]);
		}
		else {
			immutable bind = array_p.children[0];
			auto slice = immutable AST(bind.type,bind.data,bind.children,Range(Index(0,false),array_p.children[1].children[0].pos));
			return immutable AST(Type.Array,array_p.data,[slice,array_p.children[1]]);
		}
	case 3:
			immutable bind = array_p.children[1];
			auto slice = immutable AST(bind.type,bind.data,bind.children,
										Range(array_p.children[0].children[$-1].pos + 1,array_p.children[2].children[0].pos));
			return immutable AST(Type.Array,array_p.data,[array_p.children[0],slice,array_p.children[2]]);
	default:
		assert(0);
	}
}
unittest {
	import dmatch.core.parser : parse;
	assert("[a,b]~c".parse.children[0].addIndex.addSlice == 
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
						immutable AST(Type.Bind,"a",[],Index(0,false)),
						immutable AST(Type.Bind,"b",[],Index(1,false))]),
					immutable AST(Type.Bind,"c",[],Range(Index(2,false),Index(0,true)))]));
	assert ("a~[b,c]".parse.children[0].addIndex.addSlice ==
			immutable AST(Type.Array,"",[
					immutable AST(Type.Bind,"a",[],Range(Index(0,false),Index(1,true))),
					immutable AST(Type.Array_Elem,"",[
						immutable AST(Type.Bind,"b",[],Index(1,true)),
						immutable AST(Type.Bind,"c",[],Index(0,true))])]));
	
	assert ("[a]~b~[c]".parse.children[0].addIndex.addSlice ==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[],Index(0,false)),]),
				immutable AST(Type.Bind,"b",[],Range(Index(1,false),Index(0,true))),
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"c",[],Index(0,true))])]));
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
	assert("[a,b,c]".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[],Index(0,false)),
					immutable AST(Type.Bind,"b",[],Index(1,false)),
					immutable AST(Type.Bind,"c",[],Index(2,false))])]));

	assert ("[a,b]~c".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
						immutable AST(Type.Bind,"a",[],Index(0,false)),
						immutable AST(Type.Bind,"b",[],Index(1,false))]),
					immutable AST(Type.Bind,"c",[])]));

	assert ("a~[b,c]".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
					immutable AST(Type.Bind,"a",[]),
					immutable AST(Type.Array_Elem,"",[
						immutable AST(Type.Bind,"b",[],Index(1,true)),
						immutable AST(Type.Bind,"c",[],Index(0,true))])]));
	assert ("[a]~b~[c]".parse.children[0].addIndex ==
			immutable AST(Type.Array,"",[
				immutable AST(Type.Array_Elem,"",[
					immutable AST(Type.Bind,"a",[],Index(0,false)),]),
				immutable AST(Type.Bind,"b",[]),
				immutable AST(Type.Array_Elem,"",[
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
	assert ((immutable AST(Type.Array,"",[
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

	assert ((immutable AST(Type.Array,"",[
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
