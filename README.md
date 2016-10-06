# tVariant
## Overview
Tagged Variant for D
## Example
```
alias V = TVariant!(int,"x"int,"y",This*,"z");
V v1,v2;
v1.x = 5;
//v1.y = 3.14; compile error
v2.y = -3;
v1.z = v2;
```
