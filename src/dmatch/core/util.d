module dmatch.core.util;

import std.algorithm.iteration;
import std.compiler;
static if (version_major == 2 && version_minor < 71) {
	template fold(fun...) if (fun.length > 0) {
		auto fold(R,S)(R r,S seed) {
			return reduce!fun(seed,r);
		}
	}
}
