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
