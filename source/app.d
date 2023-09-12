module yslc.app;

import std.stdio;
import yslc.lexer;
import yslc.parser;
import yslc.compiler;
import yslc.preprocessor;
import yslc.backends.rm86;

const string appUsage = "
Usage: %s {FILE} [options]

Options:
	-h / --help         : Show this usage
	-o / --out {FILE}   : Tell the compiler where to put the output
	-t / --tokens       : Shows lexer output
	-a / --ast          : Shows parser output
	-p / --preprocessor : Show preprocessor output
";

int main(string[] args) {
	string inFile;
	string outFile = "out.asm";
	bool   showPreprocessor = false;
	bool   showTokens       = false;
	bool   showAST          = false;

	for (size_t i = 1; i < args.length; ++ i) {
		if (args[i][0] == '-') {
			switch (args[i]) {
				case "-h":
				case "--help": {
					writeln(appUsage);
					return 0;
				}
				case "-o":
				case "--out": {
					++ i;
					
					if (i >= args.length) {
						stderr.writefln(
							"Missing filename after %s", args[i - 1]
						);
						return 1;
					}

					outFile = args[i];
					break;
				}
				case "-t":
				case "--tokens": {
					showTokens = true;
					break;
				}
				case "-a":
				case "--ast": {
					showAST = true;
					break;
				}
				case "-p":
				case "--preprocessor": {
					showPreprocessor = true;
					break;
				}
				default: {
					stderr.writefln(
						"Unrecognised command line option %s", args[i]
					);
					return 1;
				}
			}
		}
		else {
			if (inFile != "") {
				stderr.writefln("Source file defined multiple times");
				return 1;
			}

			inFile = args[i];
		}
	}

	string[] included;	
	auto program = RunPreprocessor(inFile, [], included);

	if (showPreprocessor) {
		foreach (ref line ; program) {
			writeln(line);
		}
		return 0;
	}

	auto lexer = new Lexer();
	lexer.program = program;
	lexer.Lex();

	if (!lexer.success) {
		stderr.writeln("Lexing failed");
		return 1;
	}

	if (showTokens) {
		lexer.Dump();
		return 0;
	}

	auto parser   = new Parser();
	parser.tokens = lexer.tokens;

	parser.Parse();

	if (!parser.success) {
		stderr.writeln("Parsing failed");
		return 1;
	}

	if (showAST) {
		writeln(parser.ast);
		return 0;
	}

	Compiler compiler        = new Compiler();
	compiler.backend         = new BackendRM86();
	compiler.ast             = parser.ast;
	compiler.backend.outFile = outFile;
	compiler.Compile();
	return 0;
}
