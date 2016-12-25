module dmatch.pmatch;

import std.string : split, join;
import std.format : format;
import std.typecons : Tuple;

import dmatch.core.parser : parse;
import dmatch.core.analyzer : analyze;
import dmatch.core.generator : generate, rmRVal;

alias Tp = Tuple;
alias Expr = Tp!(string,"pattern",string,"code");

template pmatch(alias sym,string src) {
	enum pmatch = generateCode(src,sym.stringof,false);
}
unittest{
	assert ((){
		auto ary = [1,2,3];
		int y1;
		int y2;
		int[] ys;
		mixin(pmatch!(ary,q{
			x1::x2::xs => y1 = x1;y2 = x2;ys = xs;
		}));
		return y1 == 1 && y2 == 2 && ys == [3] && ary == [1,2,3];
	}());

	assert ((){
		auto ary = [1,2];
		int y1,y2;
		mixin(pmatch!(ary,q{
			x1::x2::[] => y1 = x1;y2 = x2;
		}));
		return y1 == 1 && y2 == 2;
	}());
	
	assert ((){
		auto ary = [1,2,3];
		int y1;
		int y2;
		int[] ys;
		mixin(pmatch!(ary,q{
			[x1,x2] ~ xs => y1 = x1;y2 = x2;ys = xs;
		}));
		return y1 == 1 && y2 == 2 && ys == [3] && ary == [1,2,3];
	}());

	assert ((){
		import std.variant : Variant;
		Variant v;
		v = 123;
		int x;
		mixin(pmatch!(v,q{
			i:int => x = i;
		}));
		return x == 123;
	}());

	assert ((){
		struct St {
			int xi;
			real xr;
		}
		St st = { 123, 3.14 };
		int yi;
		real yr;
		mixin(pmatch!(st,q{
			{i = xi,r = xr} => yi = i;yr = r;
		}));
		return yi == 123 && yr == 3.14;
	}());

	assert ((){
		import std.typecons : Tuple;
		Tuple!(int,real) tp;
		tp[0] = 123;
		tp[1] = 3.14;
		int yi;
		real yr;
		mixin(pmatch!(tp,q{
			[i,r] => yi = i;yr = r;
		}));
		return yi == 123 && yr == 3.14;
	}());

	assert ((){
		size_t match_num = 332;
		int n = 20;
		mixin(pmatch!(n,q{
			10 => match_num = 1;
			20 => match_num = 2;
			30 => match_num = 3;
		}));
		return match_num == 2;
	}());
}

string generateCode(string src,string arg,bool enableStaticBranch = true) {
	import std.algorithm.iteration;
	
	Expr[] exprs;
	string next_pattern;
	foreach(s;src.split("=>")) {
		if (next_pattern == "") {
			next_pattern = s;
			continue;
		}
		auto splited = s.split(';');
		exprs ~= Expr(next_pattern,splited[0..$-1].join(";") ~ ";");
		next_pattern = splited[$-1];
	}
	string code;
	foreach(expr;exprs) {
		import std.stdio;
		auto ast =
			expr.pattern
			.parse
			.analyze
			.rmRVal;
		auto pattern = format("{bool succes;%s%s}",ast.generate(arg,"succes=true;"~expr.code),"if(succes){goto __pmatch__end__;}");
		if (enableStaticBranch) {
			auto pattern_test = ast.generate(arg,"") ~ "\n";
			code ~= format("static if(__traits(compiles,(){%s})){%s}\n",pattern_test,pattern);
		}
		else {
			code ~= pattern ~ '\n';
		}
	}
	return "{import std.range:empty,save,front,popFront;" ~ code ~ "__pmatch__end__:}";
}
unittest {
}
