module yslc.compiler;

import std.algorithm;
import yslc.error;
import yslc.parser;

enum VariableType {
	Integer
}

class Variable {
	VariableType type;
	string       name;
	bool         pointer;
	bool         array;
	size_t       stackOffset;
	size_t       size; // total size in bytes
}

class IntVariable : Variable {
	bool signed;

	this(string pname, size_t psize, bool psigned, bool ppointer = false) {
		switch (psize) {
			case 1:
			case 2:
			case 4:
			case 8: break;
			default: assert(0);
		}

		name    = pname;
		type    = VariableType.Integer;
		size    = psize;
		pointer = ppointer;
		signed  = psigned;
	}
}

class CompilerBackend {
	string     outFile;
	Variable[] locals;
	size_t     topStackOffset;
	bool       success;

	Variable GetLocal(string name) {
		foreach (ref var ; locals) {
			if (var.name == name) {
				return var;
			}
		}

		return null;
	}

	void AllocateLocal(Variable var) {
		var.stackOffset  = topStackOffset;
		topStackOffset  += var.size;
		locals          ~= var;
	}

	abstract void Init();	
	abstract void Finish();
	abstract void CompileFunctionStart(FunctionStartNode node);
	abstract void CompileEnd(EndNode node);
	abstract void CompileFunctionCall(FunctionCallNode node);
	abstract void CompileAsm(AsmNode node);
	abstract void CompileLet(Variable variable);
	abstract void CompileSet(SetNode node);
	abstract void CompileReturn(ReturnNode node);
	abstract void CompileBind(BindNode node);
}

Variable TypeToVariable(string var, string type) {
	switch (type) {
		case "u8": {
			return new IntVariable(var, 1, false);
		}
		case "u16": {
			return new IntVariable(var, 2, false);
		}
		case "u32": {
			return new IntVariable(var, 4, false);
		}
		case "u64": {
			return new IntVariable(var, 8, false);
		}
		case "i8": {
			return new IntVariable(var, 1, true);
		}
		case "i16": {
			return new IntVariable(var, 2, true);
		}
		case "i32": {
			return new IntVariable(var, 4, true);
		}
		case "i64": {
			return new IntVariable(var, 8, true);
		}
		default: {
			return null;
		}
	}
}

class Compiler {
	CompilerBackend backend;
	ProgramNode     ast;

	this() {
		
	}

	void Compile() {
		backend.Init();
		backend.success = true;

		foreach (ref node ; ast.statements) {
			switch (node.type) {
				case NodeType.FunctionStart: {
					backend.CompileFunctionStart(cast(FunctionStartNode) node);
					break;
				}
				case NodeType.End: {
					backend.locals = [];
					backend.CompileEnd(cast(EndNode) node);
					break;
				}
				case NodeType.FunctionCall: {
					backend.CompileFunctionCall(cast(FunctionCallNode) node);
					break;
				}
				case NodeType.Asm: {
					backend.CompileAsm(cast(AsmNode) node);
					break;
				}
				case NodeType.Let: {
					auto     let = cast(LetNode) node;
					Variable var = TypeToVariable(let.var, let.varType);

					if (var is null) {
						ErrorUnknownType(node.GetErrorInfo(), let.varType);
						backend.success = false;
						continue;
					}

					backend.AllocateLocal(var);
					backend.CompileLet(var);
					break;
				}
				case NodeType.Set: {
					auto set = cast(SetNode) node;

					if (backend.GetLocal(set.varName) is null) {
						ErrorUndefinedVariable(node.GetErrorInfo(), set.varName);
						backend.success = false;
						continue;
					}

					backend.CompileSet(set);
					break;
				}
				case NodeType.Return: {
					// TODO: type checking
					backend.CompileReturn(cast(ReturnNode) node);
					break;
				}
				case NodeType.Bind: {
					backend.CompileBind(cast(BindNode) node);
					break;
				}
				default: assert(0);
			}
		}

		backend.Finish();
	}
}
