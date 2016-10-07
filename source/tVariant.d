module tvariant;

import std.variant : VariantException,VariantN,maxSize,This;
import std.typecons : Tuple;
import std.meta : AliasSeq;

alias None = void;

static class TVariantException : VariantException {
	this (string msg) {
		super(msg);
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

	template TypeFromTag(string tag,FieldSpecs...) {
		static if (FieldSpecs.length == 0) {
			static assert (0,"this tag : \"" ~ tag ~ "\" is valid" );
		}
		else static if (FieldSpecs[0].name == tag){
			alias TypeFromTag = FieldSpecs[0].Type;
		}
		else {
			alias TypeFromTag = TypeFromTag!(tag,FieldSpecs[1..$]);
		}
	}
	unittest {
		alias specs1 = AliasSeq!(FieldSpec!(int,"x"),FieldSpec!(real,"y"),FieldSpec!(int,"z"));
		static assert (is (TypeFromTag!("x",specs1) == int));
		static assert (is (TypeFromTag!("y",specs1) == real));
		static assert (is (TypeFromTag!("z",specs1) == int));

		alias specs2 = AliasSeq!(FieldSpec!(None,"x"),FieldSpec!(None,"y"),FieldSpec!(None,"z"));
		static assert (is (TypeFromTag!("x",specs2) == None));
		static assert (is (TypeFromTag!("y",specs2) == None));
		static assert (is (TypeFromTag!("z",specs2) == None));
	}
public:
	VariantN!(maxSize!(TypeSpecs!fieldSpecs),TypeSpecs!fieldSpecs) data;
	@property void opDispatch(string tag,T)(T x) {
		static if (is(T == TVariant!(Specs)*)) {
			data = x.data;
		} else {
			_tag = tag;
			data = x;
		}
	}
	@property auto opDispatch(string tag)() {
		if (_tag != tag)
			throw new TVariantException("TVariant: attempting to use incompatible tag " ~ tag);
		return data.get!(TypeFromTag!(tag,fieldSpecs));
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
	TVariant!(int,"x",int,"y",int,"z") tv1;
	tv1.x = 1;
	tv1.y = 2;
	tv1.z = 3;
	assert (tv1.z == 3);

	TVariant!("x","y","z") tv2;
	tv2.set!"x";
	assert (tv2.tag == "x");

	TVariant!(int,"x",double,"y",This*,"This") tv3,tv4;
	tv3.x = 1;
	tv3.y = 3.14;
	
	tv4.x = 2;
	tv3.This = &tv4;
}
