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
