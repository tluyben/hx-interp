package ;

import abc.ABC;
import haxe.io.BufferInput;
import vm.MVC;

class TestCommon
{
	var a = 3;
	var b:Int;
	
	function new(b:Int)
	{
		this.b = b;
	}
	
	function addVarB(b:Int)
	{
		this.b = this.b + b;
	}
	
	function forLoop1():Int
	{
		var total:Int = 0;
		for (i in 0...5)
		{
			total += i;
		}
		return total;
	}
	
	function forLoop2():Int
	{
		var total:Int = 0;
		var a:Array<Int> = [1, 2, 3, 4];
		for (i in 0...a.length)
		{
			total += a[i];
		}
		return total;
	}
	
	function forLoop3():Int
	{
		var total:Int = 0;
		var a:Array<Int> = [1, 2, 3, 4];
		for (i in a)
		{
			total += i;
		}
		return total;
	}
	
	function nestedFun():Int->Int->Int
	{
		var me = this;
		return function (a:Int, b:Int) { return a + b + me.a; };
	}

	function testIf1():Int
	{
		if (true)
		{
			return 1;
		}
                return 0;
	}
	
	function testIf2(v:Int):Int
	{
		if (v < 0)
		{
			return -1;
		}
		else if (v > 0)
		{
			return 1;
		}
		else
		{
			return 0;
		}
	}
	
	function testWhile():Int
	{
		var i:Int = 0;
		var total:Int = 0;
		while (i < 5)
		{
			total += i;
			i++;
		}
		return total;
	}
	
	function testIncrement():Dynamic
	{
		var o:Dynamic = { };
		o.a = 1;
		o.a += 10;
		o.a++;
		return o;
	}
	
	function testReturn():Void
	{
		this.a = 9;
		return;
		this.a = 19;
	}
	
	static function main()
	{
                MVC.initialize();
		trace("Hello compiler");
		
		//new ABC();
		new CC();
		
		#if ios
		trace("in ios");
		#else
		trace("not in ios");
		#end
		
		#if android
		trace("in android");
		#else
		trace("not in android");
		#end
		
		trace("start test mvc");
		
		trace(CommandA.execute);
		MVC.registerCommand("startUp", CommandA.execute);
		MVC.sendNotification("startUp");
	}
}

class CC extends DD implements AA implements BB
{
	public function new()
	{
		trace("new_cc");
		trace("run_super_dd");
		super();
	}
}

class DD extends ABC
{
	public function new()
	{
		trace("new_dd");
		trace("run_super_abc");
		super(9);
		
		superTest();
		superTest2();
		
		trace(xxx);
	}
	
	override public function superTest()
	{
		super.superTest();
		trace("function_child_test");
	}
}

interface AA
{
	
}

interface BB
{
	
}

class CommandA
{
	public static function execute(n:Notification)
	{
		trace("run cmd:name: " + n.name);
		trace("start mvc");
		
		var m = new MA();
		MVC.registerMediator("m", m);
		var p = new PA();
		MVC.registerMediator("p", p);
		
		p.onData();
	}
}

class MA
{
	public function new()
	{
		MVC.registerObserver("on_data", onData);
	}
	
	public function onData(n:Notification)
	{
		trace("get data in mediator:" + n.data);
	}
}

class PA
{
	public function new()
	{
		
	}
	
	public function onData()
	{
		MVC.sendNotification("on_data", 99);
	}
}

	
