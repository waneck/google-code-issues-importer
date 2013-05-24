package ;

import github.Api;
import mcli.CommandLine;
import mcli.Dispatch;
import neko.Lib;

/**
 * 
 * Google Code to Github issues importer
 * 
 * Usage: issueimport [options] <token> <google-code-repo> <github-project>
 * .  google-code-repo - name of the google code repo (e.g. haxe)
 * .  github           - path of github project (e.g. HaxeFoundation/Haxe)
 * 
 */
class Main extends CommandLine
{
	static function main() 
	{
		new Dispatch(Sys.args()).dispatch(new Main());
	}
	
	/**
	 * verbose mode
	 * @alias v
	 */
	public var verbose:Bool;
	
	/**
	 * github OAuth token
	 * @alias t
	 */
	public var token:String;
	
	/**
	 * shows this message
	 */
	public function help()
	{
		Sys.println(this.showUsage());
		Sys.exit(1);
	}
	
	public function runDefault(googleCode:String, github:String)
	{
		if (token == null)
		{
			warn("You must pass a valid OAuth token parameter");
			warn("");
			help();
		}
		log("Testing github connection");
		var g:Api = new Api(token);
		var t = g.test();
		if (!t.response)
		{
			warn("Authentication failed with message:");
			warn(t.message);
			Sys.exit(1);
		}
		
	}
	
	private function p(s:String)
	{
		Sys.println(s);
	}
	
	private function log(s:String)
	{
		if (verbose)
			Sys.println(s);
	}
	
	private function warn(s:String)
	{
		Sys.stderr().writeString(s + "\n");
	}
}