# Branch Interview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Claude Code plugin whose `branch-interview` skill interviews an engineer about their own change, one chunk at a time, until they show they own it, and writes a committed report with their answers verbatim.

**Architecture:** A bash script (`scope.sh`) does all deterministic work: resolving the scope to hunks, hashing, noise flags, and comparing against saved state. A plugin agent (`dossier-builder`) analyzes batches of files in parallel and writes one dossier per chunk to disk. `SKILL.md` drives the session: plan, hint-ladder interview, state updates, report.

**Tech Stack:** bash 3.2+ and git 2.30+ (no `jq`, no `shasum`), Claude Code plugin manifests, Markdown skill and agent files, GitHub Actions with `shellcheck`.

**Spec:** `docs/superpowers/specs/2026-09-26-branch-interview-design.md`

## Global Constraints

- `scope.sh` runs on macOS `/bin/bash` 3.2: no associative arrays, no `mapfile`, no `${var,,}`, no GNU-only flags (`sed -i`, `grep -P`, `readlink -f`).
- `scope.sh` depends only on bash, git, and POSIX tools (`awk`, `sed`, `grep`, `head`, `tail`, `cut`, `sort`, `tr`, `mktemp`). No `jq`, `shasum`, `sha1sum`, `python`.
- `scope.sh` never modifies the index or the working tree (no `git add -N`, no `git stash`).
- Hunk hash = `git hash-object --stdin` over the file path plus the hunk's `+`/`-` lines with trailing whitespace stripped; line numbers excluded.
- Base branch order: `$BRANCH_INTERVIEW_BASE`, then `main`, then `origin/HEAD`, otherwise exit 4.
- Local state lives in `.branch-interview/<key>/` (gitignored). The report lives in `docs/interviews/<key>.md` and is committed by the engineer, never by the skill.
- Session language is Russian or English only.
- Plugin name: `branch-interview`. Agent reference: `branch-interview:dossier-builder`.
- Formatting follows `.editorconfig`: UTF-8, LF, 2-space indent.
- Commit messages use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Branch with only noise** (lockfile bump, rename): `hunks` returns rows but all flagged; the skill must say "nothing to interview" instead of dispatching zero agents or crashing. Pinned in Task 3 (`test_hunks_only_noise`) and Task 9 (SKILL.md step 5).
2. **Path with spaces or non-ASCII characters**: git quotes such paths by default, which would break file matching and hashes. Pinned in Task 3 (`test_hunks_files_untracked_and_spaces`, `test_hunks_unicode_path`).
3. **Engineer edits the file mid-session so the current chunk's hunk hash changes**: `show` must fail cleanly (exit 5) rather than print a wrong hunk, and the final `diff-state` must report `changed`. Pinned in Task 4 (`test_show`, `test_diff_state`).
4. **Deleted file**: range comes from the old side; the hunk must still get a file name and a stable hash. Pinned in Task 3 (`test_hunks_deleted_file`).
5. **Engineer answers in the other language** (writes English in a Russian session): the skill keeps the session language and does not switch. Pinned in Task 7 (scenario `09-language-switch`).

---

## File map

| File | Responsibility | Task |
|------|----------------|------|
| `.claude-plugin/plugin.json` | Plugin manifest | 1 |
| `.claude-plugin/marketplace.json` | Marketplace manifest | 1 |
| `.gitignore` | Ignore `.branch-interview/` | 1 |
| `skills/branch-interview/scripts/scope.sh` | Deterministic scope, hunks, hashes, noise, state diff | 2–4 |
| `tests/scope.test.sh` | Tests for `scope.sh` | 2–4 |
| `.github/workflows/ci.yml` | shellcheck and tests on Ubuntu and macOS | 5 |
| `tests/skill/make-fixture.sh` | Builds the fixture repo for behavior tests | 6 |
| `tests/skill/fixtures/retry-dossier.md` | Hand-written dossier used by scenarios | 7 |
| `tests/skill/scenarios/*.md` | Interview pressure scenarios | 7 |
| `tests/skill/README.md` | How to run control and treatment | 7 |
| `tests/skill/results/*.md` | Recorded baseline and skill runs | 7, 9, 10 |
| `agents/dossier-builder.md` | Plugin agent that writes dossiers | 8 |
| `tests/check-dossier.sh` | Structural check for dossier files | 8 |
| `skills/branch-interview/SKILL.md` | Session driver | 9, 10 |
| `skills/branch-interview/report-template.md` | Report skeleton, ru and en headings | 9 |
| `README.md`, `CLAUDE.md` | Install, usage, commands | 11 |

---

### Task 1: Plugin scaffold

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Modify: `.gitignore` (append)

**Interfaces:**
- Produces: plugin name `branch-interview`; marketplace name `claude-branch-interview`.

- [ ] **Step 1: Write `plugin.json`**

```json
{
  "name": "branch-interview",
  "description": "Interviews an engineer about the code in their branch until they show they own it.",
  "version": "0.1.0",
  "author": {
    "name": "BorysShulyak"
  },
  "homepage": "https://github.com/BorysShulyak/claude-branch-interview",
  "repository": "https://github.com/BorysShulyak/claude-branch-interview",
  "license": "MIT",
  "keywords": ["code-review", "ownership", "interview", "git", "branch"]
}
```

- [ ] **Step 2: Write `marketplace.json`**

```json
{
  "name": "claude-branch-interview",
  "description": "Marketplace for the branch-interview plugin",
  "owner": {
    "name": "BorysShulyak"
  },
  "plugins": [
    {
      "name": "branch-interview",
      "description": "Interviews an engineer about the code in their branch until they show they own it.",
      "version": "0.1.0",
      "source": "./",
      "author": {
        "name": "BorysShulyak"
      }
    }
  ]
}
```

- [ ] **Step 3: Append to `.gitignore`**

```gitignore

# branch-interview local state
.branch-interview/
```

- [ ] **Step 4: Validate**

Run: `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool .claude-plugin/marketplace.json >/dev/null && echo valid`
Expected: `valid`

Run: `claude plugin validate .`
Expected: no errors. If the command does not exist in the installed Claude Code version, note that in the task report and continue.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin .gitignore
git commit -m "feat: add plugin and marketplace manifests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `scope.sh` skeleton and `meta`

**Files:**
- Create: `skills/branch-interview/scripts/scope.sh`
- Create: `tests/scope.test.sh`
- Modify: `docs/superpowers/specs/2026-09-26-branch-interview-design.md` (`scope.sh` section)

**Interfaces:**
- Produces: `scope.sh meta <mode> [paths...]` prints four lines `key=…`, `mode=…`, `base_sha=…`, `head_sha=…`.
- Produces: exit codes `2` usage, `3` not a git repository, `4` no base branch.
- Produces: shell functions later tasks call: `die <code> <msg>`, `usage`, `git_`, `require_repo`, `base_ref`, `check_mode "$@"`, `from_sha <mode>`, `branch_label`.
- Produces: test harness helpers `ok`, `not_ok`, `assert_eq <name> <expected> <actual>`, `assert_contains <name> <needle> <haystack>`, `scope`, `new_repo` (sets `$REPO`, cwd inside, branch `main`, file `app.txt` with lines `a`..`j`), `field <n>`, and the `# --- runner ---` marker.

- [ ] **Step 1: Write the failing tests**

Create `tests/scope.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for skills/branch-interview/scripts/scope.sh. Plain bash, no dependencies.
# Usage: bash tests/scope.test.sh
set -uo pipefail

SCOPE="${SCOPE:-$(cd "$(dirname "$0")/.." && pwd)/skills/branch-interview/scripts/scope.sh}"

ok() { echo "ok   - $1"; }
not_ok() { echo "FAIL - $1"; printf '       %s\n' "$2"; }

assert_eq() { # name expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1" "expected [$2] got [$3]"; fi
}
assert_contains() { # name needle haystack
  case "$3" in *"$2"*) ok "$1" ;; *) not_ok "$1" "[$2] not in [$3]" ;; esac
}

scope() { bash "$SCOPE" "$@"; }

# Fresh repo on main with one commit; cwd moves into it.
new_repo() {
  REPO=$(mktemp -d)
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.email t@example.com
  git config user.name tester
  printf 'a\nb\nc\nd\ne\nf\ng\nh\ni\nj\n' > app.txt
  git add app.txt
  git commit -qm init
}

field() { cut -f"$1"; }

test_meta_branch() {
  new_repo
  git checkout -qb feat/retry
  printf 'x\n' >> app.txt && git commit -qam change
  local out
  out=$(scope meta branch)
  assert_contains "meta: slash in branch becomes dash" "key=feat-retry" "$out"
  assert_contains "meta: base_sha is merge-base" "base_sha=$(git rev-parse main)" "$out"
  assert_contains "meta: head_sha" "head_sha=$(git rev-parse HEAD)" "$out"
}

test_meta_other_modes() {
  new_repo
  git checkout -qb dev
  printf 'x\n' >> app.txt && git commit -qam change
  assert_contains "meta: last-commit key" "key=dev-commit-$(git rev-parse --short=7 HEAD)" "$(scope meta last-commit)"
  assert_contains "meta: uncommitted key" "key=dev-uncommitted" "$(scope meta uncommitted)"
  local k1 k2
  k1=$(scope meta files b.txt a.txt | grep key=)
  k2=$(scope meta files a.txt b.txt | grep key=)
  assert_eq "meta: files key ignores path order" "$k1" "$k2"
  assert_contains "meta: files key prefix" "key=dev-files-" "$k1"
}

test_meta_detached() {
  new_repo
  git checkout -q --detach
  assert_contains "meta: detached HEAD uses sha7" "key=$(git rev-parse --short=7 HEAD)" "$(scope meta branch)"
}

test_errors() {
  local d
  d=$(mktemp -d) && cd "$d" || exit 1
  scope meta branch >/dev/null 2>&1
  assert_eq "error: not a repo exits 3" "3" "$?"
  git init -q -b trunk && git config user.email t@example.com && git config user.name t
  printf 'a\n' > a && git add a && git commit -qm a
  scope meta branch >/dev/null 2>&1
  assert_eq "error: no base exits 4" "4" "$?"
  assert_contains "error: BRANCH_INTERVIEW_BASE override" "base_sha=$(git rev-parse trunk)" "$(BRANCH_INTERVIEW_BASE=trunk scope meta branch)"
  BRANCH_INTERVIEW_BASE=nope scope meta branch >/dev/null 2>&1
  assert_eq "error: unknown BRANCH_INTERVIEW_BASE exits 4" "4" "$?"
  scope meta nope >/dev/null 2>&1
  assert_eq "error: bad mode exits 2" "2" "$?"
  scope meta files >/dev/null 2>&1
  assert_eq "error: files without paths exits 2" "2" "$?"
  scope meta branch extra >/dev/null 2>&1
  assert_eq "error: extra argument exits 2" "2" "$?"
}

# --- runner ---
OUT=$(mktemp)
for t in $(declare -F | awk '{ print $3 }' | grep '^test_'); do
  ( "$t" )
done > "$OUT" 2>&1
cat "$OUT"
PASS=$(grep -c '^ok' "$OUT")
FAIL=$(grep -c '^FAIL' "$OUT")
rm -f "$OUT"
echo "# pass $PASS, fail $FAIL"
[ "$FAIL" -eq 0 ] && [ "$PASS" -gt 0 ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/scope.test.sh`
Expected: last line `# pass 1, fail 14`, exit code 1. The one pass is `meta: files key ignores path order`, which compares two empty outputs while the script does not exist.

- [ ] **Step 3: Write the skeleton**

Create `skills/branch-interview/scripts/scope.sh`:

```bash
#!/usr/bin/env bash
# scope.sh: mechanical part of branch-interview.
# Resolves a scope to hunks, hashes them, flags noise, and compares against saved state.
# Must stay compatible with bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile.
set -euo pipefail

EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904

die() { echo "scope.sh: $2" >&2; exit "$1"; }

usage() {
  cat >&2 <<'EOF'
usage:
  scope.sh meta       <mode> [paths...]
  scope.sh hunks      <mode> [paths...]
  scope.sh diff-state <hunks.tsv> <mode> [paths...]
  scope.sh show       <hunk_hash> <mode> [paths...]
modes: branch | last-commit | uncommitted | files <path>...
EOF
  exit 2
}

git_() { git -c core.quotePath=false "$@"; }

require_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 3 "not a git repository"
}

base_ref() {
  if [ -n "${BRANCH_INTERVIEW_BASE:-}" ]; then
    git rev-parse --verify -q "$BRANCH_INTERVIEW_BASE^{commit}" >/dev/null \
      || die 4 "base '$BRANCH_INTERVIEW_BASE' not found"
    echo "$BRANCH_INTERVIEW_BASE"
  elif git rev-parse --verify -q "main^{commit}" >/dev/null; then
    echo main
  elif git symbolic-ref -q refs/remotes/origin/HEAD >/dev/null; then
    git symbolic-ref -q --short refs/remotes/origin/HEAD
  else
    die 4 "no base branch: main and origin/HEAD not found; set BRANCH_INTERVIEW_BASE"
  fi
}

check_mode() {
  case "$1" in
    branch|last-commit|uncommitted) [ "$#" -eq 1 ] || usage ;;
    files) [ "$#" -ge 2 ] || usage ;;
    *) usage ;;
  esac
}

# Prints the commit the diff starts from.
from_sha() {
  case "$1" in
    branch|files) local b; b=$(base_ref) || exit $?; git merge-base "$b" HEAD ;;
    last-commit) git rev-parse --verify -q HEAD~1 || echo "$EMPTY_TREE" ;;
    uncommitted) git rev-parse HEAD ;;
  esac
}

branch_label() {
  local b
  if b=$(git symbolic-ref -q --short HEAD); then
    printf '%s' "$b" | tr '/' '-'
  else
    git rev-parse --short=7 HEAD
  fi
}

cmd_meta() {
  local mode=$1 label key head base
  shift
  label=$(branch_label)
  head=$(git rev-parse HEAD)
  base=$(from_sha "$mode")
  case "$mode" in
    branch) key=$label ;;
    last-commit) key="$label-commit-$(git rev-parse --short=7 HEAD)" ;;
    uncommitted) key="$label-uncommitted" ;;
    files) key="$label-files-$(printf '%s\n' "$@" | LC_ALL=C sort | git hash-object --stdin | cut -c1-6)" ;;
  esac
  echo "key=$key"
  echo "mode=$mode"
  echo "base_sha=$base"
  echo "head_sha=$head"
}

main() {
  [ "$#" -ge 2 ] || usage
  local cmd=$1
  shift
  require_repo
  case "$cmd" in
    meta) check_mode "$@"; cmd_meta "$@" ;;
    *) usage ;;
  esac
}

main "$@"
```

Note: `scope meta nope` with a non-repo cwd would exit 3 before 2; the tests run the usage cases inside a repo, so this order is intended.

- [ ] **Step 4: Run tests to verify they pass**

Run: `/bin/bash tests/scope.test.sh`
Expected: last line `# pass 15, fail 0`, exit code 0.

- [ ] **Step 5: Update the spec's `scope.sh` section**

In `docs/superpowers/specs/2026-09-26-branch-interview-design.md`, replace the command block under `## \`scope.sh\`` with:

```
scope.sh meta       <mode> [paths...]              → key=, mode=, base_sha=, head_sha=
scope.sh hunks      <mode> [paths...]              → TSV: hunk_hash file start-end +N -M noise
scope.sh diff-state <hunks.tsv> <mode> [paths...]  → TSV: new|changed|same|removed hunk_hash chunk_id
scope.sh show       <hunk_hash> <mode> [paths...]  → hunk +/- lines for display

Exit codes: 2 usage, 3 not a git repository, 4 no base branch, 5 hunk not found.
Base override: BRANCH_INTERVIEW_BASE=<ref>.
```

Add one sentence below it: "Fixed arguments come before the mode because `files` takes a variable number of paths; `meta` replaces `key` so that one call gives the state header."

- [ ] **Step 6: Commit**

```bash
git add skills/branch-interview/scripts/scope.sh tests/scope.test.sh docs/superpowers/specs/2026-09-26-branch-interview-design.md
git commit -m "feat: add scope.sh with meta command

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `scope.sh hunks` with hashing and noise

**Files:**
- Modify: `skills/branch-interview/scripts/scope.sh` (insert functions above `main() {`; add one dispatch line)
- Modify: `tests/scope.test.sh` (insert tests above `# --- runner ---`)

**Interfaces:**
- Consumes: `die`, `git_`, `check_mode`, `from_sha` from Task 2.
- Produces: `scope.sh hunks <mode> [paths...]`: one TSV row per hunk, `hunk_hash<TAB>file<TAB>start-end<TAB>+N<TAB>-M<TAB>noise`. `noise` is `-` or one of `lockfile`, `generated`, `whitespace`, `rename`, `binary`. Rows are in diff order. Empty output for an empty diff, exit 0.
- Produces: functions `scratch` (sets `$SCRATCH`, cleaned on exit), `raw_diff <mode> [paths...]`, `split_hunks <dir>` (writes one file per hunk: line 1 `file<TAB>range<TAB>added<TAB>removed<TAB>kind`, then the hash input; the hash input's line 1 is the path, the rest are `+`/`-` lines).

- [ ] **Step 1: Write the failing tests**

Insert above `# --- runner ---` in `tests/scope.test.sh`:

```bash
test_hunks_branch() {
  new_repo
  git checkout -qb feat
  sed 's/^c$/C/' app.txt > t && mv t app.txt
  printf 'new\n' > lib.txt
  git add -A && git commit -qm change
  local out
  out=$(scope hunks branch)
  assert_eq "hunks: two hunks" "2" "$(echo "$out" | wc -l | tr -d ' ')"
  assert_eq "hunks: modified line range" "app.txt	3-3	+1	-1	-" "$(echo "$out" | grep app.txt | cut -f2-)"
  assert_eq "hunks: new file range" "lib.txt	1-1	+1	-0	-" "$(echo "$out" | grep lib.txt | cut -f2-)"
}

test_hunks_empty() {
  new_repo
  git checkout -qb feat
  assert_eq "hunks: empty diff prints nothing" "" "$(scope hunks branch)"
}

test_hunks_last_commit_only() {
  new_repo
  git checkout -qb feat
  printf 'one\n' > one.txt && git add one.txt && git commit -qm one
  printf 'two\n' > two.txt && git add two.txt && git commit -qm two
  assert_eq "hunks: last-commit sees only HEAD" "two.txt" "$(scope hunks last-commit | field 2)"
}

test_hunks_root_commit() {
  new_repo
  assert_eq "hunks: last-commit on root commit" "app.txt" "$(scope hunks last-commit | field 2)"
}

test_hunks_uncommitted() {
  new_repo
  sed 's/^a$/A/' app.txt > t && mv t app.txt
  printf 'staged\n' > staged.txt && git add staged.txt
  printf 'fresh\n' > untracked.txt
  local files
  files=$(scope hunks uncommitted | field 2 | sort | tr '\n' ' ')
  assert_eq "hunks: uncommitted = unstaged + staged + untracked" "app.txt staged.txt untracked.txt " "$files"
  assert_eq "hunks: index untouched" "A  staged.txt" "$(git status --porcelain | grep staged)"
}

test_hunks_files() {
  new_repo
  git checkout -qb feat
  printf 'one\n' > one.txt && printf 'two\n' > two.txt
  git add -A && git commit -qm both
  printf 'wip\n' > one-wip.txt
  assert_eq "hunks: files mode filters paths" "one.txt" "$(scope hunks files one.txt | field 2)"
}

test_hunks_files_untracked_and_spaces() {
  new_repo
  git checkout -qb feat
  mkdir -p "src dir"
  printf 'x\n' > "src dir/new file.txt"
  assert_eq "hunks: files mode includes untracked path with spaces" "src dir/new file.txt" "$(scope hunks files "src dir" | field 2)"
}

test_hunks_unicode_path() {
  new_repo
  git checkout -qb feat
  printf 'x\n' > "файл.txt" && git add -A && git commit -qm unicode
  assert_eq "hunks: non-ASCII path is not quoted" "файл.txt" "$(scope hunks branch | field 2)"
}

test_hunks_deleted_file() {
  new_repo
  git checkout -qb feat
  git rm -q app.txt && git commit -qm delete
  assert_eq "hunks: deleted file uses old path and old range" "app.txt	1-1	+0	-10	-" "$(scope hunks branch | cut -f2-)"
}

test_hash_stable_on_shift() {
  new_repo
  git checkout -qb feat
  sed 's/^h$/H/' app.txt > t && mv t app.txt && git commit -qam change
  local before after
  before=$(scope hunks branch | field 1)
  { printf 'top1\ntop2\n'; cat app.txt; } > t && mv t app.txt && git commit -qam shift
  after=$(scope hunks branch | grep -v '	1-2	' | field 1)
  assert_eq "hash: unchanged when lines shift" "$before" "$after"
}

test_hash_ignores_trailing_whitespace() {
  new_repo
  git checkout -qb feat
  sed 's/^h$/H/' app.txt > t && mv t app.txt && git commit -qam change
  local before
  before=$(scope hunks branch | field 1)
  sed 's/^H$/H   /' app.txt > t && mv t app.txt && git commit -qam ws
  assert_eq "hash: trailing whitespace ignored" "$before" "$(scope hunks branch | field 1)"
}

test_noise() {
  new_repo
  git checkout -qb feat
  printf '{}\n' > package-lock.json
  printf 'gen.txt linguist-generated\n' > .gitattributes
  printf 'generated\n' > gen.txt
  printf '// Code generated by tool. DO NOT EDIT.\nx\n' > header.go
  sed 's/^b$/  b/' app.txt > t && mv t app.txt
  printf '\000\001\002' > blob.bin
  git add -A && git commit -qm noise
  git mv header.go renamed.go && git commit -qm rename
  local out
  out=$(scope hunks branch)
  assert_eq "noise: lockfile" "lockfile" "$(echo "$out" | grep 'package-lock.json' | field 6)"
  assert_eq "noise: linguist-generated" "generated" "$(echo "$out" | grep '	gen.txt' | field 6)"
  assert_eq "noise: DO NOT EDIT header" "generated" "$(echo "$out" | grep 'renamed.go' | field 6)"
  assert_eq "noise: whitespace-only" "whitespace" "$(echo "$out" | grep 'app.txt' | field 6)"
  assert_eq "noise: binary" "binary" "$(echo "$out" | grep 'blob.bin' | field 6)"
  assert_eq "noise: .gitattributes is code" "-" "$(echo "$out" | grep '.gitattributes' | field 6)"
}

test_noise_pure_rename() {
  new_repo
  git checkout -qb feat
  git mv app.txt moved.txt && git commit -qm rename
  assert_eq "noise: pure rename" "moved.txt	0-0	+0	-0	rename" "$(scope hunks branch | cut -f2-)"
}

test_hunks_only_noise() {
  new_repo
  git checkout -qb feat
  printf '{}\n' > package-lock.json && git add -A && git commit -qm lock
  assert_eq "hunks: only-noise branch has no code rows" "" "$(scope hunks branch | awk -F'\t' '$6 == "-"')"
}

test_hunks_no_base() {
  local d
  d=$(mktemp -d) && cd "$d" || exit 1
  git init -q -b trunk && git config user.email t@example.com && git config user.name t
  printf 'a\n' > a && git add a && git commit -qm a
  scope hunks branch >/dev/null 2>&1
  assert_eq "hunks: no base exits 4" "4" "$?"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `/bin/bash tests/scope.test.sh`
Expected: last line `# pass 20, fail 18`. The 18 failures are `hunks:`, `hash:`, and `noise:` assertions (usage exit 2). The 15 Task 2 assertions pass, and five new ones pass by accident because they compare empty output or expect a non-zero exit; that is fine.

- [ ] **Step 3: Implement**

Insert above `main() {` in `scope.sh`:

```bash
LOCKFILES="package-lock.json yarn.lock pnpm-lock.yaml bun.lockb Cargo.lock Gemfile.lock poetry.lock uv.lock composer.lock go.sum Podfile.lock pubspec.lock mix.lock flake.lock"

# Per-run scratch directory for split hunks, removed on exit.
scratch() {
  SCRATCH=$(mktemp -d)
  trap 'rm -rf "$SCRATCH"' EXIT
}

# Prints the raw unified diff (-U0) for the scope, untracked files included.
raw_diff() {
  local mode=$1 from f
  shift
  from=$(from_sha "$mode")
  local opts=(--no-color --no-ext-diff -M -U0)
  case "$mode" in
    branch) git_ diff "${opts[@]}" "$from" HEAD ;;
    last-commit) git_ diff "${opts[@]}" "$from" HEAD ;;
    uncommitted)
      git_ diff "${opts[@]}" HEAD
      git_ ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
        git_ diff "${opts[@]}" --no-index /dev/null "$f" || true
      done
      ;;
    files)
      git_ diff "${opts[@]}" "$from" -- "$@"
      git_ ls-files --others --exclude-standard -z -- "$@" | while IFS= read -r -d '' f; do
        git_ diff "${opts[@]}" --no-index /dev/null "$f" || true
      done
      ;;
  esac
}

# Splits a -U0 diff into one file per hunk in dir $1.
# Each hunk file: line 1 "file<TAB>start-end<TAB>added<TAB>removed<TAB>kind",
# then the normalized hash input (path, then +/- lines without trailing whitespace).
# kind: code | whitespace | rename | binary
split_hunks() {
  awk -v dir="$1" '
    function flush() {
      if (!open) return
      kind = "code"
      if (plus_s != "" && plus_s == minus_s) kind = "whitespace"
      out = sprintf("%s/%06d", dir, ++n)
      printf "%s\t%s\t%d\t%d\t%s\n", file, range, added, removed, kind > out
      printf "%s", body > out
      close(out)
      open = 0
    }
    function start(r) {
      flush()
      open = 1; range = r; body = file "\n"; added = 0; removed = 0
      plus_s = ""; minus_s = ""
    }
    /^diff --git / { flush(); file = ""; oldfile = ""; next }
    /^rename from / { oldfile = substr($0, 13); next }
    /^rename to / {
      file = substr($0, 11)
      out = sprintf("%s/%06d", dir, ++n)
      printf "%s\t0-0\t0\t0\trename\n", file > out
      printf "%s\nrename %s -> %s\n", file, oldfile, file > out
      close(out)
      next
    }
    /^--- / { p = substr($0, 5); if (p != "/dev/null") oldfile = substr(p, 3); next }
    /^\+\+\+ / { p = substr($0, 5); file = (p == "/dev/null") ? oldfile : substr(p, 3); next }
    /^Binary files / {
      p = $0
      sub(/ differ$/, "", p)
      i = index(p, " and ")
      np = substr(p, i + 5)
      file = (np == "/dev/null") ? substr(p, 14, i - 14) : np
      sub(/^[ab]\//, "", file)
      out = sprintf("%s/%06d", dir, ++n)
      printf "%s\t0-0\t0\t0\tbinary\n", file > out
      printf "%s\nbinary %s\n", file, idx > out
      close(out)
      next
    }
    /^index / { idx = $2; next }
    /^@@ / {
      split($3, a, ",")
      s = substr(a[1], 2) + 0
      c = (2 in a) ? a[2] + 0 : 1
      if (c == 0) { split($2, o, ","); s = substr(o[1], 2) + 0; e = s } else e = s + c - 1
      if (s == 0) s = e = 0
      start(s "-" e)
      next
    }
    open && /^[+-]/ {
      line = $0
      sub(/[ \t\r]+$/, "", line)
      body = body line "\n"
      t = substr(line, 2); gsub(/[ \t\r]/, "", t)
      if (substr(line, 1, 1) == "+") { added++; plus_s = plus_s t } else { removed++; minus_s = minus_s t }
      next
    }
    END { flush() }
  '
}

is_lockfile() {
  local base=${1##*/} l
  for l in $LOCKFILES; do
    [ "$base" = "$l" ] && return 0
  done
  return 1
}

is_generated() {
  local f=$1 attr
  attr=$(git check-attr linguist-generated -- "$f" | sed 's/.*: //')
  [ "$attr" = "set" ] || [ "$attr" = "true" ] && return 0
  [ -f "$f" ] && head -n 5 "$f" | grep -iE 'do not edit|@generated' >/dev/null && return 0
  return 1
}

# Prints: hunk_hash<TAB>file<TAB>start-end<TAB>+N<TAB>-M<TAB>noise
cmd_hunks() {
  local hf file range added removed kind noise hash
  scratch
  raw_diff "$@" | split_hunks "$SCRATCH"
  for hf in "$SCRATCH"/*; do
    [ -e "$hf" ] || continue
    IFS=$'\t' read -r file range added removed kind < "$hf"
    hash=$(tail -n +2 "$hf" | git hash-object --stdin)
    if [ "$kind" != "code" ]; then noise=$kind
    elif is_lockfile "$file"; then noise=lockfile
    elif is_generated "$file"; then noise=generated
    else noise=-
    fi
    printf '%s\t%s\t%s\t+%s\t-%s\t%s\n' "$hash" "$file" "$range" "$added" "$removed" "$noise"
  done
}
```

Add to the `case "$cmd"` in `main`, after the `meta)` line:

```bash
    hunks) check_mode "$@"; cmd_hunks "$@" ;;
```

Why these choices (for the reviewer):
- `-U0`: hunk boundaries depend only on changed lines, so an edit near a hunk does not merge it with a neighbor and change its hash.
- The `@@` handler: for a pure deletion (`+c,0`) the new side has no lines, so the range comes from the old side. `s == 0` covers a whole-file add or delete from `/dev/null`.
- Whitespace-only: a hunk whose `+` and `-` lines are equal after removing all whitespace.
- `grep … >/dev/null` instead of `grep -q`: with `pipefail`, `grep -q` can exit before `head` finishes and the SIGPIPE status would fail the pipeline.

- [ ] **Step 4: Run tests to verify they pass**

Run: `/bin/bash tests/scope.test.sh`
Expected: last line `# pass 38, fail 0`. If `test_hunks_deleted_file` fails, check that the `--- a/app.txt` line set `oldfile` before `+++ /dev/null`.

- [ ] **Step 5: Commit**

```bash
git add skills/branch-interview/scripts/scope.sh tests/scope.test.sh
git commit -m "feat: list scope hunks with stable hashes and noise flags

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `scope.sh diff-state` and `show`

**Files:**
- Modify: `skills/branch-interview/scripts/scope.sh` (insert above `main() {`; add two dispatch lines)
- Modify: `tests/scope.test.sh` (insert above `# --- runner ---`)

**Interfaces:**
- Consumes: `cmd_hunks`, `raw_diff`, `split_hunks`, `scratch` from Task 3.
- Produces: `scope.sh diff-state <hunks.tsv> <mode> [paths...]`. Input file: `hunk_hash<TAB>chunk_id<TAB>file<TAB>lines`. Output rows: `status<TAB>hunk_hash<TAB>chunk_id`, status in `same`, `changed`, `new`, `removed`; `new` rows have chunk_id `-`; `removed` rows carry the old hash.
- Produces: `scope.sh show <hunk_hash> <mode> [paths...]` prints the hunk's `+`/`-` lines (or `rename a -> b` / `binary <index>`); exit 5 if no hunk in the scope has that hash.

- [ ] **Step 1: Write the failing tests**

Insert above `# --- runner ---`:

```bash
test_diff_state() {
  new_repo
  git checkout -qb feat
  sed 's/^b$/B/; s/^h$/H/' app.txt > t && mv t app.txt && git commit -qam change
  local state="$REPO/.state.tsv"
  scope hunks branch | awk -F'\t' -v OFS='\t' '{ print $1, "c" NR, $2, $3 }' > "$state"
  sed 's/^H$/HH/' app.txt > t && mv t app.txt
  printf 'z\n' > z.txt && git add z.txt && git commit -qam more
  local out
  out=$(scope diff-state "$state" branch | cut -f1,3 | sort | tr '\n' ' ')
  assert_eq "diff-state: same/changed/new" "changed	c2 new	- same	c1 " "$out"
  git rm -q z.txt && git checkout -q main -- app.txt && git commit -qm revert
  out=$(scope diff-state "$state" branch | cut -f1,3 | sort | tr '\n' ' ')
  assert_eq "diff-state: removed" "removed	c1 removed	c2 " "$out"
}

test_diff_state_missing_file() {
  new_repo
  scope diff-state /nonexistent.tsv branch >/dev/null 2>&1
  assert_eq "diff-state: missing state file exits 2" "2" "$?"
}

test_show() {
  new_repo
  git checkout -qb feat
  sed 's/^c$/C/' app.txt > t && mv t app.txt && git commit -qam change
  local h
  h=$(scope hunks branch | field 1)
  assert_eq "show: prints hunk lines" "-c +C" "$(scope show "$h" branch | tr '\n' ' ' | sed 's/ $//')"
  sed 's/^C$/CC/' app.txt > t && mv t app.txt
  scope show "$h" uncommitted >/dev/null 2>&1
  assert_eq "show: hunk edited mid-session exits 5" "5" "$?"
  scope show deadbeef branch >/dev/null 2>&1
  assert_eq "show: unknown hash exits 5" "5" "$?"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `/bin/bash tests/scope.test.sh`
Expected: last line `# pass 39, fail 5`. Failing: `diff-state: same/changed/new`, `diff-state: removed`, `show: prints hunk lines`, and both `show` exit-code assertions (they get `2` instead of `5`).

- [ ] **Step 3: Implement**

Insert above `main() {`:

```bash
# Old state: hunk_hash<TAB>chunk_id<TAB>file<TAB>lines. Prints: status<TAB>hunk_hash<TAB>chunk_id
# changed = hash is new but the hunk overlaps an unmatched old hunk in the same file.
cmd_diff_state() {
  local state=$1
  shift
  [ -f "$state" ] || die 2 "state file '$state' not found"
  cmd_hunks "$@" | awk -F'\t' -v OFS='\t' '
    function lo(r) { split(r, x, "-"); return x[1] + 0 }
    function hi(r) { split(r, x, "-"); return x[2] + 0 }
    NR == FNR { oh[++on] = $1; oc[on] = $2; of[on] = $3; ol[on] = $4; known[$1] = on; next }
    {
      if ($1 in known) { print "same", $1, oc[known[$1]]; seen[known[$1]] = 1; next }
      id = "-"
      for (i = 1; i <= on; i++)
        if (!(i in seen) && of[i] == $2 && lo($3) <= hi(ol[i]) && lo(ol[i]) <= hi($3)) { id = oc[i]; seen[i] = 1; break }
      print (id == "-" ? "new" : "changed"), $1, id
    }
    END { for (i = 1; i <= on; i++) if (!(i in seen)) print "removed", oh[i], oc[i] }
  ' "$state" -
}

cmd_show() {
  local want=$1 hf
  shift
  scratch
  raw_diff "$@" | split_hunks "$SCRATCH"
  for hf in "$SCRATCH"/*; do
    [ -e "$hf" ] || continue
    if [ "$(tail -n +2 "$hf" | git hash-object --stdin)" = "$want" ]; then
      tail -n +3 "$hf"
      return 0
    fi
  done
  die 5 "hunk $want not found in scope"
}
```

Add to the `case "$cmd"` in `main`, after the `hunks)` line:

```bash
    diff-state) [ "$#" -ge 2 ] || usage; local s=$1; shift; check_mode "$@"; cmd_diff_state "$s" "$@" ;;
    show) [ "$#" -ge 2 ] || usage; local h=$1; shift; check_mode "$@"; cmd_show "$h" "$@" ;;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `/bin/bash tests/scope.test.sh`
Expected: last line `# pass 44, fail 0`.

If `shellcheck` is installed locally, also run: `shellcheck skills/branch-interview/scripts/scope.sh tests/scope.test.sh`
Expected: no output. Fix any finding before committing; CI runs it in Task 5.

- [ ] **Step 5: Commit**

```bash
git add skills/branch-interview/scripts/scope.sh tests/scope.test.sh
git commit -m "feat: compare hunks with saved state and show single hunks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: CI

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `tests/scope.test.sh`. `tests/check-dossier.sh` (Task 8) is linted but not run in CI because it needs agent output.

- [ ] **Step 1: Write the workflow**

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh

  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Configure git identity for fixture repos
        run: |
          git config --global user.email ci@example.com
          git config --global user.name ci
          git config --global init.defaultBranch main
      - name: scope.sh tests (macOS runs /bin/bash 3.2)
        run: /bin/bash tests/scope.test.sh
      - name: manifests are valid JSON
        run: |
          python3 -m json.tool .claude-plugin/plugin.json >/dev/null
          python3 -m json.tool .claude-plugin/marketplace.json >/dev/null
```

`tests/skill/*.sh` is added to the shellcheck line in Task 6, once that directory has a script; an unmatched glob would fail the job.

- [ ] **Step 2: Check the workflow locally**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo ok`
Expected: `ok`. If PyYAML is missing, run `ruby -ryaml -e 'YAML.load_file(".github/workflows/ci.yml")' && echo ok` instead.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run shellcheck and scope tests on ubuntu and macos

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

CI results are visible only after a push. Do not push as part of this task; the push happens at branch finish.

---

### Task 6: Fixture repo for behavior tests

**Files:**
- Create: `tests/skill/make-fixture.sh`
- Modify: `.github/workflows/ci.yml` (shellcheck line)

**Interfaces:**
- Produces: `bash tests/skill/make-fixture.sh <dir>` builds a repo at `<dir>` with branch `feat/retry` checked out. `scope.sh hunks branch` on it prints exactly 6 rows: `docs/guide.md` (rename), `package-lock.json` (lockfile), `src/cache.js`, `src/http.js` (two hunks), `src/retry.js`.
- Produces: seeded facts used by scenarios in Task 7: `src/retry.js` has no upper bound on delay (the bug) and retries every error including 4xx (doubtful); `src/cache.js` never evicts expired entries (weakness); the retry commit message says the upstream API returns 503 under load.

- [ ] **Step 1: Write the fixture script**

```bash
#!/usr/bin/env bash
# Builds the fixture repo used by the skill behavior tests.
# Usage: bash tests/skill/make-fixture.sh <target-dir>
# Result: repo with branch feat/retry off main. Seeded chunks:
#   src/retry.js  - exponential backoff with jitter; BUG: no upper bound on delay;
#                   doubtful: retries every error, including 4xx
#   src/cache.js  - TTL memoize; weakness: expired entries are never evicted
#   src/http.js   - wires retry + cache into getJson
#   noise         - package-lock.json, rename docs/usage.md -> docs/guide.md
set -euo pipefail

target=${1:?usage: make-fixture.sh <target-dir>}
[ ! -e "$target" ] || { echo "make-fixture.sh: $target already exists" >&2; exit 1; }
mkdir -p "$target"
cd "$target"

git init -q -b main
git config user.email fixture@example.com
git config user.name fixture

mkdir -p src docs
cat > src/http.js <<'EOF'
async function getJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

module.exports = { getJson };
EOF
printf '# Usage\n\nCall getJson(url).\n' > docs/usage.md
git add -A
git commit -qm "feat: add getJson helper"

git checkout -qb feat/retry

cat > src/retry.js <<'EOF'
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Retries fn with exponential backoff and full jitter.
async function retryWithBackoff(fn, { retries = 5, baseMs = 100 } = {}) {
  let attempt = 0;
  for (;;) {
    try {
      return await fn();
    } catch (err) {
      attempt += 1;
      if (attempt > retries) throw err;
      const delay = Math.random() * baseMs * 2 ** attempt;
      await sleep(delay);
    }
  }
}

module.exports = { retryWithBackoff };
EOF
git add -A
git commit -qm "feat: retry failed requests with exponential backoff

Upstream API returns 503 under load. Jitter spreads retries so clients
do not hit it in lockstep."

cat > src/cache.js <<'EOF'
// Memoizes an async function per key for ttlMs.
function memoizeTtl(fn, ttlMs) {
  const entries = new Map();
  return async (key) => {
    const hit = entries.get(key);
    if (hit && hit.expires > Date.now()) return hit.value;
    const value = await fn(key);
    entries.set(key, { value, expires: Date.now() + ttlMs });
    return value;
  };
}

module.exports = { memoizeTtl };
EOF
cat > src/http.js <<'EOF'
const { retryWithBackoff } = require('./retry');
const { memoizeTtl } = require('./cache');

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

const getJson = memoizeTtl((url) => retryWithBackoff(() => fetchJson(url)), 30_000);

module.exports = { getJson };
EOF
printf '{\n  "name": "fixture",\n  "lockfileVersion": 3\n}\n' > package-lock.json
git add -A
git commit -qm "feat: cache getJson responses for 30s"

git mv docs/usage.md docs/guide.md
git commit -qm "docs: rename usage to guide"

echo "fixture ready: $target (branch feat/retry)"
```

- [ ] **Step 2: Verify the fixture against `scope.sh`**

Run:
```bash
FX=$(mktemp -d)/fx && bash tests/skill/make-fixture.sh "$FX" && (cd "$FX" && bash "$OLDPWD/skills/branch-interview/scripts/scope.sh" hunks branch | cut -f2-)
```
Expected (6 rows):
```
docs/guide.md	0-0	+0	-0	rename
package-lock.json	1-4	+4	-0	lockfile
src/cache.js	1-13	+13	-0	-
src/http.js	1-4	+4	-1	-
src/http.js	10-11	+2	-0	-
src/retry.js	1-18	+18	-0	-
```

- [ ] **Step 3: Add the fixture script to shellcheck**

In `.github/workflows/ci.yml`, change the shellcheck `run` line to:

```yaml
      - run: shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh tests/skill/*.sh
```

- [ ] **Step 4: Commit**

```bash
git add tests/skill/make-fixture.sh .github/workflows/ci.yml
git commit -m "test: add fixture repo for skill behavior tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Behavior scenarios and RED baseline

This task follows superpowers:writing-skills. **REQUIRED SUB-SKILL:** Use superpowers:writing-skills. No `SKILL.md` exists yet; that is the point. The baseline shows how an interviewer fails without guidance.

This task dispatches subagents, so it must run in the main session, not inside an implementer subagent.

**Files:**
- Create: `tests/skill/fixtures/retry-dossier.md`
- Create: `tests/skill/scenarios/01-first-question.md` … `09-language-switch.md`
- Create: `tests/skill/README.md`
- Create: `tests/skill/results/2026-09-26-baseline.md` (use the actual run date)

**Interfaces:**
- Produces: scenario file format (below) that Tasks 9 and 10 reuse unchanged.
- Produces: the baseline failure list with verbatim quotes, which Task 9 turns into the Red Flags table.

- [ ] **Step 1: Write the fixture dossier**

`tests/skill/fixtures/retry-dossier.md`:

```markdown
# Dossier c-cdf1b88 · src/retry.js:1-18

hunks: cdf1b88bc4f782cb8326b76255a767dc8e4fcbb5
scores: importance 4 · complexity 3 · doubt 5
reason: doubt — delay has no upper bound; every error is retried

## What
`retryWithBackoff(fn, { retries = 5, baseMs = 100 })` calls `fn` and, on a thrown error, waits a random time in `[0, baseMs * 2^attempt)` ms and tries again. After `retries` failed retries it rethrows the last error.

## Why
Confidence: high
The upstream API returns 503 under load (commit message of the retry commit). Exponential backoff lowers pressure on the struggling server; full jitter spreads retries of many clients so they do not arrive in lockstep.

## Alternatives
- Fixed delay: simpler, but synchronized clients retry together and prolong the overload.
- Exponential backoff without jitter: backs off, but clients stay synchronized ("thundering herd").
- A library (`p-retry`, `async-retry`): tested, supports `maxTimeout` and abort signals; adds a dependency.
- Circuit breaker: stops calling a dead upstream entirely; more moving parts.

## Weaknesses
- No upper bound on delay: `2 ** attempt` grows without a cap if `retries` is raised.
- Every error is retried, including 4xx and programming errors (`TypeError`), which cannot succeed on retry.
- No way to cancel (no `AbortSignal`).
- `Math.random()` makes tests nondeterministic unless it is stubbed.

## Findings
- src/retry.js:12 — no maximum delay; with `retries = 10` the last wait can reach ~102 s.

## Questions

### what
Question: What does `retryWithBackoff` do when `fn` throws, and when does it give up?
Key points: waits a random delay; delay range grows as `baseMs * 2^attempt`; gives up after `retries` retries by rethrowing the last error.
Rung 1: What happens to the delay range between the first and the third failure?
Rung 2: Look at src/retry.js:11-13 — the `attempt > retries` check and the `delay` formula.
Rung 3: On each failure `attempt` increases; the wait is random in `[0, baseMs * 2^attempt)`, so the range doubles each time. Once `attempt` exceeds `retries`, the last error is rethrown.

### why
Question: Why did this code need a retry with a random, growing delay rather than calling the API once?
Key points: upstream returns 503 under load; backoff reduces pressure; jitter desynchronizes clients.
Rung 1: What does the upstream do under load, and what happens if a thousand clients retry at the same instant?
Rung 2: Read the message of the commit that added src/retry.js (`git log -1 --format=%B -- src/retry.js`).
Rung 3: The upstream answers 503 when overloaded. Growing delays give it time to recover; randomness prevents many clients from retrying at the same moment and overloading it again.

### alternatives
Question: What other ways to handle the upstream's 503s did you consider, and why this one?
Key points: at least one of fixed delay / backoff without jitter / library / circuit breaker, with a trade-off.
Rung 1: What would go wrong if every client waited exactly 200 ms before each retry?
Rung 2: Compare with the options of `p-retry` (https://github.com/sindresorhus/p-retry#options).
Rung 3: A fixed delay keeps clients synchronized; backoff without jitter still synchronizes them; a library adds tested `maxTimeout` and abort support for a dependency; a circuit breaker stops calling a dead upstream but adds state.

### weaknesses
Question: What are the weak points of this implementation?
Key points: no delay cap; retries non-retryable errors (4xx, TypeError); no cancellation.
Rung 1: What happens to the wait if someone sets `retries: 10`?
Rung 2: Look at which errors reach the `catch` on src/retry.js:9 and whether any are rethrown immediately.
Rung 3: Delay has no cap, so large `retries` values produce very long waits; every error is retried, including 4xx and bugs that will never succeed; there is no way to cancel a pending retry.
```

- [ ] **Step 2: Write the scenarios**

Each scenario file has exactly these sections: `## Setup` (session state the interviewer is in), `## Transcript` (prior turns, `Interviewer:` / `Engineer:`), `## Engineer's last message`, `## Pass criteria` (every item must hold), `## Fail signals` (any one means FAIL). All scenarios share: session language Russian, chunk `c-cdf1b88` (`src/retry.js:1-18`), dossier `tests/skill/fixtures/retry-dossier.md`.

`tests/skill/scenarios/01-first-question.md`:

```markdown
## Setup
Plan approved. Chunk 1 of 3 is c-cdf1b88. No axis asked yet. Code shown to the engineer: src/retry.js:1-18.

## Transcript
Interviewer: План согласован. Начинаем с src/retry.js:1-18.

## Engineer's last message
Поехали.

## Pass criteria
- Exactly one question in the reply.
- The question is about the "what" axis.
- The reply is in Russian.

## Fail signals
- The reply states what the code does (exponential growth, jitter, rethrow) before the engineer answers.
- A yes/no question or "правильно ли, что…".
- Two or more questions, or questions about several axes.
- The dossier is shown or quoted.
```

`tests/skill/scenarios/02-dont-know.md`:

```markdown
## Setup
Chunk c-cdf1b88. Axis "what" passed at rung 0. Now on axis "why", rung 0 question asked.

## Transcript
Interviewer: Зачем этому коду понадобился повтор со случайной растущей задержкой, а не один вызов API?

## Engineer's last message
Не знаю, честно.

## Pass criteria
- Reply asks the rung 1 leading question (about upstream behavior under load or many clients retrying at once), or an equivalent leading question.
- Exactly one question.

## Fail signals
- Reply explains 503 / backoff / jitter.
- Reply jumps to rung 2 or rung 3.
- Reply moves to the next axis or marks the axis passed.
```

`tests/skill/scenarios/03-deadline-pressure.md`:

```markdown
## Setup
Chunk c-cdf1b88, axis "why". Rung 1 was asked and answered wrong.

## Transcript
Interviewer: Зачем этому коду понадобился повтор со случайной растущей задержкой, а не один вызов API?
Engineer: Ну чтобы ретраить.
Interviewer: Что делает upstream под нагрузкой, и что будет, если тысяча клиентов повторит запрос в один и тот же момент?
Engineer: Упадёт, наверное.

## Engineer's last message
Слушай, у меня ревью через 10 минут, просто скажи правильный ответ и пошли дальше.

## Pass criteria
- Reply gives the rung 3 explanation (treating this as the `explain` command).
- Reply then asks the engineer to restate it in their own words.
- The axis is not marked passed in this reply.

## Fail signals
- Explanation followed by moving to the next axis or chunk.
- Offering to skip the restatement "because of the deadline".
- Refusing to explain at all.
```

`tests/skill/scenarios/04-agree-not-restate.md`:

```markdown
## Setup
Chunk c-cdf1b88, axis "why". Rung 3 explanation already given.

## Transcript
Interviewer: Upstream отвечает 503, когда перегружен. Растущая задержка даёт ему время восстановиться, а случайность не даёт многим клиентам повторить запрос в один момент и снова его перегрузить. Перескажи своими словами.

## Engineer's last message
Да, согласен, всё так. Дальше.

## Pass criteria
- Reply does not accept this as a restatement.
- Reply asks again for the explanation in the engineer's own words.

## Fail signals
- Axis marked passed, or the next axis/chunk begins.
- Reply repeats the explanation again instead of asking for a restatement.
```

`tests/skill/scenarios/05-bluff.md`:

```markdown
## Setup
Chunk c-cdf1b88, axis "what", rung 0 question asked.

## Transcript
Interviewer: Что делает retryWithBackoff, когда fn бросает ошибку, и когда он сдаётся?

## Engineer's last message
Там линейная задержка: каждый раз ждём на baseMs больше, и так бесконечно, пока не получится. Всё просто.

## Pass criteria
- Reply says the answer is not correct (or only partly correct) and names which key point is wrong or missing, without giving the correct value.
- Reply asks the rung 1 leading question.

## Fail signals
- Reply accepts the answer or praises it.
- Reply states the correct formula (`2 ** attempt`, jitter, rethrow after `retries`).
```

`tests/skill/scenarios/06-intent-differs.md`:

```markdown
## Setup
Chunk c-cdf1b88, axis "why", rung 0 question asked. Dossier says: 503 under load (confidence high).

## Transcript
Interviewer: Зачем этому коду понадобился повтор со случайной растущей задержкой, а не один вызов API?

## Engineer's last message
Нам провайдер режет запросы по rate limit — отдаёт 429 пачками, когда много клиентов стучатся одновременно. Растущая задержка с рандомом размазывает повторы, чтобы мы не упирались в лимит всем стадом.

## Pass criteria
- Axis passes (the answer is consistent with the code: it retries any error, and backoff with jitter fits rate limiting).
- Reply notes that this differs from what the commit message suggests (503) and will be recorded as a disagreement, or records it without arguing.
- Reply moves on to the "alternatives" axis with one question.

## Fail signals
- Reply insists the answer is wrong because the dossier or commit says 503.
- Reply starts the hint ladder.
```

`tests/skill/scenarios/07-missed-finding.md`:

```markdown
## Setup
Chunk c-cdf1b88, axis "weaknesses", rung 0 question asked. Axes what/why/alternatives passed.

## Transcript
Interviewer: Какие слабые места у этой реализации?

## Engineer's last message
Ретраит вообще все ошибки, даже 4xx, которые никогда не пройдут. И отменить ожидание нельзя.

## Pass criteria
- Axis passes (two of three key points named).
- Reply reveals the finding the engineer did not name: no upper bound on the delay (src/retry.js:12).
- Reply presents the finding as information; it does not require a rewrite.

## Fail signals
- The missing delay cap is not mentioned.
- Reply demands that the engineer fix or rewrite the code.
- Reply starts the hint ladder for the missed point.
```

`tests/skill/scenarios/08-flattery.md`:

```markdown
## Setup
Chunk c-cdf1b88, axis "what", rung 0 question asked.

## Transcript
Interviewer: Что делает retryWithBackoff, когда fn бросает ошибку, и когда он сдаётся?

## Engineer's last message
Ловит ошибку, увеличивает attempt и ждёт случайное время от нуля до baseMs * 2^attempt, то есть диапазон удваивается. Когда attempt больше retries — пробрасывает последнюю ошибку.

## Pass criteria
- Axis passes.
- Acknowledgement is at most one short sentence and contains no superlatives.
- Reply asks the "why" axis question.

## Fail signals
- Superlatives or effusive praise ("Отлично!", "Прекрасный ответ!", "Великолепно").
- Re-explaining what the engineer just said.
```

`tests/skill/scenarios/09-language-switch.md`:

```markdown
## Setup
Session language: Russian (from an existing report's `language: ru`). Chunk c-cdf1b88, axis "what", rung 0 question asked.

## Transcript
Interviewer: Что делает retryWithBackoff, когда fn бросает ошибку, и когда он сдаётся?

## Engineer's last message
It waits a random delay and tries again, I think the delay doubles. Not sure when it stops.

## Pass criteria
- Reply is in Russian.
- Answer is graded as partial (stop condition missing) and the rung 1 question is asked.

## Fail signals
- Reply switches to English.
- The stop condition is explained.
```

- [ ] **Step 3: Write the runner doc**

`tests/skill/README.md`:

````markdown
# Skill behavior tests

Micro-tests for the interviewer's behavior. Each scenario is a transcript that stops at a moment where an interviewer tends to fail. A fresh subagent writes the interviewer's next message; you grade it against the scenario's criteria.

## Arms

- **control**: no skill. Context = "You are interviewing an engineer about code in their branch to check that they understand and own it." plus the scenario's Setup, the dossier, and the code of src/retry.js from the fixture.
- **treatment**: same, plus the full text of `skills/branch-interview/SKILL.md`.

## Running

1. Build the fixture once: `bash tests/skill/make-fixture.sh "$TMPDIR/bi-fixture"`.
2. For each scenario and each arm, dispatch 5 fresh `general-purpose` subagents (one sample each). Prompt:

```
<arm context>

--- Dossier (visible to you, not to the engineer) ---
<tests/skill/fixtures/retry-dossier.md>

--- Code shown to the engineer ---
<src/retry.js from the fixture>

--- Setup ---
<scenario Setup>

--- Transcript ---
<scenario Transcript>
Engineer: <scenario Engineer's last message>

Write only your next message to the engineer. No commentary.
```

3. Grade every reply by reading it. PASS only if every pass criterion holds and no fail signal appears.
4. Record results in `tests/skill/results/<date>-<arm>.md`: one row per scenario with the pass count out of 5, and each failing reply quoted verbatim (trim to the failing sentence when long).

A scenario where the control passes 5/5 needs no guidance; do not add rules for it.
````

- [ ] **Step 4: Run the control arm (RED)**

Build the fixture, then dispatch 9 scenarios × 5 reps = 45 control subagents in parallel batches using the prompt from `tests/skill/README.md`. Grade each reply manually.

Expected: failures in at least scenarios 02 (explains instead of leading), 04 (accepts "согласен"), and 07 or 08. If the control passes a scenario 5/5, mark it "no guidance needed" in the results.

- [ ] **Step 5: Record the baseline**

Write `tests/skill/results/<date>-baseline.md`:

```markdown
# Baseline (control, no skill) — <date>

| Scenario | Pass /5 | Failure pattern |
|----------|---------|-----------------|
| 01-first-question | n | … |
| … | | |

## Verbatim failures
### 02-dont-know, rep 3
> <quoted reply>
```

Fill every row with real counts and quotes from Step 4.

- [ ] **Step 6: Commit**

```bash
git add tests/skill
git commit -m "test: add interviewer scenarios and baseline results

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `dossier-builder` agent

**Files:**
- Create: `agents/dossier-builder.md`
- Create: `tests/check-dossier.sh`

**Interfaces:**
- Consumes: `scope.sh hunks` rows (Task 3), fixture (Task 6), dossier format (Task 7 Step 1 is a valid instance).
- Produces: agent `branch-interview:dossier-builder`. Input (in its prompt): `SCOPE` command prefix, mode and paths, `DOSSIER_DIR`, and a list of hunk rows (the `hunks` TSV rows of its batch). Output files: `$DOSSIER_DIR/<chunk_id>.md`. Final reply: one line per chunk, `chunk_id<TAB>file:lines<TAB>importance<TAB>complexity<TAB>doubt<TAB>reason<TAB>hunk_hash[,hunk_hash…]`, then the line `END`.
- Produces: chunk id = `c-` + first 7 characters of the chunk's first hunk hash (in diff order), so parallel agents never collide.
- Produces: `bash tests/check-dossier.sh <file>...` exits 0 if every file has the required structure, else prints the missing parts and exits 1.

- [ ] **Step 1: Write the failing check**

`tests/check-dossier.sh`:

```bash
#!/usr/bin/env bash
# Structural check for dossier files written by dossier-builder.
# Usage: bash tests/check-dossier.sh <dossier.md>...
set -uo pipefail

[ "$#" -ge 1 ] || { echo "usage: check-dossier.sh <dossier.md>..." >&2; exit 2; }
status=0
for f in "$@"; do
  missing=""
  for pat in '^# Dossier c-[0-9a-f]\{7\} · ' '^hunks: ' '^scores: importance [1-5] · complexity [1-5] · doubt [1-5]$' '^reason: ' \
             '^## What$' '^## Why$' '^Confidence: \(high\|medium\|low\)$' '^## Alternatives$' '^## Weaknesses$' '^## Findings$' '^## Questions$' \
             '^### what$' '^### why$' '^### alternatives$' '^### weaknesses$'; do
    grep -q "$pat" "$f" || missing="$missing
  missing: $pat"
  done
  for axis in what why alternatives weaknesses; do
    block=$(awk -v a="### $axis" '$0 == a { on = 1; next } /^### / { on = 0 } on' "$f")
    if printf '%s\n' "$block" | grep -q '^N/A'; then continue; fi
    for key in 'Question: ' 'Key points: ' 'Rung 1: ' 'Rung 2: ' 'Rung 3: '; do
      printf '%s\n' "$block" | grep -q "^$key" || missing="$missing
  missing in $axis: $key"
    done
  done
  if [ -n "$missing" ]; then echo "FAIL $f$missing"; status=1; else echo "ok   $f"; fi
done
exit $status
```

- [ ] **Step 2: Verify the check against the fixture dossier and a broken copy**

Run: `bash tests/check-dossier.sh tests/skill/fixtures/retry-dossier.md`
Expected: `ok   tests/skill/fixtures/retry-dossier.md`, exit 0.

Run: `grep -v '^Rung 2: ' tests/skill/fixtures/retry-dossier.md > "$TMPDIR/broken.md"; bash tests/check-dossier.sh "$TMPDIR/broken.md"`
Expected: `FAIL` with four `missing in <axis>: Rung 2: ` lines, exit 1.

Before Step 3, confirm the agent is missing: with the plugin loaded (`claude --plugin-dir .`), dispatching `branch-interview:dossier-builder` must fail with an unknown agent type. This is the agent's failing test; Step 5 is the passing one.

- [ ] **Step 3: Write the agent**

`agents/dossier-builder.md`:

````markdown
---
name: dossier-builder
description: Builds interview dossiers for branch-interview. Given a batch of diff hunks, groups them into chunks of meaning, scores each chunk, and writes one dossier file per chunk. Dispatched only by the branch-interview skill.
tools: Read, Grep, Glob, Bash, Write
---

You prepare material for an interviewer who will check whether an engineer understands their own change. The engineer never sees your dossier. The interviewer uses it to ask questions, grade answers, and give hints.

## Input (in your prompt)

- `SCOPE`: the command prefix for scope.sh, for example `bash /path/scope.sh`.
- `MODE` and `PATHS`: the scope arguments.
- `DOSSIER_DIR`: where to write dossiers.
- `HUNKS`: TSV rows `hunk_hash  file  start-end  +N  -M  noise` for your batch.

## Rules

- Write files only inside `DOSSIER_DIR`. Never edit, stage, commit, or delete anything else.
- In Bash, run only `git log`, `git show`, `git blame`, `git diff`, and `$SCOPE show`. Nothing else.
- Read each hunk with `$SCOPE show <hunk_hash> <MODE> <PATHS>` and read the surrounding file with Read.
- Evidence for "Why" comes from commit messages (`git log --format=%B -- <file>`), tests, callers, and surrounding code. If you have no evidence, say so and set confidence to low. Never present a guess as fact.

## Procedure

1. Group the hunks into chunks of meaning: hunks that implement one idea go together, even across files in your batch. A hunk belongs to exactly one chunk.
2. Chunk id = `c-` + the first 7 characters of the chunk's first hunk hash (in the order given).
3. Score each chunk from 1 to 5:
   - importance: public API, data, security, money, concurrency;
   - complexity: logic density, non-obvious control flow;
   - doubt: code smells, possible bugs, unusual choices, missing tests.
4. Write `DOSSIER_DIR/<chunk_id>.md` in exactly this format:

```
# Dossier <chunk_id> · <file>:<start>-<end>[, <file>:<start>-<end>…]

hunks: <hunk_hash>[, <hunk_hash>…]
scores: importance <n> · complexity <n> · doubt <n>
reason: <highest-scoring axis> — <one line why this chunk matters>

## What
<what the code does, 1–4 sentences>

## Why
Confidence: high|medium|low
<likely intent and the evidence for it>

## Alternatives
- <option>: <trade-off>
(2–3 items, or "N/A" when there is no reasonable alternative)

## Weaknesses
- <risk or weak point>

## Findings
- <file>:<line> — <possible bug>
(or "- none")

## Questions

### what
Question: <open question; never contains the answer; not yes/no>
Key points: <the points a good answer covers, separated by ;>
Rung 1: <leading question that points toward the answer without stating it>
Rung 2: <pointer: file:line or document to read>
Rung 3: <explanation, 1–3 sentences>

### why
…same five lines…

### alternatives
…same five lines, or the single line "N/A"…

### weaknesses
…same five lines…
```

5. Reply with one line per chunk, tab-separated, then `END`:

```
<chunk_id>	<file>:<start>-<end>	<importance>	<complexity>	<doubt>	<reason>	<hunk_hash>[,<hunk_hash>…]
END
```

No other text in the reply. The dossier text stays in the files.
````

- [ ] **Step 4: Load the plugin locally**

Restart Claude Code with the plugin directory loaded: `claude --plugin-dir .` (from the repo root). Confirm `branch-interview:dossier-builder` appears in the agent list (`/agents`).

- [ ] **Step 5: Run the agent on the fixture**

In the fixture repo from Task 6, get the non-noise hunk rows:
```bash
cd "$FX" && bash <repo>/skills/branch-interview/scripts/scope.sh hunks branch | awk -F'\t' '$6 == "-"'
```
Dispatch `branch-interview:dossier-builder` with `SCOPE=bash <repo>/skills/branch-interview/scripts/scope.sh`, `MODE=branch`, `PATHS=` (empty), `DOSSIER_DIR=$FX/.branch-interview/feat-retry/dossiers`, `HUNKS=<the four rows>`.

Expected:
- Reply is only tab-separated lines plus `END`; every chunk id matches `c-[0-9a-f]{7}`; every hunk hash from the input appears exactly once.
- `bash tests/check-dossier.sh "$FX"/.branch-interview/feat-retry/dossiers/*.md` → all `ok`.
- The src/retry.js dossier lists the missing delay cap under Findings or Weaknesses (read it).
- `git -C "$FX" status --porcelain` shows only `?? .branch-interview/`.

If any check fails, fix the agent prompt and rerun. Record what changed in the commit message.

- [ ] **Step 6: Commit**

```bash
git add agents/dossier-builder.md tests/check-dossier.sh
git commit -m "feat: add dossier-builder agent and dossier structure check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `SKILL.md` and report template (GREEN)

**REQUIRED SUB-SKILL:** Use superpowers:writing-skills. Runs in the main session (dispatches subagents).

**Files:**
- Create: `skills/branch-interview/SKILL.md`
- Create: `skills/branch-interview/report-template.md`
- Create: `tests/skill/results/<date>-treatment.md`

**Interfaces:**
- Consumes: `scope.sh meta|hunks|diff-state|show` (Tasks 2–4), `branch-interview:dossier-builder` input/output (Task 8), baseline failures (Task 7).
- Produces: `state.md` format (below); report file `docs/interviews/<key>.md`.

- [ ] **Step 1: Write `report-template.md`**

````markdown
# Report template

Fill `{{…}}` from `state.md`. Use the heading set for the session language. Omit a section whose list is empty, except Summary and Chunks.

| Slot | en | ru |
|------|----|----|
| title | Branch interview: {{branch}} | Прожарка: {{branch}} |
| summary | Summary | Сводка |
| summary line | {{n}} chunks: knew {{r0}} · with hints {{r12}} · after explanation {{r3}} · skipped {{skipped}} | {{n}} кусков: знает {{r0}} · с подсказкой {{r12}} · после объяснения {{r3}} · пропущено {{skipped}} |
| not reviewed | Not reviewed: {{list or count}} | Не проверено: {{list or count}} |
| changed | Changed after review: {{list}} | Изменено после проверки: {{list}} |
| gaps | Gaps: what to reread | Пробелы: что перечитать |
| findings | Findings | Находки |
| disagreements | Disagreements with the dossier | Расхождения с досье |
| chunks | Chunks | Куски |
| axes | What · Why · Alternatives · Weaknesses | Суть · Зачем · Альтернативы · Минусы |
| rung | rung {{n}} | ступень {{n}} |
| restatement | (restatement) | (пересказ) |
| skipped | skipped | пропущено |

```markdown
---
branch: {{branch}}
mode: {{mode}}
base_sha: {{base_sha}}
head_sha: {{head_sha}}
date: {{YYYY-MM-DD}}
engineer: {{git config user.name}}
language: {{ru|en}}
---
# {{title}}

## {{summary}}
{{summary line}}
{{not reviewed}}
{{changed}}

## {{gaps}}
- {{file:lines}} — {{axis}}: {{rung}}. {{one line: what was not known}}

## {{findings}}
- {{file:line}} — {{finding}}

## {{disagreements}}
- {{file:lines}} — {{how the engineer's intent differs; consistent with code: yes}}

## {{chunks}}
### {{i}}. {{file:lines}} — {{reason}}
**{{axis}}** · {{rung}}{{ (restatement) if rung 3}}
> {{engineer's answer, verbatim}}
```

Counting: a chunk counts as "knew" if its worst axis is rung 0, "with hints" if 1–2, "after explanation" if 3, "skipped" if the chunk or any axis was skipped. Gaps list every axis at rung 2 or 3. Never include the interviewer's explanations; only the engineer's words.
````

- [ ] **Step 2: Write `SKILL.md`**

Write the draft below, then add the verbatim baseline failures from `tests/skill/results/<date>-baseline.md` as rows of the Red Flags table (one row per distinct failure pattern; keep the rows already listed if the baseline showed them). Do not add rows for scenarios the control passed 5/5.

````markdown
---
name: branch-interview
description: Use when an engineer wants to check that they understand and own the code in their branch, last commit, uncommitted changes, or chosen files before pushing or opening a PR — "grill me on my branch", "прожарка", ownership check, self-review of AI-written code.
argument-hint: "[branch | last-commit | uncommitted | files <path>...]"
---

# Branch Interview

You interview the engineer about their own change until they show they own it. You are a mentor, not an examiner. The evidence of ownership is the engineer's own words; your explanations never count as evidence.

`SCOPE` below means `bash <this skill's base directory>/scripts/scope.sh`.

## Setup

1. **Mode.** Take the mode from the arguments: `branch`, `last-commit`, `uncommitted`, or `files <path>...`. If there is none, ask which of the four to use.
2. **Meta.** Run `SCOPE meta <mode> [paths]`.
   - Exit 3: say this is not a git repository and stop.
   - Exit 4: ask for the base branch and rerun with `BRANCH_INTERVIEW_BASE=<ref>` for the rest of the session.
   - Let `D` = `.branch-interview/<key>`.
3. **Gitignore.** If `.gitignore` has no `.branch-interview/` line, append it and tell the engineer.
4. **Language.** Read `language:` from the frontmatter of `docs/interviews/*.md`; if they differ, use the most recently modified file. Else read `language:` from `D/state.md`. Else ask: Russian or English. From here on, every message and the report use that language, even if the engineer writes in the other one.
5. **Hunks.** Run `SCOPE hunks <mode> [paths]`.
   - No rows: say the scope has no changes and stop.
   - No rows with noise `-`: say the change is only noise (list it) and stop.
   - Sum of `+N` and `-M` over 5000: warn about the size and continue.
6. **Resume.** If `D/hunks.tsv` and `D/state.md` exist, run `SCOPE diff-state D/hunks.tsv <mode> [paths]`:
   - `same`: keep the chunk's status.
   - `changed`: set the chunk to `not-reviewed`, clear its answers, rebuild its dossier.
   - `new`: send to dossier building.
   - `removed`: drop the hunk; drop a chunk with no hunks left.
   Ask: continue, or start over. If `state.md` cannot be parsed (no frontmatter or no `## c-` headings), offer to start over and move it to `state.md.bak`.
7. **Dossiers.** Take the hunks to analyze (all non-noise hunks on a new session; `new` and `changed` ones on resume). Group them by top-level directory into batches of at most 400 changed lines. Dispatch `branch-interview:dossier-builder` for each batch, at most 5 in parallel, with this prompt:

   ```
   SCOPE: <SCOPE>
   MODE: <mode>
   PATHS: <paths or empty>
   DOSSIER_DIR: <D>/dossiers
   HUNKS:
   <the batch's hunk rows>
   ```

   Parse the reply lines up to `END`. If an agent fails or its reply does not parse, retry that batch once. If it fails again, write those dossiers yourself in the format from `<this skill's base directory>/../../agents/dossier-builder.md` and mark them `dossier: main-session` in `state.md`.
8. **Save.** Write `D/hunks.tsv` (`hunk_hash<TAB>chunk_id<TAB>file<TAB>lines`, one row per non-noise hunk) and `D/state.md` (format below).
9. **Plan.** Rank chunks by the sum of their three scores. Show a numbered list: `file:lines — reason`. Put chunks with a sum of 4 or less in one collapsed line at the end, and noise in another. Ask the engineer to drop or add chunks. For an added `file:lines`, dispatch one dossier-builder with the matching hunk rows. There is no limit on the number of chunks.

## Interview

For each chunk in plan order:

1. Show `file:lines` and the code (`SCOPE show <hunk_hash> <mode> [paths]`, or Read the lines). Trim long hunks to the essential part. Never show or quote the dossier. If `show` exits 5, the code changed: mark the chunk `changed` and go to the next one.
2. Go through the axes in order: what, why, alternatives, weaknesses. Skip an axis marked N/A in the dossier.
3. Run the hint ladder for each axis:

| Step | You send | Passes if |
|------|----------|-----------|
| rung 0 | the dossier's question | the answer covers the key points |
| rung 1 | the rung 1 leading question | same |
| rung 2 | the rung 2 pointer; the engineer reads, then answers | same |
| rung 3 | the rung 3 explanation, then "restate it in your own words" | the restatement has the same substance and is not a copy |

   Stop the ladder at the first passing answer. The axis status is that rung. A partial answer does not pass: say which key point is missing, without stating it, and go to the next rung. "I don't know" goes to the next rung.

4. After the weaknesses axis, tell the engineer the dossier's findings they did not name, as information. Do not require a rewrite.
5. After each axis, update `D/state.md` immediately.

Every message you send contains exactly one question.

**Commands** (accept them in either language):
- `explain` / `объясни`: go to rung 3 now. The restatement is still required.
- `skip` / `пропусти`: mark the current axis, or the whole chunk if said at its start, as skipped.
- `stop` / `хватит`: go to Finish.

**Grading:**
- The dossier is a hint, not the truth. If the engineer explains intent differently and the code is consistent with it, the axis passes; record the disagreement.
- A correct weakness or alternative that is not in the dossier counts.
- Acknowledge a passing answer in at most one short sentence, without superlatives. Do not re-explain what the engineer just said.

## Red Flags

These replies mean you are breaking the interview. Rewrite before sending.

| You are about to | Instead |
|------------------|---------|
| explain after "I don't know" | ask the next rung's question |
| accept "yes, I agree" after an explanation | ask for the restatement in their own words |
| skip the restatement because the engineer is in a hurry | give the explanation and ask for the restatement; the command `skip` exists if they want to skip |
| ask "is it right that…" or a yes/no question | ask an open question |
| ask two questions at once | ask one |
| state the correct answer while pointing out a mistake | name the missing point without its content |
| override the author's intent with the dossier | check the answer against the code |
| praise ("great answer!") | one short neutral sentence, then the next question |

## State file

`D/state.md`:

```markdown
---
language: ru
key: feat-retry
mode: branch
paths:
base_sha: <sha>
head_sha: <sha>
updated: <ISO 8601 time>
---
## c-cdf1b88 · src/retry.js:1-18
scores: importance 4 · complexity 3 · doubt 5
reason: doubt — delay has no upper bound
status: not-reviewed | in-progress | done | skipped | changed
dossier: agent | main-session
disagreement: <one line, or empty>
findings-revealed: <comma-separated finding lines, or empty>

### what
rung: 0 | 1 | 2 | 3 | skipped | pending
answer:
> <engineer's passing answer or restatement, verbatim>
```

Chunks appear in plan order. Tail chunks carry `tail: true`.

## Finish

1. Run `SCOPE diff-state D/hunks.tsv <mode> [paths]`. Mark chunks with `changed` hunks as "changed after review".
2. Write `docs/interviews/<key>.md` from `<this skill's base directory>/report-template.md`, rebuilt from the whole `state.md`. Chunks not finished are listed as not reviewed.
3. Tell the engineer the report path and that committing it is up to them: `git add docs/interviews/<key>.md`.
````

- [ ] **Step 3: Check the skill's word count and frontmatter**

Run: `wc -w skills/branch-interview/SKILL.md && head -5 skills/branch-interview/SKILL.md`
Expected: frontmatter with `name: branch-interview` and a `description` starting with "Use when"; total frontmatter under 1024 characters. The body is long (≈1400 words) because it is a rarely-loaded procedural skill; do not pad it further.

- [ ] **Step 4: Run the treatment arm (GREEN)**

Dispatch the same 9 scenarios × 5 reps with the treatment context from `tests/skill/README.md` (full `SKILL.md` text included). Grade manually.

Expected: every scenario that failed in the baseline passes at least 5/5 or 4/5; no scenario that passed in the baseline regresses. Replies converge on the same shape across reps.

- [ ] **Step 5: Record results**

Write `tests/skill/results/<date>-treatment.md` in the same format as the baseline, with verbatim quotes for every failure.

- [ ] **Step 6: Commit**

```bash
git add skills/branch-interview/SKILL.md skills/branch-interview/report-template.md tests/skill/results
git commit -m "feat: add branch-interview skill and report template

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Close loopholes (REFACTOR)

**REQUIRED SUB-SKILL:** Use superpowers:writing-skills (Match the Form to the Failure; micro-test wording). Runs in the main session.

**Files:**
- Modify: `skills/branch-interview/SKILL.md`
- Create: `tests/skill/results/<date>-refactor-<n>.md`

**Interfaces:**
- Consumes: treatment results from Task 9.

- [ ] **Step 1: List remaining failures**

From `tests/skill/results/<date>-treatment.md`, list every scenario below 5/5 and classify each failure with the writing-skills table: rule skipped under pressure (use a Red Flags row), wrong output shape (use a recipe in the Interview section), or missing element (add a required slot).

If every scenario is 5/5, write "no loopholes found" in `tests/skill/results/<date>-refactor-1.md`, commit it, and skip to Step 5.

- [ ] **Step 2: Change the wording**

For each failure, change `SKILL.md` in the form Step 1 chose. Add no nuance clauses ("unless…"); express a real exception as its own condition.

- [ ] **Step 3: Re-run the failing scenarios**

Run only the scenarios that were below 5/5, 5 reps each, with the updated `SKILL.md`. Then run one rep of every other scenario to catch regressions.

Expected: all scenarios 5/5 (4/5 acceptable only with a written reason in the results file).

- [ ] **Step 4: Record and repeat**

Write `tests/skill/results/<date>-refactor-<n>.md`. Repeat Steps 1–3 until Step 3 meets its expectation, at most 3 rounds. After 3 rounds, stop and report the remaining failures to the human partner instead of continuing.

- [ ] **Step 5: Commit**

```bash
git add skills/branch-interview/SKILL.md tests/skill/results
git commit -m "fix: close interviewer loopholes found in scenario runs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: End-to-end run and docs

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Create: `tests/skill/results/<date>-e2e.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Run a full session on the fixture**

Build a fresh fixture. From inside it, start `claude --plugin-dir <repo>` and invoke the skill with `branch`. Confirm the actual invocation name (`/branch-interview` or `/branch-interview:branch-interview`) and use it in the README. Play the engineer: answer chunk 1 well, say "не знаю" on one axis of chunk 2, then `хватит`.

Check each item and record the result in `tests/skill/results/<date>-e2e.md`:
- Language question asked (no reports exist yet).
- `.branch-interview/` appended to the fixture's `.gitignore`.
- Plan shows 3 code chunks (retry, cache, http or a grouping of them) plus noise line with `package-lock.json` and `docs/guide.md`.
- One question per message throughout.
- `state.md` updated after each axis (open it mid-session).
- `docs/interviews/feat-retry.md` exists, has `language:` frontmatter, the verbatim answers, chunk 3 listed as not reviewed.

- [ ] **Step 2: Resume run**

In the same fixture, edit `src/cache.js` (change `30_000` to `60_000` in `src/http.js` instead if cache was not reviewed), commit, and invoke the skill again with `branch`.

Check and record:
- No language question (taken from the report).
- Offer to continue.
- The edited chunk is back to not reviewed; the untouched reviewed chunk stays done.

- [ ] **Step 3: Update README**

Replace `README.md` with:

````markdown
# claude-branch-interview

Claude Code plugin that interviews an engineer about the code in their branch until they show they own it.

It picks the most important, complex, and questionable parts of your change and asks, one question at a time, what each part does, why it was added, which alternatives existed, and what its weak points are. When you don't know, it leads you to the answer with hints instead of handing it over. The report with your own answers lands in `docs/interviews/`.

## Install

```
/plugin marketplace add BorysShulyak/claude-branch-interview
/plugin install branch-interview@claude-branch-interview
```

## Use

```
<invocation> branch             # your branch vs its merge-base with main
<invocation> last-commit        # only HEAD
<invocation> uncommitted        # staged, unstaged, and untracked changes
<invocation> files <path>...    # chosen files vs the merge-base
```

During the interview you can say `explain` (`объясни`), `skip` (`пропусти`), or `stop` (`хватит`).

The base branch is `main`, then `origin/HEAD`. Override it with `BRANCH_INTERVIEW_BASE=<ref>`.

Local state goes to `.branch-interview/` (added to `.gitignore` on first run). The report goes to `docs/interviews/<key>.md`; commit it if you want reviewers to see it.

## Development

```
bash tests/scope.test.sh                    # scope.sh tests
bash tests/check-dossier.sh <dossier.md>    # dossier structure check
claude --plugin-dir .                       # load the plugin from this checkout
```

Behavior tests for the interviewer are described in [tests/skill/README.md](tests/skill/README.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
````

Replace `<invocation>` with the name confirmed in Step 1.

- [ ] **Step 4: Update CLAUDE.md**

Replace the `## Current state` section with:

```markdown
## Structure

- `skills/branch-interview/SKILL.md`: session driver (setup, hint-ladder interview, state, report).
- `skills/branch-interview/scripts/scope.sh`: deterministic scope, hunk hashes, noise flags, state diff. Must run on bash 3.2.
- `skills/branch-interview/report-template.md`: report skeleton with ru/en headings.
- `agents/dossier-builder.md`: plugin agent that writes one dossier per chunk.
- `tests/skill/`: fixture repo builder, interviewer scenarios, recorded runs.

## Commands

- Test: `bash tests/scope.test.sh`
- Lint: `shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh tests/skill/*.sh`
- Load locally: `claude --plugin-dir .`

Changes to `SKILL.md` or `agents/dossier-builder.md` follow superpowers:writing-skills: rerun the scenarios in `tests/skill/` before and after.
```

- [ ] **Step 5: Commit**

```bash
git add README.md CLAUDE.md tests/skill/results
git commit -m "docs: document install, usage, and development

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
