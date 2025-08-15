#!/usr/bin/env nu
# Fetch GitHub issues (and comments) for a repository via gh CLI and export to markdown files.
# Usage: nu gh_issues.nu owner/repo [--state open|closed|all] [--limit <n>] [--outdir <dir>]

def help [] {
  print (['gh_issues.nu usage:',
          '  nu gh_issues.nu owner/repo [--state <open|closed|all>] [--limit <n>] [--outdir <dir>]',
          'Arguments:',
          '  owner/repo  GitHub repository coordinate.',
          'Options:',
          '  --state     Issue state filter (default: open).',
          '  --limit     Max number of issues to fetch (default: 200).',
          '  --outdir    Output directory (default: repo name part).',
          'Env:',
          '  GH_TOKEN / GITHUB_TOKEN respected by gh CLI.',
          'Prereqs:',
          '  gh CLI authenticated (gh auth login).'
         ] | str join (char nl))
}

def main [
  repo: string,          # owner/repo
  --state: string = 'open',
  --limit: int = 200,
  --outdir: string       # optional custom output directory
] {
  if ($repo | str contains '/') == false {
    print "Error: repo must be in owner/repo form";
    help;
    exit 1;
  }

  let repo_name = ($repo | split row '/' | last);
  let outdir = if $outdir == null { $repo_name } else { $outdir };
  mkdir $outdir | ignore

  print $"Fetching issue list for ($repo) ...";
  let issues_json = (gh issue list --repo $repo --state $state --limit $limit --json number err> /dev/stderr);
  if ($issues_json | str length) == 0 {
    print "No issues returned.";
    exit 0;
  }
  let issues = ($issues_json | from json);

  if ($issues | is-empty) {
    print "No issues after parsing.";
    exit 0;
  }

  let total = ($issues | length);
  let start_time = (date now);
  print $"Found ( $total ) issues. Fetching details...";

  for entry in ($issues | enumerate) {
    let idx = $entry.index;         # 0-based
    let issue = $entry.item;
    let n = $issue.number;
    let path = $"($outdir)/issue_($n).md";
  let percent = (((($idx + 1) * 100.0) / $total) | math round --precision 1);
    # 时间与耗时估算
    let processed = ($idx + 1);
    let elapsed = (date now) - $start_time; # duration
    let remaining = ($total - $processed);
    # 平均耗时 * 剩余数 = 预计剩余时间 (duration 支持除与乘)
    let avg_per = if $processed > 0 { $elapsed / $processed } else { 0sec };
    let eta = if $remaining > 0 { $avg_per * $remaining } else { 0sec };

    if ($path | path exists) {
      print $"[($processed)/($total) ($percent)% e=($elapsed) eta=($eta)] Overwrite issue #($n)";
    } else {
      print $"[($processed)/($total) ($percent)% e=($elapsed) eta=($eta)] Write issue #($n)";
    }

  let detail_raw = (gh issue view --repo $repo $n -c --json number,title,body,author,comments,createdAt,updatedAt,url,state,labels,assignees,milestone err> /dev/stderr);
    let data = ($detail_raw | from json);

    let labels = ( $data.labels | default [] | each {|l| $l.name } | str join ', ' | default '' );
    let assignees = ( $data.assignees | default [] | each {|a| $a.login } | str join ', ' | default '' );
    let milestone = ( $data.milestone.title? | default '' );

    let comments_md = (
      $data.comments | default [] | each {|c|
        let ca = ($c.createdAt | default '');
        let au = ($c.author.login | default 'unknown');
        let body = ($c.body | default '');
        $"### ($au) ($ca)\n\n($body)\n"
      } | str join (char nl)
    );

  let body_text = ($data.body | default '_No description_');
  let comments_section = if ($data.comments | is-empty) { "## Comments\n\n_No comments_\n" } else { $"## Comments\n\n($comments_md)" };
  let md = $"# Issue #($data.number): ($data.title)\n\n- State: ($data.state)\n- Author: ($data.author.login)\n- Created: ($data.createdAt)\n- Updated: ($data.updatedAt)\n- Labels: ($labels)\n- Assignees: ($assignees)\n- Milestone: ($milestone)\n- URL: ($data.url)\n\n## Body\n\n($body_text)\n\n($comments_section)";

    $md | save -f $path;
  }

  print $"Done. Files written to ($outdir).";
}

if ( (scope commands | where name == 'main') | is-empty ) == false {
  null | ignore
}
