package parsing.ast;

import scanning.Token;
import parsing.ast.Expression;

enum Statement {
	Block(statements:Array<Statement>);
	Class(name:Token, superclass:Null<Variable>, methods:Array<Function>);
	Expression(expression:Expression);
	Function(_:Function);
	If(condition:Expression, consequent:Statement, alternative:Null<Statement>);
	Print(expression:Expression);
	Return(keyword:Token, expression:Null<Expression>);
	While(condition:Expression, body:Statement);
	Variable(name:Token, initializer:Null<Expression>);
}

class Function {
	public final name:Token;
	public final parameters:Array<Token>;
	public final body:Array<Statement>;

	public function new(name, parameters, body) {
		this.name = name;
		this.parameters = parameters;
		this.body = body;
	}
}
