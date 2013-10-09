package vm;

enum Const
{
	CInt(v:Int);
	CFloat(f:Float);
	CString(s:String);
}

enum Expr 
{
	EPackage(v:String);
	EImport(v:String);
	EClass(name:String, file:String, parent:String,
		   vars:Array<Expr>, sVars:Array<Expr>,
		   funs:Array<Expr>, sFuns:Array<Expr>);
	
	EFunction(name:String, args:Array<String>, e:Expr);
	EReturn(?e:Expr);
	ECall(e:Expr, params:Array<Expr>);
	
	EConst(c:Const);
	EVar(n:String, ?e:Expr);
	EIdent(v:String);
	EClassIdent(v:String);
	EObject(fl:Array<{name:String, e:Expr}>);
	
	EParent(e:Expr);
	EField(e:Expr, f:String);
	EBlock(e:Array<Expr>);
	
	EBinop(op:String, e1:Expr, e2:Expr);
	EUnop(op:String, prefix:Bool, e:Expr);
	
	EIf(cond:Expr, e1:Expr, ?e2:Expr);
	ETernary(cond:Expr, e1:Expr, e2:Expr);
	EWhile(cond:Expr, e:Expr);
	EFor(v:String, it:Expr, e:Expr);
	EBreak;
	EContinue;
	
	EArray(e:Expr, index:Expr); //array access
	EArrayDecl(e:Array<Expr>); //array declare
	
	ENew(cl:String, params:Array<Expr>);
	
	EThrow(e:Expr);
	ETry(e:Expr, v:String, ecatch:Expr);
		
	ELine(l:Int);
}

enum Stop 
{
	SBreak;
	SContinue;
	SReturn(v:Dynamic);
}

enum Error 
{
	EInvalidChar(c:Int);
	EUnexpected(s:String);
	EExpected(s:String);
	EInvalidAssignment(s:String);
	EUnterminatedString;
	EUnterminatedComment;
	EUnknownVariable(v:String);
	EInvalidIterator(v:String);
	EInvalidOp(op:String);
	EInvalidAccess(f:String);
	EUpperCasePackage(s:String);
	ELowerCaseClass(s:String);
	EClassRedefined(s:String);
	EVarRedefined(s:String);
	EInvalidParam;
	EInvalid(s:String);
	EScriptThrow(o:Dynamic);
	EStop(s:String);
	EInvalidImport(s:String);
}
