module dmatch.core.analyzer;
import dmatch.core.parser : AST,NodeType;

enum Type {
	Array,
	Record,
	As,
	Bind,
	RVal,
	Range
}

class Inter {
	Type type;
	string data;
	Inter[] children;
	long pos = -1;	//-1なら不定
	string tag;	//Recordパターンの場合のメンバ名	
	this(Type type,string data,Inter[] children,long pos = -1,string tag = "") {
		this.type = type;
		this.data = data;
		this.children = children;
		this.pos = pos;
		this.tag = tag;
	}
}

Inter analyze(immutable(AST) tree) {
	switch(tree.type) {
		case NodeType.Bind :
			return new Inter(Type.Bind,tree.data,[]);
		default : 
			throw new Exception("Unknown Node");
	}
}

unittest {
}
