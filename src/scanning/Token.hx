package scanning;

class Token {
	public final lexeme:String;
	public final line:Int;
	public final literal:Null<Literal>;
	public final type:TokenType;

	public function new(lexeme:String, line:Int, literal:Null<Literal>, type:TokenType) {
		this.type = type;
		this.lexeme = lexeme;
		this.literal = literal;
		this.line = line;
	}

	public function toString() {
		return '$type $lexeme ${if (literal != null) '$literal' else 'null'}';
	}
}
