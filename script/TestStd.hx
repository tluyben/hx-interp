package ;

class TestStd
{
	function new() 
	{
		
	}
	
	function dateTest()
	{
		Date.now();
		Date.now().getFullYear();
		var d = new Date(2013, 9, 1, 0, 0, 0);
		return true;
	}
	
	function dateTools()
	{
		DateTools.hours(1);
		DateTools.parse(3600000);
		return true;
	}
	
	//ereg fail
	/*
	function testEReg()
	{
		var e = new EReg("^abc$", "");
		return e.match("eeee abc 123");
	}*/
	
	function testLambda()
	{
		if(Lambda.concat([1, 2], [3, 4]).length != 4) return false;
		if(Lambda.indexOf([1,2,3,4], 3) != 2) return false;
		if(Lambda.indexOf([1,2,3,4], 5) != -1) return false;
		if(Lambda.empty([]) != true) return false;
		
		return true;
	}
	
	function testList()
	{
		var a = new List();
		a.add(1);
		a.add(2);
		if(a.first() != 1) return false;
		if(a.last() != 2) return false;
		return true;
	}
	
	function testMath()
	{
		if (Math.max(1, 3) != 3) return false;
		return true;
	}
	
	function testReflect()
	{
		var o = { };
		Reflect.setField(o, "a", 1);
		return Reflect.field(o, "a") == 1;
	}
	
	function testType()
	{
		return Type.resolveClass("haxe.io.Input") != null;
	}
	
	function testOther()
	{
		Std.int(9.2);
		Std.random(10);
		
		var s = new String("xyz");
		if (s.length != 3) return false;
		//String.fromCharCode(25);//Failed  Reflect(String, "fromCharCode") doesn't work
		
		var b = new StringBuf();
		b.add("a");
		b.add("b");
		b.add("c");
		if (b.toString() != "abc") return false;
		return StringTools.endsWith("abc", "c");
	}
	
	function testClass()
	{
		var m = new haxe.ds.StringMap();
		m.set("a", 123);
		var o = new haxe.io.BytesOutput();
		o.writeInt32(128);
		return true;
	}
}