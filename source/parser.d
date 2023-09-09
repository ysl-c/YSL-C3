module yslc.parser;

import std.conv;
import std.format;
import yslc.error;
import yslc.lexer;

enum BlockType {
	FunctionDefinition
}

enum NodeType {
	Null,
	Program,
	FunctionStart,
	End,
	FunctionCall,
	String,
	Integer,
	Variable,
	Asm
}

class Node {
	NodeType type;

	override string toString() {
		return "";
	}
}

class ProgramNode : Node {
	Node[] statements;

	this() {
		type = NodeType.Program;
	}

	override string toString() {
		string ret;

		foreach (ref statement ; statements) {
			ret ~= statement.toString() ~ '\n';
		}

		return ret;
	}
}

class FunctionStartNode : Node {
	string name;

	this() {
		type = NodeType.FunctionStart;
	}

	override string toString() {
		return format("func %s", name);
	}
}

class EndNode : Node {
	this() {
		type = NodeType.End;
	}

	override string toString() {
		return "end";
	}
}

class FunctionCallNode : Node {
	string func;
	Node[] parameters;

	this() {
		type = NodeType.FunctionCall;
	}

	override string toString() {
		string ret = func;

		foreach (ref node ; parameters) {
			ret ~= " " ~ node.toString();
		}

		return ret;
	}
}

class StringNode : Node {
	string value;

	this() {
		type = NodeType.String;
	}

	override string toString() {
		return format("\"%s\"", value);
	}
}

class IntegerNode : Node {
	long value;

	this() {
		type = NodeType.Integer;
	}

	override string toString() {
		return format("%d", value);
	}
}

class VariableNode : Node {
	string name;

	this() {
		type = NodeType.Variable;
	}

	override string toString() {
		return name;
	}
}

class AsmNode : Node {
	string code;

	this() {
		type = NodeType.Asm;
	}

	override string toString() {
		return format("asm %s", code);
	}
}

class EndParsingException : Exception {
	this() {
		super("", "", 0);
	}
}

class Parser {
	Token[]     tokens;
	size_t      i;
	bool        success;
	ProgramNode ast;

	ErrorInfo GetErrorInfo() {
		return ErrorInfo(tokens[i].file, tokens[i].line);
	}

	void Next() {
		++ i;

		if (i >= tokens.length) {
			-- i;
			success = false;
			ErrorEndOfTokens(GetErrorInfo());
		}
	}

	void ExpectType(TokenType type) {
		if (tokens[i].type != type) {
			ErrorExpected(GetErrorInfo(), text(type), text(tokens[i].type));
			throw new EndParsingException();
		}
	}

	FunctionStartNode ParseFunc() {
		auto ret = new FunctionStartNode();

		Next();
		ExpectType(TokenType.Identifier);

		ret.name = tokens[i].contents;
		return ret;
	}

	Node ParseParameter() {
		switch (tokens[i].type) {
			case TokenType.Integer: {
				auto ret  = new IntegerNode();
				ret.value = parse!long(tokens[i].contents);
				return ret;
			}
			case TokenType.String: {
				auto ret  = new StringNode();
				ret.value = tokens[i].contents;
				return ret;
			}
			case TokenType.Identifier: {
				auto ret = new VariableNode();
				ret.name = tokens[i].contents;
				return ret;
			}
			default: assert(0);
		}
	}

	FunctionCallNode ParseFunctionCall() {
		auto ret = new FunctionCallNode();

		ret.func = tokens[i].contents;

		Next();

		while (tokens[i].type != TokenType.EndLine) {
			ret.parameters ~= ParseParameter();
			Next();
		}

		-- i;

		return ret;
	}

	AsmNode ParseAsm() {
		auto ret = new AsmNode();
		ret.code = tokens[i].contents;
		return ret;
	}

	Node ParseStatement() {
		switch (tokens[i].type) {
			case TokenType.Keyword: {
				switch (tokens[i].contents) {
					case "func": return cast(Node) ParseFunc();
					case "end":  return cast(Node) new EndNode();
					default:     assert(0);
				}
			}
			case TokenType.Asm: {
				return cast(Node) ParseAsm();
			}
			case TokenType.Identifier: return cast(Node) ParseFunctionCall();
			default: assert(0);
		}
	}

	void Parse() {
		success = true;
		ast     = new ProgramNode();
		
		for (i = 0; i < tokens.length; ++ i) {
			Node statement;
			
			try {
				statement = ParseStatement();
			}
			catch (EndParsingException) {
				success = false;
				return;
			}

			ast.statements ~= statement;

			Next();
			ExpectType(TokenType.EndLine);
		}
	}
}
