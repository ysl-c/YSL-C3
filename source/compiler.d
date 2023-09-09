module yslc.compiler;

import yslc.parser;

class CompilerBackend {
	string outFile;

	abstract void Init();	
	abstract void Finish();
	abstract void CompileFunctionStart(FunctionStartNode node);
	abstract void CompileEnd();
	abstract void CompileFunctionCall(FunctionCallNode node);
}

class Compiler {
	CompilerBackend backend;
	ProgramNode     ast;

	this() {
		
	}

	void Compile() {
		backend.Init();

		foreach (ref node ; ast.statements) {
			switch (node.type) {
				case NodeType.FunctionStart: {
					backend.CompileFunctionStart(cast(FunctionStartNode) node);
					break;
				}
				case NodeType.End: {
					backend.CompileEnd();
					break;
				}
				case NodeType.FunctionCall: {
					backend.CompileFunctionCall(cast(FunctionCallNode) node);
					break;
				}
				default: assert(0);
			}
		}

		backend.Finish();
	}
}
