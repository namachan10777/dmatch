module dmatch.core.parser;

import std.stdio;

import std.range : empty,array,zip;
import std.ascii;
import std.traits;
import std.format;
import std.compiler;
import std.algorithm.iteration;
import std.algorithm.searching;

import dmatch.tvariant;
import dmatch.core.type;
import dmatch.core.util;

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
	static assert (r.ate == "Dman is so " && r.dish == "cute." && r.succ);
}

//same : Src -> char -> Src
immutable(Src) same(alias charcter)(immutable Src src) {
	if (!src.dish.empty && src.dish[0] == charcter) {
		return Src(src.ate~src.dish[0],src.dish[1..$],true,src.trees,src.stack);
	}
	return src.failed;
}
unittest {
	static assert (Src("Dman is ", "so cute.").same!'a' == Src("Dman is ", "so cute.", false));
	static assert (Src("Dman is ", "so cute.").same!'s' == Src("Dman is s", "o cute.", true));
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
	static assert (Src("Dman is ","so cute.").str!"so cute" == Src("Dman is so cute",".",true));
	static assert (Src("Dman is ","so cute.").str!"so cool" == Src("Dman is ","so cute.",false));
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
	static assert (Src("Dman is ", "so cute.").rng!(['a','b','c']) == Src("Dman is ","so cute.",false));
	static assert (Src("Dman is ", "so cute.").rng!(['o','p','s']) == Src("Dman is s","o cute.",true));
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
	static assert (Src("Dman is ","so cute.").or!(same!'o',same!'p',same!'s',same!'q')
		== Src("Dman is s","o cute.",true));
	static assert (Src("Dman is ","so cute.").or!(same!'a',same!'b',same!'c',same!'d')
		== Src("Dman is ","so cute.",false));
}

//not : 'f -> Src -> Src
//述語fを実行して失敗すれば成功、成功すれば失敗を返す。文字は消費しない
immutable(Src) not(alias p)(immutable Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,!parsed.succ,src.trees,src.stack);
}
unittest {
	static assert (Src("Dman is ","so cute.").not!(same!'s') == Src("Dman is ","so cute.",false));
	static assert (Src("Dman is ","so cute.").not!(same!'a') == Src("Dman is ","so cute.",true));
}

//and : 'f -> Src -> Src
//述語fを実行してその結果を返す。文字は消費しない
immutable(Src) and(alias p)(immutable Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,parsed.succ,src.trees,src.stack);
}
unittest {
	static assert (Src("Dman is ","so cute.").and!(same!'s') == Src("Dman is ","so cute.",true));
	static assert (Src("Dman is ","so cute.").and!(same!'a') == Src("Dman is ","so cute.",false));
}

//many : 'f -> Src -> Src
//一回以上述語fを実行してその結果を返す
alias many(alias p) = seq!(p,rep!p);
unittest {
	static assert (Src("Dman is ","so cute.").many!(rng!"so") == Src("Dman is so"," cute.",true));
	static assert (Src("Dman is ","so cute.").many!(rng!"ab") == Src("Dman is ","so cute.",false));
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
	static assert (Src("Dman is ","so cute.").rep!(rng!"so") == Src("Dman is so"," cute.",true));
	static assert (Src("Dman is ","so cute.").rep!(rng!"ab") == Src("Dman is ","so cute.",true));
}

//opt : 'f -> Src -> Src
//述語fを一回実行して常に成功を返す
immutable(Src) opt(alias p)(immutable Src src) {
	auto parsed = p (src);
	return Src(parsed.ate, parsed.dish, true, parsed.trees, parsed.stack);
}
unittest {
	static assert (Src("Dman is ","so cute.").opt!(same!'s') == Src("Dman is s","o cute.",true));
	static assert (Src("Dman is ","so cute.").opt!(same!'a') == Src("Dman is ","so cute.",true));
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
	static assert (Src("Dman is ","so cute.").seq!(same!'s',same!'o') == Src("Dman is so"," cute.",true));
	static assert (Src("Dman is ","so cute.").seq!(same!'s',same!'O') == Src("Dman is ","so cute.",false));
}

//ateを捨てる
immutable(Src) omit(alias p)(immutable Src src) {
 	auto before_size = src.ate.length;
	auto parsed = p (src);
	return Src(parsed.ate[0..before_size],parsed.dish,parsed.succ,parsed.trees,parsed.stack);
}
unittest {
	static assert(Src("","c",true).omit!(same!'c') == Src("","",true));
	static assert(Src("ab","cd",true).omit!(same!'c') == Src("ab","d",true));
	static assert(Src("ab","cd").omit!(same!'e') == Src("ab","cd",false));
	static assert(Src("a  b").seq!(same!'a',omit!emp,same!'b') == Src("ab","",true));
}

//子をまとめて親を作る
immutable(Src) node(Type type,alias p)(immutable Src src) {
	auto parsed = p (src);
	with(parsed) {
		if (succ) return Src(ate,dish,succ,[immutable AST(type,popStack,trees)],popedStack);
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
immutable(Src) term(Type type,alias p)(immutable Src src) {
	return src.node!(type,push!p);
}
string tree2str(inout AST ast,string indent = "  ") {
	import std.format;
	import std.string;
	if (ast.pos.enabled)
		return format("%s : \"%s\" (pos = \"%s\")\n",ast.type,ast.data,ast.pos)
			~ ast.children.map!(a => indent ~ a.tree2str(indent ~ "  ")).fold!"a~b"("");
	else if (ast.range.begin.enabled)
		return format("%s : \"%s\" (range = \"%s\")\n",ast.type,ast.data,ast.range)
			~ ast.children.map!(a => indent ~ a.tree2str(indent ~ "  ")).fold!"a~b"("");
	else
		return format("%s : \"%s\"\n",ast.type,ast.data)
			~ ast.children.map!(a => indent ~ a.tree2str(indent ~ "  ")).fold!"a~b"("");
}

//基本的な規則
//特殊文字
alias emp = rep!(or!(rng!"\r\t\n "));
alias sp = rng!("!\"#$%&'()-=~^|\\{[]}@`*:+;?/.><, \t\n\r");
//symbol <- (!(sp / [0-9]) .) (!sp .)
alias symbol = seq!(seq!(not!(or!(sp,rng!digits)),any),rep!(seq!(not!sp,any)));
unittest {
	static assert (Src("i").symbol == Src("i","",true));
	static assert (Src("_Abc_100_!").symbol == Src("_Abc_100_","!",true));
	static assert (Src("0_a").symbol == Src("","0_a",false));
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
	static assert (Src("3.14f").floating == Src("3.14f","",true));
	static assert (Src("1.").floating == Src("1.","",true));
	static assert (Src(".1").floating == Src(".1","",true));
}
//integral <- "0x" [0-9]+ / [1-9] / [0-9]+ ("LU" / 'L' / 'U')?
alias integral = seq!(or!(seq!(str!"0x",many!(rng!digits)),many!(rng!digits)),opt!(or!(str!"LU",same!'L',same!'U')));
unittest {
	static assert (Src("0x12LU").integral == Src("0x12LU","",true));
}
alias num = or!(floating,integral);

//strLit <- '"' ("\""? !('"' .))* '"'
alias strLit = seq!(same!'\"',rep!(seq!(opt!(same!'a'),not!(same!'\"'),any)),same!'\"');
unittest {
	static assert (Src("\"abc\\\"").strLit == Src("\"abc\\\"","",true));
}
//charLit <- ''' '\'? . '''
alias charLit = seq!(same!'\'',opt!(same!'\\'),any,same!'\'');
unittest {
	static assert (Src(q{'\r'}).charLit == Src(q{'\r'},"",true));
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
	static assert (Src("q{abc}").quote == Src("q{abc}","",true));
}

alias null_ = seq!(str!"null",and!sp);
unittest {
	static assert (Src("null@").null_ == Src("null","@",true));
	static assert (Src("null_").null_ == Src("","null_",false));
}

alias literal = or!(num,charLit,strLit,null_);

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
	static assert (Src("Tuple!(Hoge!T,int)").template_ == Src("Tuple!(Hoge!T,int)","",true));
}

/+
func <- (template_ / symbol) emp* '(' emp* (literal / symbol) (emp* ',' emp* (literal / symbol))* emp* ')'
+/
immutable(Src) func(immutable Src src) {
	return seq!(or!(template_,symbol),emp,emp,
		same!'(',opt!(seq!(emp,or!(literal,func,template_,symbol),rep!(seq!(emp,same!',',emp,or!(literal,func,template_,symbol))),emp)),same!')')(src);
}
unittest {
	static assert(Src("foo (hoge!x, 0x12 ,hoge(foo))").func == Src("foo (hoge!x, 0x12 ,hoge(foo))","",true));
}

alias rval_p = term!(Type.RVal,or!(func,literal));
unittest {
	static assert(Src("0x12").rval_p.trees == [immutable AST(Type.RVal,"0x12",[])]);
}
alias bind_p = term!(Type.Bind,symbol);
unittest {
	static assert(Src("__abc123").bind_p.trees == [immutable AST(Type.Bind,"__abc123",[])]);
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
	static assert(Src("  ( ( a+b)* )c").withdraw == Src(" ( a+b)* ","c",true));
	static assert(Src("  ( ( a+b* c").withdraw == Src("","  ( ( a+b* c",false));
}

// if (x > 2)
immutable(Src) guard_p (immutable Src src) {
	auto parsed = src.term!(Type.If,seq!(omit!(str!"if"),omit!emp,withdraw));
	if (parsed.succ) return parsed;
	else return src.failed;
}
unittest {
	static assert(Src("if (a > 2)").guard_p.trees == [immutable AST(Type.If,"a > 2",[])]);
	static assert(Src("if (a > 2 ").guard_p == Src("","if (a > 2 ",false));
}

//a @ b @ c
immutable(Src) as_p(immutable Src src) {
	alias pattern = or!(array_p,bracket_p,record_p,variant_p,rval_p,bind_p);
	return src.node!(Type.As,seq!(pattern,many!(seq!(omit!(seq!(emp,same!'@',emp)),pattern))));
}
unittest {
	static assert(Src("a @ b").as_p.trees == [immutable AST(Type.As,"",[immutable AST(Type.Bind,"a",[]),immutable AST(Type.Bind,"b",[])])]);
	static assert(Src("a @ ").as_p == Src("","a @ ",false));
}

// [a,b,c]
immutable(Src) array_elem_p(immutable Src src) {
	alias pattern = or!(as_p,array_p,bracket_p,rval_p,bind_p,);
	return src.node!(Type.Array_Elem,seq!(omit!(same!'['),omit!emp,opt!(seq!(pattern,rep!(seq!(omit!emp,omit!(same!','),pattern)),omit!emp)),omit!(same!']')));
}
unittest {
	static assert(Src("[a,b]").array_elem_p.trees ==
		[immutable AST(Type.Array_Elem,"",[immutable AST(Type.Bind,"a",[]),immutable AST(Type.Bind,"b",[])])]);
	static assert(Src("[]").array_elem_p.trees ==
		[immutable AST(Type.Array_Elem,"",[])]);
	static assert(Src("[,]").array_elem_p == Src("","[,]",false));
}

//[a,b,c] ~ d
immutable(Src) array_p(immutable Src src) {
	alias pattern = or!(array_elem_p,rval_p,bind_p);
	return src.node!(Type.Array,or!(
		seq!(pattern,omit!emp,many!(seq!(omit!emp,omit!(same!'~'),omit!emp,pattern))),
		array_elem_p));
}
unittest {
	static assert(Src("[a]~[]").array_p.trees == [
		immutable AST(Type.Array,"",[
			immutable AST(Type.Array_Elem,"",[immutable AST(Type.Bind,"a",[])]),
			immutable AST(Type.Array_Elem,"",[])])]);
	static assert(Src("~[a]").array_p == Src("","~[a]",false));
}

//a::b::c
immutable(Src) range_p(immutable Src src) {
	alias pattern = or!(as_p,bracket_p,array_p,variant_p,rval_p,bind_p);
	return src.node!(Type.Range,seq!(pattern,many!(seq!(omit!emp,omit!(str!"::"),omit!emp,pattern))));
}
unittest {
	static assert(Src("x::xs").range_p.trees == [immutable AST(Type.Range,"",[immutable AST(Type.Bind,"x",[]),immutable AST(Type.Bind,"xs",[])])]);
	static assert(Src("x::").range_p == Src("","x::",false));
}

//a : c
immutable(Src) variant_p(immutable Src src) {
	alias pattern = or!(bracket_p,array_p,rval_p,bind_p);
	return src.node!(Type.Variant,seq!(pattern,omit!emp,omit!(same!':'),omit!emp,push!(or!(template_,symbol))));
}
unittest {
	static assert (Src("x:A").variant_p.trees == [immutable AST(Type.Variant,"A",[immutable AST(Type.Bind,"x",[])])]);
	static assert (Src(":A").variant_p == Src("",":A",false));
}

//{a = b,c = d}
immutable(Src) record_p(immutable Src src) {
	alias pattern = or!(as_p,bracket_p,array_p,range_p,record_p,variant_p,rval_p,bind_p);
	alias pair_p = node!(Type.Pair,seq!(pattern,omit!emp,omit!(same!'='),omit!emp,push!(or!(template_,symbol))));
	return src.node!(Type.Record,seq!(omit!(same!'{'),omit!emp,pair_p,rep!(seq!(omit!emp,omit!(same!','),omit!emp,pair_p,omit!emp)),omit!emp,omit!(same!'}')));
}
unittest {
	static assert (Src("{a = b,c = d}").record_p.trees == [
		immutable AST(Type.Record,"",[
			immutable AST(Type.Pair,"b",[immutable AST(Type.Bind,"a",[])]),
			immutable AST(Type.Pair,"d",[immutable AST(Type.Bind,"c",[])])])]);
}

//(a::b) @ c :: d
immutable(Src) bracket_p(immutable Src src) {
	alias pattern = or!(as_p,range_p,variant_p);
	return src.seq!(omit!(same!'('),omit!emp,pattern,omit!emp,omit!(same!')'));
}
unittest {
	static assert (Src("(x::xs)").bracket_p == Src("x::xs").range_p);
	static assert (Src("(x::)").bracket_p == Src("","(x::)",false));
}

immutable(AST) parse(immutable string src) {
	auto parsed = Src(src).node!(Type.Root,seq!(omit!emp,seq!(or!(range_p,as_p,variant_p,record_p,bracket_p,array_p,bind_p),omit!emp),omit!emp,opt!guard_p));
	if (!parsed.succ || !parsed.dish.empty) throw new Exception("Syntax Error");
	return parsed.trees[0];
}
unittest {
	static assert ("x@y::xs if(x > 2)".parse ==
		immutable AST(Type.Root,"",[
			immutable AST(Type.Range,"",[
				immutable AST(Type.As,"",[
					immutable AST(Type.Bind,"x",[]),
					immutable AST(Type.Bind,"y",[])]),
				immutable AST(Type.Bind,"xs",[])]),
		immutable AST(Type.If,"x > 2",[])]));
}
