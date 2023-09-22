module yslc.backends.c99;

// C99 backend
// Compiles YSL-C to C99

import std.file;
import std.format;
import std.algorithm;
import yslc.error;
import yslc.parser;
import yslc.compiler;

class BackendC99 : CompilerBackend {
	string res; // output C code

	override void Init() {
		res ~= "#include <stdint.h>\n";
	}
	
	override void Finish() {
		std.file.write(outFile, res);
	}

	string TypeAsCType(string type) {
		switch (type) {
			case "void": return "void";
			case "u8":   return "uint8_t";
			case "i8":   return "int8_t";
			case "u16":  return "uint16_t";
			case "i16":  return "int16_t";
			case "u32":  return "uint32_t";
			case "i32":  return "int32_t";
			case "u64":  return "uint64_t";
			case "i64":  return "int64_t";
			case "addr": return "void*";
			default:     throw new BackendException(format("Unknown type: %s", type));
		}
	}

	string IntVariableAsCType(IntVariable variable) {
		switch (variable.size) {
			case 1:  return variable.signed? "int8_t"  : "uint8_t";
			case 2:  return variable.signed? "int16_t" : "uint16_t";
			case 4:  return variable.signed? "int32_t" : "uint32_t";
			case 8:  return variable.signed? "int64_t" : "uint64_t";
			default: assert(0);
		}
	}
	
	override void CompileFunctionStart(FunctionStartNode node) {
		res ~= TypeAsCType(node.returns) ~ ' ';
		res ~= format("%s(", node.name);

		foreach (i, ref param ; node.parameters) {
			res ~= format("%s %s", TypeAsCType(node.types[i]), param);

			if (i < node.parameters.length - 1) {
				res ~= ", ";
			}
		}

		res ~= format(") {\n");
	}
	
	override void CompileEnd(EndNode node) {
		res ~= "}\n";
	}

	void CompileParameter(Node pnode) {
		switch (pnode.type) {
			case NodeType.String: {
				auto node = cast(StringNode) pnode;
				res ~= format("\"%s\"", node.value);
				break;
			}
			case NodeType.Integer: {
				auto node = cast(IntegerNode) pnode;
				res ~= format("%d", node.value);
				break;
			}
			case NodeType.Variable: {
				auto node = cast(VariableNode) pnode;
				res ~= node.name;
				break;
			}
			default: assert(0);
		}
	}
	
	override void CompileFunctionCall(FunctionCallNode node) {
		if (node.saves) {
			res ~= format("%s = ", node.saveTo);
		}
	
		res ~= format("%s(", node.func);

		foreach (i, ref param ; node.parameters) {
			CompileParameter(param);

			if (i < node.parameters.length - 1) {
				res ~= ", ";
			}
		}

		res ~= ");\n";
	}
	
	override void CompileAsm(AsmNode node) {
		res     ~= node.code ~ '\n';
		success  = false;
	}
	
	override void CompileLet(Variable variable) {
		switch (variable.type) {
			case VariableType.Integer: {
				res ~= format(
					"%s %s;\n", IntVariableAsCType(cast(IntVariable) variable),
					variable.name
				);
				break;
			}
			default: assert(0);
		}
	}
	
	override void CompileSet(SetNode node) {
		res ~= format("%s = ", node.varName);
		CompileParameter(node.value);
		res ~= ";\n";
	}
	
	override void CompileReturn(ReturnNode node) {
		res ~= "return ";
		CompileParameter(node.value);
		res ~= ";\n";
	}

	override void CompileBind(BindNode node) {
		res ~= format("%s %s(", TypeAsCType(node.returnType), node.name);

		foreach (i, ref arg ; node.types) {
			res ~= format("%s", TypeAsCType(arg));

			if (i < node.types.length - 1) {
				res ~= ", ";
			}
		}

		res ~= ");\n";
	}

	override void CompileIf(IfNode node) {
		res ~= "if (";
		CompileFunctionCall(node.check);
		res = res[0 .. $ - 2]; // remove ;
		res ~= ") {";
	}

	override void CompileWhile(WhileNode node) {
		res ~= "while (";
		CompileFunctionCall(node.check);
		res = res[0 .. $ - 2]; // remove ;
		res ~= ") {";
	}
}
