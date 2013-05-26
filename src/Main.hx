package ;

import github.Api;
import mcli.CommandLine;
import mcli.Dispatch;
using Lambda;
using StringTools;

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
	 * do not perform any destructive actions
	 * @alias d
	**/
	public var dryRun:Bool;

	/**
	 * force all answers to be yes
	 * @alias f
	**/
	public var force:Bool;

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

		var api:Api = new Api(token);
		var t = api.test();
		if (!t.response)
		{
			warn("Authentication failed with message:");
			warn(t.message);
			Sys.exit(1);
		}

		var n = null;
		var code = new gcode.Issues(googleCode);
		var milestones = new Map();
		var githubMilestones = api.issues.milestones(github);
		function getMilestone(milestone)
		{
			if (milestone == null || milestone == "") return null;

			var m = milestones.get(milestone);
			if (m != null) return m;
			if (dryRun) return null;

			m = api.issues.createMilestone(github, milestone);
			milestones.set(milestone, m);
			return m;
		}

		//start synchronizing
		var i = 0;
		while(true)
		{
			i++;
			log('Processing issue $i');
			// var issue = issues[i];
			var entry = code.issue(i);
			var giti = api.issues.get(github, i);
			if (entry == null)
			{
				break;
				warn('Found empty issue id $i.');
				//check if exists, and create stub
				if (giti == null)
				{
					warn('Creating stub issue for $i');
					if (!dryRun)
					{
						api.issues.create(github,'Google Code stub issue', 'This issue was created to keep Google Code and Github issue numbers in sync', ['imported'], true);
					}
				}
				continue;
			}
			//only do it if github issue does not exist
			//TODO support sync
			if (giti == null)
			{
				var googlei = code.comments(i);
				if (!dryRun)
				{
					var closed = entry.state == "closed";
					var content = '<i>[Google Issue #$i : http://code.google.com/$googleCode/issues/detail?id=$i]</i>\n by <i>${entry.author}, at ${entry.published}</i>\n' + entry.content.split('{{{').join('<pre>').split('}}}').join("</pre>");
					var milestone = null;
					var labels = entry.labels.filter(function(s) return if(s.startsWith('Milestone-')) { milestone = s.substr(10); false; } else true);
					var issue = api.issues.create(github, googlei.title, content, null, getMilestone(milestone), getLabels(labels), closed);
					//add comments
					for (c in googlei.entries)
					{
						api.issues.createComment(github, issue.number, '<i>[comment from ${c.author}, published at ${c.published}]</i>\n' + c.content);
					}
				}
			} else {
				log('issue already exists. skipping...');
			}

			//edit the issue
			//TODO
		}
	}

	private function ask(txt:String, def=true):Bool
	{
		if (force) return def;

		var response = null;
		p(txt);
		while(response != "y" && response != "n")
		{
			Sys.print("(y/n) ");
			response = Sys.stdin().readLine().toLowerCase();
		}
		return response == "y";
	}

	private function getLabels(labels:Array<String>)
	{
		if (labels == null) return ["imported"];
		var ret = ["imported"];
		for (l in labels)
		{
			ret.push(l.toLowerCase());
		}
		return ret;
	}

	// private function createIssue(gcodeHeader:Array<String>, gcodeIssue:Array<String>, ) {

	// }

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
