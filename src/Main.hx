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

		//ok, get issues from google code
		var issues = [];
		var header = null, nid:Null<Int> = null;

		var n = null;
		var code = new gcode.Issues(googleCode);
		do
		{
			log("Querying google code for issues");
			n = code.next();
			if (header == null)
			{
				header = n.header;
				nid = header.indexOf("ID");
				if (nid == -1)
					throw "Google code header must include issue ID. Its response header was however: " + header.join(",");
			}

			for (d in n.data)
			{
				issues.push(d);
			}
		}
		while(!n.isLast);

		var nmilestones = header.indexOf("Milestone"), nlabels = header.indexOf("AllLabels"), nstatus = header.indexOf("Status");
		var milestones = new Map();
		var githubMilestones = api.issues.milestones(github);
		for(m in githubMilestones)
		{
			milestones.set(m.title, m.number);
		}

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

		log(issues.length + " issues found");
		//sort by id
		var oissues = [];
		for (i in issues)
		{
			var id = Std.parseInt(i[nid]);
			if (id == null) throw 'Unexpected ${i[nid]} as ID';
			if (oissues[id] != null) throw 'Duplicate issue for $id';
			oissues[id] = i;
		}
		issues = oissues;
		//start synchronizing

		for (i in 1...issues.length)
		{
			log('Processing issue $i');
			var issue = issues[i];
			var giti = api.issues.get(github, i);
			if (issue == null)
			{
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
					var closed = switch(issue[nstatus].trim())
					{
						case "Fixed","WontFix","Invalid","Done":true;
						default: false;
					};
					var entry = code.issue(i);
					var closed = entry.state == "closed";
					var content = '[Google Issue #$i : http://code.google.com/$googleCode/issues/detail?id=$i]\n by ${entry.author}, at ${entry.published}\n' + entry.content;
					var issue = api.issues.create(github, googlei.title, content, null, getMilestone(issue[nmilestones]), getLabels(issue[nlabels].split(', ')), closed);
					//add comments
					for (c in googlei.entries)
					{
						api.issues.createComment(github, issue.number, '[comment from ${c.author}, published at ${c.published}]\n' + c.content);
					}
				}
			}

			//edit the issue
			//TOOD
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
			ret.push(l);
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
