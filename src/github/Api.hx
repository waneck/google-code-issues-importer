package github;
import haxe.Http;
import haxe.Json;

/**
 * Github API
 * @author waneck
 */
class Api
{
	public var issues(default, null):Issues;

	private var token:String;

	public function new(token:String)
	{
		this.token = token;
		this.issues = new Issues(this);
	}

	public function test():{ response:Bool, message:String }
	{
		var h:Http = new Http('https://api.github.com/');
		// h.setParameter("access_token", token);
		var ok:Null<Bool> = null, msg = null;
		h.onData = function (s) { ok = true; msg = s; };
		h.onError = function (s) { ok = false; msg = s; };
		request(h,false);
		// h.request(false);

		return { response: ok, message: msg };
	}

	public function request(http:Http, post:Bool)
	{
		// http.setParameter("access_token", token);
		setAuth(http);
		http.request(post);
	}

	public function customRequest(http:Http, post:Bool, method:String)
	{
		setAuth(http);
		var output = new haxe.io.BytesOutput();
		var err = false;
		var old = http.onError;
		http.onError = function(e) {
			#if neko
			untyped http.responseData = neko.Lib.stringReference(output.getBytes());
			#else
			untyped http.responseData = output.getBytes().toString();
			#end
			err = true;
			old(e);
		}
		http.customRequest(post,output, null, method);
		if( !err )
		#if neko
			untyped http.onData(http.responseData = neko.Lib.stringReference(output.getBytes()));
		#else
			untyped http.onData(http.responseData = output.getBytes().toString());
		#end
	}

	public function setAuth(http:Http)
	{
		http.setHeader("User-Agent", "curl/7.27.0");
		http.setHeader("Authorization", 'token $token');
	}

	public dynamic function onError(s:String)
	{
		throw s;
	}
}

typedef Label = { url:String, name:String, color:String };
typedef User = { login:String, id:Int, avatar_url:String, gravatar_id:String, url:String };
typedef Milestone = { url:String, number:Int, state:String, title:String, description:String, creator:User, open_issues:Int, closed_issues:Int, created_at:String, due_on:Null<String> };

typedef Issue = {
	url:String,
	html_url:String,
	number:Int,
	state:String,
	title:String,
	body:String,
	user:User,
	labels:Array<Label>,
	assignee:User,
	milestone:Milestone,
	comments:Int,
	pull_request: { html_url:String, diff_url:String, patch_url:String },
	closed_at: Null<String>,
	created_at:String,
	updated_at:String
}

class Issues
{
	public var api(default, null):Api;

	public function new(api)
	{
		this.api = api;
	}

	public function get(repo:String, n:Int):Null<Issue>
	{
		var http = new Http('https://api.github.com/repos/$repo/issues/$n');
		var ret:Dynamic = null;
		http.onStatus = function(s:Int)
		{
			if (s == 404)
				http.onError = function(_) {};
		};
		http.onError = api.onError;
		http.onData = function(s) ret = Json.parse(s);
		api.request(http,false);
		if (ret.message != null)
		{
			if (ret.message == "Not Found")
				return null;
			api.onError(ret.message);
		}
		return ret;
	}

	public function create(repo:String, title:String, ?body:String, ?assignee:String, ?milestone:Int, ?labels:Array<String>, closed=false):Issue
	{
		var http = new Http('https://api.github.com/repos/$repo/issues');
		http.onError = api.onError;
		var obj:Dynamic = {};
		obj.title = title;
		if (body != null)
		{
			obj.body = haxe.Utf8.encode(body);
		}
		if (assignee != null) obj.assignee = assignee;
		if (milestone != null) obj.milestone = milestone;
		if (labels != null) obj.labels = labels;
		// if (closed) obj.state = "closed" else obj.state = "open";
		http.setPostData(Json.stringify(obj));

		var ret:Dynamic = null;
		http.onData = function(s) ret = Json.parse(s);

		api.request(http,true);

		if (closed) edit(repo,ret.number,title,body,assignee,milestone,labels,closed);
		return ret;
	}

	public function edit(repo:String, id:Int, title:String, ?body:String, ?assignee:String, ?milestone:Int, ?labels:Array<String>, ?closed)
	{
		var http = new Http('https://api.github.com/repos/$repo/issues/$id');
		http.onError = api.onError;
		var obj:Dynamic = {};
		obj.title = title;
		if (body != null)
		{
			obj.body = haxe.Utf8.encode(body);
		}
		if (assignee != null) obj.assignee = assignee;
		if (milestone != null) obj.milestone = milestone;
		if (labels != null) obj.labels = labels;
		if (closed) obj.state = "closed" else obj.state = "open";
		http.setPostData(Json.stringify(obj));

		api.setAuth(http);
		api.customRequest(http, true, "PATCH");
	}

	public function milestones(repo:String):Array<{ url:String, number:Int, title:String, description:String, creator:User }>
	{
		var http = new Http('https://api.github.com/repos/$repo/milestones');
		var ret:Dynamic = null;
		http.onError = api.onError;
		http.onData = function(s) ret = Json.parse(s);
		api.request(http,false);
		return ret;
	}

	public function createMilestone(repo:String, name:String):Int
	{
		var http = new Http('https://api.github.com/repos/$repo/milestones');
		var ret:Dynamic = null;
		http.onError = api.onError;
		http.onData = function(s) ret = Json.parse(s);
		var obj:Dynamic = { title:name };
		http.setPostData(Json.stringify(obj));
		api.request(http,true);
		trace(ret);
		return ret.number;
	}

	public function createComment(repo:String, id:Int, body:String)
	{
		var http = new Http('https://api.github.com/repos/$repo/issues/$id/comments');
		http.onError = api.onError;
		var obj:Dynamic = { body:body };
		http.setPostData(Json.stringify(obj));
		api.request(http,true);
	}
}
