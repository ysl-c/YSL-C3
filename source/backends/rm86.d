module yslc.backends.rm86;

// Real Mode x86 backend
// made for MS-DOS, NightlightOS and general real mode OSDev

import std.file;
import std.format;
import std.algorithm;
import yslc.parser;
import yslc.compiler;

struct Function {
	string func;
	string assembly;
}

class BackendRM86 : CompilerBackend {
	string      assembly;
	BlockType[] blocks;
	string[]    strings;
	string[]    functions;

	void PopBlock() {
		blocks = blocks.remove(blocks.length - 1);
	}

	override void Init() {
		assembly = "goto __func__main\n";
	}

	override void Finish() {
		std.file.write(outFile, assembly);
	}

	override void CompileFunctionStart(FunctionStartNode node) {
		assembly  ~= format("__func__%s:\n", node.name);
		blocks    ~= BlockType.FunctionDefinition;
		assembly  ~= "push bp\nmov bp, sp\n";
		functions = Function(node.name, "");
	}

	override void CompileEnd() {
		assembly ~= "pop bp\nret\n";
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
				break; // TODO
			}
			default: assert(0);
		}
	}

	override void CompileFunctionCall(FunctionCallNode node) {
		foreach (ref param ; node.parameters) {
			CompileParameter(param);
		}

		assembly ~= format("call __func__%s\n", node.func);
	}
}
