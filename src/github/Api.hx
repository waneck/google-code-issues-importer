package github;
import haxe.Http;

/**
 * Github API
 * @author waneck
 */
class Api
{
	private var token:String;
	
	public function new(token:String) 
	{
		this.token = token;
	}
	
	public function test():{ response:Bool, message:String }
	{
		var h:Http = new Http('https://api.github.com');
		h.setParameter("access_token", token);
		var ok:Null<Bool> = null, msg = null;
		h.onData = function (s) { ok = true; msg = s; };
		h.onError = function (s) { ok = false; msg = s; };
		h.request(false);
		
		return { response: ok, message: msg };
	}
	
	public dynamic function onError(s:String)
	{
		throw s;
	}
	
}