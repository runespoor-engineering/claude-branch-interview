# Skill behavior tests

Micro-tests for the interviewer's behavior. Each scenario is a transcript that stops at a moment where an interviewer tends to fail. A fresh headless `claude -p` call writes the interviewer's next message; you grade it against the scenario's criteria.

## Arms

- **control**: no skill. Context = "You are interviewing an engineer about code in their branch to check that they understand and own it." plus the scenario's Setup, the dossier, and the code of src/retry.js from the fixture.
- **treatment**: same, plus the full text of `skills/branch-interview/SKILL.md`.

## Running

Each sample is a fresh, isolated headless call — not a dispatched subagent. Run it from a temp directory outside the repo so no project `CLAUDE.md` or plugins load:

```bash
cd "$RUN_DIR" && claude -p --setting-sources "" --disable-slash-commands \
  --strict-mcp-config --tools "" --model claude-sonnet-5 \
  --system-prompt "$(cat arm-context.txt)" -- "$(cat prompt-<scenario>.txt)"
```

The system prompt is the arm context; the user message is the prompt template below (dossier, code, setup, transcript, engineer's last message). One call = one sample. Save each reply to a file, e.g. `$RUN_DIR/out/<scenario>-<rep>.txt`.

1. Build the fixture once: `bash tests/skill/make-fixture.sh "$TMPDIR/bi-fixture"`.
2. For each scenario and each arm, run 5 samples (one headless call each). Prompt:

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
4. Put a summary in the PR description: one row per scenario with the pass count out of 5, and each failing reply quoted verbatim (trim to the failing sentence when long). Raw replies stay local; `tests/skill/results/` is gitignored.

### Helper script

`tests/skill/run-arm.sh <arm: control|treatment> <scenario-file> <reps> <out-dir>` automates the above for one scenario: it builds the arm context, builds a fresh fixture repo with `make-fixture.sh` into a temp dir and reads `src/retry.js` from it, reads the dossier from `tests/skill/fixtures/retry-dossier.md`, pulls the scenario's `## Setup` / `## Transcript` / `## Engineer's last message` sections out of `<scenario-file>`, assembles the prompt above, and runs the headless command `<reps>` times (up to 5 in parallel), writing sample N's reply to `<out-dir>/<scenario-basename>-N.txt`. For the `treatment` arm it appends the full text of `skills/branch-interview/SKILL.md` to the arm context, and fails with a clear error if that file does not exist yet. It runs on bash 3.2 (`/bin/bash`) and passes `shellcheck`.

Example, run from the repo root:

```bash
bash tests/skill/run-arm.sh control tests/skill/scenarios/01-first-question.md 5 /tmp/bi-out/01-first-question
```

A scenario where the control passes 5/5 needs no guidance; do not add rules for it.
