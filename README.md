# cresume

A cross-directory session resume picker for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

The built-in `/resume` only shows sessions from your current directory. `cresume` finds sessions across **all** your projects and lets you pick one with an interactive fuzzy finder — then `cd`s to the right directory and resumes it.

![picker preview](/cresume-preview.png)

## Features

- Scans all Claude Code sessions across every project directory
- Interactive fuzzy search via `fzf`
- Multi-line display: bold title, dim metadata (relative time, path, branch, size)
- Preview pane showing your first few prompts from the session
- Automatically `cd`s to the correct directory and resumes the session

## Dependencies

- [fzf](https://github.com/junegunn/fzf) — `brew install fzf`
- [jq](https://github.com/jqlang/jq) — `brew install jq`

## Install

```bash
# Clone the repo
git clone https://github.com/joshbermanssw/cresume.git ~/.claude/bin/cresume-repo

# Source it in your shell config
echo '[ -f "$HOME/.claude/bin/cresume-repo/cresume.sh" ] && source "$HOME/.claude/bin/cresume-repo/cresume.sh"' >> ~/.zshrc

# Or if you use bash
echo '[ -f "$HOME/.claude/bin/cresume-repo/cresume.sh" ] && source "$HOME/.claude/bin/cresume-repo/cresume.sh"' >> ~/.bashrc
```

Then restart your terminal or run `source ~/.zshrc`.

## Usage

```bash
cresume          # Pick from 50 most recent sessions
cresume -a       # Pick from all sessions
cresume <term>   # Pre-filter with a search term
```

## How it works

`cresume` is a shell **function** (not a script) so it can `cd` in your current shell. It:

1. Scans `~/.claude/projects/*/` for session `.jsonl` files
2. Extracts metadata (directory, branch, timestamps) and first user message from each
3. Presents them in `fzf` sorted by most recent, with a preview of your first few prompts
4. On selection: `cd`s to the project directory and runs `claude --resume <session-id>`

## License

MIT
