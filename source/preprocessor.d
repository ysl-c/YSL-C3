module yslc.preprocessor;

import std.uni;
import std.file;
import std.path;
import std.array;
import std.format;
import std.stdio;
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
	string file, string[] includePaths, ref string[] included, bool ignoreInclude,
	string[] preInclude, bool firstRun
) {
	CodeLine[] ret;
	string[]   code    = readText(file).replace("\r\n", "\n").split("\n");
	bool       success = true;

	void Include(string path, ErrorInfo error) {
		if (included.canFind(path)) {
			return;
		}

		string localPath = path;
		
		if (!exists(path)) {
			bool exist = false;
			
			foreach (ref ipath ; includePaths) {
				localPath = ipath ~ "/" ~ path;
				
				if (exists(localPath)) {
					exist = true;

					if (included.canFind(localPath)) {
						break;
					}

					included ~= localPath;
					
					ret ~= RunPreprocessor(
						localPath, includePaths, included, ignoreInclude, [], false
					);
					
					break;
				}
			}

			if (exist) {
				goto includeFinishUp;
			}
			
			ErrorNoSuchFile(error, path);
			success = false;
			return;
		}

		includeFinishUp:
		included ~= localPath;
		ret      ~= RunPreprocessor(
			localPath, includePaths, included, ignoreInclude, [],
			false
		);
	}

	if (firstRun) {
		auto error = ErrorInfo("<program params>", 0);
		foreach (ref path ; preInclude) {
			Include(path, error);
		}
	}

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

					Include(localPath, error);
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
