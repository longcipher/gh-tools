#!/usr/bin/env nu
# GitHub issues exporter with fixed-width progress output (ms precision times).

def help [] {
  print (['gh_issues.nu usage:',
          '  nu gh_issues.nu owner/repo [--state <open|closed|all>] [--limit <n>] [--outdir <dir>]',
          'Options: --state (default open) --limit (default 200) --outdir (default repo name)',
          'Requires: gh auth login'] | str join (char nl))
}

def pad_left [s:string, w:int, ch:string = ' '] {
  let l = ($s | str length)
  if $l >= $w { $s } else { let pad_len = ($w - $l); let pad = (1..$pad_len | each { $ch } | str join ''); $pad + $s }
}

def zero_pad [n:int, w:int] {
  let s = ($n | into string)
  let l = ($s | str length)
  if $l >= $w { $s } else { let pad_len = ($w - $l); let pad = (1..$pad_len | each { '0' } | str join ''); $pad + $s }
}

def fmt_duration [d] {
  let ms = ($d / 1ms | into int)
  let m = (($ms / 60000) | into int)
  let rem = ($ms - ($m * 60000))
  let s = (($rem / 1000) | into int)
  let ms2 = ($rem - ($s * 1000))
  $"(zero_pad $m 2):(zero_pad $s 2).(zero_pad $ms2 3)"
}

def fmt_percent [i:int, total:int] {
  let pct = (((($i * 100.0) / $total) | math round --precision 1) | into string)
  pad_left $pct 5 ' '
}

def main [
  repo: string,
  --state: string = 'open',
  --limit: int = 200,
  --outdir: string
] {
  if ($repo | str contains '/') == false { print 'Error: repo must be owner/repo'; help; exit 1 }

  let repo_name = ($repo | split row '/' | last)
  let outdir = if $outdir == null { $repo_name } else { $outdir }
  mkdir $outdir | ignore

  print $"Fetching issue list for ($repo) ..."
  let issues_json = (gh issue list --repo $repo --state $state --limit $limit --json number err> /dev/stderr)
  if ($issues_json | str length) == 0 { print 'No issues returned.'; exit 0 }
  let issues = ($issues_json | from json)
  if ($issues | is-empty) { print 'No issues after parsing.'; exit 0 }

  let total = ($issues | length)
  let width_total = ($total | into string | str length)
  let start_time = (date now)
  print $"Found ( $total ) issues. Fetching details..."

  for entry in ($issues | enumerate) {
    let idx = $entry.index
    let issue = $entry.item
    let n = $issue.number
    let processed = ($idx + 1)
    let elapsed = (date now) - $start_time
    let remaining = ($total - $processed)
    let avg_per = if $processed > 0 { $elapsed / $processed } else { 0sec }
    let eta = if $remaining > 0 { $avg_per * $remaining } else { 0sec }

  let idx_disp = (pad_left ($processed | into string) $width_total ' ')
    let pct_disp = (fmt_percent $processed $total)
    let e_disp = (fmt_duration $elapsed)
    let eta_disp = (fmt_duration $eta)
    let path = $"($outdir)/issue_($n).md"
    let action = if ($path | path exists) { 'Overwrite' } else { 'Write    ' }
    print $"[($idx_disp)/($total) ($pct_disp)% e=($e_disp) eta=($eta_disp)] ($action) issue #($n)"

    let detail_raw = (gh issue view --repo $repo $n -c --json number,title,body,author,comments,createdAt,updatedAt,url,state,labels,assignees,milestone err> /dev/stderr)
    let data = ($detail_raw | from json)
    let labels = ( $data.labels | default [] | each {|l| $l.name } | str join ', ' | default '' )
    let assignees = ( $data.assignees | default [] | each {|a| $a.login } | str join ', ' | default '' )
    let milestone = ( $data.milestone.title? | default '' )
    let comments_md = (
      $data.comments | default [] | each {|c|
        let ca = ($c.createdAt | default '')
        let au = ($c.author.login | default 'unknown')
        let body = ($c.body | default '')
        $"### ($au) ($ca)\n\n($body)\n"
      } | str join (char nl)
    )
    let body_text = ($data.body | default '_No description_')
    let comments_section = if ($data.comments | is-empty) { '## Comments\n\n_No comments_\n' } else { $"## Comments\n\n($comments_md)" }
    let md = $"# Issue #($data.number): ($data.title)\n\n- State: ($data.state)\n- Author: ($data.author.login)\n- Created: ($data.createdAt)\n- Updated: ($data.updatedAt)\n- Labels: ($labels)\n- Assignees: ($assignees)\n- Milestone: ($milestone)\n- URL: ($data.url)\n\n## Body\n\n($body_text)\n\n($comments_section)"
    $md | save -f $path
  }

  let total_elapsed = (date now) - $start_time
  print $"Done. Files written to ($outdir). Total elapsed: (fmt_duration $total_elapsed)"
}
