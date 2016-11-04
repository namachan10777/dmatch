module dmatch.core.parser;

import std.stdio;

import std.range;
import std.ascii;
import std.range;
import std.traits;

import dmatch.tvariant;

enum NodeType {
	Root,
	Bind,
	RVal,
	As,
	Array,
	Array_Elem
}

struct Src {
	immutable string ate;
	immutable string dish;
	immutable bool succ;
	AST tree;
	this(immutable string dish){
		this("",dish,true,null);
	}
	this(immutable string dish,AST ast){
		this("",dish,true,ast);
	}
	this(immutable string ate,immutable string dish){
		this(ate,dish,true,null);
	}
	this(immutable string ate,immutable string dish,immutable bool succ){
		this(ate,dish,succ,null);
	}
	this(immutable string ate,immutable string dish,immutable bool succ,AST ast){
		this.ate = ate;
		this.dish = dish;
		this.succ = succ;
		this.tree = ast;
	}
	@property
	Src failed(){
		return Src(ate,dish,false,tree);
	}
}

class AST {
public:
	NodeType type;
	AST parent;
	string data;
	AST[] children;
	this (NodeType type,string data) {
		this(type,data,null,null);
	}
	this (NodeType type,string data,AST parent,AST[] children) {
		this.type = type;
		this.data = data;
		this.parent = parent;
		this.children = children;
	}
	AST addChild(AST child)
	in{
		assert (child !is null);
	}
	body
	{
		child.parent = this;	
		this.children ~= child;
		return this;
	}
	AST deleteChild() {
		--children.length;
		return this;
	}
	AST dataChange(string data) {
		this.data = data;
		return this;
	}
	@property
	AST root(){
		if (parent is null)
			return this;
		else
			return parent.root;
	}
}


//成功すれば文字を消費し結果(true | false)と一緒に消費した文字を付け加えたものを返す

//any : Src -> Src
//任意の一文字を取る。
 Src any(Src src) {
	if (src.dish.empty)
		return Src(src.ate,src.dish,false,src.tree);
	return Src(src.ate~src.dish[0],src.dish[1..$],true,src.tree);
}
unittest {
	auto r = Src("Dman is", " so cute.", true).any.any.any.any;
	assert (r.ate == "Dman is so " && r.dish == "cute." && r.succ);
}

//same : Src -> char -> Src
Src same(alias charcter)(Src src) {
	if (!src.dish.empty && src.dish[0] == charcter) {
		return Src(src.ate~src.dish[0],src.dish[1..$],true,src.tree);
	}
	return Src(src.ate,src.dish,false,src.tree);
}
unittest {
	assert (Src("Dman is ", "so cute.").same!'a' == Src("Dman is ", "so cute.", false));
	assert (Src("Dman is ", "so cute.").same!'s' == Src("Dman is s", "o cute.", true));
}

 Src str(alias token)(Src src) {
	size_t idx;
	foreach(i,head;token) {
		if (src.dish.length <= i ||  head != src.dish[i])
			return src.failed;
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
 Src rng(alias candidate)(Src src) {
	if (!src.dish.empty)
		foreach(c ; candidate) 
			if (c == src.dish[0])
				return Src(src.ate~src.dish[0],src.dish[1..$],true,src.tree);
	return Src(src.ate,src.dish,false,src.tree);
}
unittest {
	assert (Src("Dman is ", "so cute.").rng!(['a','b','c']) == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ", "so cute.").rng!(['o','p','s']) == Src("Dman is s","o cute.",true));
}

//or : 'f ... -> Src -> Src
 Src or(ps...)(Src src) {
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
 Src not(alias p)(Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,!parsed.succ);
}
unittest {
	assert (Src("Dman is ","so cute.").not!(same!'s') == Src("Dman is ","so cute.",false));
	assert (Src("Dman is ","so cute.").not!(same!'a') == Src("Dman is ","so cute.",true));
}

//and : 'f -> Src -> Src
//述語fを実行してその結果を返す。文字は消費しない
 Src and(alias p)(Src src) {
	auto parsed = p (src);
	return Src(src.ate,src.dish,parsed.succ);
}
unittest {
	assert (Src("Dman is ","so cute.").and!(same!'s') == Src("Dman is ","so cute.",true));
	assert (Src("Dman is ","so cute.").and!(same!'a') == Src("Dman is ","so cute.",false));
}

//many : 'f -> Src -> Src
//一回以上述語fを実行してその結果を返す
 Src many(alias p)(Src src) {
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
 Src rep(alias p)(Src src) {
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
 Src opt(alias p)(Src src) {
	auto parsed = p (src);
	return Src(parsed.ate, parsed.dish, true);
}
unittest {
	assert (Src("Dman is ","so cute.").opt!(same!'s') == Src("Dman is s","o cute.",true));
	assert (Src("Dman is ","so cute.").opt!(same!'a') == Src("Dman is ","so cute.",true));
}

//seq : 'f... -> Src -> Src
//述語f...を左から順に実行して結果を返す。バックトラックする。
 Src seq(ps...)(Src src) {
	Src seq_impl(ps...)(Src init,Src src) {
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

//ateを捨てる
 Src omit(alias p)(Src src) {
 	auto before_size = src.ate.length;
	auto parsed = p (src);
	return Src(parsed.ate[0..before_size],parsed.dish,parsed.succ,parsed.tree);
}
unittest {
	assert(Src("","c",true).omit!(same!'c') == Src("","",true));
	assert(Src("ab","cd",true).omit!(same!'c') == Src("ab","d",true));
	assert(Src("ab","cd").omit!(same!'e') == Src("ab","cd",false));
	assert(Src("a  b").seq!(same!'a',omit!emp,same!'b') == Src("ab","",true));
}

//解析が成功した場合子を作りそれを親とする
 Src node(NodeType type,alias p)(Src src)
in{
	assert(src.tree !is null);
}
body{
	auto new_node = new AST(type,"");
	src.tree.addChild(new_node);
	auto parsed = p (Src(src.ate,src.dish,src.succ,new_node));
	if (parsed.succ) {
		return Src(parsed.ate,parsed.dish,true,src.tree);
	}
	else {
		src.tree.deleteChild;
		//パース結果を全て破棄する
		return src.failed;
	}
}
unittest{
	auto tree = Src("","abc",true,new AST(NodeType.Root,""))
					.node!(NodeType.Root,seq!(raise!(same!'a'),sel!(NodeType.Bind,same!'b'),sel!(NodeType.Bind,same!'c')))
					.tree
					.children[0];
	assert (tree.data == "a" &&
			tree.children[0].data == "b" &&
			tree.children[0].type == NodeType.Bind &&
			tree.children[1].data == "c" &&
			tree.children[1].type == NodeType.Bind);
	auto tree2 = Src("","ab",true,new AST(NodeType.Root,""))
					.node!(NodeType.Root,seq!(raise!(same!'a'),sel!(NodeType.Bind,same!'b'),sel!(NodeType.Bind,same!'c')))
					.tree;
	assert (tree2.data == "" &&
			tree2.children.empty);
}

//解析が成功した場合に子を追加する
Src sel(NodeType type,alias p)(Src src)
in{
	assert (src.tree !is null);
}
body{
	auto parsed = p (src);
	if (parsed.succ) {
		//子を追加したノードを新しいノードとするSrcを返す(=ノードに子要素を追加する)
		src.tree.addChild(new AST(type,parsed.ate));
		return Src("",parsed.dish,true,src.tree);
	}
	else {
		return parsed;
	}
}
unittest {
	auto tree = Src("","012",true,new AST(NodeType.Root,""))
					.node!(NodeType.Root,rep!(sel!(NodeType.Bind,rng!digits)))
					.tree
					.children[0];
	assert (tree.data == "" &&
			tree.type == NodeType.Root &&
			tree.children[0].data == "0" &&
			tree.children[0].type == NodeType.Bind &&
			tree.children[1].data == "1" &&
			tree.children[1].type == NodeType.Bind &&
			tree.children[2].data == "2" &&
			tree.children[2].type == NodeType.Bind);
}

//親のデータを解析結果に変更する
 Src raise(alias p)(Src src) {
	auto parsed = p (src);
	if (parsed.succ) {
		//親(現在のノード)のデータを変更したもの
		parsed.tree.dataChange(parsed.ate);
		//を返す
		return Src("",parsed.dish,parsed.succ,parsed.tree);
	}
	else {
		return src.failed;
	}
}
unittest {
	auto src = Src("","a",true,new AST(NodeType.Root,""))
					.raise!(same!'a');
	assert (src.succ && src.tree.data == "a");
}
debug{
	void print_tree(AST ast,string indent = "") {
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

 Src quote(Src src) {
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
 Src func(Src src) {
	return seq!(or!(template_,symbol),emp,emp,
		same!'(',opt!(seq!(emp,or!(literal,func,template_,symbol),rep!(seq!(emp,same!',',emp,or!(literal,func,template_,symbol))),emp)),same!')')(src);
}
unittest {
	assert(Src("foo (hoge!x, 0x12 ,hoge(foo))").func == Src("foo (hoge!x, 0x12 ,hoge(foo))","",true));
}
/+
pattern <- bind
+/
alias pattern = or!(as,bind,rVal);
/+
bind <- symbol
+/
//alias bind = sel!(NodeType.Bind,symbol);
Src bind(Src src) {
	return sel!(NodeType.Bind,symbol)(src);
}
unittest{
	auto tree = Src("","__abc123",true,new AST(NodeType.Root,"")).bind.tree;
	assert (tree.children[0].type == NodeType.Bind && tree.children[0].data == "__abc123");
}
Src rVal(Src src) {
	return sel!(NodeType.RVal,or!(literal,func))(src);
}
unittest{
	auto tree = Src("","func(12.3)",true,new AST(NodeType.Root,"")).rVal.tree;
	assert (tree.children[0].type == NodeType.RVal && tree.children[0].data == "func(12.3)");
}
/+
pattern @ pattern @ pattern
as <- pattern emp* ('@' pattern emp*)+
+/
//alias as = node!(NodeType.As,seq!(pattern,many!(emp,same!'@',emp,pattern)));
alias pattern4as = or!(bind);
Src as(Src src) {
	return node!(NodeType.As,seq!(pattern4as,omit!emp,many!(seq!(omit!(seq!(emp,same!'@',emp)),pattern4as))))(src);
}
unittest {
	auto tree = Src("","foo @ bar @ hoge",true,new AST(NodeType.Root,""))
				.as
				.tree
				.children[0];
	assert (tree.type == NodeType.As &&
			tree.data == "" &&
			tree.children[0].type == NodeType.Bind &&
			tree.children[0].data == "foo" &&
			tree.children[1].type == NodeType.Bind &&
			tree.children[1].data == "bar" &&
			tree.children[2].type == NodeType.Bind &&
			tree.children[2].data == "hoge");
}
/+
[pattern,pattern,pattern]
array_elem <- [emp* pattern emp* (',' pattern emp*)*]
+/
Src array_elem(Src src) {
	return node!(NodeType.Array_Elem,seq!(omit!(seq!(same!'[',emp)),pattern,omit!emp,rep!(seq!(omit!(same!','),pattern,omit!(emp))),omit!(same!']')))(src);
}
unittest{
	auto tree = Src("","[abc@def,b,10]",true,new AST(NodeType.Root,"")).array_elem.tree;
}
/+
array_elem ~ array_elem ~ bind
array <- (array_elem / bind) ('~' (array_elem / bind))+
+/
Src array(Src src) {
	return node!(NodeType.Array,seq!(or!(bind,array_elem),omit!emp,rep!(seq!(omit!(seq!(emp,same!'~',emp)),or!(bind,array_elem)))))(src);
}
unittest{
	auto parsed = Src("","[b,10]~xs",true,new AST(NodeType.Root,"")).array;
	parsed.writeln;
	parsed.tree.print_tree;
}
