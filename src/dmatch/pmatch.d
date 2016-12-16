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
	int x;
	pragma(msg,pmatch!(x,"a => write(a);"));
}

string generateCode(string src,string arg) {
	import std.algorithm.iteration;
//:	import std.range;
	
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
	string r;
	foreach(expr;exprs) {
		r ~= [expr.pattern
			.parse
			.analyze
			.rmRVal]
			.generate(arg,expr.code) ~ "\n";
	}
	return r;
}
unittest {
}
