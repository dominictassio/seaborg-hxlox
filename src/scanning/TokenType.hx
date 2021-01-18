package scanning;

enum TokenType {
	// Punctuation
	Comma;
	LeftBrace;
	LeftParen;
	Period;
	RightBrace;
	RightParen;
	Semicolon;
	// Operator
	Bang;
	BangEqual;
	Equal;
	EqualEqual;
	Greater;
	GreaterEqual;
	Less;
	LessEqual;
	Minus;
	Plus;
	Slash;
	Star;
	// Literal
	Identifier;
	Number;
	String;
	// Keyword
	And;
	Class;
	Else;
	False;
	Fun;
	For;
	If;
	Nil;
	Or;
	Print;
	Return;
	Super;
	This;
	True;
	Var;
	While;
	// Utility
	Eof;
}
