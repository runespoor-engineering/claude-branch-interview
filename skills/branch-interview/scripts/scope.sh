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
  echo "root=$(pwd -P)"
}

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
  # Fixed prefixes and --no-relative keep paths stable under diff.noprefix / diff.relative.
  local opts=(--no-color --no-ext-diff --no-relative --src-prefix=a/ --dst-prefix=b/ -M -U0)
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
    function unquote(p) {
      if (substr(p, 1, 1) != "\"") return p
      p = substr(p, 2, length(p) - 2)
      result = ""
      i = 1
      while (i <= length(p)) {
        c = substr(p, i, 1)
        if (c == "\\" && i + 1 <= length(p)) {
          next_c = substr(p, i + 1, 1)
          if (next_c == "\"") { result = result "\""; i += 2 }
          else if (next_c == "\\") { result = result "\\"; i += 2 }
          else if (next_c == "t") { result = result "\t"; i += 2 }
          else if (next_c == "n") { result = result "\n"; i += 2 }
          else { result = result c; i++ }
        } else { result = result c; i++ }
      }
      return result
    }
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
    function flush_pending_rename() {
      if (!pending_rename) return
      out = sprintf("%s/%06d", dir, ++n)
      printf "%s\t0-0\t0\t0\trename\n", file > out
      printf "%s", pending_rename_text > out
      close(out)
      pending_rename = 0
      pending_rename_text = ""
    }
    function start(r) {
      flush_pending_rename()
      flush()
      open = 1; range = r; body = file "\n"; added = 0; removed = 0
      plus_s = ""; minus_s = ""
    }
    /^diff --git / { flush_pending_rename(); flush(); file = ""; oldfile = ""; pending_rename = 0; next }
    /^rename from / { p = substr($0, 13); oldfile = unquote(p); next }
    /^rename to / {
      p = substr($0, 11)
      file = unquote(p)
      pending_rename = 1
      pending_rename_text = file "\nrename " oldfile " -> " file "\n"
      next
    }
    /^--- / { p = substr($0, 5); sub(/\t$/, "", p); p = unquote(p); if (p != "/dev/null") oldfile = substr(p, 3); next }
    /^\+\+\+ / { p = substr($0, 5); sub(/\t$/, "", p); p = unquote(p); file = (p == "/dev/null") ? oldfile : substr(p, 3); next }
    /^Binary files / {
      pending_rename = 0
      p = $0
      sub(/ differ$/, "", p)
      i = index(p, " and ")
      op = substr(p, 14, i - 14)
      np = substr(p, i + 5)
      op = unquote(op)
      np = unquote(np)
      sub(/^[ab]\//, "", op)
      sub(/^[ab]\//, "", np)
      file = (np == "/dev/null") ? op : np
      out = sprintf("%s/%06d", dir, ++n)
      printf "%s\t0-0\t0\t0\tbinary\n", file > out
      printf "%s\nbinary %s\n", file, idx > out
      close(out)
      next
    }
    /^index / { idx = $2; next }
    /^@@ / {
      pending_rename = 0
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
    END { flush_pending_rename(); flush() }
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

# Splits the scope into $SCRATCH and prints: hunk_hash<TAB>hunk_file.
# Identical hunks in one file get "#<n>" appended to the hash input from the second copy on,
# so every hunk has its own hash and the first copy keeps the plain one.
# The caller runs `scratch` first, in the same process that reads the hunk files.
hunk_hashes() {
  local hf base n hash seen
  seen="$SCRATCH/.seen"
  raw_diff "$@" | split_hunks "$SCRATCH"
  : > "$seen"
  for hf in "$SCRATCH"/[0-9]*; do
    [ -e "$hf" ] || continue
    base=$(tail -n +2 "$hf" | git hash-object --stdin)
    n=$(grep -c "^$base\$" "$seen" || true)
    echo "$base" >> "$seen"
    if [ "$n" -eq 0 ]; then
      hash=$base
    else
      hash=$({ tail -n +2 "$hf"; printf '#%d\n' "$((n + 1))"; } | git hash-object --stdin)
    fi
    printf '%s\t%s\n' "$hash" "$hf"
  done
}

# Prints: hunk_hash<TAB>file<TAB>start-end<TAB>+N<TAB>-M<TAB>noise
cmd_hunks() {
  local hf file range added removed kind noise hash
  scratch
  hunk_hashes "$@" | while IFS=$'\t' read -r hash hf; do
    IFS=$'\t' read -r file range added removed kind < "$hf"
    if [ "$kind" != "code" ]; then noise=$kind
    elif is_lockfile "$file"; then noise=lockfile
    elif is_generated "$file"; then noise=generated
    else noise=-
    fi
    printf '%s\t%s\t%s\t+%s\t-%s\t%s\n' "$hash" "$file" "$range" "$added" "$removed" "$noise"
  done
}

# Old state: hunk_hash<TAB>chunk_id<TAB>file<TAB>lines. Prints: status<TAB>hunk_hash<TAB>chunk_id
# changed = hash is new but the hunk overlaps an unmatched old hunk in the same file.
# Noise hunks are skipped: the state holds only non-noise hunks.
cmd_diff_state() {
  local state=$1
  shift
  [ -f "$state" ] || die 2 "state file '$state' not found"
  cmd_hunks "$@" | awk -F'\t' -v OFS='\t' '
    function lo(r) { split(r, x, "-"); return x[1] + 0 }
    function hi(r) { split(r, x, "-"); return x[2] + 0 }
    NR == FNR { oh[++on] = $1; oc[on] = $2; of[on] = $3; ol[on] = $4; known[$1] = on; next }
    $6 != "-" { next }
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
  hf=$(hunk_hashes "$@" | awk -F'\t' -v w="$want" '$1 == w { print $2; exit }')
  [ -n "$hf" ] || die 5 "hunk $want not found in scope"
  tail -n +3 "$hf"
}

main() {
  [ "$#" -ge 2 ] || usage
  local cmd=$1 fixed="" mode prefix p
  shift
  case "$cmd" in
    meta|hunks) ;;
    diff-state|show) [ "$#" -ge 2 ] || usage; fixed=$1; shift ;;
    *) usage ;;
  esac
  require_repo
  check_mode "$@"
  mode=$1
  shift
  # Work from the repo root so scope and paths do not depend on the current directory.
  # `files` paths are relative to the caller's directory: prefix them, drop a leading "./".
  prefix=$(git rev-parse --show-prefix)
  case "$fixed" in /*|"") ;; *) [ "$cmd" = diff-state ] && fixed="$PWD/$fixed" ;; esac
  cd "$(git rev-parse --show-toplevel)"
  local paths=()
  for p in "$@"; do
    p=${p#./}
    paths+=("$prefix$p")
  done
  set -- "$mode" ${paths[@]+"${paths[@]}"}
  case "$cmd" in
    meta) cmd_meta "$@" ;;
    hunks) cmd_hunks "$@" ;;
    diff-state) cmd_diff_state "$fixed" "$@" ;;
    show) cmd_show "$fixed" "$@" ;;
  esac
}

main "$@"
