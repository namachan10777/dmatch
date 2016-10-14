module tvariant;

import std.variant : VariantException,VariantN,maxSize,This;
import std.typecons : Tuple,ReplaceType,tuple;
import std.meta : AliasSeq;
import std.traits : isPointer,PointerTarget;

import std.stdio;

private:

alias None = void;

public:

enum isType(T) = true;
enum isType(alias T) = false;

template MutilateTemplate(X : T!P,alias T,P...) {
	enum isTemplate = true;
	alias Template = T;
	alias Parameters = P;
}
template MutilateTemplate(X...) {
	enum isTemplate = false;
	alias Template = void;
	alias Parameters = void;
}
unittest {
	static assert (MutilateTemplate!(Tuple!(int,real)).isTemplate);
	static assert (is(MutilateTemplate!(Tuple!(int,real)).Parameters == AliasSeq!(int,real)));
	static assert (is(MutilateTemplate!(Tuple!(int,real)).Template!(int,real) == Tuple!(int,real)));

	static assert (!MutilateTemplate!int.isTemplate);
	static assert (!MutilateTemplate!"x".isTemplate);
}

template hasT(T,Specs...) {
	import std.traits : isPointer,PointerTarget;
	static if (Specs.length == 0) {
		enum hasT = false;
	}
	else static if (is(Specs[0] == T)) {
		enum hasT = true;
	}
	else static if (!isType!(Specs[0])) {
		enum hasT = hasT!(T,Specs[1..$]);
	}
	else static if (isPointer!(Specs[0])){
		enum hasT = hasT!(T,PointerTarget!(Specs[0]),Specs[1..$]);
	}
	else static if (MutilateTemplate!(Specs[0]).isTemplate){
		alias Mutilated = MutilateTemplate!(Specs[0]);
		enum hasT =
			hasT!(T,Mutilated.Parameters,Specs[1..$]);
	}
	else {
		enum hasT =
			hasT!(T,Specs[1..$]);
	}
}
unittest {
	static assert (hasT!(short,AliasSeq!(string,int,short,real)));
	static assert (hasT!(short*,AliasSeq!(int,Tuple!(int,short*))));
	static assert (hasT!(short,AliasSeq!(int,Tuple!(int,short*))));
}

template ReplaceTypeRecurse(From,To,T...) {
	static if (T.length == 0) {
		alias ReplaceTypeRecurse = AliasSeq!();
	}
	else static if (!isType!(T[0])) {
		alias ReplaceTypeRecurse =
			AliasSeq!(
				T[0],
				ReplaceTypeRecurse!(From,To,T[1..$]));
	}
	else static if (is(T[0] == From)) {
		alias ReplaceTypeRecurse =
			AliasSeq!(To,ReplaceTypeRecurse!(From,To,T[1..$]));
	}
	else static if (isPointer!(T[0])) {
		alias ReplaceTypeRecurse =
			AliasSeq!(
				ReplaceTypeRecurse!(From,To,PointerTarget!(T[0]))[0]*,
				ReplaceTypeRecurse!(From,To,T[1..$]));	
	}
	else {
		alias Mutilated = MutilateTemplate!(T[0]);
		static if (Mutilated.isTemplate) {
			alias ReplaceTypeRecurse =
				AliasSeq!(
					Mutilated.Template!(
						ReplaceTypeRecurse!(From,To,Mutilated.Parameters)),
					ReplaceTypeRecurse!(From,To,T[1..$]));
		}
		else {
			alias ReplaceTypeRecurse =
				AliasSeq!(T[0],ReplaceTypeRecurse!(From,To,T[1..$]));
		}
	}
}
unittest {
	static assert (is(ReplaceTypeRecurse!(int,double,AliasSeq!(float,int,real)) == AliasSeq!(float,double,real)));
	static assert (is(ReplaceTypeRecurse!(int,real,Tuple!(int,bool)) == AliasSeq!(Tuple!(real,bool))));
	static assert (is(ReplaceTypeRecurse!(int,real,Tuple!(int,int)) == AliasSeq!(Tuple!(real,real))));
	static assert (is(ReplaceTypeRecurse!(int,real,Tuple!(int,string,Tuple!(int,int))) == AliasSeq!(Tuple!(real,string,Tuple!(real,real)))));
	static assert (is(ReplaceTypeRecurse!(int*,real*,Tuple!(int,string,Tuple!(int*,int*)*)) == AliasSeq!(Tuple!(int,string,Tuple!(real*,real*)*))));
}

static class TVariantException : Exception {
	this (string msg,size_t line = __LINE__,string file = __FILE__) {
		super(msg,file,line);
	}
}

struct TVariant(Specs...) {
private:
	string _tag;
    template FieldSpec(T, string s) {
        alias Type = T;
        alias name = s;
    }

	template parseSpecs(Specs...)
    {
        static if (Specs.length == 0) {
            alias parseSpecs = AliasSeq!();
        }
        else static if (is(Specs[0])) {
            static if (is(typeof(Specs[1]) : string)) {
                alias parseSpecs =
                    AliasSeq!(FieldSpec!(Specs[0 .. 2]),
                              parseSpecs!(Specs[2 .. $]));
            }
			else{
				static assert(0, "Attempted to instantiate TVariant with an "
	                            ~"invalid argument: "~ Specs[0].stringof);
            }
        }
		else {
			alias parseSpecs =
				AliasSeq!(FieldSpec!(None,Specs[0]),
							parseSpecs!(Specs[1..$]));
        }
    }
	unittest {
		import std.stdio;
		static assert ( is(typeof(parseSpecs!(int,"x",real,"y","z"))
							== typeof(AliasSeq!(FieldSpec!(int,"x"),FieldSpec!(real,"y"),FieldSpec!(None,"z")))));
		static assert ( is(typeof(parseSpecs!("x","y","z"))
							== typeof(AliasSeq!(FieldSpec!(None,"x"),FieldSpec!(None,"y"),FieldSpec!(None,"z")))));
		static assert ( is(typeof(parseSpecs!("x"))
							== typeof(AliasSeq!(FieldSpec!(None,"x")))));
	}

	alias allowedSpecs = ReplaceTypeRecurse!(This*,TVariant!Specs*,Specs);
	alias fieldSpecs = parseSpecs!Specs;

	template TypeSpecs(FieldSpecs...) {
		static if (FieldSpecs.length == 0) {
			alias TypeSpecs = AliasSeq!();
		}
		else {
			alias TypeSpecs =
				AliasSeq!(FieldSpecs[0].Type,
							TypeSpecs!(FieldSpecs[1..$]));
		}
	}
	unittest {
		alias specs = AliasSeq!(FieldSpec!(int,"x"),FieldSpec!(real,"y"),FieldSpec!(string,"z"));
		static assert (is (TypeSpecs!specs == AliasSeq!(int,real,string)));
	}

	template IndexFromTag(string tag,FieldSpecs...){
		static if (FieldSpecs.length == 0) {
			static assert (0,"this tag : \"" ~ tag ~ "\" is valid");
		}
		else static if (FieldSpecs[0].name == tag) {
			enum IndexFromTag = 0;
		}
		else {
			enum IndexFromTag = 1 + IndexFromTag!(tag,FieldSpecs[1..$]);
		}
	}
	unittest {
		alias specs1 = AliasSeq!(FieldSpec!(int,"x"),FieldSpec!(real,"y"),FieldSpec!(int,"z"));
		static assert (IndexFromTag!("x",specs1) == 0);
		static assert (IndexFromTag!("y",specs1) == 1);
		static assert (IndexFromTag!("z",specs1) == 2);
	}
public:
	VariantN!(maxSize!(TypeSpecs!fieldSpecs),TypeSpecs!fieldSpecs) data;
	@property void opDispatch(string tag,T)(T x) {
		alias SType = TypeSpecs!(fieldSpecs)[IndexFromTag!(tag,fieldSpecs)];
		static if (hasT!(This,SType)) {
			auto targetTypePtr = cast(ReplaceTypeRecurse!(This*,typeof(data)*,SType)[0]*)&x;
			_tag = tag;
			data = *targetTypePtr;
		}
		else {
			_tag = tag;
			data = x;
		}
	}
	@property auto opDispatch(string tag)() {
		if (_tag != tag)
			throw new TVariantException("TVariant: attempting to use incompatible tag " ~ tag);
		alias RType = fieldSpecs[IndexFromTag!(tag,fieldSpecs)].Type;
		static if (is(RType == void)) {
			pragma(msg,"tag : "~tag~" type is void");
		}
		else static if (hasT!(This,RType)){
			auto r = data.get!(IndexFromTag!(tag,fieldSpecs));
			auto targetTypePtr = cast(ReplaceTypeRecurse!(This*,typeof(this)*,RType)[0]*)&r;
			return *targetTypePtr;
		}
		else {
			return data.get!(IndexFromTag!(tag,fieldSpecs));
		}
	}
	@property string tag (){
		return _tag;
	}
	@property void tag(string tag){
		_tag = tag;
	}
	@property void set(string tag)(){
		_tag = tag;
	}
}

unittest {
	TVariant!(int,"x",Tuple!(This*,This*),"child") v1,v2,v3;
	v2.x = 1;
	v1.child = tuple(&v2,&v3);
	assert (v1.child[0].x == 1);
}
