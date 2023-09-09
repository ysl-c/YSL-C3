module yslc.lexer;

import std.stdio;
import std.format;
import std.string;
import std.algorithm;
import yslc.error;
import yslc.language;
import yslc.preprocessor;

enum TokenType {
	Null,
	Keyword,
	Identifier,
	Integer,
	String,
	EndLine
}

struct Token {
	TokenType type;
	string    contents;
	string    file;
	size_t    line;

	string toString() {
		return format("(%s:%d) %s: %s", file, line, type, contents);
	}
}

class Lexer {
	Token[]    tokens;
	string     reading;
	size_t     line;
	size_t     col;
	CodeLine[] program;
	bool       success;

	this() {
		
	}

	Token AddToken(TokenType type) {
		string contents = reading;
		reading         = "";
		return Token(type, contents, program[line].file, program[line].line);
	}

	char CurrentChar() {
		return program[line].contents[col];
	}

	ErrorInfo GetErrorInfo() {
		return ErrorInfo(program[line].file, program[line].line);
	}

	void AddReading(ref Token[] tokens) {
		if (reading.strip() == "") {
			return;
		}
		else if (reading.isNumeric()) {
			tokens ~= AddToken(TokenType.Integer);
		}
		else if (Language.keywords.canFind(reading)) {
			tokens ~= AddToken(TokenType.Keyword);
		}
		else {
			tokens ~= AddToken(TokenType.Identifier);
		}
	}
	
	Token[] LexLine() {
		Token[] ret;
		bool    inString = false;

		for (col = 0; col < program[line].contents.length; ++ col) {
			if (inString) {
				switch (CurrentChar()) {
					case '\\': {
						++ col;

						char ch;

						try {
							ch = Language.EscapeChar(CurrentChar());
						}
						catch (LanguageException e) {
							ErrorUnknownEscape(GetErrorInfo(), CurrentChar());
							success = false;
							return ret;
						}

						reading ~= ch;
						break;
					}
					case '"': {
						inString = false;
						ret ~= AddToken(TokenType.String);
						break;
					}
					default: {
						reading ~= CurrentChar();
					}
				}
			}
			else {
				switch (CurrentChar()) {
					case '\t':
					case ' ': {
						AddReading(ret);
						break;
					}
					case '"': {
						inString = true;
						break;
					}
					case '#': {
						goto end;
					}
					default: {
						reading ~= CurrentChar();
					}
				}
			}
		}

		AddReading(ret);

		end:
		ret ~= AddToken(TokenType.EndLine);
		return ret;
	}

	void Lex() {
		success = true;
		
		for (line = 0; line < program.length; ++ line) {
			tokens ~= LexLine();
		}
	}

	void Dump() {
		foreach (ref token ; tokens) {
			writeln(token);
		}
	}
}
