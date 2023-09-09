module yslc.error;

import std.stdio;
import core.stdc.stdlib;
import yslc.preprocessor;

struct ErrorInfo {
	string file;
	size_t line;
}

void ErrorBegin(ErrorInfo info) {
	version (Windows) {
		stderr.writef("%s:%d: error: ", info.file, info.line + 1);
	}
	else {
		stderr.writef(
			"\x1b[1m%s:%d: \x1b[31merror:\x1b[0m ", info.file, info.line + 1
		);
	}
}

void ErrorUnknownEscape(ErrorInfo info, char ch) {
	ErrorBegin(info);
	stderr.writefln("Unknown escape sequence \\%c", ch);
}

void ErrorNoSuchFile(ErrorInfo info, string file) {
	ErrorBegin(info);
	stderr.writefln("No such file exists: '%s'", file);
}

void ErrorUnknownDirective(ErrorInfo info, string directive) {
	ErrorBegin(info);
	stderr.writefln("Unknown directive: '%s'", directive);
}

void ErrorEndOfTokens(ErrorInfo info) {
	ErrorBegin(info);
	stderr.writeln("Unexpected end of tokens");
}

void ErrorExpected(ErrorInfo info, string expected, string got) {
	ErrorBegin(info);
	stderr.writefln("Expected %s, got %s", expected, got);
}
