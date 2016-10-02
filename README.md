# dmatch
## Overview
Pattern matching for D
## Description
* match and disasemble Tuple,Range,Array,Struct,Class.
* Suport guard expression.

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
//Tuple
(x,y)
(x,_)
```
#### Class and Struct
```
{x : alpha}
{x : alpha,y : beta}
```

#### Composite
```
[(x,_)] ~ xs
{[x,...] : alpha,{z : theta} : beta}
```
