module dmatch.pmatch;

import std.string;
import std.typecons;

import dmatch.core.parser;
import dmatch.core.analyzer;
import dmatch.core.generator;

alias Tp = Tuple;
alias Expr = Tp!(string,"pattern",string,"code");

template pmatch(alias sym,string src) {
	enum pmatch = generateCode(src,sym.stringof);
}
unittest{
	auto ary = [1,2,3];
	int y1;
	int y2;
	int[] ys;
	mixin(pmatch!(ary,q{
		x1::x2::xs => y1 = x1;y2 = x2;ys = xs;
	}));
	assert (y1 == 1 && y2 == 2 && ys == [3]);
}

string generateCode(string src,string arg) {
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
	string pattern,pattern_test;
	foreach(expr;exprs) {
		auto ast =
			expr.pattern
			.parse
			.analyze
			.rmRVal;
		pattern_test = ast.generate(arg,"") ~ "\n";
		pattern      = ast.generate(arg,expr.code) ~ "\n";
	}
	return "import std.range:save,front,popFront;"~format("static if(__traits(compiles,(){%s})){%s}",pattern_test,pattern);
}
unittest {
}
