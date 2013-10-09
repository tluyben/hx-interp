package ;

import haxe.unit.TestCase;

class TestCommon extends TestCase
{
	var ins:Dynamic;

    override public function setup() 
	{
        ins = TestMain.current.createInstance("TestCommon", [5]);
	}	
	
    public function testAssignment()
	{
        assertEquals(ins.b, 5);
    }
	
	public function testCallFunc()
	{
		ins.addVarB(3);
		assertEquals(ins.b, 8);
	}
	
	public function testConstructor()
	{
		assertEquals(ins.a, 3);
	}
	
    public function testFor()
	{
        assertEquals(ins.forLoop1(), 10);
        assertEquals(ins.forLoop2(), 10);
        assertEquals(ins.forLoop3(), 10);
	}
	
	public function testNested()
	{
		ins.a = 10;
		var f = ins.nestedFun();
		assertEquals(f(2, 5), 17);
	}
	
	public function testIf()
	{
		assertEquals(ins.testIf1(), 1);
		assertEquals(ins.testIf2(5), 1);
		assertEquals(ins.testIf2(-5), -1);
		assertEquals(ins.testIf2(0), 0);
	}
	
	public function testWhile()
	{
		assertEquals(ins.testWhile(), 10);
	}
	
	public function testIncrement()
	{
		assertEquals(ins.testIncrement().a, 12);
	}
	
	public function testReturn()
	{
		ins.testReturn();
		assertEquals(ins.a, 9);
	}
}