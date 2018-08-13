module dmatch.core.newparser;

import pegged.grammar;

mixin(grammar(`
Dmatch:
	Pattern < Range / As / Variant / Record / Bracket / Array / Bind

	Keyword <~ "if"

	Bind < Symbol

	Symbol < !Keyword [a-zA-Z_] ([a-zA-Z0-9_])*

	Template < Symbol "!" Symbol / "(" (Symbol / Template) ("," (Symbol / Template))* ")"

	Bracket < "(" Pattern ")"
	
	As < Pattern "@" Pattern

	ArrayElem < ("[" (Pattern ("," Pattern)*)? "]")
	Array < ArrayElem / ((ArrayElem / Symbol) ("~" (ArrayElem / Symbol))+)

	Variant < Pattern ":" Template

	Range < Pattern ( "::" Pattern )+

	Pair < Pattern "=" Symbol
	Record < "{" Pair ( "," Pair )* "}"
`));

unittest {
	auto p = Dmatch("a");
	import std.stdio;
	p.writeln;
}
