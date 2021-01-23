package parsing.ast;

import scanning.Token;
import parsing.ast.Expr;

enum Stmt {
	BlockStmt(stmts:Array<Stmt>);
	ClassDecl(name:Token, superclass:Null<Variable>, methods:Array<Function>);
	ExprStmt(value:Expr);
	FunDecl(fun:Function);
	IfStmt(cond:Expr, cons:Stmt, alt:Null<Stmt>);
	PrintStmt(value:Expr);
	ReturnStmt(keyword:Token, value:Null<Expr>);
	VarDecl(name:Token, value:Null<Expr>);
	WhileStmt(cond:Expr, body:Stmt);
	None;
}

class Function {
	public final name:Token;
	public final params:Array<Token>;
	public final body:Array<Stmt>;

	public function new(name, params, body) {
		this.name = name;
		this.params = params;
		this.body = body;
	}
}
