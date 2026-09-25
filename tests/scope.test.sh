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

test_hunks_rename_with_edit() {
  new_repo
  git checkout -qb feat
  git mv app.txt moved.txt
  sed 's/^c$/C/' moved.txt > t && mv t moved.txt
  git add -A && git commit -qm rename_edit
  assert_eq "hunks: rename with edit yields code row only" "moved.txt	3-3	+1	-1	-" "$(scope hunks branch | cut -f2-)"
}

test_hunks_quoted_path() {
  new_repo
  git checkout -qb feat
  printf 'x\n' > "weird\"name.txt" && git add -A && git commit -qm quoted
  local file errs
  file=$(scope hunks branch | field 2)
  errs=$(scope hunks branch 2>&1 >/dev/null)
  assert_eq "hunks: quoted path is unquoted" "weird\"name.txt" "$file"
  assert_eq "hunks: quoted path no error" "" "$errs"
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
