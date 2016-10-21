module tvariant;

import std.variant : VariantException,VariantN,maxSize,This;
import std.typecons : Tuple,ReplaceType,tuple,Nullable;
import std.meta : AliasSeq;
import std.traits;
import std.array : replace;
import std.format : format;

import std.stdio;

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
	static assert (is(
		ReplaceTypeRec!(int,float,AliasSeq!(Tuple!(int*,int),real,int*)) == AliasSeq!(Tuple!(float*,float),real,float*)));
	static assert (is(
		ReplaceTypeRec!(int,byte,AliasSeq!(int[int],int[],int[3])) == AliasSeq!(byte[byte],byte[],byte[3])));
}

struct TVariant(Specs...){
private:
	template Data(Specs...) {
		template Members(Specs...) {
			static if (Specs.length == 0) {
				enum Members = "";
			}
			else static if (is(typeof(Specs[0]) : string)) {
				enum Members = format("None %s;",Specs[0]) ~ Members!(Specs[1..$]);
			}
			else static if (is(Specs[0]) && is(typeof(Specs[1]) : string)) {
				enum Members = format("%s %s;",Specs[0].stringof,Specs[1]) ~ Members!(Specs[2..$]);
			}
			else {
				static assert (0,"Cannot Find Tag");
			}
		}
		mixin ("union __Data{"~Members!Specs~"}");
		alias Data = __Data;
	}

	ref auto this2TVariant(T)(ref T x) {
		static if (is(ReplaceTypeRec!(This,TVariant!Specs,T)[0] == T)) {
			return x;
		}
		else {
			auto ptr = cast(ReplaceTypeRec!(This,TVariant!Specs,T)[0]*)&x;
			return *ptr;
		}
	}

	ref auto tVariant2This(T)(ref T x) {
		static if (is(ReplaceTypeRec!(TVariant!Specs,This,T)[0] == T)) {
			return x;
		}
		else {
			auto ptr = cast(ReplaceTypeRec!(TVariant!Specs,This,T)[0]*)&x;
			return *ptr;
		}
	}


	Data!Specs data;
	string _tag;

public:
	string tag() {
		return _tag;
	}
	/++
		Setter
	+/
	auto set(string tag)(){
		mixin("data."~tag) = typeof(mixin("data."~tag)).init;
		_tag = tag;
	}
	auto set(string tag)(ReplaceTypeRec!(This,TVariant!Specs,typeof(mixin("data."~tag)))[0] x) {
		import std.stdio;
		static assert (__traits(hasMember,typeof(data),tag),format("tag %s is not exist",tag));
		static assert (is(typeof(mixin("data."~tag)) == typeof(tVariant2This(x))),
						format("tag : %s type is %s. but argment type is %s",
							typeof(mixin("data."~tag).stringof,
							typeof(tVariant2This(x)).stringof)));
		mixin("data."~tag) = tVariant2This(x);
		_tag = tag;
	}
	/++
		Getter
	+/
	ref auto get(string tag)(){
		static if (hasMember!(typeof(data),tag)) {
			if (tag != _tag) {
				throw new TVariantException(format("Now tag is %s",_tag));
			}
			return this2TVariant(mixin("data."~tag));
		}
		else {
			static assert (0,format("tag %s is not exist",tag));
		}
	}
	auto opDispatch(string tag,T)(T x) {
		this.set!tag(x);
	}
	ref auto opDispatch(string tag)() {
		return get!tag;	
	}
}

unittest {
	import std.stdio;
	TVariant!(int,"x",double,"y",This*[],"z") tv1,tv2;
	tv1.y = 3.14;
	tv2.set!"z";
	tv2.z ~= &tv1;
	assert (tv2.z[0].y == 3.14);
	static assert (!__traits(compiles,tv1.w));
}
