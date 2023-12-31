module yslc.language;

import std.format;

class LanguageException : Exception {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

class Language {
	static const string[] keywords = [
		"func",
		"end",
		"let",
		"set",
		"return",
		"extern",
		"if",
		"while",
		"overload",
		"for"
	];

	static const string[] operators = [
		"->"
	];

	static const string[] intTypes = [
		"u8", "u16", "u32", "u64",
		"i8", "i16", "i32", "i64"
	];

	static char EscapeChar(char ch) {
		switch (ch) {
			case 'n':  return '\n';
			case 'e':  return '\x1b';
			case 'r':  return '\r';
			case '"':  return '"';
			case '\\': return '\\';
			case 'a':  return '\a';
			case 'b':  return '\b';
			case '0':  return '\0';
			case 't':  return '\t';
			case 'v':  return '\v';
			default:   throw new LanguageException(format("Invalid escape %c", ch));
		}
	}
}
