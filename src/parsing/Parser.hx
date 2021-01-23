package parsing;

import scanning.TokenType;
import parsing.ast.Expr;
import parsing.ast.Stmt;
import scanning.Token;

class Parser {
	private final tokens:Array<Token>;
	private var current = 0;

	public function new(tokens) {
		this.tokens = tokens;
	}

	public function parse() {
		final statements = [
			while (!isAtEnd()) {
				switch (parseDeclaration()) {
					case None:
						continue;
					case stmt:
						stmt;
				}
			}
		];
		return statements;
	}

	private function parseDeclaration() {
		return try {
			switch (peek().type) {
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
			None;
		}
	}

	private function parseClassDeclaration() {
		consume(Class, "Expect 'class'.");
		final name = consume(Identifier, "Expect class name.");
		var superclass = if (match([Less])) {
			new Variable(consume(Identifier, "Expect superclass name."));
		} else {
			null;
		};
		consume(LeftBrace, "Expect '{' before class body.");
		final methods = [];
		while (!check(RightBrace) && !isAtEnd())
			methods.push(parseFunction("method"));
		consume(RightBrace, "Expect '}' after class body.");
		return ClassDecl(name, superclass, methods);
	}

	private function parseFunctionDeclaration() {
		consume(Fun, "Expect 'fun'.");
		return FunDecl(parseFunction("function"));
	}

	private function parseFunction(kind:String) {
		final name = consume(Identifier, 'Expect $kind name.');
		consume(LeftParen, 'Expect \'(\' after $kind name.');
		final parameters = [];
		if (!check(RightParen))
			do {
				if (parameters.length >= 255)
					error(peek(), "Can't have more than 255 parameters.");
				parameters.push(consume(Identifier, "Expect parameter name."));
			} while (match([Comma]));
		consume(RightParen, "Expect ')' after parameters.");
		consume(LeftBrace, 'Expect \'{\' before $kind body.');
		final body = parseBlock();
		return new Function(name, parameters, body);
	}

	private function parseVariableDeclaration() {
		consume(Var, "Expect 'var'.");
		final name = consume(Identifier, "Expect variable name.");
		final initializer = if (match([Equal])) parseExpression() else null;
		consume(Semicolon, "Expect ';' after variable declaration.");
		return VarDecl(name, initializer);
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
		consume(For, "Expect 'for'.");
		consume(LeftParen, "Expect '(' after 'for'.");
		final initializer = switch (peek().type) {
			case Semicolon:
				advance();
				null;
			case Var:
				parseVariableDeclaration();
			default:
				parseExpressionStatement();
		};
		final condition = if (!check(Semicolon)) {
			parseExpression();
		} else {
			LiteralExpr(Boolean(true));
		};
		consume(Semicolon, "Expect ';' after loop condition.");
		final increment = if (!check(RightParen)) parseExpression() else null;
		consume(RightParen, "Expect ')' after for clauses.");
		var body = parseStatement();
		if (increment != null)
			body = BlockStmt([body, ExprStmt(increment)]);
		body = WhileStmt(condition, body);
		if (initializer != null)
			body = BlockStmt([initializer, body]);
		return body;
	}

	private function parseIfStatement() {
		consume(If, "Expect 'if'.");
		consume(LeftParen, "Expect '(' after 'if'.");
		final condition = parseExpression();
		consume(RightParen, "Expect ')' after if condition.");
		final consequent = parseStatement();
		final alternative = if (match([Else])) parseStatement() else null;
		return IfStmt(condition, consequent, alternative);
	}

	private function parsePrintStatement() {
		consume(Print, "Expect 'print'.");
		final value = parseExpression();
		consume(Semicolon, "Expect ';' after value.");
		return PrintStmt(value);
	}

	private function parseReturnStatement() {
		consume(Return, "Expect 'return'.");
		final keyword = previous();
		final value = if (!check(Semicolon)) parseExpression() else null;
		consume(Semicolon, "Expect ';' after return value.");
		return ReturnStmt(keyword, value);
	}

	private function parseWhileStatement() {
		consume(While, "Expect 'while'.");
		consume(LeftParen, "Expect '(' after 'while'.");
		final condition = parseExpression();
		consume(RightParen, "Expect ')' after condition.");
		final body = parseStatement();
		return WhileStmt(condition, body);
	}

	private function parseBlockStatement() {
		consume(LeftBrace, "Expect '{'.");
		return BlockStmt(parseBlock());
	}

	private function parseBlock() {
		final statements = [
			while (!check(RightBrace) && !isAtEnd())
				switch parseDeclaration() {
					case None:
						continue;
					case stmt:
						stmt;
				}
		];
		consume(RightBrace, "Expect '}' after block.");
		return statements;
	}

	private function parseExpressionStatement() {
		final expression = parseExpression();
		consume(Semicolon, "Expect ';' after expression.");
		return ExprStmt(expression);
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
				case VariableExpr(variable):
					return AssignExpr(variable.name, value);
				case GetExpr(object, name):
					return SetExpr(object, name, value);
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

	inline private function parseLogicalExpression(operators, next) {
		var left = next();
		while (match(operators)) {
			final op = previous();
			final right = next();
			left = LogicalExpr(left, op, right);
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

	private function parseBinaryExpression(operators, next) {
		var left = next();
		while (match(operators)) {
			final op = previous();
			final right = next();
			left = BinaryExpr(left, op, right);
		}
		return left;
	}

	private function parsePrefix() {
		return if (match([Bang, Minus])) {
			final operator_ = previous();
			final right = parsePrefix();
			PrefixExpr(operator_, right);
		} else parseCall();
	}

	private function parseCall() {
		var expr = parsePrimary();
		while (true)
			expr = switch peek().type {
				case LeftParen:
					advance();
					finishCall(expr);
				case Period:
					advance();
					final name = consume(Identifier, "Expect property name after '.'.");
					GetExpr(expr, name);
				default:
					break;
			}
		return expr;
	}

	private function finishCall(callee) {
		final args = [];
		if (!check(RightParen))
			do {
				if (args.length >= 255)
					error(peek(), 'Can\'t have more than 255 arguments.');
				args.push(parseExpression());
			} while (match([Comma]));
		final parenthesis = consume(RightParen, 'Expect \')\' after arguments.');
		return CallExpr(callee, parenthesis, args);
	}

	private function parsePrimary() {
		final next = advance();
		final literal = next.literal;
		return switch next.type {
			case False:
				LiteralExpr(Boolean(false));
			case True:
				LiteralExpr(Boolean(true));
			case Nil:
				LiteralExpr(Nil);
			case Number | String if (literal != null):
				LiteralExpr(literal);
			case Super:
				final keyword = previous();
				consume(Period, "Expect '.' after 'super'.");
				final method = consume(Identifier, "Expect superclass method name.");
				SuperExpr(keyword, method);
			case This:
				ThisExpr(previous());
			case Identifier:
				VariableExpr(new Variable(previous()));
			case LeftParen:
				final expression = parseExpression();
				consume(RightParen, "Expect \')\' after expression.");
				GroupingExpr(expression);
			default:
				throw error(previous(), "Expect expression.");
		}
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
