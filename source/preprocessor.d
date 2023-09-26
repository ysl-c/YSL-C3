module yslc.preprocessor;

import std.uni;
import std.file;
import std.path;
import std.array;
import std.format;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import yslc.error;
import yslc.split;

struct CodeLine {
	string file;
	size_t line;
	string contents;

	string toString() {
		return format("(%s:%d) %s", file, line, contents);
	}
}

CodeLine[] RunPreprocessor(
	string file, string[] includePaths, ref string[] included, bool ignoreInclude
) {
	CodeLine[] ret;
	string[]   code    = readText(file).replace("\r\n", "\n").split("\n");
	bool       success = true;

	foreach (i, ref line ; code) {
		if (line.empty()) {
			continue;
		}

		auto error = ErrorInfo(file, i);
	
		if (line[0] == '%') {
			auto parts = Split(file, i, line, &success);

			switch (parts[0]) {
				case "%include": {
					if (ignoreInclude) continue;
				
					string localPath = dirName(file) ~ "/" ~ parts[1];

					if (included.canFind(localPath)) {
						break;
					}
					
					if (!exists(localPath)) {
						bool exist = false;

						foreach (ref path ; includePaths) {
							localPath = path ~ "/" ~ parts[1];
							
							if (exists(localPath)) {
								exist = true;

								if (included.canFind(localPath)) {
									break;
								}

								included ~= localPath;
								
								ret ~= RunPreprocessor(
									localPath, includePaths, included, ignoreInclude
								);
								
								break;
							}
						}

						if (exist) {
							break;
						}
						
						ErrorNoSuchFile(error, localPath);
						success = false;
						break;
					}

					included ~= localPath;
					ret      ~= RunPreprocessor(
						localPath, includePaths, included, ignoreInclude
					);
					break;
				}
				default: {
					ErrorUnknownDirective(error, parts[0]);
					success = false;
					break;
				}
			}
		}
		else if (line.strip().empty()) {
			continue;
		}
		else if (line.strip()[0] == '#') {
			// comment
			continue;
		}
		else {
			ret ~= CodeLine(
				file, // file name
				i,    // line number
				line  // line contents
			);
		}
	}

	if (!success) {
		exit(1);
	}

	return ret;
}
