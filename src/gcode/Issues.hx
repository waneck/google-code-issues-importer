package gcode;
import haxe.Http;
import haxe.xml.Fast;
using StringTools;
using Lambda;
using gcode.Issues;

class Issues
{

	private var project:String;
	private var colspec:Null<Array<String>>;
	private var all:Bool;
	private var resultNumber = 0;
	public function new(project:String, ?colspec:Array<String>, ?all=true)
	{
		this.project = project;
		this.colspec = colspec;
		this.all = true;
	}

	public function next():{ header:Array<String>, data:Array<Array<String>>, isLast:Bool }
	{
		var http = new Http('http://code.google.com/p/$project/issues/csv');
		http.setHeader("User-Agent", "curl/7.27.0");
		if(all)
			http.setParameter('can', '1');
		if (colspec != null)
			http.setParameter('colspec', colspec.join(" "));
		http.setParameter('start', resultNumber + "");
		http.onError = function(s) { throw 'Error contacting gooogle code: $s'; };
		var data = null;
		http.onData = function(s) {
			data = s;
		};
		http.request(false);

		var ret = parse(data, ','.code);
		var isLast = true;
		if (ret.data != null)
		{
			var lst = ret.data.pop();
			while (ret.data.length > 0 && (lst[0] == null || lst[0].startsWith("This file is truncated")))
			{
				if (lst[0].startsWith("This file is truncated"))
					isLast = false;

				lst = ret.data.pop();
			}
			resultNumber += ret.data.length;
		}
		return { header: ret.header, data: ret.data, isLast: isLast };
	}

	public function comments(id:Int):{ updated:String, title:String, entries:Array<{ published:String, title:String, content:String, author:String }> }
	{
		var http = new Http('http://code.google.com/feeds/issues/p/$project/issues/$id/comments/full');
		http.setHeader("User-Agent", "curl/7.27.0");
		http.onError = function(msg) throw msg;
		var data= null;
		http.onData = function(msg) data = msg;
		http.request(false);
		var x = new Fast(Xml.parse(data).firstElement());
		return {
			updated: x.node.updated.innerData,
			title: x.node.title.innerHTML.normalize(),
			entries: x.nodes.entry.map(function(e) return {
				published: e.node.published.innerData,
				title: e.node.title.innerHTML.normalize(),
				content: normalize(e.node.content.innerHTML),
				author: e.node.author.node.name.innerData
			}).array()
		};
	}

	public function issue(id:Int): { published:String, title:String, author:String, state:String, content:String, labels:Array<String> }
	{
		//http://code.google.com/feeds/issues/p/haxe/issues/full/3
		var http = new Http('http://code.google.com/feeds/issues/p/$project/issues/full/$id');
		http.setHeader("User-Agent", "curl/7.27.0");
		http.onError = function(msg) throw msg;
		var data= null;
		http.onData = function(msg) data = msg;
		http.request(false);
		try
		{
			var x = new Fast(Xml.parse(data).firstElement());
			var labels = x.nodes.resolve("issues:label").map(function(x) return x.innerData).array();
			return {
				published: x.node.published.innerData,
				title: x.node.title.innerHTML.normalize(),
				content: normalize(x.node.content.innerHTML),
				author: x.node.author.node.name.innerData,
				state: x.node.resolve('issues:state').innerData,
				labels: labels,
			};
		}
		catch(e:Dynamic) { return null; }
	}

	private static function normalize(s:String)
	{
		return s.split("<![CDATA[").join("").split("]]>").join("").split("&lt;").join("<").split("&gt;").join(">").split("&amp;").join("&");
	}

	private static function parse(s:String, sepCode:Int):{ header:Array<String>, data:Array<Array<String>> }
	{
		//quick and dirty csv parser
		var i = new haxe.io.StringInput(s);
		var header = [];
		var data:Array<Array<String>> = null;

		var cur = null;
		var buf = null;
		try
		{
			while(true)
			{
				if (data == null)
				{
					cur = header;
				} else {
					cur = [];
					data.push(cur);
				}

				buf = new StringBuf();
				var chr = i.readByte();
				while(true)
				{
					var inEscape = false;
					switch(chr)
					{
					case '"'.code if (inEscape):
							var b = i.readByte();
							if (b == '"'.code) {
								buf.addChar('"'.code);
								chr = i.readByte();
							} else {
								inEscape = false;
								chr = b;
							}
					case '"'.code:
						inEscape = true;
						chr = i.readByte();
					case '\n'.code if (!inEscape):
						break;
					case _ if (!inEscape && chr == sepCode):
						cur.push(buf.toString());
						buf = new StringBuf();
						chr = i.readByte();
					case _:
						buf.addChar(chr);
						chr = i.readByte();
					}
				}
				var b = buf.toString();
				if (b.length > 0)
					cur.push(b);

				if (data == null)
					data = [];
			}
		}
		catch(e:haxe.io.Eof)
		{
			var b = buf.toString();
			if (b.length > 0)
				cur.push(b);
		}

		return { header: header, data : data };
	}
}
