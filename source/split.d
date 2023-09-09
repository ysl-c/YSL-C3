module yslc.split;

import std.range;
import yslc.error;

string[] Split(string file, size_t line, string str, bool* success) {
	string[] ret;
	string   reading;
	bool     inString;

	ErrorInfo error = ErrorInfo(file, line);

	for (size_t i = 0; i < str.length; ++ i) {
		switch (str[i]) {
			case '\t':
			case ' ': {
				if (inString) {
					reading ~= str[i];
					break;
				}

				if (!reading.empty()) {
					ret ~= reading;
				}
				
				reading  = "";
				break;
			}
			case '"': {
				inString = !inString;
				break;
			}
			case '\\': {
				++ i;
				switch (str[i]) {
					case 'n': {
						reading ~= '\n';
						break;
					}
					case 'r': {
						reading ~= '\r';
						break;
					}
					case 'e': {
						reading ~= '\x1b';
						break;
					}
					default: {
						ErrorUnknownEscape(error, str[i]);
						*success = false;
					}
				}
				break;
			}
			default: {
				reading ~= str[i];
				break;
			}
		}
	}

	if (!reading.empty()) {
		ret ~= reading;
	}

	return ret;
}
