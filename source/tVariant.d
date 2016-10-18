module tvariant;

import std.variant : VariantException,VariantN,maxSize,This;
import std.typecons : Tuple,ReplaceType,tuple,Nullable;
import std.meta : AliasSeq;
import std.traits : isPointer,PointerTarget,TemplateArgsOf,TemplateOf,hasMember;
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

	auto this2TVariant(T)(T x) {
		static if (is(ReplaceTypeRec!(This,TVariant!Specs,T)[0] == T)) {
			return x;
		}
		else {
			auto ptr = cast(ReplaceTypeRec!(This,TVariant!Specs,T)[0]*)&x;
			return *ptr;
		}
	}

	auto tVariant2This(T)(T x) {
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
	/++
		Setter
	+/
	auto set(string tag,T)(T x) {
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
	auto get(string tag)(){
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
	auto opDispatch(string tag)() {
		static if (hasMember!(typeof(data),tag)) {
			Nullable!(typeof(this2TVariant(mixin("data."~tag)))) r;
			if (tag == _tag)
				r = this2TVariant(mixin("data."~tag));
			return r;
		}
		else {
			static assert (false);
		}
	}
}

unittest {
	TVariant!(int,"x",double,"y",This*,"z") tv1,tv2;
	tv1.y = 3.14;
	tv2.z = &tv1;
	assert (tv2.z.y.get == 3.14);
	assert (tv2.x.isNull);
	static assert (!__traits(compiles,tv1.w));
}
