# gh-tools

github tools based on gh cli

## Install (macOS)

Install `gh-issues` command:

```bash
cd gh-tools
./install.sh
```

If `/usr/local/bin` is not writable, installer uses `~/.local/bin`.
You can also choose your own install path:

```bash
./install.sh --prefix "$HOME/bin"
```

After install, run directly:

```bash
gh-issues owner/repo --state all --limit 50
```

## gh_issues.nu

Export issues (with comments) of a repository to local markdown files.

Usage:

```bash
gh-issues owner/repo [--state open|closed|all] [--limit N] [--outdir DIR]
```

Or run without installation:

```bash
nu gh_issues.nu owner/repo [--state open|closed|all] [--limit N] [--outdir DIR]
```

Details:

* Default output directory is the repo name (the part after the slash). Override with `--outdir`.
* File naming pattern: `issue_<number>.md`.
* Each file includes: metadata header, body, comments.
* Auth required: run `gh auth login` first and ensure access to the repo.
* Progress line shows index, percentage, elapsed (e) and estimated remaining time (eta).

Example:

```bash
nu gh_issues.nu nushell/nushell --state all --limit 50
```
