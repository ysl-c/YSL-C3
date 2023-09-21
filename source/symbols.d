module yslc.symbols;

struct Parameter {
	string name;
	string type;
}

struct Function {
	string      name;
	Parameter[] params;
	string      returns;
}
