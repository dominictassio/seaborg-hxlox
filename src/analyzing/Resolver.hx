package analyzing;

import interpreting.Interpreter;
import parsing.ast.Expr;
import parsing.ast.Stmt;
import scanning.Token;

class Resolver {
	private final interpreter:Interpreter;
	private final scopes:Array<Map<String, Bool>> = [];
	private var currentClassType:ClassType = None;
	private var currentFunctionType:FunctionType = None;

	public function new(interpreter) {
		this.interpreter = interpreter;
	}

	public function resolve(statements:Array<Stmt>) {
		for (statement in statements)
			resolveStmt(statement);
	}

	private function resolveBlockStmt(stmts) {
		beginScope();
		resolve(stmts);
		endScope();
	}

	private function resolveClassDecl(name, superclass, methods) {
		final enclosingClassType = currentClassType;
		currentClassType = Class;
		declare(name);
		define(name);
		if ((superclass : Null<Variable>) != null && name.lexeme == superclass.name.lexeme)
			Lox.parseError(superclass.name, "A class can't inherit from itself.");
		if (superclass != null) {
			currentClassType = Subclass;
			resolveVariableExpr(VariableExpr(superclass), superclass.name);
		}
		if (superclass != null) {
			beginScope();
			scopes[scopes.length - 1]["super"] = true;
		}
		beginScope();
		scopes[scopes.length - 1]["this"] = true;
		for (method in (methods : Array<Function>)) {
			var declaration = FunctionType.Method;
			if (method.name.lexeme == "init")
				declaration = Initializer;
			resolveFunction(method.params, method.body, declaration);
		}
		endScope();
		if (superclass != null)
			endScope();
		currentClassType = enclosingClassType;
	}

	private function resolveExprStmt(value) {
		resolveExpr(value);
	}

	private function resolveFunDecl(name, params, body) {
		declare(name);
		define(name);
		resolveFunction(params, body, Function);
	}

	private function resolveIfStmt(condition, consequent, alternative) {
		resolveExpr(condition);
		resolveStmt(consequent);
		if (alternative != null)
			resolveStmt(alternative);
	}

	private function resolvePrintStmt(value) {
		resolveExpr(value);
	}

	private function resolveReturnStmt(keyword, value) {
		if (currentFunctionType.equals(None))
			Lox.parseError(keyword, "Can't return from top-level code.");
		if (value != null) {
			if (currentFunctionType.equals(Initializer))
				Lox.parseError(keyword, "Can't return a value from an initializer.");
			resolveExpr(value);
		}
	}

	private function resolveVarDecl(name, value) {
		declare(name);
		if (value != null)
			resolveExpr(value);
		define(name);
	}

	private function resolveWhileStmt(cond, body) {
		resolveExpr(cond);
		resolveStmt(body);
	}

	private function resolveStmt(stmt) {
		switch stmt {
			case BlockStmt(stmts):
				resolveBlockStmt(stmts);
			case ClassDecl(name, superclass, methods):
				resolveClassDecl(name, superclass, methods);
			case ExprStmt(value):
				resolveExprStmt(value);
			case FunDecl(fun):
				resolveFunDecl(fun.name, fun.params, fun.body);
			case IfStmt(cond, cons, alt):
				resolveIfStmt(cond, cons, alt);
			case PrintStmt(value):
				resolvePrintStmt(value);
			case ReturnStmt(keyword, value):
				resolveReturnStmt(keyword, value);
			case VarDecl(name, value):
				resolveVarDecl(name, value);
			case WhileStmt(cond, body):
				resolveWhileStmt(cond, body);
			case None:
				null;
		}
	}

	public function resolveAssignExpr(expr, name, value) {
		resolveExpr(value);
		resolveLocal(expr, name);
	}

	public function resolveBinaryExpr(left, right) {
		resolveExpr(left);
		resolveExpr(right);
	}

	public function resolveCallExpr(callee, args) {
		resolveExpr(callee);
		for (arg in (args : Array<Expr>))
			resolveExpr(arg);
	}

	public function resolveGetExpr(object) {
		resolveExpr(object);
	}

	public function resolveGroupingExpr(value) {
		resolveExpr(value);
	}

	public function resolvePrefixExpr(right) {
		resolveExpr(right);
	}

	public function resolveSetExpr(object, value) {
		resolveExpr(value);
		resolveExpr(object);
	}

	public function resolveSuperExpr(expr, keyword) {
		switch currentClassType {
			case None:
				Lox.parseError(keyword, "Can't use 'super' outside of a class.");
			case Class:
				Lox.parseError(keyword, "Can't use 'super' in a class with no superclass.");
			default:
				null;
		}
		resolveLocal(expr, keyword);
	}

	private function resolveThisExpr(expr, keyword) {
		if (currentClassType.equals(None))
			Lox.parseError(keyword, "Can't use 'this' outside of a class.");
		else
			resolveLocal(expr, keyword);
	}

	private function resolveVariableExpr(expr, name:Token) {
		if (scopes.length != 0 && scopes[scopes.length - 1][name.lexeme] == false)
			Lox.parseError(name, "Can't read local variable in its own initializer.");
		resolveLocal(expr, name);
	}

	private function resolveExpr(expr:Expr) {
		switch expr {
			case AssignExpr(name, value):
				resolveAssignExpr(expr, name, value);
			case BinaryExpr(left, _, right):
				resolveBinaryExpr(left, right);
			case CallExpr(callee, _, args):
				resolveCallExpr(callee, args);
			case GetExpr(object, _):
				resolveGetExpr(object);
			case GroupingExpr(value):
				resolveGroupingExpr(value);
			case LiteralExpr(_):
				null;
			case LogicalExpr(left, _, right):
				resolveBinaryExpr(left, right);
			case PrefixExpr(_, right):
				resolvePrefixExpr(right);
			case SetExpr(object, _, value):
				resolveSetExpr(object, value);
			case SuperExpr(keyword, _):
				resolveSuperExpr(expr, keyword);
			case ThisExpr(keyword):
				resolveThisExpr(expr, keyword);
			case VariableExpr(variable):
				resolveVariableExpr(expr, variable.name);
		}
	}

	private function resolveFunction(params, body, type) {
		final enclosingFunctionType = currentFunctionType;
		currentFunctionType = type;
		beginScope();
		for (param in (params : Array<Token>)) {
			declare(param);
			define(param);
		}
		resolve(body);
		endScope();
		currentFunctionType = enclosingFunctionType;
	}

	private function resolveLocal(expr:Expr, name:Token) {
		var index = scopes.length - 1;
		while (index >= 0) {
			final scope = scopes[index];
			if (scope.exists(name.lexeme)) {
				interpreter.resolve(expr, scopes.length - 1 - index);
				return;
			}
			index -= 1;
		}
	}

	private function beginScope() {
		scopes.push([]);
	}

	private function endScope() {
		scopes.pop();
	}

	private function declare(name:Token) {
		if (scopes.length == 0)
			return;
		final scope = scopes[scopes.length - 1];
		if (scope.exists(name.lexeme))
			Lox.parseError(name, "Already variable with this name in this scope.");
		scope[name.lexeme] = false;
	}

	private function define(name:Token) {
		if (scopes.length == 0)
			return;
		scopes[scopes.length - 1][name.lexeme] = true;
	}
}
