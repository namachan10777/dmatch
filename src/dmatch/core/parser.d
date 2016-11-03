module dmatch.core.parser;

import std.stdio;

import std.range;
import std.ascii;
import std.range;
import std.traits;

import dmatch.tvariant;

enum NodeType {
	Root,
	Bind
}

struct Src {
	immutable string ate;
	immutable string dish;
	immutable bool succ;
	immutable AST tree;
	this(immutable string dish) {
		this("",dish,true,null);
	}
	this(immutable string dish,immutable AST ast) {
		this("",dish,true,ast);
	}
	this(immutable string ate,immutable string dish) {
		this(ate,dish,true,null);
	}
	this(immutable string ate,immutable string dish,immutable bool succ) {
		this(ate,dish,succ,null);
	}
	this(immutable string ate,immutable string dish,immutable bool succ,immutable AST ast) {
		this.ate = ate;
		this.dish = dish;
		this.succ = succ;
		this.tree = ast;
	}
	@property
	immutable(Src) failed() immutable{
		return Src(ate,dish,false,tree);
	}
}

class AST {
public:
	immutable NodeType type;
	immutable string data;
	immutable AST[] children;
	immutable AST parent;
	this (immutable NodeType type,immutable string data) {
		this(type,data,null,null);
	}
	this (immutable NodeType type,immutable string data,immutable AST parent,immutable AST[] children) {
		this.type = type;
		this.data = data;
		this.parent = parent;
		this.children = children;
	}
	immutable(AST) childrenAdded(immutable AST[] children) immutable{
		return cast(immutable)new AST(type,data,parent,this.children ~ children);
	}
	immutable(AST) dataChanged(immutable string data) immutable{
		return cast(immutable)new AST(type,data,parent,children);
	}
	@property
	immutable(AST) root() immutable{
		if (parent is null)
			return this;
		else
			return parent.root;
	}
}


//成功すれば文字を消費し結果(true | false)と一緒に消費した文字を付け加えたものを返す

//any : Src -> Src
//任意の一文字を取る。
immutable(Src) any(immutable Src src) {
	if (src.dish.empty)
		return Src(src.ate,src.dish,false,src.tree);
	return Src(src.ate~src.dish[0],src.dish[1..$],true,src.tree);
}
unittest {
	auto r = Src("Dman is", " so cute.", true).any.any.any.any;
	assert (r.ate == "Dman is so " && r.dish == "cute." && r.succ);
}

//same : Src -> char -> Src
immutable(Src) same(alias charcter)(immutable Src src) {
	if (!src.dish.empty && src.dish[0] == charcter) {
		return Src(src.ate~src.dish[0],src.dish[1..$],true,src.tree);
	}
	return Src(src.ate,src.dish,false,src.tree);
}
unittest {
	assert (Src("Dman is ", "so cute.").same!'a' == Src("Dman is ", "so cute.", false));
	assert (Src("Dman is ", "so cute.").same!'s' == Src("Dman is s", "o cute.", true));
}

immutable(Src) str(alias token)(immutable Src src) {
	size_t idx;
	foreach(i,head;token) {
		if (head != src.dish[i]) return src.failed;
		idx = i;
	}
	return Src(src.ate~src.dish[0..idx+1],src.dish[idx+1..$],true,src.tree);
}
unittest {
	assert (Src("Dman is ","so cute.").str!"so cute" == Src("Dman is so cute",".",true));
	assert (Src("Dman is ","so cute.").str!"so cool" == Src("Dman is ","so cute.",false));
}

//rng : char[] -> Src -> Src
//指定された文字が含まれていれば成功、無ければ失敗を返す
immutable(Src) rng(alias candidate)(immutable Src src) {
	foreach(c ; candidate) {
		if (!src.dish.empty && c == src.dish[0])
			return Src(src.ate~src.dish[0],src.dish[1..$],true,src.tree);
	}
	return Src(src.ate,src.dish,false,src.tree);
}
unittest {
	assert (Src("Dman is ", "so cute.").rng!(['a','b','c']) == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ", "so cute.").rng!(['o','p','s']) == Src("Dman is s","o cute.",true));
}

//or : 'f ... -> Src -> Src
immutable(Src) or(ps...)(immutable Src src) {
	static if (ps.length == 1) {
		immutable parsed = ps[0](src);
		if (parsed.succ) return parsed;
		else return src.failed;
	}
	else {
		immutable parsed = ps[0](src);
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
immutable(Src) not(alias p)(immutable Src src) {
	immutable parsed = p (src);
	return Src(src.ate,src.dish,!parsed.succ);
}
unittest {
	assert (Src("Dman is ","so cute.").not!(same!'s') == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ","so cute.").not!(same!'a') == Src("Dman is ","so cute.",true));
}

//and : 'f -> Src -> Src
//述語fを実行してその結果を返す。文字は消費しない
immutable(Src) and(alias p)(immutable Src src) {
	immutable parsed = p (src);
	return Src(src.ate,src.dish,parsed.succ);
}
unittest {
	assert (Src("Dman is ","so cute.").and!(same!'s') == Src("Dman is ","so cute.",true));
	assert (Src("Dman is ","so cute.").and!(same!'a') == Src("Dman is ","so cute.",false));
}

//many : 'f -> Src -> Src
//一回以上述語fを実行してその結果を返す
immutable(Src) many(alias p)(immutable Src src) {
	immutable parsed = p(src);
	if (parsed.succ) return rep!(p)(parsed);
	else return src.failed;
}
unittest {
	assert (Src("Dman is ","so cute.").many!(rng!"so") == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").many!(rng!"ab") == Src("Dman is ","so cute.",false));
}

//rep : 'f -> Src -> Src
//述語fを0回以上実行して常に成功を返す
immutable(Src) rep(alias p)(immutable Src src) {
	immutable parsed = p (src);
	if (parsed.succ) return rep!p(parsed);
	else return src;
}
unittest {
	assert (Src("Dman is ","so cute.").rep!(rng!"so") == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").rep!(rng!"ab") == Src("Dman is ","so cute.",true));
}

//opt : 'f -> Src -> Src
//述語fを一回実行して常に成功を返す
immutable(Src) opt(alias p)(immutable(Src) src) {
	immutable parsed = p (src);
	return Src(parsed.ate, parsed.dish, true);
}
unittest {
	assert (Src("Dman is ","so cute.").opt!(same!'s') == Src("Dman is s","o cute.",true));
	assert (Src("Dman is ","so cute.").opt!(same!'a') == Src("Dman is ","so cute.",true));
}

//seq : 'f... -> Src -> Src
//述語f...を左から順に実行して結果を返す。バックトラックする。
immutable(Src) seq(ps...)(immutable Src src) {
	immutable(Src) seq_impl(ps...)(immutable Src init,immutable Src src) {
		static if (ps.length == 0) {
			return src;
		}
		else {
			immutable parsed = ps[0](src);
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

//ateを捨てる
immutable(Src) omit(alias p)(immutable Src src) {
	immutable parsed = p (src);
	return Src("",parsed.dish,parsed.succ,parsed.tree);
}

//解析が成功した場合子を作りそれを親とする
immutable(Src) node(NodeType type,alias p)(immutable Src src) {
	immutable parent = src.tree.childrenAdded(cast(immutable)[new AST(type,"")]);
	immutable target = Src(src.ate,src.dish,src.succ,parent.children[$-1]);
	immutable parsed = p (target);
	if (parsed.succ) {
		return parsed;
	}
	else {
		return src.failed;
	}
}
unittest{
	immutable src = Src("","ab",true,cast(immutable)new AST(NodeType.Root,""))
					.node!(NodeType.Root,seq!(raise!(same!'a'),sel!(NodeType.Bind,same!'b')));
	assert (src.tree.data == "a" && src.tree.children[0].data == "b" && src.tree.children[0].type == NodeType.Bind);
}

//解析が成功した場合に子を追加する
immutable(Src) sel(NodeType type,alias p)(immutable(Src) src) {
	immutable parsed = p (src);
	if (parsed.succ) {
		return Src("",parsed.dish,parsed.succ,parsed.tree.childrenAdded(cast(immutable)[new AST(type,parsed.ate)]));
	}
	else {
		return parsed;
	}
}
unittest {
	immutable src = Src("","a",true,cast(immutable)new AST(NodeType.Root,""))
					.sel!(NodeType.Bind,same!'a');
	immutable child = src.tree.children[0];
	assert (src.succ && child.type == NodeType.Bind && child.data == "a");
}

//親のデータを変更する
immutable(Src) raise(alias p)(immutable Src src) {
	immutable parsed = p (src);
	if (parsed.succ) {
		immutable parent = parsed.tree.dataChanged(parsed.ate);
		return Src("",parsed.dish,parsed.succ,parent);
	}
	return src.failed;
}
unittest {
	immutable src = Src("","a",true,cast(immutable)new AST(NodeType.Root,""))
					.raise!(same!'a');
	assert (src.succ && src.tree.data == "a");
}
debug{
	void print_tree(immutable(AST) ast,string indent = "") {
		import std.format;
		writeln(indent,format("%s : %s",ast.data,ast.type));
		if (ast.children.length > 0) {
			foreach(child;ast.children)
				print_tree(child,indent~"  ");
		}
	}
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

immutable(Src) quote(immutable Src src) {
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

/+
template_ <- symbol emp* ('!' emp* (symbol / literal / template_)) /
		('(' emp* (symbol / literal / template_) emp* (',' emp* symbol / literal / template_ emp* )* ')')
+/
immutable(Src) template_ (immutable Src src) {
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
immutable(Src) func(immutable Src src) {
	return seq!(or!(template_,symbol),rep!emp,
		same!'(',opt!(seq!(rep!emp,or!(literal,func,template_,symbol),rep!(seq!(rep!emp,same!',',rep!emp,or!(literal,func,template_,symbol))),rep!emp)),same!')')(src);
}
unittest {
	assert(Src("foo (hoge!x, 0x12 ,hoge( foo))").func == Src("foo (hoge!x, 0x12 ,hoge( foo))","",true));
}
