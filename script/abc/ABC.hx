package abc;

import abc.xxx.YYY;

class ABC
{
	var xxx:String;
	
	public function new(a:Int) 
	{
		trace("new_abc::" + a);
		/*
		new YYY();
		new DEF();
		new HHH();
		new abc.HHH();*/
		xxx = "xxx";
	}
	
	public function superTest()
	{
		trace("function_super_test");
	}
	
	public function superTest2()
	{
		trace("function_super_test2");
	}
}

class HHH
{
	public function new() 
	{
		trace("new_hhh");
	}
}