module yslc.backends.rm86;

// Real Mode x86 backend
// made for MS-DOS, NightlightOS and general real mode OSDev

import std.file;
import std.format;
import std.algorithm;
import yslc.error;
import yslc.parser;
import yslc.compiler;

struct Function {
	string func;
	string assembly;
}

class BackendRM86 : CompilerBackend {
	string      assembly;
	string[]    strings;

	string SizeAsAsmType(size_t size) {
		switch (size) {
			case 1: return "byte";
			case 2: return "word";
			case 3: return "dword";
			case 4: return "qword";
			default: assert(0);
		}
	}

	override void Init() {
		// basically the runtime
		assembly ~= "mov bp, sp\n";
		assembly ~= "jmp __func__main\n";
	}

	override void Finish() {
		foreach (i, ref str ; strings) {
			assembly ~= format("__string__%d: db \"%s\", 0\n", i, str);
		}
		
		std.file.write(outFile, assembly);
	}

	override void CompileFunctionStart(FunctionStartNode node) {
		assembly  ~= format("__func__%s:\n", node.name);

		foreach (i, ref param ; node.parameters) {
			Variable var = TypeToVariable(param, node.types[i]);
			AllocateLocal(var);
		}
	}

	override void CompileEnd(EndNode node) {
		assembly ~= "pop bx\nmov sp, bp\npop bp\npush bx\n";
		assembly ~= "ret\n";
		
		PopBlock();
	}

	void CompileParameter(Node pnode) {
		switch (pnode.type) {
			case NodeType.String: {
				auto node = cast(StringNode) pnode;

				strings  ~= node.value;
				assembly ~= format("push __string__%d\n", strings.length - 1);
				break;
			}
			case NodeType.Integer: {
				auto node = cast(IntegerNode) pnode;

				assembly ~= format("push word %d\n", node.value);
				break;
			}
			case NodeType.Variable: {
				auto node = cast(VariableNode) pnode;
				auto var  = GetLocal(node.name);

				if (var.size == 1) {
					assembly ~= "mov bx, sp\n";
					assembly ~= format("lea si, [bp - %d]\n", var.stackOffset);
					assembly ~= "mov dl, [si]\n";
					assembly ~= "mov [bx], dl\n";
				}
				else {
					assembly ~= format(
						"push %s [bp - %d]\n", SizeAsAsmType(var.size),
						var.stackOffset
					);
				}
				break;
			}
			default: assert(0);
		}
	}

	override void CompileFunctionCall(FunctionCallNode node) {
		assembly ~= "push bp\n";
		assembly ~= "mov bp, sp\n";
		foreach (ref param ; node.parameters) {
			CompileParameter(param);
		}

		assembly ~= format("call __func__%s\n", node.func);
	}

	override void CompileAsm(AsmNode node) {
		assembly ~= format("%s\n", node.code);
	}

	override void CompileLet(Variable variable) {
		string type = SizeAsAsmType(variable.size);

		assembly ~= format("push %s 0\n", type);
	}

	override void CompileSet(SetNode node) {
		auto var = GetLocal(node.varName);
		CompileParameter(node.value);

		switch (var.size) {
			case 1: {
				assembly ~= "pop ax\n";
				assembly ~= format("mov [bp - %d], al\n", var.stackOffset);
				break;
			}
			case 2: {
				assembly ~= "pop ax\n";
				assembly ~= format("mov [bp - %d], ax\n", var.stackOffset);
				break;
			}
			case 4: {
				assembly ~= "pop eax\n";
				assembly ~= format("mov [bp - %d], eax\n", var.stackOffset);
				break;
			}
			case 8: {
				ErrorTypeUnsupported(node.GetErrorInfo());
				success = false;
				break;
			}
			default: assert(0);
		}
	}

	override void CompileReturn(ReturnNode node) {
		CompileParameter(node.value);
		assembly ~= "pop ax\nmov sp, bp\npop bp\nret\n";
	}

	override void CompileBind(BindNode node) {
		ErrorFeatureUnsupported(node.GetErrorInfo());
	}

	override void CompileIf(IfNode node) {
		assert(0); // TODO
	}
}
