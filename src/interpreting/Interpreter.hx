package interpreting;

import interpreting.native.Clock;
import parsing.ast.Expr;

class Interpreter {
	public final globals = new Environment();

	private final locals:Map<Expr, Int> = [];
	private var environment:Environment;

	public function new() {
		// globals.define('clock', new Clock());
		environment = globals;
	}

	public function resolve(expression, depth) {
		locals[expression] = depth;
	}
}
