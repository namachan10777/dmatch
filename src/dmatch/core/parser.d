module dmatch.core.parser;

import std.stdio;

import std.range;
import std.ascii;
import std.traits;
import std.format;
import std.compiler;
import std.algorithm.iteration;

import dmatch.tvariant;

enum NodeType {
	Root,
	Bind,
	RVal,
	As,
	Array,
	Array_Elem,
	Range,
	Record,
	Pair,
	Variant,
	If
}

struct Src {
	immutable string ate;
	immutable string dish;
	immutable bool succ;
	immutable string[] stack;
	immutable AST[] trees;
	this(immutable string dish) {
		this("",dish,true,null,[]);
	}
	this(immutable string ate,immutable string dish) {
		this(ate,dish,true,null,[]);
	}
	this(immutable string ate,immutable string dish,immutable bool succ) {
		this(ate,dish,succ,null,[]);
	}
	this(immutable string ate,immutable string dish,immutable bool succ,immutable AST[] ast,immutable string[] stack) {
		this.ate = ate;
		this.dish = dish;
		this.succ = succ;
		this.trees = ast;
		this.stack = stack;
	}
	@property
	immutable(Src) failed() immutable{
		return Src(ate,dish,false,trees,stack);
	}
	@property
	immutable(Src) treeCleared() immutable {
		return Src(ate,dish,succ,[],stack);
	}
	@property
	immutable(string) popStack() immutable {
		if (stack.empty) return "";
		return stack[$-1];
	}
	@property
	immutable(string[]) popedStack() immutable {
		if (stack.empty) return [];
		return stack[0..$-1];
	}
}

class AST {
public:
	immutable NodeType type;
	immutable string data;
	immutable AST[] children;
	this(immutable NodeType type,immutable string data,immutable AST[] children) immutable {
		this.type = type;
		this.data = data;
		this.children = children;
	}
	immutable(AST) childrenChanged(immutable AST[] children) immutable{
		return new immutable AST(type,data,children);
	}
	immutable(AST) dataChanged(immutable string data) immutable {
		return new immutable AST(type,data,children);
	}
	immutable(AST) typeChanged(immutable NodeType type) immutable {
		return new immutable AST(type,data,children);
	}
	string toString() immutable {
		import std.string;
		return format("AST( %s, %s, [%s])",type,'\"'~data~'\"',children.map!(a => a.toString).join(","));
	}
	override bool opEquals(Object o) {
		auto ast = cast(AST)o;
		if (ast is null) return false;
		static if (version_major >= 2 && version_minor >= 71) {
			return	type == ast.type &&
					data == ast.data &&
					zip(children,ast.children)
					.map!(a => a[0] == a[1])
					.fold!"a&&b"(true);
		}
		else {
			return	type == ast.type &&
					data == ast.data &&
					zip(children,ast.children)
					.map!(a => a[0] == a[1])
					.array
					.reduce!"a&&b";
		}
	}
}
unittest {
	auto a1 = new immutable AST(NodeType.Bind,"a",[]);
	auto a2 = new immutable AST(NodeType.Bind,"a",[]);
	auto b1 = new immutable AST(NodeType.RVal,"1",[]);
	auto b2 = new immutable AST(NodeType.RVal,"1",[]);
	auto r1 = new immutable AST(NodeType.Root,"",[a1,b1]);
	auto r2 = new immutable AST(NodeType.Root,"",[a2,b2]);
	assert (r1 == r2);
	auto c1 = new immutable AST(NodeType.Bind,"c",[]);
	auto r3 = new immutable AST(NodeType.Root,"",[a1,c1]);
	assert (r1 != r3);
}


//成功すれば文字を消費し結果(true | false)と一緒に消費した文字を付け加えたものを返す
//any : Src -> Src
//任意の一文字を取る。
immutable(Src) any(immutable Src src) {
	if (src.dish.empty)
		return src.failed;
	return Src(src.ate~src.dish[0],src.dish[1..$],true,src.trees,src.stack);
}
unittest {
	immutable r = Src("Dman is"," so cute.").any.any.any.any;
	assert (r.ate == "Dman is so " && r.dish == "cute." && r.succ);
}

//same : Src -> char -> Src
immutable(Src) same(alias charcter)(immutable Src src) {
	if (!src.dish.empty && src.dish[0] == charcter) {
		return Src(src.ate~src.dish[0],src.dish[1..$],true,src.trees,src.stack);
	}
	return src.failed;
}
unittest {
	assert (Src("Dman is ", "so cute.").same!'a' == Src("Dman is ", "so cute.", false));
	assert (Src("Dman is ", "so cute.").same!'s' == Src("Dman is s", "o cute.", true));
}

immutable(Src) str(alias token)(immutable Src src) {
	size_t idx;
	foreach(i,head;token) {
		if (src.dish.length <= i ||  head != src.dish[i])
			return src.failed;
		idx = i;
	}
	return Src(src.ate~src.dish[0..idx+1],src.dish[idx+1..$],true,src.trees,src.stack);
}
unittest {
	assert (Src("Dman is ","so cute.").str!"so cute" == Src("Dman is so cute",".",true));
	assert (Src("Dman is ","so cute.").str!"so cool" == Src("Dman is ","so cute.",false));
}

//rng : char[] -> Src -> Src
//指定された文字が含まれていれば成功、無ければ失敗を返す
immutable(Src) rng(alias candidate)(immutable Src src) {
	if (!src.dish.empty)
		foreach(c ; candidate)
			if (c == src.dish[0])
				return Src(src.ate~src.dish[0],src.dish[1..$],true,src.trees,src.stack);
	return src.failed;
}
unittest {
	assert (Src("Dman is ", "so cute.").rng!(['a','b','c']) == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ", "so cute.").rng!(['o','p','s']) == Src("Dman is s","o cute.",true));
}

//or : 'f ... -> Src -> Src
immutable(Src) or(ps...)(immutable Src src) {
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
immutable(Src) not(alias p)(immutable Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,!parsed.succ,src.trees,src.stack);
}
unittest {
	assert (Src("Dman is ","so cute.").not!(same!'s') == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ","so cute.").not!(same!'a') == Src("Dman is ","so cute.",true));
}

//and : 'f -> Src -> Src
//述語fを実行してその結果を返す。文字は消費しない
immutable(Src) and(alias p)(immutable Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,parsed.succ,src.trees,src.stack);
}
unittest {
	assert (Src("Dman is ","so cute.").and!(same!'s') == Src("Dman is ","so cute.",true));
	assert (Src("Dman is ","so cute.").and!(same!'a') == Src("Dman is ","so cute.",false));
}

//many : 'f -> Src -> Src
//一回以上述語fを実行してその結果を返す
alias many(alias p) = seq!(p,rep!p);
unittest {
	assert (Src("Dman is ","so cute.").many!(rng!"so") == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").many!(rng!"ab") == Src("Dman is ","so cute.",false));
}

//rep : 'f -> Src -> Src
//述語fを0回以上実行して常に成功を返す
immutable(Src) rep(alias p)(immutable Src src) {
	immutable(Src) rep_impl(immutable Src src,immutable AST[] trees_) {
		auto parsed = p(src);
		with (parsed) {
			if (succ) return rep_impl(treeCleared,trees_~trees);
			else return Src(src.ate,src.dish,true,trees_,src.stack);
		}
	}
	return rep_impl(src,[]);
}
unittest {
	assert (Src("Dman is ","so cute.").rep!(rng!"so") == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").rep!(rng!"ab") == Src("Dman is ","so cute.",true));
}

//opt : 'f -> Src -> Src
//述語fを一回実行して常に成功を返す
immutable(Src) opt(alias p)(immutable Src src) {
	auto parsed = p (src);
	return Src(parsed.ate, parsed.dish, true, parsed.trees, parsed.stack);
}
unittest {
	assert (Src("Dman is ","so cute.").opt!(same!'s') == Src("Dman is s","o cute.",true));
	assert (Src("Dman is ","so cute.").opt!(same!'a') == Src("Dman is ","so cute.",true));
}

//seq : 'f... -> Src -> Src
//述語f...を左から順に実行して結果を返す。バックトラックする。
immutable(Src) seq(ps...)(immutable Src init) {
	immutable(Src) seq_impl(ps...)(immutable Src src,immutable AST[] trees_) {
		static if (ps.length == 0) {
			with(src) {
				return Src(ate,dish,succ,trees_,stack);
			}
		}
		else {
			auto parsed = ps[0](src);
			with(parsed) {
				if (succ) return seq_impl!(ps[1..$])(parsed.treeCleared,trees_~trees);
				else return init.failed;
			}
		}
	}
	return seq_impl!ps(init,[]);
}
unittest {
	assert (Src("Dman is ","so cute.").seq!(same!'s',same!'o') == Src("Dman is so"," cute.",true));
	assert (Src("Dman is ","so cute.").seq!(same!'s',same!'O') == Src("Dman is ","so cute.",false));
}

//ateを捨てる
immutable(Src) omit(alias p)(immutable Src src) {
 	auto before_size = src.ate.length;
	auto parsed = p (src);
	return Src(parsed.ate[0..before_size],parsed.dish,parsed.succ,parsed.trees,parsed.stack);
}
unittest {
	assert(Src("","c",true).omit!(same!'c') == Src("","",true));
	assert(Src("ab","cd",true).omit!(same!'c') == Src("ab","d",true));
	assert(Src("ab","cd").omit!(same!'e') == Src("ab","cd",false));
	assert(Src("a  b").seq!(same!'a',omit!emp,same!'b') == Src("ab","",true));
}

//子をまとめて親を作る
immutable(Src) node(NodeType type,alias p)(immutable Src src) {
	auto parsed = p (src);
	with(parsed) {
		if (succ) return Src(ate,dish,succ,[new immutable AST(type,popStack,trees)],popedStack);
		else return src.failed;
	}
}
unittest{
}

immutable(Src) push(alias p)(immutable Src src) {
	auto parsed = p (src);
	with (parsed) {
		if (succ) return Src("",dish,succ,trees,stack ~ ate);
		else return src.failed;
	}
}
immutable(Src) term(NodeType type,alias p)(immutable Src src) {
	return src.node!(type,push!p);
}
debug{
	string tree2str(inout AST ast,string indent = "") {
		import std.format;
		import std.string;
		static if (version_major >= 2 && version_minor >= 71) {
			return format("%s : %s\n",ast.type,ast.data) ~ ast.children.map!(a => indent ~ a.tree2str(indent ~ "  ")).fold!"a~b"("");
		}
		else {
			return format("%s : %s\n",ast.type,ast.data) ~ ast.children.map!(a => indent ~ a.tree2str(indent ~ "  ")).array.reduce!"a~b";
		}
	}
}

//基本的な規則
//特殊文字
alias emp = rep!(or!(rng!"\r\t\n "));
alias sp = rng!("!\"#$%&'()-=~^|\\{[]}@`*:+;?/.><, \t\n\r");
//symbol <- (!(sp / [0-9]) .) (!sp .)
alias symbol = seq!(seq!(not!(or!(sp,rng!digits)),any),rep!(seq!(not!sp,any)));
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
 Src template_ (Src src) {
	return seq!(symbol,emp,same!'!',emp,or!(
			or!(symbol,literal),
			seq!(same!'(',emp,or!(template_,symbol,literal),rep!(seq!(same!',',emp,or!(template_,symbol,literal),emp)),same!')')))(src);
}
unittest {
	assert (Src("Tuple!(Hoge!T,int)").template_ == Src("Tuple!(Hoge!T,int)","",true));
}

/+
func <- (template_ / symbol) emp* '(' emp* (literal / symbol) (emp* ',' emp* (literal / symbol))* emp* ')'
+/
immutable(Src) func(immutable Src src) {
	return seq!(or!(template_,symbol),emp,emp,
		same!'(',opt!(seq!(emp,or!(literal,func,template_,symbol),rep!(seq!(emp,same!',',emp,or!(literal,func,template_,symbol))),emp)),same!')')(src);
}
unittest {
	assert(Src("foo (hoge!x, 0x12 ,hoge(foo))").func == Src("foo (hoge!x, 0x12 ,hoge(foo))","",true));
}

alias rval_p = term!(NodeType.RVal,or!(func,literal));
alias bind_p = term!(NodeType.Bind,symbol);
unittest {
}

//if (/+この部分+/)　を抜き出す
immutable(Src) withdraw(immutable Src src) {
	size_t cnt;
	bool found_begin;
	size_t begin;
	with (src) {
		foreach(i,head;dish) {
			if (head == '(') {
				if (!found_begin){
					begin = i;
					found_begin = true;
				}
				++cnt;
			}
			else if (head == ')') {
				--cnt;
				if (found_begin && cnt == 0)
					return Src(dish[begin+1..i],dish[i+1..$],true,trees,stack);
			}
		}
		return failed;
	}
}
unittest {
	assert(Src("  ( ( a+b)* )c").withdraw == Src(" ( a+b)* ","c",true));
	assert(Src("  ( ( a+b* c").withdraw == Src("","  ( ( a+b* c",false));
}
immutable(Src) guard_p (immutable Src src) {
	auto parsed = src.term!(NodeType.If,seq!(omit!(str!"if"),omit!emp,withdraw));
	if (parsed.succ) return parsed;
	else return src.failed;
}
unittest {
}

immutable(Src) as_p(immutable Src src) {
	alias pattern = or!(array_p,bracket_p,variant_p,rval_p,bind_p);
	return src.node!(NodeType.As,seq!(pattern,many!(seq!(omit!(seq!(emp,same!'@',emp)),pattern))));
}
unittest {
}

immutable(Src) array_elem_p(immutable Src src) {
	alias pattern = or!(as_p,array_p,bracket_p,rval_p,bind_p,);
	return src.node!(NodeType.Array_Elem,seq!(omit!(same!'['),omit!emp,opt!(seq!(pattern,rep!(seq!(omit!emp,omit!(same!','),pattern)),omit!emp)),omit!(same!']')));
}
unittest {
}

immutable(Src) array_p(immutable Src src) {
	alias pattern = or!(array_elem_p,rval_p,bind_p);
	return src.node!(NodeType.Array,or!(
		seq!(pattern,omit!emp,many!(seq!(omit!emp,omit!(same!'~'),omit!emp,pattern))),
		array_elem_p));
}
unittest {
}

immutable(Src) range_p(immutable Src src) {
	alias pattern = or!(as_p,bracket_p,array_p,variant_p,rval_p,bind_p);
	return src.node!(NodeType.Range,seq!(pattern,many!(seq!(omit!emp,omit!(str!"::"),omit!emp,pattern))));
}
unittest {
}

immutable(Src) variant_p(immutable Src src) {
	alias pattern = or!(bracket_p,array_p,rval_p,bind_p);
	return src.node!(NodeType.Variant,seq!(pattern,omit!emp,omit!(same!':'),omit!emp,push!(or!(template_,symbol))));
}

immutable(Src) record_p(immutable Src src) {
	alias pattern = or!(as_p,bracket_p,array_p,range_p,variant_p,rval_p,bind_p);
	alias pair_p = node!(NodeType.Pair,seq!(pattern,omit!emp,omit!(same!'='),omit!emp,push!(or!(template_,symbol))));
	return src.node!(NodeType.Record,seq!(omit!(same!'{'),omit!emp,pair_p,rep!(seq!(omit!emp,omit!(same!','),omit!emp,pair_p,omit!emp)),omit!emp,omit!(same!'}')));
}
unittest {
}

immutable(Src) bracket_p(immutable Src src) {
	alias pattern = or!(as_p,range_p,variant_p);
	return src.seq!(same!'(',emp,pattern,emp,same!')');
}

immutable(AST) parse(immutable string src) {
	auto parsed = Src(src).node!(NodeType.Root,seq!(omit!emp,seq!(or!(as_p,variant_p,range_p,record_p,bracket_p,array_p),omit!emp),omit!emp,opt!guard_p));
	if (!parsed.succ || !parsed.dish.empty) throw new Exception("Syntax Error");
	return parsed.trees[0];
}
unittest {
}
