package parsing.ast;

import scanning.Literal;
import scanning.Token;

enum Expr {
	AssignExpr(name:Token, value:Expr);
	BinaryExpr(left:Expr, op:Token, right:Expr);
	CallExpr(callee:Expr, paren:Token, args:Array<Expr>);
	GetExpr(object:Expr, name:Token);
	GroupingExpr(value:Expr);
	LiteralExpr(value:Literal);
	LogicalExpr(left:Expr, op:Token, right:Expr);
	PrefixExpr(op:Token, right:Expr);
	SetExpr(object:Expr, name:Token, value:Expr);
	SuperExpr(keyword:Token, method:Token);
	ThisExpr(keyword:Token);
	VariableExpr(variable:Variable);
}

class Variable {
	public final name:Token;

	public function new(name) {
		this.name = name;
	}
}
