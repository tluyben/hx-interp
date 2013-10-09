package vm;

import haxe.io.BytesInput;
import haxe.io.Input;
import haxe.ds.GenericStack;
import sys.FileSystem;
import sys.io.File;

import vm.AST;

enum Token 
{
	TEof;
	TConst(c:Const);
	TId(s:String);
	TOp(s:String);
	TPOpen;
	TPClose;
	TBrOpen;
	TBrClose;
	TDot;
	TComma;
	TSemicolon;
	TBkOpen;
	TBkClose;
	TQuestion;
	TDoubleDot;
}

class Parser
{
	public var line:Int;
	public var blockLine:Int;
	public var opChars:String;
	public var identChars:String;
	public var opPriority:Map<String, Int>;
	public var opRightAssoc:Map<String, Bool>;
	public var unops:Map<String, Bool>;
	
	var input:Input;
	var char:Int;
	var ops:Array<Bool>;
	var idents:Array<Bool>;
	var tokens:GenericStack<Token>;
	
	var paths:Array<String>;
	var allCls:Map<String, Bool>;
	var globalCls:Map<String, Bool>;
	var fileCls:Map<String, Array<String>>;
	var localCls:Map<String, String>;
	
	var fileName:String;
	var packageName:String;
	
	var pre:PreParser;
	
	public function new() 
	{
		paths = new Array();
		allCls = new Map<String, Bool>();
		globalCls = new Map<String, Bool>();
		fileCls = new Map<String, Array<String>>();
		
		opChars = "+*/-=!><&|^%~";
		identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
		
		var priorities = 
		[
			["%"],
			["*", "/"],
			["+", "-"],
			["<<", ">>", ">>>"],
			["|", "&", "^"],
			["==", "!=", ">", "<", ">=", "<="],
			["..."],
			["&&"],
			["||"],
			["=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", ">>>=", "|=", "&=", "^="],
		];

		opPriority = new Map();
		opRightAssoc = new Map();
		unops = new Map();

		for (i in 0...priorities.length)
			for (x in priorities[i]) 
			{
				opPriority.set(x, i);
				if(i == 9) opRightAssoc.set(x, true);
			}
		
		for (x in ["!", "++", "--", "-", "~"])
			unops.set(x, x == "++" || x == "--");
		
		ops = new Array();
		idents = new Array();
		for (i in 0...opChars.length)
			ops[opChars.charCodeAt(i)] = true;
		for (i in 0...identChars.length)
			idents[identChars.charCodeAt(i)] = true;
			
		pre = new PreParser();
	}
	
	public function addPath(path:String):Void
	{
		paths.push(path);
		parseFolder(path);
	}
	
	public function parse(path:String, file:String, flags:Array<String>) //flags
	{
		var input:Input = cast new BytesInput(pre.process(path, flags));
		
		packageName = "";
		fileName = file;
		
		localCls = new Map<String, String>();
		addImports(path, file);
		
		tokens = new GenericStack<Token>();
		char = -1;
		this.input = input;
				
		line = 1;
		blockLine = 1;
			
		var a = new Array();
		var tk = token();
		tokens.add(tk);
		if (!Type.enumEq(tk, TId("package")))
			a.push(EPackage(""));
		
		while (true) 
		{
			tk = token();
			tokens.add(tk);
			
			switch(tk)
			{
			case TId(s):
				if (s == "interface")
				{
					readString("}".charCodeAt(0));//skip interface
					token();
					continue;
				}
				else if (s != "class" && s != "package" && s != "import")
					error(EUnexpected(s));
				if (s == "package" && a.length > 0) 
					error(EUnexpected(s));
			case TEof:
				break;
			default:
				error(EUnexpected(tokenString(tk)));
			}
			
			a.push(parseFullExpr());
		}
		
		return a;
	}
	
	function parseFullExpr() 
	{
		var e = parseExpr();
		var tk = token();
		if (tk != TSemicolon && tk != TEof) 
		{
			if(isBlock(e))
				tokens.add(tk);
			else
				error(EUnexpected(tokenString(tk)));
		}
		return e;
	}
	
	function parseExpr() 
	{
		var tk = token();
		switch(tk) 
		{
		case TId(id):
			var e = parseStructure(id);
			if (e == null)
			{
				if (globalCls.exists(id))
					e = EClassIdent(id);
				else if (localCls.exists(id))
					e = EClassIdent(localCls.get(id));
				else
					e = EIdent(id);
			}
			return parseExprNext(e);
		case TConst(c):
			return parseExprNext(EConst(c));
		case TPOpen:
			var e = parseExpr();
			ensure(TPClose);
			return parseExprNext(EParent(e));
		case TBrOpen:
			tk = token();
			switch(tk) 
			{
			case TBrClose:
				return parseExprNext(EObject([]));
			case TId(_):
				var tk2 = token();
				tokens.add(tk2);
				tokens.add(tk);
				switch(tk2) 
				{
				case TDoubleDot:
					return parseExprNext(parseObject(0));
				default:
				}
			default:
				tokens.add(tk);
			}
			var a = new Array();
			while (true) 
			{
				if (blockLine != line)
				{
					a.push(ELine(line));
					blockLine = line;
				}
				a.push(parseFullExpr());
				tk = token();
				if(tk == TBrClose)
					break;
				tokens.add(tk);
			}
			return EBlock(a);
		case TOp(op):
			if(unops.exists(op))
				return makeUnop(op, parseExpr());
			error(EUnexpected(tokenString(tk)));
			return null;
		case TBkOpen:
			var a = new Array();
			tk = token();
			while (tk != TBkClose) 
			{
				tokens.add(tk);
				a.push(parseExpr());
				tk = token();
				if(tk == TComma)
					tk = token();
			}
			return parseExprNext(EArrayDecl(a));
		default:
			error(EUnexpected(tokenString(tk)));
			return null;
		}
	}
	
	function parseExprNext(e1:Expr) 
	{
		switch(e1)
		{
		case EClass(_, _, _, _, _, _):
			tokens.add(TSemicolon);
			return e1;
		default:
		}
		var tk = token();
		switch(tk) 
		{
		case TOp(op):
			if (unops.get(op)) 
			{
				if (isBlock(e1) || switch(e1) { case EParent(_):true; default:false;} ) 
				{
					tokens.add(tk);
					return e1;
				}
				return parseExprNext(EUnop(op, false, e1));
			}
			return makeBinop(op, e1, parseExpr());
		case TDot:
			tk = token();
			var field = null;
			switch(tk) 
			{
			case TId(id): field = id;
			default: error(EUnexpected(tokenString(tk)));
			}
			
			if (Type.enumConstructor(e1) == "EIdent")
			{
				var a = new Array();
				a.push(Type.enumParameters(e1)[0]);
				a.push(field);
				if (allCls.exists(a.join(".")))
					return parseExprNext(EClassIdent(a.join(".")));
				var cache = new Array();
				var next = true;
				while (next)
				{
					tk = token();
					cache.push(tk);
					switch(tk) 
					{
					case TDot:
						tk = token();
						cache.push(tk);
						switch(tk) 
						{
						case TId(id): 
							a.push(id);
							if (allCls.exists(a.join(".")))
								return parseExprNext(EClassIdent(a.join(".")));
						default: error(EUnexpected(tokenString(tk)));
						}
					default:
						next = false;
					}
				}
				var total = cache.length;
				var i = total - 1;
				while (i > -1)
				{
					tokens.add(cache[i]);
					i--;
				}
				return parseExprNext(EField(e1, field));
			}
			else
			{
				return parseExprNext(EField(e1, field));	
			}
		case TPOpen:
			if (Type.enumEq(e1, EIdent("super")))
				return parseExprNext(ECall(EField(EIdent("super"), "new"), parseExprList(TPClose)));
			else
				return parseExprNext(ECall(e1, parseExprList(TPClose)));
		case TBkOpen:
			var e2 = parseExpr();
			ensure(TBkClose);
			return parseExprNext(EArray(e1, e2));
		case TQuestion:
			var e2 = parseExpr();
			ensure(TDoubleDot);
			var e3 = parseExpr();
			return ETernary(e1, e2, e3);
		default:
			tokens.add(tk);
			return e1;
		}
	}
	
	function parseStructure(id) 
	{
		return switch(id)
		{
		case "package":
			var v = "";
			while (true)
			{
				var tk = token();
				switch(tk) 
				{
				case TDot: v += ".";
				case TId(id): v += id;
				case TSemicolon: 
					tokens.add(tk);
					break;
				default: error(EUnexpected(tokenString(tk)));
				}
			}
			if (!isLowerCase(v)) error(EUpperCasePackage(v));
			packageName = v;
			var pre = StringTools.replace(v, ".", "/");
			if (pre != "") pre = "/" + pre;
			fileName = pre + "/" + fileName;
			EPackage(v);
		case "import":
			var v = "";
			while (true)
			{
				var tk = token();
				switch(tk) 
				{
				case TDot: v += ".";
				case TId(id): v += id;
				case TSemicolon: 
					tokens.add(tk);
					break;
				default: error(EUnexpected(tokenString(tk)));
				}
			}
			addImport(v);
			EImport(v);
		case "class":
			var ident = null;
			var parent = null;
			var vars = new Array();
			var sVars = new Array();
			var funs = new Array();
			var sFuns = new Array();
			var tk = token();
			switch(tk) 
			{
			case TId(id): ident = id;
			default: error(EUnexpected(tokenString(tk)));
			}
			while (true)
			{
			tk = token();
			switch(tk)
			{
				case TId(id):
					switch(id)
					{
					case "implements":
						readString("{".charCodeAt(0));
						break;
					case "extends":
						var a = new Array();
						var tk = token();
						switch(tk) 
						{
						case TId(id): a.push(id);
						default: error(EUnexpected(tokenString(tk)));
						}
						var next = true;
						while (true) 
						{
							tk = token();
							switch(tk) 
							{
							case TDot:
								tk = token();
								switch(tk) 
								{
								case TId(id): a.push(id);
								default: error(EUnexpected(tokenString(tk)));
								}
							default: 
								tokens.add(tk); 
								break;
							}
						}
						parent = a.join(".");
						if (localCls.exists(parent))
							parent = localCls.get(parent);
					default: error(EUnexpected(id));
					}
				case TBrOpen: break;
				default: error(EUnexpected(tokenString(tk)));
				}
			}
			var isStatic = false;
			while (true)
			{
				tk = token();
				switch(tk)
				{
				case TId(id): 
					switch(id)
					{
					case "static":
						isStatic = true;
					case "public":
					case "private":
					case "override":
					case "var":
						tokens.add(tk);
						var varExpr = parseFullExpr();
						if (isStatic)
						{
							sVars.push(varExpr);
							isStatic = false;
						}
						else 
						{
							vars.push(varExpr);
						}
					case "function":
						tokens.add(tk);
						var funExpr = parseFullExpr();
						if (isStatic)
						{
							sFuns.push(funExpr);
							isStatic = false;
						}
						else funs.push(funExpr);
					default: error(EUnexpected(id));
					}
				case TBrClose: break;
				default: error(EUnexpected(tokenString(tk)));
				}
			}
			if (!startWithUpperCase(ident)) error(ELowerCaseClass(ident));
			EClass(((packageName == "") ? "" : packageName + ".") + ident, fileName, parent, vars, sVars, funs, sFuns);
		case "var":
			var tk = token();
			var ident = null;
			switch(tk) 
			{
			case TId(id): ident = id;
			default: error(EUnexpected(tokenString(tk)));
			}
			tk = token();
			if (tk == TDoubleDot)
			{
				parseType();
				tk = token();
			}
			var e = null;
			if(Type.enumEq(tk, TOp("=")))
				e = parseExpr();
			else
				tokens.add(tk);
			EVar(ident, e);
		case "if":
			var cond = parseExpr();
			var e1 = parseExpr();
			var e2 = null;
			var semic = false;
			var tk = token();
			if (tk == TSemicolon) 
			{
				semic = true;
				tk = token();
			}
			if (Type.enumEq(tk, TId("else")))
			{
				e2 = parseExpr();
			}
			else 
			{
				tokens.add(tk);
				if(semic) tokens.add(TSemicolon);
			}
			EIf(cond, e1, e2);
		case "while":
			var econd = parseExpr();
			var e = parseExpr();
			EWhile(econd, e);
		case "for":
			ensure(TPOpen);
			var tk = token();
			var vname = null;
			switch(tk) 
			{
			case TId(id): vname = id;
			default: error(EUnexpected(tokenString(tk)));
			}
			tk = token();
			if(!Type.enumEq(tk,TId("in"))) error(EUnexpected(tokenString(tk)));
			var eiter = parseExpr();
			ensure(TPClose);
			var e = parseExpr();
			EFor(vname,eiter,e);
		case "break": EBreak;
		case "continue": EContinue;
		case "else": 
			error(EUnexpected(id));
			null;
		case "switch":
			var cases = new Array();
			var casesCon = new Array();
			var defaultCase = null;
			
			ensure(TPOpen);
			var e = parseExpr();
			ensure(TPClose);
			ensure(TBrOpen);
			while (true)
			{
				var tk = token();
				switch(tk)
				{
				case TId(id):
					if (id == "case" || id == "default")
					{
						if(id == "case")
							casesCon.push(parseExpr());
						ensure(TDoubleDot);
						var a = new Array();
						while (true) 
						{
							if (blockLine != line)
							{
								a.push(ELine(line));
								blockLine = line;
							}
							a.push(parseFullExpr());
							tk = token();
							tokens.add(tk);
							if (tk == TBrClose || Type.enumEq(tk, TId("case")) || Type.enumEq(tk, TId("default")))
								break;
						}
						(id == "case") ? cases.push(EBlock(a)) : defaultCase = EBlock(a);
					}
				case TBrClose:
					break;
				default:error(EInvalid(tokenString(tk)));
				}
			}
			if (cases.length < 1)error(EInvalid("case count"));
			var r = EIf(EBinop("==", e, casesCon[cases.length - 1]), cases[cases.length - 1], defaultCase);
			var i = cases.length - 2;
			while (i > -1)
			{
				r = EIf(EBinop("==", e, casesCon[i]), cases[i], r);
				i--;
			}
			r;
		case "function":
			var tk = token();
			var name = null;
			switch(tk) 
			{
			case TId(id): name = id;
			default: tokens.add(tk);
			}
			ensure(TPOpen);
			var args = new Array();
			tk = token();
			if (tk != TPClose) 
			{
				var arg = true;
				while (arg) 
				{
					var name = null;
					switch(tk) 
					{
					case TId(id): name = id;
					default: error(EUnexpected(tokenString(tk)));
					}
					tk = token();
					if (tk == TDoubleDot) 
					{
						parseType();
						tk = token();
					}
					args.push(name);
					switch(tk) 
					{
					case TComma:
						tk = token();
					case TPClose:
						arg = false;
					default:
						error(EUnexpected(tokenString(tk)));
					}
				}
			}
			tk = token();
			if(tk != TDoubleDot)
				tokens.add(tk);
			else
				parseType();
			var body = parseExpr();
			EFunction(name, args, body);
		case "return":
			var tk = token();
			tokens.add(tk);
			var e = if(tk == TSemicolon) null else parseExpr();
			EReturn(e);
		case "new":
			var a = new Array();
			var tk = token();
			switch(tk) 
			{
			case TId(id): a.push(id);
			default: error(EUnexpected(tokenString(tk)));
			}
			var next = true;
			while (next) 
			{
				tk = token();
				switch(tk) 
				{
				case TDot:
					tk = token();
					switch(tk) 
					{
					case TId(id): a.push(id);
					default: error(EUnexpected(tokenString(tk)));
					}
				case TPOpen:
					next = false;
				default:
					error(EUnexpected(tokenString(tk)));
				}
			}
			var args = parseExprList(TPClose);
			var cl = a.join(".");
			if (localCls.exists(cl))
				cl = localCls.get(cl);
			ENew(cl, args);
		case "throw":
			var e = parseExpr();
			EThrow(e);
		case "try":
			var e = parseExpr();
			var tk = token();
			if(!Type.enumEq(tk, TId("catch"))) error(EUnexpected(tokenString(tk)));
			ensure(TPOpen);
			tk = token();
			var vname = switch(tk) 
			{
			case TId(id): id;
			default: 
				error(EUnexpected(tokenString(tk)));
				null;
			}
			ensure(TDoubleDot);
			parseType();
			ensure(TPClose);
			var ec = parseExpr();
			ETry(e, vname, ec);
		default:
			null;
		}
	}
	
	function parseExprList(etk) 
	{
		var args = new Array();
		var tk = token();
		if(tk == etk)
			return args;
		tokens.add(tk);
		while (true) 
		{
			args.push(parseExpr());
			tk = token();
			switch(tk) 
			{
			case TComma:
			default:
				if(tk == etk) break;
				error(EUnexpected(tokenString(tk)));
			}
		}
		return args;
	}
	
	function parseObject(p1) 
	{
		var fl = new Array();
		while (true) 
		{
			var tk = token();
			var id = null;
			switch(tk) 
			{
			case TId(i): id = i;
			case TBrClose:
				break;
			default:
				error(EUnexpected(tokenString(tk)));
			}
			ensure(TDoubleDot);
			fl.push({name:id, e:parseExpr()});
			tk = token();
			switch( tk ) {
			case TBrClose:
				break;
			case TComma:
			default:
				error(EUnexpected(tokenString(tk)));
			}
		}
		return parseExprNext(EObject(fl));
	}
	
	function parseType()
	{
		//TO-DO function:Void->Int :: var a:{b:Int, c:Int}
		var tk = token();
		switch(tk) 
		{
		case TId(_):
			while (true) 
			{
				tk = token();
				if (tk != TDot)
				{
					break;
				}
				tk = token();
				switch(tk) 
				{
				case TId(_):
				default:
					error(EUnexpected(tokenString(tk)));
				}
			}
			switch(tk) 
			{
			case TOp(op):
				if (op == "<") 
				{
					while (true) 
					{
						parseType();
						tk = token();
						switch(tk) 
						{
						case TComma: continue;
						case TOp(op): if( op ==	">" ) break;
						default:
						}
						error(EExpected(">"));
					}
				}
				else tokens.add(tk);
			default: tokens.add(tk);
			}
		default: error(EUnexpected(tokenString(tk)));
		}
	}
	
	function isBlock(e) 
	{
		return switch(e) 
		{
		case EBlock(_), EObject(_): true;
		case EFunction(_, _, e): isBlock(e);
		case EVar(_, e): e != null && isBlock(e);
		case EIf(_, e1, e2): if( e2 != null ) isBlock(e2) else isBlock(e1);
		case EBinop(_, _, e): isBlock(e);
		case EUnop(_, prefix, e): !prefix && isBlock(e);
		case EWhile(_, e): isBlock(e);
		case EFor(_, _, e): isBlock(e);
		case EReturn(e): e != null && isBlock(e);
		default: false;
		}
	}

	function makeUnop(op, e) 
	{
		return switch(e) 
		{
		case EBinop(bop, e1, e2): EBinop(bop, makeUnop(op, e1), e2);
		case ETernary(e1, e2, e3): ETernary(makeUnop(op, e1), e2, e3);
		default: EUnop(op, true, e);
		}
	}
	
	function makeBinop(op, e1, e) 
	{
		return switch(e) 
		{
		case EBinop(op2, e2, e3):
			if(opPriority.get(op) <= opPriority.get(op2) && !opRightAssoc.exists(op))
				EBinop(op2, makeBinop(op,e1,e2),e3);
			else
				EBinop(op, e1, e);
		case ETernary(e2, e3, e4):
			if(opRightAssoc.exists(op))
				EBinop(op,e1,e);
			else
				ETernary(makeBinop(op, e1, e2), e3, e4);
		default:
			EBinop(op,e1,e);
		}
	}	
	
	function token() 
	{
		if(!tokens.isEmpty())
			return tokens.pop();
		var char;
		if (this.char < 0)
		{
			char = readChar();
		}
		else 
		{
			char = this.char;
			this.char = -1;
		}
		while (true) 
		{
			switch(char) 
			{
			case 0: return TEof;
			case 32,9,13: // space, tab, CR
			case 10: 
				line++; // LF
			case 48,49,50,51,52,53,54,55,56,57: // 0...9
				var n = (char - 48) * 1.0;
				var exp = 0.;
				while (true) 
				{
					char = readChar();
					exp *= 10;
					switch(char) 
					{
					case 48,49,50,51,52,53,54,55,56,57:
						n = n * 10 + (char - 48);
					case 46:
						if (exp > 0) 
						{
							// in case of '...'
							if (exp == 10 && readChar() == 46) 
							{
								tokens.add(TOp("..."));
								var i = Std.int(n);
								return TConst((i == n) ? CInt(i) : CFloat(n));
							}
							error(EInvalidChar(char));
						}
						exp = 1.;
					case 120: // x
						if(n > 0 || exp > 0)
							error(EInvalidChar(char));
						// read hexa
						var n = 0;
						while (true) 
						{
							char = readChar();
							switch(char) 
							{
							case 48,49,50,51,52,53,54,55,56,57: // 0-9
								n = (n << 4) + char - 48;
							case 65,66,67,68,69,70: // A-F
								n = (n << 4) + (char - 55);
							case 97,98,99,100,101,102: // a-f
								n = (n << 4) + (char - 87);
							default:
								this.char = char;
								return TConst(CInt(n));
							}
						}
					default:
						this.char = char;
						var i = Std.int(n);
						return TConst((exp > 0) ? CFloat(n * 10 / exp) : ((i == n) ? CInt(i) : CFloat(n)));
					}
				}
			case 59: return TSemicolon;
			case 40: return TPOpen; // (
			case 41: return TPClose; // )
			case 44: return TComma; // ,
			case 46: // .
				char = readChar();
				switch( char ) 
				{
				case 48,49,50,51,52,53,54,55,56,57:
					var n = char - 48;
					var exp = 1;
					while (true) 
					{
						char = readChar();
						exp *= 10;
						switch(char) 
						{
						case 48,49,50,51,52,53,54,55,56,57:
							n = n * 10 + (char - 48);
						default:
							this.char = char;
							return TConst(CFloat(n/exp));
						}
					}
				case 46:
					char = readChar();
					if(char != 46)
						error(EInvalidChar(char));
					return TOp("...");
				default:
					this.char = char;
					return TDot;
				}
			case 123: return TBrOpen; //{
			case 125: return TBrClose; //}
			case 91: return TBkOpen; //[
			case 93: return TBkClose; //]
			case 39: return TConst(CString(readString(39))); //"
			case 34: return TConst(CString(readString(34))); //'
			case 63: return TQuestion; //?
			case 58: return TDoubleDot; //:
			default:
				if (ops[char]) 
				{
					var op = String.fromCharCode(char);
					while (true) 
					{
						char = readChar();
						if (!ops[char]) 
						{
							if (op.charCodeAt(0) == 47) // /
							{
								return tokenComment(op, char);
							}
							this.char = char;
							return TOp(op);
						}
						op += String.fromCharCode(char);
					}
				}
				if (idents[char])
				{
					var id = String.fromCharCode(char);
					while (true) 
					{
						char = readChar();
						if (!idents[char]) 
						{
							this.char = char;
							return TId(id);
						}
						id += String.fromCharCode(char);
					}
				}
				error(EInvalidChar(char));
			}
			char = readChar();
		}
		return null;
	}
	
	function tokenComment(op:String, char:Int) 
	{
		var c = op.charCodeAt(1);
		var s = input;
		if (c == 47) 
		{ 
			// comment
			try 
			{
				while (char != 10 && char != 13) 
					char = s.readByte();
				this.char = char;
			}
			catch (e:Dynamic) 
			{
			}
			return token();
		}
		if (c == 42) 
		{ 
			/* comment */
			var old = line;
			try 
			{
				while (true) 
				{
					while (char != 42) 
					{
						if(char == 10) line++;
						char = s.readByte();
					}
					char = s.readByte();
					if (char == 47)
						break;
				}
			}
			catch (e:Dynamic) 
			{
				line = old;
				error(EUnterminatedComment);
			}
			return token();
		}
		this.char = char;
		return TOp(op);
	}
	
	function readChar() 
	{
		return try input.readByte() catch(e:Dynamic) 0;
	}
	
	function readString(until) 
	{
		var c = 0;
		var b = new haxe.io.BytesOutput();
		var esc = false;
		var old = line;
		var s = input;

		while (true) 
		{
			try 
			{
				c = s.readByte();
			} 
			catch (e:Dynamic) 
			{
				line = old;
				error(EUnterminatedString);
			}
			if (esc) 
			{
				esc = false;
				switch (c) 
				{
				case 'n'.code: b.writeByte(10);
				case 'r'.code: b.writeByte(13);
				case 't'.code: b.writeByte(9);
				case "'".code, '"'.code, '\\'.code: b.writeByte(c);
				default: error(EInvalidChar(c));
				}
			} 
			else if (c == 92) // "\"
			{
				esc = true;
			}
			else if (c == until )
			{
				break;
			}
			else 
			{
				if(c == 10) line++;
				b.writeByte(c);
			}
		}
		return b.getBytes().toString();
	}
	
	function constString(c)
	{
		return switch(c) 
		{
		case CInt(v): Std.string(v);
		case CFloat(f): Std.string(f);
		case CString(s): s; // TODO : escape + quote
		}
	}
	
	function tokenString(t) 
	{
		return switch(t)
		{
		case TEof: "<eof>";
		case TConst(c): constString(c);
		case TId(s): s;
		case TOp(s): s;
		case TPOpen: "(";
		case TPClose: ")";
		case TBrOpen: "{";
		case TBrClose: "}";
		case TDot: ".";
		case TComma: ",";
		case TSemicolon: ";";
		case TBkOpen: "[";
		case TBkClose: "]";
		case TQuestion: "?";
		case TDoubleDot: ":";
		}
	}
	
	function ensure(tk) 
	{
		var t = token();
		if(t != tk) error(EUnexpected(tokenString(t)));
	}

	function error(err) 
	{
		throw "File " + fileName + " Line " + this.line + " : " + Std.string(err);
	}
	
	public function addImports(path:String, file:String):Void
	{
		path = path.substring(0, path.lastIndexOf("/"));
		var idx = Lambda.indexOf(paths, path);
		var isGlobal = !(Lambda.indexOf(paths, path) == -1);
		var pack = "";
		if (idx == -1)
		{
			for (p in paths)
			{
				if (path.indexOf(p) != -1)
				{
					pack = path.split(p + "/").join("");
					pack = pack.split("/").join(".");
					break;
				}
			}
			
			var files = FileSystem.readDirectory(path);
			for (f in files)
			{
				if (!FileSystem.isDirectory(path + "/" + f))
				{
					addImport(pack + "." + f.split(".")[0]);
				}
			}
		}
	}
	
	public function addImport(importPath:String):Void
	{
		var parts = importPath.split(".");
		if (parts.length > 1 && startWithUpperCase(parts[parts.length - 2]))
		{
			parts.pop();
		}
		importPath = parts.join(".");
		var n = "/" + parts.join("/");
		for (p in paths)
		{
			if (FileSystem.exists(p + n + ".hx"))
			{
				if (!fileCls.exists(importPath))
				{
					parseFile(p + n + ".hx", parts[parts.length - 1]);
				}
				break;
			}
		}
		if (fileCls.exists(importPath))
		{
			parts.pop();
			var pack = parts.join(".");
			var cls = fileCls.get(importPath);
			for (c in cls)
			{
				localCls.set(c, pack + ((pack == "") ? "" : ".") + c);
			}
		}
		else
		{
			error(EInvalidImport(importPath));
		}
	}
	
	function parseFolder(path:String):Void
	{
		var files = FileSystem.readDirectory(path);
		for (f in files)
		{
			if (!FileSystem.isDirectory(path + "/" + f))
			{
				var cls:Array<String> = parseFile(path + "/" + f, f.split(".")[0]);
				for (c in cls)
				{
					if (!globalCls.exists(c))
					{
						globalCls.set(c, true);
					}
				}
			}
		}
		return null;
	}
	
	function parseFile(path:String, ident:String):Array<String>
	{
		var cls = new Array<String>();
		var content:String = File.getContent(path);
		
		//find package
		var p:EReg = ~/package ([A-Za-z0-9_.]+)[ ]*;/;
		var pack = "";
		if (p.match(content))
		{
			pack = p.matched(1);
		}
		if (pack != "") pack += ".";
		
		//find class
		var r:EReg = ~/class ([A-Z][A-Za-z0-9_]+)/;
		var start:Int = 0;
		var len:Int = content.length;
		while (r.matchSub(content, start, len))
		{
			cls.push(r.matched(1));
			var pos:{pos:Int, len:Int} = r.matchedPos();
			start = pos.pos + pos.len;
			len = content.length - start;
		}
		
		if (cls.length > 0)
		{
			var file = pack + ident;
			fileCls.set(file, cls);
		}
		var fullCls = new Array<String>();
		for (c in cls)
		{
			allCls.set(pack + c, true);
			fullCls.push(pack + c);
		}
		return cls;
	}
	
	inline function startWithUpperCase(n:String):Bool
	{
		return n.substr(0, 1).toUpperCase() == n.substr(0, 1);
	}
	
	inline function isLowerCase(n:String):Bool
	{
		return n.toLowerCase() == n;
	}	
}