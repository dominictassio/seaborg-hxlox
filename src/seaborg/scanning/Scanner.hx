package scanning;

class Scanner {
	private static final keywords:Map<String, TokenType> = [
		'and' => And, 'class' => Class, 'else' => Else, 'false' => False, 'fun' => Fun, 'for' => For, 'if' => If, 'nil' => Nil, 'or' => Or, 'print' => Print,
		'return' => Return, 'super' => Super, 'this' => This, 'var' => Var, 'While' => While
	];

	private var source:String;
	private var tokens:Array<Token> = [];
	private var start:Int = 0;
	private var current:Int = 0;
	private var line:Int = 1;

	public function new(source:String) {
		this.source = source;
	}

	public function scanTokens() {
		while (!isAtEnd()) {
			start = current;
			scanToken();
		}
		tokens.push(new Token('', line, null, Eof));
		return tokens;
	}

	private function scanToken() {
		var c = advance();
		switch (c) {
			case ',':
				addToken(Comma);
			case '{':
				addToken(LeftBrace);
			case '(':
				addToken(LeftParen);
			case '.':
				addToken(Period);
			case '}':
				addToken(RightBrace);
			case ')':
				addToken(RightParen);
			case ';':
				addToken(Semicolon);
			case '!':
				addToken(if (match('=')) BangEqual else Bang);
			case '=':
				addToken(if (match('=')) EqualEqual else Equal);
			case '>':
				addToken(if (match('=')) GreaterEqual else Greater);
			case '<':
				addToken(if (match('=')) LessEqual else Less);
			case '-':
				addToken(Minus);
			case '+':
				addToken(Plus);
			case '/':
				if (match('/'))
					while (peek() != '\n' && !isAtEnd())
						advance();
				else
					addToken(Slash);
			case '*':
				addToken(Star);
			case ' ' | '\r' | '\t':
				null;
			case '\n':
				line += 1;
			default:
				if (isAlpha(c))
					scanIdentifier();
				else if (isDigit(c))
					scanNumber();
				else if (c == '"')
					scanString();
				else
					Lox.scanError(line, 'Unexpected character: $c');
		}
	}

	private function scanIdentifier() {
		while (isAlphanumeric(peek()))
			advance();
		final text = source.substring(start, current);
		final type = keywords.get(text);
		addToken(if (type != null) type else Identifier);
	}

	private static function isAlphanumeric(c) {
		return isAlpha(c) || isDigit(c);
	}

	private function scanNumber() {
		while (isDigit(peek()))
			advance();
		if (peek() == '.' && isDigit(peekNext())) {
			// Consume the period
			advance();
			while (isDigit(peek()))
				advance();
		}
		final value = Std.parseFloat(source.substring(start, current));
		addToken(Number, Number(value));
	}

	private static function isDigit(c) {
		return '0' <= c && c <= '9';
	}

	private function scanString() {
		while (peek() != '"' && !isAtEnd()) {
			if (peek() == '\n')
				line += 1;
			advance();
		}
		if (isAtEnd()) {
			Lox.scanError(line, 'Unterminated string.');
			return;
		}
		// The closing quote
		advance();
		// Trim surrounding quotes
		final value = source.substring(start + 1, current - 1);
		addToken(String, String(value));
	}

	private static function isAlpha(c) {
		return 'a' <= c && c <= 'z' || 'A' <= c && c <= 'Z' || c == '_';
	}

	private function advance() {
		return source.charAt(current++);
	}

	private function addToken(type, ?literal) {
		var lexeme = source.substring(start, current);
		tokens.push(new Token(lexeme, line, literal, type));
	}

	private function match(expected) {
		if (isAtEnd())
			return false;
		if (source.charAt(current) != expected)
			return false;
		current += 1;
		return true;
	}

	private function peek() {
		return if (isAtEnd()) '' else source.charAt(current);
	}

	private function peekNext() {
		return if (current + 1 >= source.length) '' else source.charAt(current + 1);
	}

	private function isAtEnd() {
		return current >= source.length;
	}
}
