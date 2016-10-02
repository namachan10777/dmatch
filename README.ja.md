# dmatch
## Overview
D言語でパターンマッチするライブラリです.
## Description
Tuple,Range,Array,Struct,Classなどからなるデータ構造にマッチして分解することが出来ます.

ガードを用いてマッチする条件を追加する事も出来ます.
## Example
### サンプルコード
```
int add_all(int[] list){
	return pmatch!(int[],
			q{[] => return 0;},
			q{[x] ~ xs => return x + add_all(xs);})
			(list);
}
```
### パターンのサンプル

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
#### Complex
```
[(x,_)] ~ xs
{[x,...] : alpha,{z : theta} : beta}
```
