# dmatch
[![Build Status](https://travis-ci.org/namachan10777/dmatch.svg?branch=develop)](https://travis-ci.org/namachan10777/dmatch)

*This repository under development...*

[Japanese ver](./README.ja.md)
## Overview
Pattern matching for D
## Description
* match and disasemble Tuple,Range,Array,Struct,Class.
* Suport guard expression.
* Tagged Variant

## Example
### sample code
this code doesn't work now.
```
int add_all(int[] list){
	mixin(pmatch!(list,q{
		[] => return 0;
		[x] ~ xs => x + return add_all(xs);
	}));
}
```
### sample pattern

#### InputRange
```
x::xs
[]
x::[]
```
#### Array
```
[]
[x]
[x,_]
[x] ~ xs
xs ~ [x]
```

#### Tuple
```
[x,_]
[x,y]
```
#### Class and Struct
```
{x = alpha}
{x = alpha,y = beta}
```
#### std.variant.Algebraic and Variant
```
x:int
[x]~xs : real[]
[x:int[]]~xs
```
#### Input Range
```
x::xs
x::y::xs
```
#### Tagged Variant
```
x:Num
[x]~xs:Array
[x:Num]~xs
```
#### Complex
```
[(x,_)] ~ xs
{[x]~_ : alpha,{z : theta} : beta}
{Num x : theta}
```
# Sytax difination
strings literal, charcter literal, floating point literal and interger literal are defined as 'literal'.
Allowed Identifier names are defined as 'identifier'
## PEG

```
                   bind <- identifier
				   rval <- literal
                 record <- '{' patterns '=' identifier (',' patterns '=' identifier)* '}'
                bracket <- patterns
variant_accept_patterns <- array | record | bind
                variant <- variant_accept_patterns ':' identifier
     as_accept_patterns <- record | bracket | record | variant | bind | rval
                     as <- as_accept_patterns ('@' as_accept_patterns)+
  range_accept_patterns <- as | array | variant | record | bind
                  range <- (range_accept_patterns "::")+ bind
          array_element <- '[' (patterns (',' patterns)+)? ']'
                  array <- ((array_element | bind) ('~' (array_element | bind))+) | array_element
               patterns <- as | array | range | variant | record | bind | rval | "[]"
```

## BNF
```
         bind ::= identifier
         rval ::= literal
       record ::= '{' patterns '=' identifier (',' patterns '=' identifier)* '}'
      bracket ::= '(' patterns ')'
      variant ::= (array | record | bracket | bind | rval) ':' identifier
           as ::= patterns ('@' patterns)+
        range ::= (patterns "::")+ identifier
array_element ::= '[' (patterns (',' patterns)*)? ']'
        array ::= (array_element | bind) ('~' (array_element | bind))*
	 patterns ::= as | range | array | variant | record | bracket | bind | rval
```
