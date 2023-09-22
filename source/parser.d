module yslc.parser;

import std.conv;
import std.stdio;
import std.format;
import yslc.error;
import yslc.lexer;
import yslc.symbols;

enum BlockType {
	Function,
	If,
	While
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
	Asm,
	Let,
	Set,
	Return,
	Bind,
	If
}

class Node {
	NodeType type;
	string   file;
	size_t   line;

	override string toString() {
		return "";
	}

	ErrorInfo GetErrorInfo() {
		return ErrorInfo(file, line);
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
			ret ~= format("%s\n", statement.toString());
		}

		return ret;
	}
}

class FunctionStartNode : Node {
	string   name;
	string   returns;
	string[] parameters;
	string[] types;

	this() {
		type = NodeType.FunctionStart;
	}

	override string toString() {
		string ret = format("func %s", name);

		foreach (i, ref param ; parameters) {
			ret ~= format(" %s %s", types[i], param);
		}

		ret ~= format(" -> %s", returns);

		return ret;
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
	bool   saves;
	string saveTo;

	this() {
		type = NodeType.FunctionCall;
	}

	override string toString() {
		string ret = func;

		foreach (ref node ; parameters) {
			ret ~= " " ~ node.toString();
		}

		if (saves) {
			ret ~= format(" -> %s", saveTo);
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

class LetNode : Node {
	string varType;
	string var;

	this() {
		type = NodeType.Let;
	}

	override string toString() {
		return format("let %s %s", varType, var);
	}
}

class SetNode : Node {
	string varName;
	Node   value;

	this() {
		type = NodeType.Set;
	}

	override string toString() {
		return format("set %s %s", varName, value.toString());
	}
}

class ReturnNode : Node {
	Node value;

	this() {
		type = NodeType.Return;
	}

	override string toString() {
		return format("return %s", value.toString());
	}
}

class BindNode : Node {
	string   returnType;
	string   name;
	string[] types;

	this() {
		type = NodeType.Bind;
	}

	override string toString() {
		string ret = format("bind %s %s", returnType, name);

		foreach (ref arg ; types) {
			ret ~= format("%s ", arg);
		}

		return ret;
	}
}

class IfNode : Node {
	FunctionCallNode check;

	this() {
		type = NodeType.If;
	}

	override string toString() {
		return format("if %s", check.toString());
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

	void SetupNode(Node node) {
		node.file = tokens[i].file;
		node.line = tokens[i].line;
	}

	FunctionStartNode ParseFunc() {
		auto ret    = new FunctionStartNode();
		ret.returns = "void";
		SetupNode(ret);

		Next();
		ExpectType(TokenType.Identifier);

		ret.name = tokens[i].contents;

		Next();

		while (tokens[i].type != TokenType.EndLine) {
			if (tokens[i].type == TokenType.Identifier) {
				ExpectType(TokenType.Identifier);

				ret.types ~= tokens[i].contents;
				Next();
				ExpectType(TokenType.Identifier);
				ret.parameters ~= tokens[i].contents;
			}
			else if (
				(tokens[i].type == TokenType.Operator) && (tokens[i].contents == "->")
			) {
				Next();
				ExpectType(TokenType.Identifier);
				ret.returns = tokens[i].contents;
			}
			else {
				assert(0); // TODO: ERRORS!!!!!!!!!!!!!!!!!!!!!!!
			}
			
			Next();
		}

		-- i;
		
		return ret;
	}

	EndNode ParseEnd() {
		auto ret = new EndNode();
		SetupNode(ret);
		return ret;
	}

	Node ParseParameter() {
		switch (tokens[i].type) {
			case TokenType.Integer: {
				auto ret  = new IntegerNode();
				SetupNode(ret);
				
				ret.value = parse!long(tokens[i].contents);
				return ret;
			}
			case TokenType.String: {
				auto ret  = new StringNode();
				SetupNode(ret);
				
				ret.value = tokens[i].contents;
				return ret;
			}
			case TokenType.Identifier: {
				auto ret = new VariableNode();
				SetupNode(ret);
				
				ret.name = tokens[i].contents;
				return ret;
			}
			default: assert(0);
		}
	}

	FunctionCallNode ParseFunctionCall() {
		auto ret = new FunctionCallNode();
		SetupNode(ret);

		ret.func = tokens[i].contents;

		Next();

		while (tokens[i].type != TokenType.EndLine) {
			if ((tokens[i].type == TokenType.Operator) && (tokens[i].contents == "->")) {
				Next();
				ExpectType(TokenType.Identifier);
				ret.saves  = true;
				ret.saveTo = tokens[i].contents;
			}
			else {
				ret.parameters ~= ParseParameter();
			}
			Next();
		}

		-- i;

		return ret;
	}

	AsmNode ParseAsm() {
		auto ret = new AsmNode();
		SetupNode(ret);
		
		ret.code = tokens[i].contents;
		return ret;
	}

	LetNode ParseLet() {
		auto ret = new LetNode();
		SetupNode(ret);

		Next();
		ExpectType(TokenType.Identifier);

		ret.varType = tokens[i].contents;

		Next();
		ExpectType(TokenType.Identifier);
		
		ret.var = tokens[i].contents;
		return ret;
	}

	SetNode ParseSet() {
		auto ret = new SetNode();
		SetupNode(ret);

		Next();
		ExpectType(TokenType.Identifier);

		ret.varName = tokens[i].contents;

		Next();
		ret.value = ParseParameter();

		return ret;
	}

	ReturnNode ParseReturn() {
		auto ret = new ReturnNode();
		SetupNode(ret);

		Next();
		ret.value = ParseParameter();

		return ret;
	}

	BindNode ParseBind() {
		auto ret = new BindNode();
		SetupNode(ret);

		Next();
		ExpectType(TokenType.Identifier);
		ret.returnType = tokens[i].contents;

		Next();
		ExpectType(TokenType.Identifier);
		ret.name = tokens[i].contents;

		Next();
		while (tokens[i].type != TokenType.EndLine) {
			ExpectType(TokenType.Identifier);
			ret.types ~= tokens[i].contents;
			
			Next();
		}
		-- i;

		return ret;
	}

	IfNode ParseIf() {
		auto ret = new IfNode();
		SetupNode(ret);

		Next();
		ExpectType(TokenType.Identifier);
		ret.check = ParseFunctionCall();

		return ret;
	}

	Node ParseStatement() {
		switch (tokens[i].type) {
			case TokenType.Keyword: {
				switch (tokens[i].contents) {
					case "func":   return cast(Node) ParseFunc();
					case "end":    return cast(Node) ParseEnd();
					case "let":    return cast(Node) ParseLet();
					case "set":    return cast(Node) ParseSet();
					case "return": return cast(Node) ParseReturn();
					case "extern": return cast(Node) ParseBind();
					case "if":     return cast(Node) ParseIf();
					default:       assert(0);
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
