package vm;

/*********************************************************************
 ******* hxvm compile -out -src -main -path[multi] -flag[multi] ******
 ******* hxvm runscript -src -main -path[multi] -flag[multi] *********
 ******* hxvm runbytes file ******************************************
 *********************************************************************
 ******************** Compiled Achieve Structure *********************
 ******* -main **********************************************
 ******* class list **************************************************
 ******* codes file (divide by class define) *************************
 *********************************************************************/


import cpp.Lib;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import sys.FileSystem;
import sys.io.File;

import vm.Interpreter;
import vm.Parser;
import vm.ByteCode;
import vm.AST;

class VM 
{
	var classes:Array<Expr>;
	var parser:Parser;
	var interp:Interpreter;
	
	public function new()
	{
	}
	
	public function callStatic(cl:String, f:String, args:Array<Dynamic>)
	{
		if (interp != null) 
			return interp.callStatic(cl, f, args);
		else
			return null;
	}
	
	public function createInstance(cl:String, args:Array<Dynamic>)
	{
		if (interp != null)
			return interp.createInstance(cl, args);
		else
			return null;
	}
	
	public function runBytes(path:String)
	{
		var bytes = File.getBytes(path);
		
		var input:BytesInput = new BytesInput(bytes);
		input.bigEndian = true;
		
		var len = input.readByte();
		var mainClass = input.read(len).toString();
		var total = input.readUInt16();
		for (i in 0...total)
		{
			len = input.readByte();
			input.read(len).toString();//fast way to read class name (lib)
		}
		classes = new Array<Expr>();
		for (i in 0...total)
		{
			len = input.readUInt24();
			classes.push(ByteCode.decode(input.read(len)));
		}
		bytes = null;
		
		interp = new Interpreter();
		interp.loadClasses(classes);
		classes = null;
		interp.callStatic(mainClass, "main", []);
	}
	
	public function runSource(info:ScriptInfo)
	{
		if (info.src == null) throw "Invalid source folder";
		if (info.main == null) throw "Invalid main class";
		
		parseSource(info.src, info.path, info.flags);
		
		parser = null;
		interp = new Interpreter();
		interp.loadClasses(classes);
		classes = null;
		interp.callStatic(info.main, "main", []);
	}
	
	public function encodeSource(info:ScriptInfo)
	{
		if (info.src == null) throw "Invalid source folder";
		if (info.main == null) throw "Invalid main class";
		if (info.out == null) throw "Invalid out file";
		
		parseSource(info.src, info.path, info.flags);
		
		var output:BytesOutput = new BytesOutput();
		output.bigEndian = true;
		output.writeByte(info.main.length);
		output.write(Bytes.ofString(info.main));
		var total:Int = 0;
		for (c in classes)
		{
			switch(c)
			{
			case EClass(name, file, parent, vars, sVars, funs, sFuns): total++;
			default:
			}
			
		}
		output.writeUInt16(total);
		for (c in classes)
		{
			switch(c)
			{
			case EClass(name, file, parent, vars, sVars, funs, sFuns):
				output.writeByte(name.length);
				output.write(Bytes.ofString(name));
			default:
			}
			
		}
		for (c in classes)
		{
			switch(c)
			{
			case EClass(name, file, parent, vars, sVars, funs, sFuns):
				var b:Bytes = ByteCode.encode(c);
				output.writeUInt24(b.length);
				output.write(b);
			default:
			}
		}
		
		File.saveBytes(info.out, output.getBytes());
		
		classes = null;
		parser = null;
	}
	
	
	function parseSource(src:String, path:Array<String>, flags:Array<String>)
	{
		classes = new Array<Expr>();
		parser = new Parser();
		
		for (p in path) parser.addPath(p);
		parseFolder(src, flags);
	}
	
	function parseFolder(folder:String, flags:Array<String>)
	{
		var files = FileSystem.readDirectory(folder);
		for (f in files)
		{
			if (FileSystem.isDirectory(folder + "/" + f))
			{
				parseFolder(folder + "/" + f, flags);
			}
			else
			{
				var cls:Array<Expr> = parser.parse(folder + "/" + f, f, flags);
				classes = classes.concat(cls);
			}
		}
		return null;
	}
	
	
	static function main() 
	{
		var args = Sys.args();
		if (args.length < 2) printUsage();
		
		switch(args[0])
		{
			case "compile":
				Lib.println("Compiling...");
				args.shift();
				var info = new ScriptInfo(args);
				var vm = new VM();
				vm.encodeSource(info);
				Lib.println("Export: " + info.out);
			case "runscript":
				Lib.println("Running...");
				args.shift();
				var info = new ScriptInfo(args);
				var vm = new VM();
				vm.runSource(info);
				Lib.println("Run completed");
			case "runbytes":
				Lib.println("Running...");
				var vm = new VM();
				vm.runBytes(FileSystem.fullPath(args[1]));
				Lib.println("Run completed");
			default: printUsage();
		}
	}
	
	static function printUsage()
	{
		Lib.println("hxvm: Compile or run script for haxe.");
		Lib.println("    Usage");
		Lib.println("    Compile    : hxvm compile -out file.hxc -src code_folder -main Main -path haxe_home/Std -path custom");
		Lib.println("    Run Script : hxvm runscript -src code_folder -main Main -path haxe_home/Std -path custom");
		Lib.println("    Run Bytes  : hxvm runbytes file.hxc");
	}
	
}

class ScriptInfo
{
	public var out:String;
	public var src:String;
	public var main:String;
	public var path:Array<String>;
	public var flags:Array<String>;
	
	public function new(args:Array<String>)
	{
		if ((args.length % 2) != 0) throw "Params error";
		path = new Array<String>();
		flags = new Array<String>();
		var i = 0;
		while (i < args.length)
		{
			switch(args[i])
			{
			case "-out":
				out = fullPath(args[i + 1]);
			case "-src":
				src = fullPath(args[i + 1]);
				path.push(fullPath(args[i + 1]));
			case "-path":
				path.push(fullPath(args[i + 1]));
			case "-flag":
				flags.push(args[i + 1]);
			case "-main":
				main = args[i + 1];
			default: throw "Params error";
			}
			i += 2;
		}
	}
	
	public inline function fullPath(path):String
	{
		var newPath = FileSystem.fullPath(path);
		if (!FileSystem.exists(newPath))
			throw "Folder doesn't exist:" + newPath;
		return newPath;
	}
}

