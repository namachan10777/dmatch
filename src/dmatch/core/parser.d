module dmatch.core.parser;

import std.stdio;

import std.typecons : tuple,Tuple;
import std.range;

struct Arg {
	immutable string shit;
	immutable string dish;
	immutable bool succ;
	this(immutable string shit,immutable string dish,immutable bool succ) {
		this.shit = shit;
		this.dish = dish;
		this.succ = succ;
	}
	@property
	Arg failed() const{
		return Arg(shit,dish,false);
	}
}

//成功すれば文字を消費し結果(true | false)と一緒に消費した文字を付け加えたものを返す

//any : Arg -> Arg
//任意の一文字を取る。
Arg any(in Arg arg) {
	if (arg.dish.empty) return Arg(arg.shit,arg.dish,false);
	return Arg(arg.shit~arg.dish[0],arg.dish[1..$],true);
}
unittest {
	auto r = Arg("Dman is", " so cute.", true).any.any.any.any;
	assert (r.shit == "Dman is so " && r.dish == "cute." && r.succ);
}

//same : Arg -> char -> Arg
Arg same(alias charcter)(in Arg arg) {
	if (!arg.dish.empty && arg.dish.front == charcter) {
		return Arg(arg.shit~arg.dish[0],arg.dish[1..$],true);
	}
	return Arg(arg.shit,arg.dish,false);
}
unittest {
	auto parsed1 = Arg("Dman is ", "so cute.", true).same!'a';
	assert (parsed1 == Arg("Dman is ", "so cute.", false));
	auto parsed2 = Arg("Dman is ", "so cute.", true).same!'s';
	assert (parsed2 == Arg("Dman is s", "o cute.", true));
}

//rng : char[] -> Arg -> Arg
//指定された文字が含まれていれば成功、無ければ失敗を返す
Arg rng(alias candidate)(in Arg arg) {
	foreach(c ; candidate) {
		if (c == arg.dish[0]) return Arg(arg.shit~arg.dish[0],arg.dish[1..$],true);
	}
	return Arg(arg.shit,arg.dish,false);
}
unittest {
	auto parsed1 = Arg("Dman is ", "so cute.", true).rng!(['a','b','c']);
	assert (parsed1.shit == "Dman is " && parsed1.dish == "so cute." && !parsed1.succ);
	auto parsed2 = Arg("Dman is ", "so cute.", true).rng!(['o','p','s']);
	assert (parsed2.shit == "Dman is s" && parsed2.dish == "o cute." && parsed2.succ);
}

//or : 'f ... -> Arg -> Arg
Arg or(ps...)(in Arg arg) {
	static if (ps.length == 1) {
		auto parsed = ps[0](arg);
		if (parsed.succ) return parsed;
		else return arg.failed;
	}
	else {
		auto parsed = ps[0](arg);
		if (parsed.succ) return parsed;
		else return or!(ps[1..$])(arg);
	}
}
unittest {
	assert (Arg("Dman is ","so cute.",true).or!(same!'o',same!'p',same!'s',same!'q')
		== Arg("Dman is s","o cute.",true));
	assert (Arg("Dman is ","so cute.",true).or!(same!'a',same!'b',same!'c',same!'d')
		== Arg("Dman is ","so cute.",false));
}

//not : 'f -> Arg -> Arg
//述語fを実行して失敗すれば成功、成功すれば失敗を返す。文字は消費しない
Arg not(alias p)(in Arg arg) {
	auto parsed = p (arg);
	return Arg(arg.shit,arg.dish,!parsed.succ);
}
unittest {
	auto parsed1 = Arg("Dman is ","so cute.",true).not!(same!'s');
	assert (parsed1 == Arg("Dman is ","so cute.",false));
	auto parsed2 = Arg("Dman is ","so cute.",true).not!(same!'a');
	assert (parsed2 == Arg("Dman is ","so cute.",true));
}

//and : 'f -> Arg -> Arg
//述語fを実行してその結果を返す。文字は消費しない
Arg and(alias p)(in Arg arg) {
	auto parsed = p (arg);
	return Arg(arg.shit,arg.dish,parsed.succ);
}
unittest {
	auto parsed1 = Arg("Dman is ","so cute.",true).and!(same!'s');
	assert (parsed1 == Arg("Dman is ","so cute.",true));
	auto parsed2 = Arg("Dman is ","so cute.",true).and!(same!'a');
	assert (parsed2 == Arg("Dman is ","so cute.",false));
}

//many : 'f -> Arg -> Arg
//一回以上述語fを実行してその結果を返す
Arg many(alias p)(in Arg arg) {
}

//rep : 'f -> Arg -> Arg
//述語fを0回以上実行して常に成功を返す
Arg rep(alias p)(in Arg arg) {
	auto parsed = p (arg);
	if (parsed.succ) rep!p(parsed);
	else arg;
}

//opt : 'f -> Arg -> Arg
//述語fを一回実行して常に成功を返す
Arg opt(alias p)(in Arg arg) {
	auto parsed = p (arg);
	return Arg(parsed.shit, parsed.dish, true);
}
unittest {
	assert (Arg("Dman is ","so cute.",true).opt!(same!'s') == Arg("Dman is s","o cute.",true));
	assert (Arg("Dman is ","so cute.",true).opt!(same!'a') == Arg("Dman is ","so cute.",true));
}

//seq : 'f... -> Arg -> Arg
//述語f...を左から順に実行して結果を返す。バックトラックする。
Arg seq(ps...)(in Arg arg) {
	Arg seq_impl(ps...)(in Arg init,in Arg arg) {
		static if (ps.length == 0) {
			return arg;
		}
		else {
			auto parsed = ps[0](arg);
			if (parsed.succ) return seq_impl!(ps[1..$])(init,parsed);
			else return init.failed;
		}
	}
	return seq_impl!ps(arg,arg);
}
unittest {
	assert (Arg("Dman is ","so cute.",true).seq!(same!'s',same!'o') == Arg("Dman is so"," cute.",true));
	assert (Arg("Dman is ","so cute.",true).seq!(same!'s',same!'O') == Arg("Dman is ","so cute.",false));
}
