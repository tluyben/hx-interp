package vm;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sys.io.File;

/************************************
 * condition compile
 * #if #ifn #else #end
*************************************/

class PreParser
{
	var flags:Array<String>;
	var parts:Array<SplitInfo>;
	var output:Array<{start:Int, end:Int}>;
	var total:Int;
	
	public function new() 
	{
	}
	
	public function process(path:String, flags:Array<String>)
	{
		var content:String = File.getContent(path);
		total = content.length;
		
		parts = new Array<SplitInfo>();
		this.flags = flags;
		
		//find #condiftion
		var r:EReg = ~/#([A-Za-z0-9_.]+)/;
		var start:Int = 0;
		var len:Int = content.length;
		while (r.matchSub(content, start, len))
		{
			var pos:{pos:Int, len:Int} = r.matchedPos();
			start = pos.pos + pos.len;
			len = content.length - start;
			
			var info = new SplitInfo();
			info.start = pos.pos;
			info.end = pos.pos + pos.len;
			info.keyword = r.matched(1);
			parts.push(info);
		}
		
		if (parts.length == 0) return Bytes.ofString(content);
		
		r = ~/[ ]+([A-Za-z0-9_.]+)/;
		for (i in 0...parts.length)
		{
			if (parts[i].keyword.indexOf("if") != -1)
			{
				if (i == parts.length - 1) throw "#End Expected";
				if (r.matchSub(content, parts[i].start, parts[i + 1].start - parts[i].end))
				{
					parts[i].flag = r.matched(1);
					var pos:{pos:Int, len:Int} = r.matchedPos();
					parts[i].end = pos.pos + pos.len;
				}
				else
					throw "#if(ifn) Condition Expected";
			}
		}
		
		output = new Array<{start:Int, end:Int}>();
		
		add(0);
		
		var inBytes = Bytes.ofString(content);
		var bytesBuf = new BytesBuffer();
		for (i in 0...output.length)
		{
			for (j in output[i].start...output[i].end)
			{
				bytesBuf.addByte(inBytes.get(j));
			}
			if (i != output.length - 1)
			{
				for (j in output[i].end...output[i + 1].start)
				{
					var code = inBytes.get(j);
					if (code == 10 || code == 13)
					{
						bytesBuf.addByte(code);
					}
				}
			}
		}
		
		return bytesBuf.getBytes();
	}
	
	function add(start:Int)
	{
		var keyword = parts[start].keyword;
		
		if (start == 0)
			output.push({start:0, end:parts[0].start});
		else
			output.push({start:parts[start - 1].end, end:parts[start].start});
		
		if (keyword == "else" || keyword == "end") return start;
		
		while (true)
		{
			keyword = parts[start].keyword;
			if (keyword == "end" || keyword == "else") return start;
			
			var flag = parts[start].flag;
			if ((keyword == "if" && Lambda.indexOf(flags, flag) != -1) || (keyword == "ifn" && Lambda.indexOf(flags, flag) == -1))
			{
				start = add(start + 1);
				keyword = parts[start].keyword;
				if (keyword == "else")
					start = skip(start + 1);
			}
			else
			{
				start = skip(start + 1);
				keyword = parts[start].keyword;
				if (keyword == "else")
					start = add(start + 1);
			}
			if (parts[start].keyword != "end") throw "#End Expected";
			start++;
			if (start == parts.length)
			{
				output.push({start:parts[start - 1].end, end:total});
				break;
			}
			else
			{
				output.push({start:parts[start - 1].end, end:parts[start].start});
			}
		}
		
		return start;
	}
	
	function skip(start:Int)
	{
		while (true)
		{
			var keyword = parts[start].keyword;
			if (keyword == "end" || keyword == "else") break;
			
			if (keyword == "if" || keyword == "ifn")
				start++;
			else throw "Unexpected " + keyword;
			keyword = parts[start].keyword;
			if (keyword == "else")
				start++;
			keyword = parts[start].keyword;
			if (keyword == "end")
				start++;
			else throw "Unexpected " + keyword;
		}
		return start;
	}
	
}

class SplitInfo
{
	public var keyword:String;
	public var flag:String;
	public var start:Int;
	public var end:Int;
	
	public function new()
	{
		
	}
}

