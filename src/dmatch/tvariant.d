module dmatch.tvariant;

import std.meta : AliasSeq;
import std.traits;
import std.format : format;

public import std.variant : This;

public:

struct TVariant(Specs...){
private:
	template Field(T,string str) {
		alias Type = T;
		enum tag = str;
	}
	template parseSpecs(Specs...) {
		static if (Specs.length == 0) {
			alias parseSpecs = AliasSeq!();	
		}
		else static if (is(typeof(Specs[0]) : string)) {
			alias parseSpecs = AliasSeq!(Field!(None,Specs[0]),parseSpecs!(Specs[1..$]));
		}
		else static if (is(Specs[0]) && is(typeof(Specs[1]) : string)) {
			alias parseSpecs = AliasSeq!(Field!(Specs[0],Specs[1]),parseSpecs!(Specs[2..$]));
		}
	}
	template maxSize(Specs...) {
		static if (Specs.length == 0) {
			enum maxSize = 0;
		}
		else {
			import std.algorithm.comparison;
			static if (!__traits(compiles,typeof(Specs[0]))) {
				enum maxSize = max(Specs[0].sizeof,maxSize!(Specs[1..$]));
			}
			else {
				enum maxSize = maxSize!(Specs[1..$]);
			}
		}
	}
	unittest {
		static assert (maxSize!("a","b","c") == 0);
		static assert (maxSize!(int,real,"a") == real.sizeof);
	}
	template TypeFromTag(string tag,Specs...) {
		static if (Specs.length == 0) {
			static assert (0,"tag "~tag~" is not exist");
		}
		else static if (is(typeof(Specs[0]) : string)) {
			static if (Specs[0] == tag) {
				alias TypeFromTag = None;
			}
			else {
				alias TypeFromTag = TypeFromTag!(tag,Specs[1..$]);
			}
		}
		else static if (is(Specs[0]) && is(typeof(Specs[1]) : string)) {
			static if (Specs[1] == tag) {
				alias TypeFromTag = Specs[0];
			}
			else {
				alias TypeFromTag = TypeFromTag!(tag,Specs[2..$]);
			}
		}
		else {
			alias TypeFromTag = TypeFromTag!(tag,Specs[1..$]);
		}
	}
	unittest {
		static assert (is(TypeFromTag!("c",AliasSeq!(int,"a","b",real,"c")) == real));
	}
	template tagExist(string tag,Specs...) {
		alias parsedSpecs = parseSpecs!(Specs);	
		template tagExistImpl(string tag,parsedSpecs...){
			static if (parsedSpecs.length == 0) {
				enum tagExistImpl = false;
			}
			static if (parsedSpecs[0].tag == tag) {
				enum tagExistImpl = true;
			}
			else {
				enum tagExistImpl = tagExistImpl!(tag,parsedSpecs[1..$]);
			}
		}
		enum tagExist = tagExistImpl!(tag,parsedSpecs);
	}
	unittest {
		static assert (tagExist!("a",AliasSeq!(int,"x","y","a")));
	}
	union{
		ubyte[maxSize!Specs] store;
	}
	string _tag;
	void assign(T)(T x) {
		store = *cast(ubyte[maxSize!Specs]*)&x;
	}
	ref auto read(T)() {
		return *cast(T*)&store;
	}
public:
	static auto create(string tag,T)(T x) {
		auto tv = new TVariant!Specs;
		tv.set!(tag,T)(x);
		return tv;
	}
	@property
	const(string) tag() {
		return _tag;
	}
	void set(string tag)() {
		assign(TypeFromTag!(tag,Specs).init);
		_tag = tag;
	}

	T set(string tag,T)(T x)
	in{
		static assert (tagExist!(tag,Specs),format("tag %s is not exist",tag));
		static assert (is(ReplaceTypeRec!(TVariant!Specs,This,T)[0] == TypeFromTag!(tag,Specs))
						,format("type of tag is \'%s\'. but argument type is \'%s\'",TypeFromTag!(tag,Specs).stringof,ReplaceTypeRec!(TVariant!Specs,This,T)[0].stringof));
	}
	body{
		assign(x);
		_tag = tag;
		return x;
	}

	ref auto get(string tag)()
	in{
		static assert (tagExist!(tag,Specs),format("tag %s is not exist",tag));
		assert (tag == _tag,format("now tag is %s",_tag));
	}
	body {
		alias targetType = ReplaceTypeRec!(This,TVariant!Specs,TypeFromTag!(tag,Specs))[0];
		return read!targetType;
	}
	
	@property
	ref auto opDispatch(string tag)() {
		return get!tag;
	}
	
	@property
	auto opDispatch(string tag,T)(T x) {
		return set!(tag,T)(x);
	}

	bool opEquals(TVariant!Specs x) {
		if (_tag != x.tag) return false;
		template Compare(Specs...) {
			alias parsed = parseSpecs!Specs;
			template Cases(Specs...) {
				static if (Specs.length == 0) {
					enum Cases = q{default : return false;};
				}
				else {
					enum Cases = format(q{case "%s" : return get!"%s" == x.get!"%s";},Specs[0].tag,Specs[0].tag,Specs[0].tag)
								~ Cases!(Specs[1..$]);
				}
			}
			enum Compare = format(q{switch(_tag){%s}},Cases!parsed);
		}
		mixin(Compare!Specs);
	}

	bool opEquals(TVariant!Specs* x) {
		return opEquals(*x);
	}
}

unittest {
	TVariant!(float,"x",float,"y",This*[],"z","w") tv1,tv2;
	tv1.opDispatch!"x"= 3.14f;
	tv1.x= 3.14f;
	tv2.set!"z";
	tv2.z ~= &tv1;
	assert (tv2.z[0].x == 3.14f);
	tv2.y = 3.14f;
	assert (tv2 != tv1);
	tv2.x =3.14f;
	assert (tv2 == tv1);
}

private:

static class TVariantException : Exception {
	this(string msg,string file = __FILE__,int line = __LINE__) {
		super (msg,file,line);
	}
}

struct None{};

template ReplaceTypeRec(From,To,Types...){
	static if (Types.length == 0) {
		alias ReplaceTypeRec = AliasSeq!();
	}
	else static if (is(typeof(Types[0]) : string)) {
		alias ReplaceTypeRec = AliasSeq!(Types[0],ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else static if (isPointer!(Types[0])) {
		alias ReplaceTypeRec =
			AliasSeq!(
				ReplaceTypeRec!(From,To,PointerTarget!(Types[0]))[0]*,
				ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else static if (is(Types[0] == From)) {
		alias ReplaceTypeRec = AliasSeq!(To,ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else static if (__traits(isStaticArray,Types[0])) {
		enum len = Types[0].length;
		alias Base = ForeachType!(Types[0]);
		alias ReplaceTypeRec = AliasSeq!(ReplaceTypeRec!(From,To,Base)[0][len],ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else static if (__traits(isAssociativeArray,Types[0])) {
		alias Key = KeyType!(Types[0]);
		alias Base = ForeachType!(Types[0]);
		alias ReplaceTypeRec = AliasSeq!(ReplaceTypeRec!(From,To,Base)[0][ReplaceTypeRec!(From,To,Key)[0]],ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else static if (isDynamicArray!(Types[0])) {
		alias Base = ForeachType!(Types[0]);
		alias ReplaceTypeRec = AliasSeq!(ReplaceTypeRec!(From,To,Base)[0][],ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else static if (__traits(compiles,TemplateOf!(Types[0]))) {
		alias Base = TemplateOf!(Types[0]);
		alias Args = TemplateArgsOf!(Types[0]);
		alias ReplaceTypeRec = AliasSeq!(Base!(ReplaceTypeRec!(From,To,Args)),ReplaceTypeRec!(From,To,Types[1..$]));
	}
	else {
		alias ReplaceTypeRec = AliasSeq!(Types[0],ReplaceTypeRec!(From,To,Types[1..$]));
	}
}
unittest {
	import std.typecons : Tuple;
	static assert (is(
		ReplaceTypeRec!(int,float,AliasSeq!(Tuple!(int*,int),real,int*)) == AliasSeq!(Tuple!(float*,float),real,float*)));
	static assert (is(
		ReplaceTypeRec!(int,byte,AliasSeq!(int[int],int[],int[3])) == AliasSeq!(byte[byte],byte[],byte[3])));
}
