package vm;

import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Bytes;

import vm.AST;

class ByteCode
{
	var input:BytesInput;
	var output:BytesOutput;
	
	public function new() 
	{
	}
	
	function encodeClass(c:Expr)
	{
		output = new BytesOutput();
		output.bigEndian = true;
		
		switch(c)
		{
		case EClass(name, file, parent, vars, sVars, funs, sFuns):
			doEncodeString(name);
			doEncodeString(file);
			doEncodeString(parent);
			output.writeUInt16(vars.length);
			for (e in vars) doEncode(e);
			output.writeUInt16(sVars.length);
			for (e in sVars) doEncode(e);
			output.writeUInt16(funs.length);
			for (e in funs) doEncode(e);
			output.writeUInt16(sFuns.length);
			for (e in sFuns) doEncode(e);
		default: throw EInvalid("class");
		}
	}
	
	function decodeClass(b:Bytes):Expr
	{
		input = new BytesInput(b);
		input.bigEndian = true;
		
		var name = doDecodeString();
		var file = doDecodeString();
		var parent = doDecodeString();
		var vars = new Array();
		for (i in 0...input.readUInt16())
			vars.push(doDecode());
		var sVars = new Array();
		for (i in 0...input.readUInt16())
			sVars.push(doDecode());
		var funs = new Array();
		for (i in 0...input.readUInt16())
			funs.push(doDecode());
		var sFuns = new Array();
		for (i in 0...input.readUInt16())
			sFuns.push(doDecode());
		return EClass(name, file, parent, vars, sVars, funs, sFuns);
	}
	
	function doEncodeString(v:String) 
	{
		var vb = Bytes.ofString(v);
		output.writeUInt16(vb.length);
		output.write(vb);
	}

	function doDecodeString() 
	{
		var len = input.readUInt16();
		return input.readString(len);
	}

	function doEncodeConst(c:Const) 
	{
		switch(c) 
		{
		case CInt(v):
			output.writeByte(Type.enumIndex(c));
			output.writeInt32(v);
		case CFloat(f):
			output.writeByte(Type.enumIndex(c));
			output.writeFloat(f);
		case CString(s):
			output.writeByte(Type.enumIndex(c));
			doEncodeString(s);
		}
	}

	function doDecodeConst() 
	{
		return switch(input.readByte())
		{
		case 0:
			CInt(input.readInt32());
		case 1:
			CFloat(input.readFloat());
		case 2:
			CString(doDecodeString());
		default:
			throw EInvalid("Code");
		}
	}

	function doEncode(e:Expr) 
	{
		output.writeByte(Type.enumIndex(e));
		switch(e)
		{
		case EFunction(name, params, e):
			doEncodeString(name == null ? "" : name);
			output.writeByte(params.length);
			for(p in params)
				doEncodeString(p);
			doEncode(e);
		case EReturn(e):
			if(e == null)
				output.writeByte(255);
			else
				doEncode(e);
		case ECall(e, el):
			doEncode(e);
			output.writeByte(el.length);
			for(e in el)
				doEncode(e);
   
		case EConst(c):
			doEncodeConst(c);
		case EVar(n, e):
			doEncodeString(n);
			if(e == null)
				output.writeByte(255);
			else
				doEncode(e);
		case EIdent(v):
			doEncodeString(v);
		case EClassIdent(v):
			doEncodeString(v);
		case EObject(fl):
			output.writeByte(fl.length);
			for (f in fl) 
			{
				doEncodeString(f.name);
				doEncode(f.e);
			}
			
		case EParent(e):
			doEncode(e);
		case EField(e, f):
			doEncode(e);
			doEncodeString(f);
		case EBlock(el):
			output.writeUInt16(el.length);
			for (e in el)
			{
				doEncode(e);
			}
			
		case EBinop(op, e1, e2):
			doEncodeString(op);
			doEncode(e1);
			doEncode(e2);
		case EUnop(op, prefix, e):
			doEncodeString(op);
			output.writeByte(prefix ? 1 : 0);
			doEncode(e);
			
		case EIf(cond, e1, e2):
			doEncode(cond);
			doEncode(e1);
			if(e2 == null)
				output.writeByte(255);
			else
				doEncode(e2);
		case ETernary(cond, e1, e2):
			doEncode(cond);
			doEncode(e1);
			doEncode(e2);
		case EWhile(cond, e):
			doEncode(cond);
			doEncode(e);
		case EFor(v, it, e):
			doEncodeString(v);
			doEncode(it);
			doEncode(e);
		case EBreak, EContinue:
			
		case EArray(e, index):
			doEncode(e);
			doEncode(index);
		case EArrayDecl(el):
			output.writeByte(el.length);
			for(e in el)
				doEncode(e);
				
		case ENew(cl, params):
			doEncodeString(cl);
			output.writeByte(params.length);
			for(e in params)
				doEncode(e);
				
		case EThrow(e):
			doEncode(e);
		case ETry(e, v, ecatch):
			doEncode(e);
			doEncodeString(v);
			doEncode(ecatch);
			
		case ELine(l):
			doEncodeConst(CInt(l));
		
		default: throw EInvalid("Expr");
		}
	}
	
	
	function doDecode():Expr 
	{
		return switch(input.readByte()) 
		{
		case 3:
			var name = doDecodeString();
			var params = new Array();
			for(i in 0...input.readByte())
				params.push(doDecodeString());
			var e = doDecode();
			
			EFunction((name == "") ? null: name, params, e);
		case 4:
			EReturn(doDecode());
		case 5:
			var e = doDecode();
			var params = new Array();
			for (i in 0...input.readByte())
				params.push(doDecode());
			ECall(e, params);
			
		case 6:
			EConst(doDecodeConst());
		case 7:
			var n = doDecodeString();
			EVar(n, doDecode());
		case 8:
			EIdent(doDecodeString());
		case 9:
			EClassIdent(doDecodeString());
		case 10:
			var fl = new Array();
			for (i in 0...input.readByte()) 
			{
				var name = doDecodeString();
				var e = doDecode();
				fl.push({name:name, e:e});
			}
			EObject(fl);
			
		case 11:
			EParent(doDecode());
		case 12:
			var e = doDecode();
			EField(e, doDecodeString());
		case 13:
			var len = input.readUInt16();
			var a = new Array();
			for (i in 0...len)
			{
				a.push(doDecode());
			}
			EBlock(a);
			
		case 14:
			var op = doDecodeString();
			var e1 = doDecode();
			EBinop(op, e1, doDecode());
		case 15:
			var op = doDecodeString();
			var prefix = input.readByte() != 0;
			EUnop(op, prefix, doDecode());
			
		case 16:
			var cond = doDecode();
			var e1 = doDecode();
			EIf(cond, e1, doDecode());
		case 17:
			var cond = doDecode();
			var e1 = doDecode();
			ETernary(cond, e1, doDecode());	
		case 18:
			var cond = doDecode();
			EWhile(cond, doDecode());
		case 19:
			var v = doDecodeString();
			var it = doDecode();
			EFor(v, it, doDecode());
			
		case 20:
			EBreak;
		case 21:
			EContinue;
			
		case 22:
			var e = doDecode();
			EArray(e, doDecode());
		case 23:
			var el = new Array();
			for(i in 0...input.readByte())
				el.push(doDecode());
			EArrayDecl(el);
			
		case 24:
			var cl = doDecodeString();
			var el = new Array();
			for(i in 0...input.readByte())
				el.push(doDecode());
			ENew(cl, el);
			
		case 25:
			EThrow(doDecode());
		case 26:
			var e = doDecode();
			var v = doDecodeString();
			ETry(e, v, doDecode());
			
		case 27:
			ELine(Type.enumParameters(doDecodeConst())[0]);
	
		case 255:
			null;
		default:
			throw "Invalid code";
		}
	}

	
	public static function encode(e:Expr):Bytes 
	{
		var b = new ByteCode();
		b.encodeClass(e);
		return b.output.getBytes();
	}
	
	public static function decode(bytes:Bytes):Expr 
	{
		var b = new ByteCode();
		return b.decodeClass(bytes);
	}
}
