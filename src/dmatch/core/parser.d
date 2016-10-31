module dmatch.core.parser;

import std.stdio;

import std.typecons : tuple,Tuple;
import std.range;

struct Src {
	immutable string ate;
	immutable string dish;
	immutable bool succ;
	this(immutable string dish) {
		this("",dish,true);
	}
	this(immutable string ate,immutable string dish) {
		this(ate,dish,true);
	}
	this(immutable string ate,immutable string dish,immutable bool succ) {
		this.ate = ate;
		this.dish = dish;
		this.succ = succ;
	}
	@property
	Src failed() const{
		return Src(ate,dish,false);
	}
}

//成功すれば文字を消費し結果(true | false)と一緒に消費した文字を付け加えたものを返す

//any : Src -> Src
//任意の一文字を取る。
Src any(in Src src) {
	if (src.dish.empty) return Src(src.ate,src.dish,false);
	return Src(src.ate~src.dish[0],src.dish[1..$],true);
}
unittest {
	auto r = Src("Dman is", " so cute.", true).any.any.any.any;
	assert (r.ate == "Dman is so " && r.dish == "cute." && r.succ);
}

//same : Src -> char -> Src
Src same(alias charcter)(in Src src) {
	if (!src.dish.empty && src.dish.front == charcter) {
		return Src(src.ate~src.dish[0],src.dish[1..$],true);
	}
	return Src(src.ate,src.dish,false);
}
unittest {
	assert (Src("Dman is ", "so cute.").same!'a' == Src("Dman is ", "so cute.", false));
	assert (Src("Dman is ", "so cute.").same!'s' == Src("Dman is s", "o cute.", true));
}

Src str(alias token)(in Src src) {
	size_t idx;
	foreach(i,head;token) {
		if (head != src.dish[i]) return src.failed;
		idx = i;
	}
	return Src(src.ate~src.dish[0..idx+1],src.dish[idx+1..$],true);
}
unittest {
	assert (Src("Dman is ","so cute.").str!"so cute" == Src("Dman is so cute",".",true));
	assert (Src("Dman is ","so cute.").str!"so cool" == Src("Dman is ","so cute.",false));
}
//rng : char[] -> Src -> Src
//指定された文字が含まれていれば成功、無ければ失敗を返す
Src rng(alias candidate)(in Src src) {
	foreach(c ; candidate) {
		if (!src.dish.empty && c == src.dish[0]) return Src(src.ate~src.dish[0],src.dish[1..$],true);
	}
	return Src(src.ate,src.dish,false);
}
unittest {
	assert (Src("Dman is ", "so cute.").rng!(['a','b','c']) == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ", "so cute.").rng!(['o','p','s']) == Src("Dman is s","o cute.",true));
}

//or : 'f ... -> Src -> Src
Src or(ps...)(in Src src) {
	static if (ps.length == 1) {
		auto parsed = ps[0](src);
		if (parsed.succ) return parsed;
		else return src.failed;
	}
	else {
		auto parsed = ps[0](src);
		if (parsed.succ) return parsed;
		else return or!(ps[1..$])(src);
	}
}
unittest {
	assert (Src("Dman is ","so cute.").or!(same!'o',same!'p',same!'s',same!'q')
		== Src("Dman is s","o cute.",true));
	assert (Src("Dman is ","so cute.").or!(same!'a',same!'b',same!'c',same!'d')
		== Src("Dman is ","so cute.",false));
}

//not : 'f -> Src -> Src
//述語fを実行して失敗すれば成功、成功すれば失敗を返す。文字は消費しない
Src not(alias p)(in Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,!parsed.succ);
}
unittest {
	assert (Src("Dman is ","so cute.").not!(same!'s') == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ","so cute.").not!(same!'a') == Src("Dman is ","so cute.",true));
}

//and : 'f -> Src -> Src
//述語fを実行してその結果を返す。文字は消費しない
Src and(alias p)(in Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,parsed.succ);
}
unittest {
	assert (Src("Dman is ","so cute.").and!(same!'s') == Src("Dman is ","so cute.",true));
	assert (Src("Dman is ","so cute.").and!(same!'a') == Src("Dman is ","so cute.",false));
}

//many : 'f -> Src -> Src
//一回以上述語fを実行してその結果を返す
Src many(alias p)(in Src src) {
	auto parsed = p(src);
	if (parsed.succ) return rep!(p)(parsed);
	else return src.failed;
}
unittest {
	assert (Src("Dman is ","so cute.").many!(rng!"so") == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").many!(rng!"ab") == Src("Dman is ","so cute.",false));
}

//rep : 'f -> Src -> Src
//述語fを0回以上実行して常に成功を返す
Src rep(alias p)(in Src src) {
	auto parsed = p (src);
	if (parsed.succ) return rep!p(parsed);
	else return src;
}
unittest {
	assert (Src("Dman is ","so cute.").rep!(rng!"so") == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").rep!(rng!"ab") == Src("Dman is ","so cute.",true));
}

//opt : 'f -> Src -> Src
//述語fを一回実行して常に成功を返す
Src opt(alias p)(in Src src) {
	auto parsed = p (src);
	return Src(parsed.ate, parsed.dish, true);
}
unittest {
	assert (Src("Dman is ","so cute.").opt!(same!'s') == Src("Dman is s","o cute.",true));
	assert (Src("Dman is ","so cute.").opt!(same!'a') == Src("Dman is ","so cute.",true));
}

//seq : 'f... -> Src -> Src
//述語f...を左から順に実行して結果を返す。バックトラックする。
Src seq(ps...)(in Src src) {
	Src seq_impl(ps...)(in Src init,in Src src) {
		static if (ps.length == 0) {
			return src;
		}
		else {
			auto parsed = ps[0](src);
			if (parsed.succ) return seq_impl!(ps[1..$])(init,parsed);
			else return init.failed;
		}
	}
	return seq_impl!ps(src,src);
}
unittest {
	assert (Src("Dman is ","so cute.").seq!(same!'s',same!'o') == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").seq!(same!'s',same!'O') == Src("Dman is ","so cute.",false));
}
