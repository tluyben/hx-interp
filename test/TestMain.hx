package ;

import sys.io.File;
import vm.VM;

class TestMain
{
	public static var current:vm.VM;

	public function new() 
	{
		
	}
	
	public function run()
	{
		var vm = new VM();
		var info = new ScriptInfo(["-src", "./script", "-main", "TestCommon", "-path", "C:/HaxeToolkit/haxe/std", "-path", "./src", "-flag", "ios"]);
		vm.runSource(info);
		
		current = vm;
		
		var r = new haxe.unit.TestRunner();
        r.add(new TestCommon());
        r.add(new TestStd());

        r.run();
	}
}