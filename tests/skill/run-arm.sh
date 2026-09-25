#!/bin/bash
# Runs N headless interviewer samples for one scenario, in one arm.
#
# Usage: tests/skill/run-arm.sh <control|treatment> <scenario-file> <reps> <out-dir>
#
# Builds the prompt from:
#   - the arm context (control: the neutral interviewer framing; treatment: the
#     same framing plus the full text of skills/branch-interview/SKILL.md)
#   - the fixture dossier at tests/skill/fixtures/retry-dossier.md
#   - src/retry.js, read from a fixture repo built fresh into a temp dir with
#     make-fixture.sh
#   - the scenario file's Setup / Transcript / Engineer's last message sections
#
# Each sample is one fresh headless call, run from a temp directory outside
# the repo so no project CLAUDE.md or plugins load:
#
#   cd "$RUN_DIR" && claude -p --setting-sources "" --disable-slash-commands \
#     --strict-mcp-config --tools "" --model claude-sonnet-5 \
#     --system-prompt "$(cat arm-context.txt)" -- "$(cat prompt-<scenario>.txt)"
#
# Sample N's reply is written to <out-dir>/<scenario-basename>-N.txt (stderr,
# if any, alongside it as <...>-N.txt.err). Up to 5 samples run in parallel.

set -euo pipefail

usage() {
  echo "usage: $(basename "$0") <control|treatment> <scenario-file> <reps> <out-dir>" >&2
  exit 1
}

[ $# -eq 4 ] || usage

arm=$1
scenario_file=$2
reps=$3
out_dir=$4

case "$arm" in
  control|treatment) ;;
  *)
    echo "run-arm.sh: arm must be 'control' or 'treatment', got '$arm'" >&2
    exit 1
    ;;
esac

case "$reps" in
  ''|*[!0-9]*)
    echo "run-arm.sh: reps must be a positive integer, got '$reps'" >&2
    exit 1
    ;;
esac
[ "$reps" -ge 1 ] || { echo "run-arm.sh: reps must be at least 1" >&2; exit 1; }

[ -f "$scenario_file" ] || {
  echo "run-arm.sh: scenario file not found: $scenario_file" >&2
  exit 1
}

script_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$script_dir/../.." && pwd)

dossier_file="$repo_root/tests/skill/fixtures/retry-dossier.md"
skill_file="$repo_root/skills/branch-interview/SKILL.md"
make_fixture="$repo_root/tests/skill/make-fixture.sh"

[ -f "$dossier_file" ] || {
  echo "run-arm.sh: dossier not found: $dossier_file" >&2
  exit 1
}
[ -f "$make_fixture" ] || {
  echo "run-arm.sh: fixture builder not found: $make_fixture" >&2
  exit 1
}

if [ "$arm" = "treatment" ] && [ ! -f "$skill_file" ]; then
  echo "run-arm.sh: treatment arm requires $skill_file, which does not exist yet" >&2
  exit 1
fi

command -v claude >/dev/null 2>&1 || {
  echo "run-arm.sh: 'claude' CLI not found on PATH" >&2
  exit 1
}

mkdir -p "$out_dir"

# --- build a fresh fixture repo and grab the code shown to the engineer ---
fixture_parent=$(mktemp -d)
fixture_dir="$fixture_parent/bi-fixture"
bash "$make_fixture" "$fixture_dir" >/dev/null
code_file="$fixture_dir/src/retry.js"
[ -f "$code_file" ] || {
  echo "run-arm.sh: fixture builder did not produce $code_file" >&2
  exit 1
}

# --- work dir outside the repo: holds the system prompt and user prompt, and
#     is the cwd every headless call runs from ---
work_dir=$(mktemp -d)

cleanup() {
  rm -rf "$fixture_parent" "$work_dir"
}
trap cleanup EXIT

control_context="You are interviewing an engineer about code in their branch to check that they understand and own it."

arm_context_file="$work_dir/arm-context.txt"
if [ "$arm" = "control" ]; then
  printf '%s\n' "$control_context" > "$arm_context_file"
else
  {
    printf '%s\n' "$control_context"
    printf '\n'
    cat "$skill_file"
  } > "$arm_context_file"
fi

# --- pull the scenario's sections out of its markdown ---
extract_section() {
  # $1 = file, $2 = heading text without the leading "## "
  awk -v heading="## $2" '
    $0 == heading { found = 1; next }
    found && /^## / { found = 0 }
    found { print }
  ' "$1"
}

setup=$(extract_section "$scenario_file" "Setup")
transcript=$(extract_section "$scenario_file" "Transcript")
last_msg=$(extract_section "$scenario_file" "Engineer's last message")

dossier_content=$(cat "$dossier_file")
code_content=$(cat "$code_file")

scenario_name=$(basename "$scenario_file" .md)
prompt_file="$work_dir/prompt-$scenario_name.txt"

{
  printf -- '--- Dossier (visible to you, not to the engineer) ---\n'
  printf '%s\n' "$dossier_content"
  printf '\n'
  printf -- '--- Code shown to the engineer ---\n'
  printf '%s\n' "$code_content"
  printf '\n'
  printf -- '--- Setup ---\n'
  printf '%s\n' "$setup"
  printf '\n'
  printf -- '--- Transcript ---\n'
  printf '%s\n' "$transcript"
  printf 'Engineer: %s\n' "$last_msg"
  printf '\n'
  printf 'Write only your next message to the engineer. No commentary.\n'
} > "$prompt_file"

# --- run the samples, up to 5 in parallel ---
system_prompt=$(cat "$arm_context_file")
user_prompt=$(cat "$prompt_file")

rep=1
while [ "$rep" -le "$reps" ]; do
  pids=""
  batch_end=$((rep + 4))
  if [ "$batch_end" -gt "$reps" ]; then
    batch_end=$reps
  fi

  j=$rep
  while [ "$j" -le "$batch_end" ]; do
    out_file="$out_dir/${scenario_name}-${j}.txt"
    (
      cd "$work_dir" && claude -p \
        --setting-sources "" \
        --disable-slash-commands \
        --strict-mcp-config \
        --tools "" \
        --model claude-sonnet-5 \
        --system-prompt "$system_prompt" \
        -- "$user_prompt" \
        > "$out_file" 2> "$out_file.err"
    ) &
    pids="$pids $!"
    j=$((j + 1))
  done

  for pid in $pids; do
    if ! wait "$pid"; then
      echo "run-arm.sh: warning: sample process $pid exited non-zero" >&2
    fi
  done

  rep=$((batch_end + 1))
done

echo "run-arm.sh: wrote $reps ${arm} replies for $scenario_name to $out_dir"
