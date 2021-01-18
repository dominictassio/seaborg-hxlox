package parsing;

import scanning.TokenType;
import parsing.ast.Expression;
import parsing.ast.Statement;
import scanning.Token;

class Parser {
	private final tokens:Array<Token>;
	private var current = 0;

	public function new(tokens) {
		this.tokens = tokens;
	}

	public function parse() {
		final statements = new Array<Statement>();
		while (!isAtEnd()) {
			final statement = parseDeclaration();
			if (statement != null)
				statements.push(statement);
		}
		return statements;
	}

	private function parseDeclaration():Null<Statement> {
		try {
			return switch (peek().type) {
				case Class:
					parseClassDeclaration();
				case Fun:
					parseFunctionDeclaration();
				case Var:
					parseVariableDeclaration();
				default:
					parseStatement();
			};
		} catch (error:ParseException) {
			synchronize();
			return null;
		}
	}

	private function parseClassDeclaration() {
		advance(); // Consume 'class' keyword.
		final name = consume(Identifier, 'Expect class name.');
		var superclass = if (match([Less])) new Variable(consume(Identifier, 'Expect superclass name.')) else null;
		consume(LeftBrace, 'Expect \'{\' before class body.');
		final methods = [];
		while (!check(RightBrace) && !isAtEnd())
			methods.push(parseFunction("method"));
		consume(RightBrace, 'Expect \'}\' after class body.');
		return Class(name, superclass, methods);
	}

	private function parseFunctionDeclaration() {
		advance(); // Consume 'fun' keyword
		return Function(parseFunction("function"));
	}

	private function parseFunction(kind:String) {
		final name = consume(Identifier, 'Expect $kind name.');
		consume(LeftParen, 'Expect \'(\' after $kind name.');
		final parameters = [];
		if (!check(RightParen))
			do {
				if (parameters.length >= 255) {
					error(peek(), 'Can\'t have more than 255 parameters.');
				}
				parameters.push(consume(Identifier, 'Expect parameter name.'));
			} while (match([Comma]));
		consume(RightParen, 'Expect \')\' after parameters');
		consume(LeftBrace, 'Expect \'{\' before $kind body.');
		final body = parseBlock();
		return new Function(name, parameters, body);
	}

	private function parseVariableDeclaration() {
		advance(); // Consume 'var' keyword
		final name = consume(Identifier, 'Expect variable name.');
		final initializer = if (match([Equal])) parseExpression() else null;
		consume(Semicolon, 'Expect \';\' after variable declaration.');
		return Variable(name, initializer);
	}

	private function parseStatement() {
		return switch (peek().type) {
			case For:
				parseForStatement();
			case If:
				parseIfStatement();
			case Print:
				parsePrintStatement();
			case Return:
				parseReturnStatement();
			case While:
				parseWhileStatement();
			case LeftBrace:
				parseBlockStatement();
			default:
				parseExpressionStatement();
		}
	}

	private function parseForStatement() {
		advance(); // Consume 'for' keyword
		consume(LeftParen, 'Expect \'(\' after \'for\'.');
		final initializer = switch (peek().type) {
			case Semicolon:
				advance();
				null;
			case Var:
				parseVariableDeclaration();
			default:
				parseExpressionStatement();
		};
		final condition = if (!check(Semicolon)) parseExpression() else Literal(Boolean(true));
		consume(Semicolon, 'Expect \';\' after loop condition.');
		final increment = if (!check(RightParen)) parseExpression() else null;
		consume(RightParen, 'Expect \')\' after for clauses.');
		var body = parseStatement();
		if (increment != null)
			body = Block([body, Expression(increment)]);
		body = While(condition, body);
		if (initializer != null)
			body = Block([initializer, body]);
		return body;
	}

	private function parseIfStatement() {
		advance(); // Consume 'if' keyword
		consume(LeftParen, 'Expect \'(\' after \'if\'.');
		final condition = parseExpression();
		consume(RightParen, 'Expect \')\' after if condition.');
		final consequent = parseStatement();
		final alternative = if (match([Else])) parseStatement() else null;
		return If(condition, consequent, alternative);
	}

	private function parsePrintStatement() {
		advance(); // Consume 'print' keyword
		final expression = parseExpression();
		consume(Semicolon, 'Expect \';\' after value.');
		return Print(expression);
	}

	private function parseReturnStatement() {
		advance(); // Consume 'return' keyword
		final keyword = previous();
		final expression = if (!check(Semicolon)) parseExpression() else null;
		consume(Semicolon, 'Expect \';\' after return value.');
		return Return(keyword, expression);
	}

	private function parseWhileStatement() {
		advance(); // Consume 'while' keyword
		consume(LeftParen, 'Expect \'(\' after \'whie\'.');
		final condition = parseExpression();
		consume(RightParen, 'Expect \')\' after condition.');
		final body = parseStatement();
		return While(condition, body);
	}

	private function parseBlockStatement() {
		return Block(parseBlock());
	}

	private function parseBlock() {
		advance(); // Consume '{'
		final statements = new Array<Statement>();
		while (!check(RightBrace) && !isAtEnd()) {
			final statement = parseDeclaration();
			if (statement != null)
				statements.push(statement);
		}
		consume(RightBrace, 'Expect \'}\' after block.');
		return statements;
	}

	private function parseExpressionStatement() {
		final expression = parseExpression();
		consume(Semicolon, 'Expect \';\' after expression.');
		return Expression(expression);
	}

	private function parseExpression() {
		return parseAssignment();
	}

	private function parseAssignment() {
		final expression = parseOr();
		if (match([Equal])) {
			final equals = previous();
			final value = parseAssignment();
			switch (expression) {
				case Variable(variable):
					return Assign(variable.name, value);
				case Get(object, name):
					return Set(object, name, value);
				default:
					error(equals, 'Invalid assignment target.');
			}
		}
		return expression;
	}

	private function parseOr() {
		return parseLogicalExpression([Or], parseAnd);
	}

	private function parseAnd() {
		return parseLogicalExpression([And], parseEquality);
	}

	private function parseLogicalExpression(operators, next) {
		var left = next();
		while (match(operators)) {
			final operator_ = previous();
			final right = next();
			left = Logical(left, operator_, right);
		}
		return left;
	}

	private function parseEquality() {
		return parseBinaryExpression([BangEqual, EqualEqual], parseComparison);
	}

	private function parseComparison() {
		return parseBinaryExpression([Greater, GreaterEqual, Less, LessEqual], parseSum);
	}

	private function parseSum() {
		return parseBinaryExpression([Minus, Plus], parseProduct);
	}

	private function parseProduct() {
		return parseBinaryExpression([Slash, Star], parsePrefix);
	}

	private function parsePrefix() {
		if (match([Bang, Minus])) {
			final operator_ = previous();
			final right = parsePrefix();
			return Prefix(operator_, right);
		}
		return parseCall();
	}

	private function parseCall() {
		var expression = parsePrimary();
		while (true) {
			switch (peek().type) {
				case LeftParen:
					advance();
					expression = finishCall(expression);
				case Period:
					advance();
					final name = consume(Identifier, 'Expect property name after \'.\'.');
					expression = Get(expression, name);
				default:
					break;
			}
		}
		return expression;
	}

	private function finishCall(callee:Expression) {
		final arguments = [];
		if (!check(RightParen)) {
			do {
				if (arguments.length >= 255) {
					error(peek(), 'Can\'t have more than 255 arguments.');
				}
				arguments.push(parseExpression());
			} while (match([Comma]));
		}
		final parenthesis = consume(RightParen, 'Expect \')\' after arguments.');
		return Call(callee, parenthesis, arguments);
	}

	private function parsePrimary() {
		final next = peek();
		final literal = next.literal;
		return switch (next.type) {
			case False:
				advance();
				Literal(Boolean(false));
			case True:
				advance();
				Literal(Boolean(true));
			case Nil:
				advance();
				Literal(Nil);
			case Number | String if (literal != null):
				advance();
				Literal(literal);
			case Super:
				final keyword = advance();
				consume(Period, 'Expect \'.\' after \'super\'.');
				final method = consume(Identifier, 'Expect superclass method name.');
				Super(keyword, method);
			case This:
				This(advance());
			case Identifier:
				(Variable(new Variable(advance())) : Expression);
			case LeftParen:
				advance();
				final expression = parseExpression();
				consume(RightParen, 'Expect \')\' after expression.');
				Grouping(expression);
			default:
				throw error(next, 'Expect expression');
		}
	}

	private function parseBinaryExpression(operators, next) {
		var left = next();
		while (match(operators)) {
			final operator_ = previous();
			final right = next();
			left = Binary(left, operator_, right);
		}
		return left;
	}

	private function match(types:Array<TokenType>) {
		for (type in types) {
			if (check(type)) {
				advance();
				return true;
			}
		}
		return false;
	}

	private function consume(type, message) {
		if (check(type))
			return advance();
		throw error(peek(), message);
	}

	private function check(type) {
		return if (isAtEnd()) false else peek().type.equals(type);
	}

	private function advance() {
		if (!isAtEnd())
			current += 1;
		return previous();
	}

	private function isAtEnd() {
		return peek().type.equals(Eof);
	}

	private function peek() {
		return tokens[current];
	}

	private function previous() {
		return tokens[current - 1];
	}

	private function error(token, message) {
		Lox.parseError(token, message);
		return new ParseException();
	}

	private function synchronize() {
		advance();
		while (!isAtEnd()) {
			if (previous().type.equals(Semicolon))
				return;
			switch (peek().type) {
				case Class | For | Fun | If | Print | Return | While:
					return;
				default:
					advance();
			}
		}
	}
}
