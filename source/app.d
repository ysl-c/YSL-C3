module yslc.app;

import std.path;
import std.stdio;
import std.format;
import std.string;
import std.process;
import yslc.lexer;
import yslc.parser;
import yslc.compiler;
import yslc.preprocessor;
import yslc.backends.c99;
import yslc.backends.rm86;

const string appUsage = "
Usage: %s {FILE} [options]

Options:
	-h  / --help                : Show this usage
	-o  / --out {FILE}          : Tell the compiler where to put the output
	-t  / --tokens              : Shows lexer output
	-a  / --ast                 : Shows parser output
	-p  / --preprocessor        : Show preprocessor output
	-b  / --target {BACKEND}    : Choose backend to compile with
	-fc / --final {COMMAND}     : Runs the given command after compilation with the
	                              user's shell
	-af / --append-final {TEXT} : Appends the given text to the final command
	-sf / --show-functions      : Shows functions from the given source file

Backends:
	rm86 - For x86 real mode/MS-DOS
	c99  - Compiles to C99 code (also sets final command to C compiler call)
";

int main(string[] args) {
	string inFile;
	string outFile    = "out.asm";
	string backendArg = "c99";
	bool   showPreprocessor = false;
	bool   showTokens       = false;
	bool   showAST          = false;
	string runFinal         = "";
	bool   defaultFinal     = true;
	bool   showFunctions    = false;

	assert(args.length >= 1);

	if (args.length == 1) {
		writefln(appUsage.strip(), args[0]);
		return 0;
	}

	for (size_t i = 1; i < args.length; ++ i) {
		if (args[i][0] == '-') {
			switch (args[i]) {
				case "-h":
				case "--help": {
					writefln(appUsage.strip(), args[0]);
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
				case "-b":
				case "--target": {
					++ i;
					
					if (i >= args.length) {
						stderr.writefln(
							"Missing filename after %s", args[i - 1]
						);
						return 1;
					}

					backendArg = args[i];
					break;
				}
				case "-fc":
				case "--final": {
					++ i;
					
					if (i >= args.length) {
						stderr.writefln(
							"Missing filename after %s", args[i - 1]
						);
						return 1;
					}

					runFinal     = args[i];
					defaultFinal = false;
					break;
				}
				case "-af":
				case "--append-final": {
					++ i;
					
					if (i >= args.length) {
						stderr.writefln(
							"Missing filename after %s", args[i - 1]
						);
						return 1;
					}

					runFinal ~= args[i];
					break;
				}
				case "-sf":
				case "--show-functions": {
					showFunctions = true;
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

	if (showFunctions) {
		foreach (ref node ; parser.ast.statements) {
			switch (node.type) {
				case NodeType.FunctionStart:
				case NodeType.Overload: {
					writeln(node);
					break;
				}
				default: continue;
			}
		}
		return 0;
	}

	CompilerBackend backend;

	switch (backendArg) {
		case "rm86": {
			backend         = new BackendRM86();
			backend.outFile = outFile;
			break;
		}
		case "c99": {
			backend         = new BackendC99();
			backend.outFile = outFile ~ ".c";
			if (defaultFinal) {
				runFinal = format(
					"cc %s -o %s -std=c99 -O2 %s && rm %s",
					backend.outFile, outFile, runFinal, backend.outFile
				);
			}
			break;
		}
		default: {
			stderr.writefln("Unknown backend %s", backendArg);
			return 1;
		}
	}

	Compiler compiler        = new Compiler();
	compiler.backend         = backend;
	compiler.ast             = parser.ast;
	compiler.Compile();

	if (!compiler.backend.success) {
		stderr.writeln("Compilation failed");
		return 1;
	}

	if (runFinal != "") {
		auto res = executeShell(runFinal);

		if (res.status != 0) {
			stderr.writefln(
				"Final command failed:Command: %s\n\n%s\n", runFinal, res.output
			);
		}
	}
	return 0;
}
