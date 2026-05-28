# AGENTS.md — Multi-Agent Coordination Rules

This file governs behavior when multiple AI agents (or successive agent runs) work on this repository. Single-agent Claude Code sessions should also follow these rules.

---

## Pre-Task Checklist

Before any work on this repository, ALWAYS:

1. **Read CLAUDE.md first.** It contains hard constraints that override all other guidance.
2. **Check git status:** `git status`
3. **Check recent commits:** `git log --oneline -10`
4. **Verify you're in the right directory:** `pwd` → should be `~/Codes/myWorkspace/`

If anything is uncommitted or in a confusing state, ask the user before proceeding.

---

## Read-Only Operations (No Approval Needed)

These are safe — no risk of breaking the system or losing work:

- Reading any file in the repository
- Running `git status`, `git log`, `git diff`
- Running `git show <commit>`
- Checking system state: `pacman -Q`, `systemctl status`, `uname -r`
- Reading config files: `/etc/fstab`, `/etc/mkinitcpio.conf`, `/etc/systemd/journald.conf.d/`
- Testing syntax: `hyprctl reload`, `zsh -i -c "exit"`, shell script syntax checks
- Listing files: `find`, `ls`, `tree`
- Grepping for patterns: `grep`, `rg`

---

## Operations Requiring Explicit User Approval

**These modify system state or critical files. Always ask first.**

### File/System Modifications

- Editing `/etc/mkinitcpio.conf` → rebuilds the entire kernel boot environment
- Editing `/boot/loader/entries/` → changes boot behavior
- Running `sudo` commands that modify `/etc/`, `/boot/`, or system services
- Creating/deleting snapper snapshots
- Modifying `/etc/docker/daemon.json` or Docker system configs
- Enabling/disabling any system-level services: `sudo systemctl enable/disable`
- Changing user shell: `chsh`

### Package Management

- `pacman -S` (install packages) — even with `--needed`
- `yay -S` (AUR package install)
- `pacman -R`, `pacman -Rns` (remove packages)
- `yay -R` (AUR package removal)
- Any upgrade command: `pacman -Syu` (use `~/.local/bin/update.sh` instead)

### Git Operations

- `git push` or `git push --force` (affects remote)
- `git reset --hard`, `git checkout -- .` (destructive)
- `git branch -D`, `git tag -d` (deletion)
- `git stash drop` (loss of work)
- Any rebase or force operation

### Snapshot/Recovery Operations

- `snapper create`, `snapper delete` (any snapshot management)
- `snapper undochange` (modifying snapshot contents)
- Modifying `/etc/snapper/configs/`
- Subvolume operations: `btrfs subvolume`, `btrfs qgroup`

---

## Strictly Forbidden (Never Without Explicit User Command)

**These operations are prohibited outright unless the user explicitly asks for them. Do not attempt them even if they seem efficient.**

- Deleting any snapper snapshot
- Modifying `/boot/loader/entries/windows.conf` (Windows dual-boot entry — preserve as-is)
- Touching `/.snapshots/` directory
- Changing BTRFS subvolume layout or mount points
- Enabling SDDM or any other login manager (TTY autologin is the default and only canonical flow)
- Re-introducing HyDE, oh-my-zsh, GRUB, swww, optimus-manager, or any blacklisted component (see CLAUDE.md)
- Running `pacman -Rns` without explicit user instruction

---

## Testing Requirements

Before committing changes, verify:

### Shell Scripts

```bash
# Syntax check
bash -n install/00-pre.sh
bash -n install/01-btrfs-verify.sh
# ... all scripts in install/

# Verify set -euo pipefail is at the top
head -5 install/00-pre.sh | grep "set -euo pipefail"
```

### Hyprland Configs

```bash
# Syntax check (if Hyprland is installed)
hyprctl reload

# Verify a specific option was applied
hyprctl -j getoption general:border_size
```

### zsh Configs

```bash
# Test startup
zsh -i -c "exit"

# Test that plugins source correctly
zsh -i -c "echo \$HISTFILE"
```

### Git Commits

```bash
# Verify commit format matches convention from CLAUDE.md
git log --oneline -1

# Verify no large binaries were added
git ls-files -z --cached | xargs -0 du -h | sort -rh | head -10
```

---

## Commit Workflow

### Before Committing

1. Run `git status` — no surprises?
2. Run `git diff` — does the content match intent?
3. Verify the commit message format: `<type>(<scope>): <description>`
4. If modifying install scripts, syntax-check them: `bash -n <script>`
5. If modifying Hyprland, test: `hyprctl reload` (if running Hyprland)

### Commit Format

```
<type>(<scope>): <description>

Optional longer explanation if the change is non-obvious.

Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `chore`

**Scopes:** `hypr`, `waybar`, `zsh`, `kitty`, `nvidia`, `btrfs`, `packages`, `scripts`, `chrome`, `theme`, `gaming`, `docs`, `arch`

**Examples:**
- `feat(hypr): add SUPER+SHIFT+S workspace overview keybind`
- `fix(nvidia): add NVreg_PreserveVideoMemoryAllocations to modprobe.d`
- `docs(btrfs): clarify subvolume mount order for fresh install`
- `chore(packages): add lib32-vulkan-tools for 32-bit gaming`

### After Committing

- Do NOT push to remote without user approval
- Do NOT amend the commit (create a new one if a fix is needed)
- Print the commit hash and let the user see it: `git log -1 --oneline`

---

## Stow Operations

When deploying configs via stow:

**Correct command:**
```bash
cd ~/Codes/myWorkspace
stow -t ~ configs/<package>
```

**WRONG commands (do not use):**
```bash
stow -d configs <package>           # Wrong — stows INTO dotfiles dir
cd configs && stow <package>        # Wrong — changes CWD, breaks -t ~
```

**Conflict resolution (first-run):**
```bash
# If target file exists in home
stow --adopt -t ~ configs/<package>     # pulls existing files into repo
git checkout -- .                       # restores canonical content
```

Never delete user files first. Let stow handle it.

---

## Handling Build/Installation Errors

If an install script fails during execution:

1. **Do not retry immediately.** Understand the failure first.
2. **Check error messages.** Are they permanent (missing dependency) or transient (network)?
3. **Inspect the script.** Does `set -euo pipefail` catch the error?
4. **Ask the user.** What should happen next? Retry? Skip? Fix and re-run?

Never use `--ignore-errors`, `|| true`, or `set +e` to suppress errors. If an error must be ignored, document WHY with a comment.

---

## Handling Untracked Files

If `git status` shows untracked files in the working tree:

1. Investigate: `git check-ignore -v <file>` — is it in `.gitignore`?
2. If not in `.gitignore` and should be: add to `.gitignore` and commit
3. If untracked and should not be: ask user before adding or ignoring
4. Never blindly `git add .` — review changes first

---

## Emergency Procedures

### System Won't Boot

1. Boot into live USB (Arch ISO)
2. Follow `recovery/chroot-guide.md` to chroot into the system
3. Diagnose from chroot: `systemctl status`, `journalctl -b -e`
4. Do NOT attempt `pacman -S`, `snapper`, or other commands without full understanding

### Git Merge Conflicts

1. Do NOT force-push or reset --hard
2. Run `git status` to see conflicted files
3. Open each conflicted file and resolve manually
4. Run `git add <resolved files>` and `git commit` with a clear message

### Snapper Corruption

1. Do NOT delete snapshots automatically
2. Check `snapper -c root list` for valid snapshots
3. Ask user before performing rollback

---

## Multi-Agent Handoff

If work is being passed to another agent:

1. **Commit all progress.** No uncommitted changes.
2. **Write a clear commit message** explaining what was done and what's next.
3. **Leave a note in the task description** for the next agent: what's complete, what's pending, any gotchas.
4. **Do NOT leave work-in-progress state.** Either finish it or explicitly mark it incomplete.

---

## Dealing With Disagreement

If you believe a rule in CLAUDE.md or AGENTS.md is wrong or outdated:

1. **Do NOT violate the rule to prove the point.**
2. **Document your concern** in a comment or commit message.
3. **Ask the user** if the rule should be changed.
4. **Update the rule together** if the user agrees.

Example: "CLAUDE.md forbids `oh-my-zsh`, but the user now wants it installed. I'll ask for explicit permission to override CLAUDE.md before making the change."

---

## Summary: Ask vs. Act

| Scenario | Action |
|---|---|
| Reading a file | Act (safe) |
| Checking git status | Act (safe) |
| Editing install script | Ask (affects system) |
| Running pacman -S | Ask (package install) |
| Creating snapper snapshot | Ask (loss of space) |
| Git commit to local repo | Act (safe if on correct branch) |
| Git push to remote | Ask (affects others) |
| Editing CLAUDE.md or AGENTS.md | Ask (changes the rules) |
| Adding new stow package | Ask (affects home dir) |
| Deleting a file from the repo | Ask (loss of history) |

When in doubt: **ask the user first**.
