module dmatch.core.parser;

import std.stdio;

import std.typecons : tuple,Tuple;
import std.range;
import std.ascii;

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

//基本的な規則
//特殊文字
enum sp = "!\"#$%&'()-=~^|\\{[]}@`*:+;?/.><,";
alias emp = or!(rng!"\r\t\n ");
//symbol <- (!(sp / [0-9]) .) (!sp .)
alias symbol = seq!(seq!(not!(or!(rng!sp,rng!digits)),any),rep!(seq!(not!(rng!sp),any)));
unittest {
	assert (Src("i").symbol == Src("i","",true));
	assert (Src("_Abc_100_!").symbol == Src("_Abc_100_","!",true));
	assert (Src("0_a").symbol == Src("","0_a",false));
}

//literal

/+floating <- [0-9]* '.' [0-9]+ ('e' ('+' / '-')? [0-9])? 'f'?
			/ [0-9]+ '.' [0-9]*
+/
alias floating = or!(
		seq!(rep!(rng!digits),same!'.',many!(rng!digits),
			opt!(seq!(same!'e',opt!(or!(same!'+',same!'-')),rng!digits)),opt!(same!'f')),
		seq!(many!(rng!digits),same!'.',rep!(rng!digits))
	);
unittest {
	assert (Src("3.14f").floating == Src("3.14f","",true));
	assert (Src("1.").floating == Src("1.","",true));
	assert (Src(".1").floating == Src(".1","",true));
}
//integral <- "0x" [0-9]+ / [1-9] / [0-9]+ ("LU" / 'L' / 'U')?
alias integral = seq!(or!(seq!(str!"0x",many!(rng!digits)),many!(rng!digits)),opt!(or!(str!"LU",same!'L',same!'U')));
unittest {
	assert (Src("0x12LU").integral == Src("0x12LU","",true));
}
alias num = or!(floating,integral);

//strLit <- '"' ("\""? !('"' .))* '"'
alias strLit = seq!(same!'\"',rep!(seq!(opt!(same!'a'),not!(same!'\"'),any)),same!'\"');
unittest {
	assert (Src("\"abc\\\"").strLit == Src("\"abc\\\"","",true));
}
//charLit <- ''' '\'? . '''
alias charLit = seq!(same!'\'',opt!(same!'\\'),any,same!'\'');
unittest {
	assert (Src(q{'\r'}).charLit == Src(q{'\r'},"",true));
}

Src quote(in Src src) {
	if (src.dish[0..2] == "q{") {
		auto bracketCnt = 1LU;
		foreach(i,head;src.dish[2..$]) {
			if 		(head == '{') ++bracketCnt;
			else if (head == '}') --bracketCnt;
			if (bracketCnt == 0) return Src(src.ate~src.dish[0..i+3],src.dish[i+3..$],true);
		}
	}
	return src.failed;
}
unittest {
	assert (Src("q{abc}").quote == Src("q{abc}","",true));
}

alias literal = or!(num,charLit,strLit);

Src rtest(in Src src) {
	return seq!(or!(same!'a',seq!(same!'(',rtest,same!')')))(src);
}

/+
template_ <- symbol emp* ('!' emp* (symbol / literal / template_)) /
		('(' emp* (symbol / literal / template_) emp* (',' emp* symbol / literal / template_ emp* )* ')')
+/
Src template_ (in Src src) {
	return seq!(symbol,rep!emp,same!'!',rep!emp,or!(
			or!(symbol,literal),
			seq!(same!'(',rep!emp,or!(template_,symbol,literal),rep!(seq!(same!',',rep!emp,or!(template_,symbol,literal),rep!emp)),same!')')))(src);
}
unittest {
	assert (Src("Tuple!(Hoge!T,int)").template_ == Src("Tuple!(Hoge!T,int)","",true));
}

/+
func <- (template_ / symbol) emp* '(' emp* (literal / symbol) (emp* ',' emp* (literal / symbol))* emp* ')'
+/
Src func(in Src src) {
	return seq!(or!(template_,symbol),rep!emp,
		same!'(',opt!(seq!(rep!emp,or!(literal,func,template_,symbol),rep!(seq!(rep!emp,same!',',rep!emp,or!(literal,func,template_,symbol))),rep!emp)),same!')')(src);
}
unittest {
	assert(Src("foo (hoge!x, 0x12 ,hoge( foo))").func == Src("foo (hoge!x, 0x12 ,hoge( foo))","",true));
}
