module dmatch.pmatch;

import std.string;
import std.typecons;

import dmatch.core.parser;
import dmatch.core.analyzer;
import dmatch.core.generator;

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
		import std.stdio;
		auto ary = [1,2,3];
		int y1;
		int y2;
		int[] ys;
		mixin(pmatch!(ary,q{
			[x1,x2] ~ xs => y1 = x1;y2 = x2;ys = xs;
		}));
		return y1 == 1 && y2 == 2 && ys == [3] && ary == [1,2,3];
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
