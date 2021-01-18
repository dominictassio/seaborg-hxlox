import haxe.io.Eof;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import scanning.Scanner;
import scanning.Token;

class Lox {
	// private static final interpreter:Interpreter = new Interpreter();
	public static var hadError:Bool = false;
	public static var hadRuntimeError:Bool = false;

	public static function main() {
		final args = Sys.args();
		if (args.length > 1) {
			Sys.println('Usage: seaborg-hxlox [script]');
			Sys.exit(64);
		} else if (args.length == 1) {
			runFile(args[0]);
		} else {
			runPrompt();
		}
	}

	public static function scanError(line:Int, message:String) {
		report(line, '', message);
	}

	public static function parseError(token:Token, message:String) {
		report(token.line, ' at ' + switch (token.type) {
			case Eof:
				'end';
			default:
				'\'${token.lexeme}\'';
		}, message);
	}

	// public static function runtimeError(error:Interpreting.RuntimeError) {
	// 	Sys.println(error.message, '\n[line ${error.token.line}]');
	// 	hadRuntimeError = true;
	// }

	private static function runFile(path:String) {
		final fullPath = Path.normalize(Path.join([Sys.getCwd(), path]));
		if (!FileSystem.exists(fullPath)) {
			Sys.exit(66);
		}
		final contents = File.getContent(fullPath);
		runFile(contents);
		if (hadError)
			Sys.exit(65);
		if (hadRuntimeError)
			Sys.exit(70);
	}

	private static function runPrompt() {
		final input = Sys.stdin();
		while (true) {
			Sys.print('> ');
			try {
				final line = input.readLine();
				run(line);
				hadError = false;
			} catch (e:Eof) {
				Sys.println("\nbye.");
				break;
			}
		}
	}

	private static function run(source:String) {
		final scanner = new Scanner(source);
		final tokens = scanner.scanTokens();
		// final parser = new Parser(tokens);
		// final statements = parser.parse();
		// resolver.resolve(stmts);
		// if (hadError)
		// 	return;
		// final resolver = new Resolver(interpreter);
		// resolver.resolve(statements);
		// if (hadError)
		// 	return;
		// interpreter.interpret(statements);
	}

	private static function report(line:Int, where:String, message:String) {
		Sys.stderr().writeString('[line $line] Error$where: $message\n');
		hadError = true;
	}
}
