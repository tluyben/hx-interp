package ;

import haxe.unit.TestCase;

class TestStd extends TestCase
{
	var ins:Dynamic;

    override public function setup() 
	{
        ins = TestMain.current.createInstance("TestStd", []);
	}	
	
	function testDateTools()
	{
		assertTrue(ins.dateTest());
		assertTrue(ins.dateTools());
	}
	
	function testLamda()
	{
		assertTrue(ins.testLambda());
	}
	
	function testList()
	{
		assertTrue(ins.testList());
	}
	
	function testOther()
	{
		assertTrue(ins.testMath());
		assertTrue(ins.testReflect());
		assertTrue(ins.testOther());
		assertTrue(ins.testType());
		
		assertTrue(ins.testClass());
	}
}