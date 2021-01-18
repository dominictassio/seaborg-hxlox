package parsing.ast;

import scanning.Literal;
import scanning.Token;

enum Expression {
	Assign(name:Token, value:Expression);
	Binary(left:Expression, operator_:Token, right:Expression);
	Call(callee:Expression, parenthesis:Token, arguments:Array<Expression>);
	Get(object:Expression, name:Token);
	Grouping(expression:Expression);
	Literal(value:Literal);
	Logical(left:Expression, operator_:Token, right:Expression);
	Prefix(operator_:Token, right:Expression);
	Set(object:Expression, name:Token, value:Expression);
	Super(keyword:Token, method:Token);
	This(keyword:Token);
	Variable(_:Variable);
}

class Variable {
	public final name:Token;

	public function new(name) {
		this.name = name;
	}
}
