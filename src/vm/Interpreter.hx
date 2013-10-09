package vm;

import cpp.Lib;
import vm.AST;
import vm.MVC;

class Interpreter
{
	public var env:Map<String, Dynamic>;
	public var context:Dynamic;//instance or virtual_class's svars
	public var stack:Dynamic;//for function
	
	var classMap:Map<String, VirtualClass>;//define
	var binops:Map<String, Expr->Expr->Dynamic>;
	
	public function new() 
	{
		classMap = new Map();
		
		initOps();
		initEnv();
		
		MVC.finalize();
		MVC.initialize();
	}
	
	public inline function register(k:String, v:Dynamic):Void
	{
		env.set(k, v);
	}
	
	public function loadClasses(exprs:Array<Expr>):Void
	{
		for (exp in exprs)
		{
			switch(exp)
			{
			case EClass(name, file, parent, vars, sVars, funs, sFuns):
				var define:VirtualClass = new VirtualClass(this);
				define.className = name;
				define.fileName = file;
				define.superName = parent;
				for (v in vars)
				{
					switch(v)
					{
					case EVar(n, e): Reflect.setField(define.varsProto, n, e);
					default:
					}
				}
				for (v in sVars)
				{
					switch(v)
					{
					case EVar(n, e): Reflect.setField(define.sVars, n, e);
					default:
					}
				}
				for (f in funs)
				{
					switch(f)
					{
					case EFunction(n, args, e): Reflect.setField(define.funsProto, n, new VirtualFunction(this, n, args, e));
					default:
					}
				}
				for (f in sFuns)
				{
					switch(f)
					{
					case EFunction(n, args, e): Reflect.setField(define.sFunsProto, n, new VirtualFunction(this, n, args, e));
					default:
					}
				}
				classMap.set(name, define);
				define.initialize();
			default:
			}
		}
	}
	
	public function callStatic(cl:String, f:String, args:Array<Dynamic>):Dynamic
	{
		return classMap.get(cl).callStatic(f, args);
	}

	public function createInstance(cl:String, args:Array<Dynamic>):Dynamic
	{
		if (classMap.exists(cl))
		{
			return classMap.get(cl).createInstance(args);
		}
		var c = env.get(cl);
		if (c == null) c = Type.resolveClass(cl);
		if (c == null) error(EInvalid("Class:" + cl));
		return Type.createInstance(c, args);
	}

	public function createEmptyInstance(cl:String):Dynamic
	{
		if (classMap.exists(cl))
		{
			return classMap.get(cl).createInstance(null, false);
		}
		var c = env.get(cl);
		if (c == null) c = Type.resolveClass(cl);
		if (c == null) error(EInvalid("Class:" + cl));
		return Type.createEmptyInstance(c);
	}
		
	public function expr(e:Expr):Dynamic 
	{
		switch(e) 
		{
		case EConst(c):
			switch(c) 
			{
			case CInt(v): return v;
			case CFloat(f): return f;
			case CString(s): return s;
			}
		case EIdent(id):
			return resolve(id);
		case EClassIdent(id):
			return resolveClass(id);
		case EVar(n, e):
			declare(n, (e == null) ? null : expr(e));
			return null;
		case EParent(e):
			return expr(e);
		case EBlock(exprs):
			var v = null;
			for(e in exprs)
				v = expr(e);
			return v;
		case EField(e, f):
			return get(expr(e), f);
		case EBinop(op, e1, e2):
			var fop = binops.get(op);
			if (fop == null) 
			{
				error(EInvalidOp(op));
			}
			return fop(e1, e2);
		case EUnop(op, prefix, e):
			switch(op) 
			{
			case "!":
				return expr(e) != true;
			case "-":
				return -expr(e);
			case "++":
				return increment(e, prefix, 1);
			case "--":
				return increment(e, prefix, -1);
			case "~":
				return ~expr(e);
			default:
				error(EInvalidOp(op));
			}
		case ECall(e, params):
			var args = new Array();
			for(p in params)
				args.push(expr(p));
			return Reflect.callMethod(null, expr(e), args);
		case EIf(econd, e1, e2):
			return if(expr(econd) == true) expr(e1) else if(e2 == null) null else expr(e2);
		case EWhile(econd, e):
			whileLoop(econd, e);
			return null;
		case EFor(v, it, e):
			forLoop(v, it, e);
			return null;
		case EBreak:
			throw SBreak;
		case EContinue:
			throw SContinue;
		case EReturn(e):
			throw SReturn((e == null) ? null : expr(e));
		case EFunction(name, params, fexpr):
			if (name == null) name = "anonymous";
			var f = new VirtualFunction(this, name, params, fexpr);
			return f.bind(stack);
		case EArrayDecl(arr):
			var a = new Array();
			for(e in arr)
				a.push(expr(e));
			return a;
		case EArray(e,index):
			return expr(e)[expr(index)];
		case ENew(cl, params):
			var a = new Array();
			for(e in params)
				a.push(expr(e));
			return createInstance(cl, a);
		case EThrow(e):
			error(EScriptThrow(expr(e)));
		case ETry(e, n, ecatch):
			try 
			{
				var v : Dynamic = expr(e);
				return v;
			} 
			catch (err:Stop) 
			{
				error(EStop(Std.string(err)));
			} 
			catch (err:Dynamic) 
			{
				var v:Dynamic = expr(ecatch);
				return v;
			}
		case EObject(fl):
			var o = {};
			for(f in fl)
				set(o, f.name,expr(f.e));
			return o;
		case ETernary(econd, e1, e2):
			return if (expr(econd) == true) expr(e1) else expr(e2);
		case ELine(l):
			stack.__line__ = l;
			return null;
		default: return null;
		}
		return null;
	}
	
	public function exprReturn(e):Dynamic 
	{
		try 
		{
			return expr(e);
		} 
		catch (e:Stop ) 
		{
			switch(e) 
			{
			case SBreak: 
				error(EInvalid("break"));
			case SContinue: 
				error(EInvalid("continue"));
			case SReturn(v): return v;
			}
		}
		return null;
	}
	
	inline function declare(n:String, v:Dynamic):Void
	{
		Reflect.setField(stack, n, v);
	}
	
	function resolveClass(cl:String):Dynamic
	{
		if (classMap.exists(cl))
		{
			return classMap.get(cl).sVars;
		}
		var c = env.get(cl);
		if (c == null) c = Type.resolveClass(cl);
		if (c == null) error(EInvalid("Class:" + cl));
		return c;
	}
	
	function resolve(n:String):Dynamic 
	{
		if (Reflect.hasField(stack, n))
		{
			return Reflect.field(stack, n);
		}
		else if (context != null)
		{
			if (Reflect.hasField(context, n))
			{
				return Reflect.field(context, n);
			}
			else if (Reflect.hasField(context.__static__, n))
			{
				return Reflect.field(context.__static__, n);
			}
			else if (env.exists(n))
			{
				return env.get(n);
			}
			else if (n == "this")
			{
				return context;
			}
			else if (n == "super")
			{
				return context.__super__;
			}
			else
			{
				var _super:Dynamic = context.__super__; 
				while (_super != null)
				{
					if (Reflect.hasField(_super, n))
						return Reflect.field(_super, n);
					else
						_super = _super.__super__; 
				}
				return error(EInvalid("Access:" + n));
			}
		}
		else
		{
			return error(EInvalid("Access:" + n));
		}
	}
			
	function assign(e1:Expr, e2:Expr):Dynamic
	{
		var v = expr(e2);
		switch(e1) 
		{
		case EIdent(id):
			assignIdent(id, v);
		case EField(e, f):
			v = set(expr(e), f, v);
		case EArray(e, index):
			expr(e)[expr(index)] = v;
		default: 
			error(EInvalidOp("="));
		}
		return v;
	}
	
	function assignIdent(f:String, v:Dynamic):Void
	{
		if (Reflect.hasField(stack, f))
		{
			Reflect.setField(stack, f, v);
		}
		else if (context != null)
		{
			if (Reflect.hasField(context, f))
			{
				Reflect.setField(context, f, v);
			}
			else if (Reflect.hasField(context.__static__, f))
			{
				Reflect.setField(context.__static__, f, v);
			}
			else
			{
				return error(EInvalid("assignment"));
			}
		}
		else
		{
			error(EInvalid("assignment"));
		}
	}

	function get(o:Dynamic, f:String):Dynamic 
	{
		return Reflect.field(o, f);
	}

	function set(o:Dynamic, f:String, v:Dynamic):Dynamic 
	{
		if (o == null) 
		{
			error(EInvalidAccess(f));
		}
		Reflect.setField(o, f, v);
		return v;
	}
	
	function increment(e:Expr, prefix:Bool, delta:Int):Dynamic 
	{
		switch(e) 
		{
		case EIdent(id):
			var v:Dynamic = resolve(id);
			var l = resolve(id);
			if (prefix) 
			{
				v += delta;
				assignIdent(id, v);
			} 
			else 
			{
				assignIdent(id, v + delta);
			}
			return v;
		case EField(e,f):
			var obj = expr(e);
			var v:Dynamic = get(obj, f);
			if (prefix) 
			{
				v += delta;
				set(obj, f, v);
			} 
			else
			{
				set(obj, f, v + delta);
			}
			return v;
		case EArray(e, index):
			var arr = expr(e);
			var index = expr(index);
			var v = arr[index];
			if (prefix) 
			{
				v += delta;
				arr[index] = v;
			} 
			else
			{
				arr[index] = v + delta;
			}
			return v;
		default:
			error(EInvalidOp((delta > 0) ? "++" : "--"));
			return null;
		}
	}
	
	function whileLoop(econd, e):Void
	{
		while (expr(econd) == true)
		{
			try 
			{
				expr(e);
			} 
			catch (err:Stop) 
			{
				switch(err) 
				{
				case SContinue:
				case SBreak: break;
				case SReturn(_): 
					error(EStop(Std.string(err)));
				}
			}
		}
	}

	function forLoop(n, it, e):Void
	{
		var iterator:Dynamic = expr(it);
		if (iterator.iterator != null) iterator = iterator.iterator();

		while (iterator.hasNext()) 
		{
			declare(n, iterator.next());
			try 
			{
				expr(e);
			} 
			catch (err:Stop) 
			{
				switch(err) 
				{
				case SContinue:
				case SBreak: break;
				case SReturn(_): 
					error(EStop(Std.string(err)));
				}
			}
		}
	}
	
	function initOps():Void
	{
		var me = this;
		binops = new Map();
		
		binops.set("+", function(e1, e2) return me.expr(e1) + me.expr(e2));
		binops.set("-", function(e1, e2) return me.expr(e1) - me.expr(e2));
		binops.set("*", function(e1, e2) return me.expr(e1) * me.expr(e2));
		binops.set("/", function(e1, e2) return me.expr(e1) / me.expr(e2));
		binops.set("%", function(e1, e2) return me.expr(e1) % me.expr(e2));
		binops.set("&", function(e1, e2) return me.expr(e1) & me.expr(e2));
		binops.set("|", function(e1, e2) return me.expr(e1) | me.expr(e2));
		binops.set("^", function(e1, e2) return me.expr(e1) ^ me.expr(e2));
		binops.set("<<", function(e1, e2) return me.expr(e1) << me.expr(e2));
		binops.set(">>", function(e1, e2) return me.expr(e1) >> me.expr(e2));
		binops.set(">>>", function(e1, e2) return me.expr(e1) >>> me.expr(e2));
		binops.set("==", function(e1, e2) return me.expr(e1) == me.expr(e2));
		binops.set("!=", function(e1, e2) return me.expr(e1) != me.expr(e2));
		binops.set(">=", function(e1, e2) return me.expr(e1) >= me.expr(e2));
		binops.set("<=", function(e1, e2) return me.expr(e1) <= me.expr(e2));
		binops.set(">", function(e1, e2) return me.expr(e1) > me.expr(e2));
		binops.set("<", function(e1, e2) return me.expr(e1) < me.expr(e2));
		binops.set("||", function(e1, e2) return me.expr(e1) == true || me.expr(e2) == true);
		binops.set("&&", function(e1, e2) return me.expr(e1) == true && me.expr(e2) == true);
		binops.set("=", assign);
		binops.set("...", function(e1, e2) return new IntIterator (me.expr(e1), me.expr(e2)));
		
		assignOp("+=", function(v1:Dynamic, v2:Dynamic) return v1 + v2);
		assignOp("-=", function(v1:Float, v2:Float) return v1 - v2);
		assignOp("*=", function(v1:Float, v2:Float) return v1 * v2);
		assignOp("/=", function(v1:Float, v2:Float) return v1 / v2);
		assignOp("%=", function(v1:Float, v2:Float) return v1 % v2);
		assignOp("&=", function(v1, v2) return v1 & v2);
		assignOp("|=", function(v1, v2) return v1 | v2);
		assignOp("^=", function(v1, v2) return v1 ^ v2);
		assignOp("<<=", function(v1, v2) return v1 << v2);
		assignOp(">>=", function(v1, v2) return v1 >> v2);
		assignOp(">>>=", function(v1, v2) return v1 >>> v2);
	}
	
	function assignOp(op, fop:Dynamic->Dynamic->Dynamic):Void
	{
		var me = this;
		binops.set(op, function(e1, e2) return me.evalAssignOp(op, fop, e1, e2));
	}
	
	function evalAssignOp(op, fop, e1, e2):Dynamic 
	{
		var v;
		switch(e1) 
		{
		case EIdent(id):
			v = fop(expr(e1), expr(e2));
			assignIdent(id, v);
		case EField(e, f):
			var obj = expr(e);
			v = fop(get(obj,f),expr(e2));
			v = set(obj, f, v);
		case EArray(e, index):
			var arr = expr(e);
			var index = expr(index);
			v = fop(arr[index], expr(e2));
			arr[index] = v;
		default:
			error(EInvalidOp(op));
			return null;
		}
		return v;
	}
	
	function initEnv()
	{
		env = new Map<String, Dynamic>();
		
		//common
		env.set("trace", log);
		env.set("null", null);
		env.set("true", true);
		env.set("false", false);
		
		//Std
		env.set("Type", Type);
		env.set("Date", Date);
		env.set("DateTools", DateTools);
		env.set("EReg", EReg);//Failed
		env.set("IntIterator", IntIterator);
		env.set("Lambda", Lambda);
		env.set("List", List);
		env.set("Math", Math);
		env.set("Reflect", Reflect);
		env.set("Std", Std);
		env.set("String", String);
		env.set("StringBuf", StringBuf);
		env.set("StringTools", StringTools);
		env.set("Sys", Sys);
		env.set("Type", Type);
		env.set("Xml", Xml);
		
		env.set("haxe.CallStack", haxe.CallStack);
		env.set("haxe.Http", haxe.Http);
		env.set("haxe.Int64", haxe.Int64);
		env.set("haxe.Json", haxe.Json);
		env.set("haxe.Log", haxe.Log);
		env.set("haxe.Serializer", haxe.Serializer);
		env.set("haxe.Template", haxe.Template);
		env.set("haxe.Timer", haxe.Timer);
		env.set("haxe.Unserializer", haxe.Unserializer);
		env.set("haxe.Utf8", haxe.Utf8);
		
		env.set("haxe.crypto.Adler32", haxe.crypto.Adler32);
		env.set("haxe.crypto.BaseCode", haxe.crypto.BaseCode);
		env.set("haxe.crypto.Crc32", haxe.crypto.Crc32);
		env.set("haxe.crypto.Md5", haxe.crypto.Md5);
		env.set("haxe.crypto.Sha1", haxe.crypto.Sha1);
		
		env.set("haxe.ds.ArraySort", haxe.ds.ArraySort);
		env.set("haxe.ds.BalancedTree", haxe.ds.BalancedTree);
		env.set("haxe.ds.EnumValueMap", haxe.ds.EnumValueMap);
		env.set("haxe.ds.HashMap", haxe.ds.HashMap);
		env.set("haxe.ds.IntMap", haxe.ds.IntMap);
		env.set("haxe.ds.ObjectMap", haxe.ds.ObjectMap);
		env.set("haxe.ds.StringMap", haxe.ds.StringMap);
		env.set("haxe.ds.Vector", haxe.ds.Vector);
		env.set("haxe.ds.WeakMap", haxe.ds.WeakMap);

		env.set("haxe.io.BufferInput", haxe.io.BufferInput);
		env.set("haxe.io.Bytes", haxe.io.Bytes);
		env.set("haxe.io.BytesBuffer", haxe.io.BytesBuffer);
		env.set("haxe.io.BytesData", haxe.io.BytesData);
		env.set("haxe.io.BytesInput", haxe.io.BytesInput);
		env.set("haxe.io.BytesOutput", haxe.io.BytesOutput);
		env.set("haxe.io.Eof", haxe.io.Eof);
		env.set("haxe.io.Input", haxe.io.Input);
		env.set("haxe.io.Output", haxe.io.Output);
		env.set("haxe.io.Path", haxe.io.Path);
		env.set("haxe.io.StringInput", haxe.io.StringInput);
		
		env.set("sys.FileSystem", sys.FileSystem);
		env.set("sys.io.File", sys.io.File);
		env.set("sys.io.FileInput", sys.io.FileInput);
		env.set("sys.io.FileOutput", sys.io.FileOutput);
	}
	
	public function error(err:Error) 
	{
		var errors:Array<String> = new Array();
		errors.push("Error : " + Std.string(err));
		var _stack:Dynamic = stack;
		while (true)
		{
			if (_stack.__proto__ == null)
			{
				errors.push("Called from nested function...");
			}
			else
			{
				errors.push("Called from " + _stack.__proto__.className + "::" + _stack.__method__ 
							+ ", " + stack.__proto__.fileName + " " + _stack.__line__);
			}
			if (_stack.__stack__ == null)
			{
				break;
			}
			else
			{
				_stack = _stack.__stack__;
			}
		}
		var i:Int = errors.length - 1;
		while (i > -1)
		{
			Lib.println(errors[i]);
			i--;
		}
		Sys.exit(1);
		return null;
	}
	
	public function log(v:Dynamic)
	{
		Lib.println(stack.__proto__.fileName + ":" + stack.__line__ + ": " + stack.__method__ + " " + v);
	}
}

class VirtualClass
{
	public var fileName:String;
	public var className:String;
	public var superName:String;
	
	public var varsProto:Dynamic; //var define
	public var sVarsProto:Dynamic; //static var define
	public var sFunsProto:Dynamic; //static function define
	public var funsProto:Dynamic; //function define
	public var sVars:Dynamic; //store static variables
	
	var interp:Interpreter;
	
	public function new(interp:Interpreter)
	{
		this.interp = interp;
		
		varsProto = {};
		sVarsProto = {};
		funsProto = {};
		sFunsProto = {};
		sVars = { };
		sVars.__proto__ = this;
	}
	
	public inline function callStatic(f:String, args:Array<Dynamic>):Dynamic
	{
		return Reflect.callMethod(null, Reflect.field(sVars, f), args);
	}
	
	public inline function createInstance(args:Array<Dynamic>, callConstructor:Bool = true):Dynamic
	{
		var ins:Dynamic = { };
		ins.__proto__ = this;
		ins.__static__ = sVars;
		if (this.superName != null)
			ins.__super__ = interp.createEmptyInstance(this.superName);
		else
			ins.__super__ = null;
		
		var oldContext = interp.context;
		interp.context = ins;
		
		var fields:Array<String> = Reflect.fields(funsProto);
		for (f in fields)
		{
			Reflect.setField(ins, f, Reflect.field(funsProto, f).bind(ins));
		}
		fields = Reflect.fields(varsProto);
		for (f in fields)
		{
			if (Reflect.field(varsProto, f) != null)
			{
				Reflect.setField(ins, f, interp.expr(Reflect.field(varsProto, f)));
			}
			else
			{
				Reflect.setField(ins, f, null);
			}
		}
		if(callConstructor) Reflect.callMethod(null, Reflect.field(ins, "new"), args);//call new function
		
		interp.context = oldContext;

		return ins;
	}
	
	public function initialize():Void
	{
		var oldContext = interp.context;
		interp.context = sVars;
		
		var fields:Array<String> = Reflect.fields(sFunsProto);
		for (f in fields)
		{
			Reflect.setField(sVars, f, Reflect.field(sFunsProto, f).bind(sVars));
		}
		fields = Reflect.fields(sVarsProto);
		for (f in fields)
		{
			if (Reflect.field(sVarsProto, f) != null)
			{
				Reflect.setField(sVars, f, interp.expr(Reflect.field(sVarsProto, f)));
			}
			else
			{
				Reflect.setField(sVars, f, null);
			}
		}
		
		interp.context = oldContext;
	}
}

class VirtualFunction
{
	var name:String;
	var interp:Interpreter;
	var params:Array<String>;
	var expr:Expr;
	
	public function new(interp:Interpreter, name:String, params:Array<String>, expr:Expr)
	{
		this.interp = interp;
		this.params = params;
		this.expr = expr;
		this.name = name;
	}
	
	public function exec(context:Dynamic, args:Array<Dynamic>):Dynamic
	{
		if (args.length != params.length) 
		{
			interp.error(EInvalidParam);
		}

		var oldContext = interp.context;
		interp.context = context;
		var stack:Dynamic = { };
		stack.__stack__ = interp.stack;
		stack.__proto__ = context.__proto__;
		stack.__method__ = name;
		
		interp.stack = stack;
		
		for(i in 0...params.length)
			Reflect.setField(interp.stack, params[i], args[i]);
		var result = interp.exprReturn(expr);
		
		interp.context = oldContext;
		interp.stack = stack.__stack__;
		stack.__stack__ = null;
		stack.__proto__ = null;
		
		return result;
	}
	
	public function bind(context:Dynamic):Dynamic
	{
		return Reflect.makeVarArgs(exec.bind(context, _));
	}
}
