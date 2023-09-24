module yslc.compiler;

import std.conv;
import std.algorithm;
import yslc.error;
import yslc.parser;
import yslc.language;

enum VariableType {
	Integer,
	Address
}

class Variable {
	VariableType type;
	string       name;
	bool         array;
	size_t       stackOffset;
	size_t       size; // total size in bytes
}

class IntVariable : Variable {
	bool signed;

	this(string pname, size_t psize, bool psigned) {
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
		signed  = psigned;
	}
}

class AddressVariable : Variable {
	this(string pname) {
		name = pname;
		type = VariableType.Address;
	}
}

struct Function {
	string   name;
	string   returns;
	string[] params;
}

struct Overload {
	string   name;
	string[] functions;
}

class BackendException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class CompilerBackend {
	string      outFile;
	Variable[]  locals;
	BlockType[] blocks;
	size_t      topStackOffset;
	bool        success;
	Function[]  functions;
	string      currentFunction;

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

	void PopBlock() {
		blocks = blocks.remove(blocks.length - 1);
	}

	bool FunctionExists(string name) {
		foreach (ref func ; functions) {
			if (func.name == name) {
				return true;
			}
		}

		return false;
	}

	Function GetFunction(string name) {
		foreach (ref func ; functions) {
			if (func.name == name) {
				return func;
			}
		}

		assert(0);
	}

	bool ParametersMatch(string[] types, Node[] params) {
		if (types.length != params.length) return false;

		foreach (i, ref param ; params) {
			switch (param.type) {
				case NodeType.String: {
					if (types[i] != "addr") return false;
					break;
				}
				case NodeType.Integer: {
					if (!Language.intTypes.canFind(types[i])) return false;
					break;
				}
				case NodeType.Variable: {
					auto node = cast(VariableNode) param;
					auto var  = GetLocal(node.name);

					if (var is null) {
						ErrorUndefinedVariable(node.GetErrorInfo(), node.name);
					}

					switch (var.type) {
						case VariableType.Integer: {
							auto ivar = cast(IntVariable) var;

							if (ivar.signed) {
								switch (ivar.size) {
									case 1: if (types[i] != "i8")  return false; break;
									case 2: if (types[i] != "i16") return false; break;
									case 4: if (types[i] != "i32") return false; break;
									case 8: if (types[i] != "i64") return false; break;
									default: assert(0);
								}
							}
							else {
								switch (ivar.size) {
									case 1: if (types[i] != "u8")  return false; break;
									case 2: if (types[i] != "u16") return false; break;
									case 4: if (types[i] != "u32") return false; break;
									case 8: if (types[i] != "u64") return false; break;
									default: assert(0);
								}
							}
							break;
						}
						case VariableType.Address: {
							if (types[i] != "addr") return false;
							break;
						}
						default: assert(0);
					}
					break;
				}
				default: assert(0);
			}
		}

		return true;
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
	abstract void CompileIf(IfNode node);
	abstract void CompileWhile(WhileNode node);
	abstract void CompileFor(ForNode node);
}

Variable TypeToVariable(string var, string type) {
	switch (type) {
		case "u8":   return new IntVariable(var, 1, false);
		case "u16":  return new IntVariable(var, 2, false);
		case "u32":  return new IntVariable(var, 4, false);
		case "u64":  return new IntVariable(var, 8, false);
		case "i8":   return new IntVariable(var, 1, true);
		case "i16":  return new IntVariable(var, 2, true);
		case "i32":  return new IntVariable(var, 4, true);
		case "i64":  return new IntVariable(var, 8, true);
		case "addr": return new AddressVariable(var);
		default:     return null;
	}
}

class Compiler {
	CompilerBackend backend;
	ProgramNode     ast;
	Overload[]      overloads;

	this() {
		
	}

	bool OverloadExists(string name) {
		foreach (ref overload ; overloads) {
			if (overload.name == name) {
				return true;
			}
		}

		return false;
	}

	Overload GetOverload(string name) {
		foreach (ref overload ; overloads) {
			if (overload.name == name) {
				return overload;
			}
		}

		assert(0);
	}

	void Compile() {
		backend.Init();
		backend.success = true;

		// generate symbols(?)
		foreach (ref node ; ast.statements) {
			if (node.type != NodeType.FunctionStart) {
				continue;
			}

			auto funcNode = cast(FunctionStartNode) node;
			auto func = Function(funcNode.name, funcNode.returns, funcNode.types);

			backend.functions ~= func;
		}

		for (size_t i = 0; i < ast.statements.length; ++ i) {
			auto node = ast.statements[i];
			
			switch (node.type) {
				case NodeType.FunctionStart: {
					auto pnode = cast(FunctionStartNode) node;
				
					if (backend.currentFunction != "") {
						ErrorFunctionInsideFunction(node.GetErrorInfo());
						backend.success = false;
						continue;
					}

					foreach (j, ref type ; pnode.types) {
						string name = pnode.parameters[j];

						backend.AllocateLocal(TypeToVariable(name, type));
					}
				
					backend.currentFunction  = pnode.name;
					backend.blocks          ~= BlockType.Function;
					backend.CompileFunctionStart(pnode);
					break;
				}
				case NodeType.End: {
					if (backend.blocks.length == 0) {
						ErrorExtraEnd(node.GetErrorInfo());
						backend.success = false;
						continue;
					}

					if (backend.blocks[$ - 1] == BlockType.Function) {
						backend.locals          = [];
						backend.currentFunction = "";
					}
					
					backend.CompileEnd(cast(EndNode) node);
					backend.PopBlock();
					break;
				}
				case NodeType.FunctionCall: {
					auto pnode = cast(FunctionCallNode) node;

					if (OverloadExists(pnode.func)) {
						// decide which function to call
						auto overload = GetOverload(pnode.func);

						foreach (ref funcName ; overload.functions) {
							if (!backend.FunctionExists(funcName)) {
								ErrorCallingBrokenOverload(node.GetErrorInfo(), funcName);
								backend.success = false;
								break;
							}
						
							auto func = backend.GetFunction(funcName);

							if (backend.ParametersMatch(func.params, pnode.parameters)) {
								// this one should be called
								pnode.func = funcName;
								break;
							}
						}
					}
					else if (!backend.FunctionExists(pnode.func)) {
						ErrorCallingUndefinedFunction(node.GetErrorInfo(), pnode.func);
						backend.success = false;
						break;
					}
				
					backend.CompileFunctionCall(pnode);
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
					auto pnode = cast(BindNode) node;
					auto func  = Function(pnode.name, pnode.returnType, pnode.types);
					
					backend.functions ~= func;
					
					backend.CompileBind(pnode);
					break;
				}
				case NodeType.If: {
					backend.blocks ~= BlockType.If;
					backend.CompileIf(cast(IfNode) node);
					break;
				}
				case NodeType.While: {
					backend.blocks ~= BlockType.While;
					backend.CompileWhile(cast(WhileNode) node);
					break;
				}
				case NodeType.Overload: {
					Overload overload;
					overload.name = (cast(OverloadNode) node).name;

					++ i;
					for (; i < ast.statements.length; ++ i) {
						auto node2 = ast.statements[i];

						switch (node2.type) {
							case NodeType.FunctionCall: {
								auto pnode2 = cast(FunctionCallNode) node2;

								overload.functions ~= pnode2.func;
								break;
							}
							case NodeType.End: goto overloadDone;
							default: {
								ErrorUnexpectedStatement(
									node.GetErrorInfo(), text(node2.type)
								);
								backend.success = false;
								goto overloadEnd;
							}
						}
					}

					overloadDone:
					overloads ~= overload;

					overloadEnd:
					break;
				}
				case NodeType.For: {
					backend.blocks ~= BlockType.For;
					backend.CompileFor(cast(ForNode) node);
					break;
				}
				default: assert(0);
			}
		}

		backend.Finish();
	}
}
