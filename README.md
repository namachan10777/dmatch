# dmatch
[![Build Status](https://travis-ci.org/namachan10777/dmatch.svg?branch=master)](https://travis-ci.org/namachan10777/dmatch)
[Japanese ver](./README.ja.md)
## Overview
Pattern matching for D
## Description
* match and disasemble Tuple,Range,Array,Struct,Class.
* Suport guard expression.
* Tagged Variant

## Example
### sample code
```
int add_all(int[] list){
	return pmatch!(int[],
			q{[] => return 0;},
			q{[x] ~ xs => return x + add_all(xs);})
			(list);
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
[x,_,...]
[x] ~ xs
xs ~ [x]
```
#### Tuple
```
(x,y)
(x,_)
```
#### Class and Struct
```
{x : alpha}
{x : alpha,y : beta}
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
#### Composite
```
[(x,_)] ~ xs
{[x,...] : alpha,{z : theta} : beta}
```
