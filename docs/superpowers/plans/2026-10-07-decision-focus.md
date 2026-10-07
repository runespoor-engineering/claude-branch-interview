# Decision Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By default, interview only about at most 5 decision chunks; every other chunk collapses into a plan line; `--all` keeps the old behavior.

**Architecture:** The dossier builder labels each chunk `decision` or `support` by the role of the change, and writes dossiers only for decisions unless told `DOSSIERS: all`. The interviewer (`SKILL.md`) reads the new `kind` column, selects the top 5 decisions for the plan, records `focus` and `kind` in `state.md`, and the report counts unplanned chunks in one "out of plan" line.

**Tech Stack:** Markdown instructions for Claude Code (skill + plugin agent), bash 3.2 test helpers, headless `claude -p` for behavior tests.

**Spec:** `docs/superpowers/specs/2026-10-07-decision-focus-design.md`

## Global Constraints

- The classification depends on the role of a change, never on its language, framework, file type, or directory. No stack-specific examples in the agent or skill text.
- No project-specific names or examples anywhere in the repo.
- Limit: at most 5 automatically numbered chunks; only `decision` chunks with a score sum of 5 or more.
- `--all` anywhere in the arguments, never a path.
- Missing `focus:` in an existing `state.md` means `all`.
- `scope.sh` does not change.
- Shell files run on bash 3.2 and pass `shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh tests/skill/*.sh`.
- `.editorconfig`: UTF-8, LF, 2-space indent.
- Commits follow Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Changes to `SKILL.md` or `agents/dossier-builder.md`: run scenarios 01–12 in the treatment arm before and after (`CLAUDE.md`).
- Headless runs that need permissions use `--dangerously-skip-permissions` only inside a throwaway fixture repo under the session scratchpad, never in this repo.

## Review Focus

1. Resume of a session written before this change (`state.md` with no `focus:` and no `kind:`): it must resume as `all`, keep statuses, and not rebuild anything. Test: Task 5, check E5.
2. A scope with no decision at all (only docs): the interviewer must say so, show the collapsed lines, and ask the engineer to pick; it must not start asking. Test: Task 5, check E6.
3. `--all` after `files <path>...`: it must set focus and must not be taken as a path. Test: Task 5, check E7.
4. `--inline --all` together: no agents, dossiers for every chunk. Test: Task 5, check E4.
5. A `support` chunk with a higher score sum than every decision: it must never be numbered. Test: Task 3, scenario 13 (the `support` row with sum 12).

## File map

| File | Responsibility | Task |
|------|----------------|------|
| `tests/skill/make-fixture.sh` | fixture repo; gains one commit with support files and a config decision | 1 |
| `docs/testing.md` | fixture description, scenario table, end-to-end checklist | 1, 3, 5 |
| `agents/dossier-builder.md` | `DOSSIERS` input, grouping rule, `kind` step, reply column | 2 |
| `docs/how-it-works.md` | key terms, steps 4, 5, 7, 8 | 2, 3, 4 |
| `tests/skill/scenarios/13-plan-limit.md` | frozen plan moment | 3 |
| `skills/branch-interview/SKILL.md` | focus flag, step 6/7/9, state format | 3 |
| `README.md` | `--all` usage | 3 |
| `skills/branch-interview/report-template.md` | `focus` field, "out of plan" line | 4 |

Paths used below:

```bash
REPO=/Users/borysshuliak/Desktop/repos/claude-branch-interview
S=<session scratchpad directory>
SCOPE="bash $REPO/skills/branch-interview/scripts/scope.sh"
```

---

### Task 0: Baseline of scenarios 01–12

**Files:** none committed. Results go to `tests/skill/results/` (gitignored).

- [ ] **Step 1: Run every scenario in the treatment arm, 5 samples each**

```bash
cd "$REPO"
for f in tests/skill/scenarios/[01][0-9]-*.md; do
  n=$(basename "$f" .md)
  bash tests/skill/run-arm.sh treatment "$f" 5 "tests/skill/results/before/$n"
done
```

Expected: `run-arm.sh: wrote 5 treatment replies for <name> to …` for all 12.

- [ ] **Step 2: Grade every reply against its scenario's Pass criteria and Fail signals**

Write `tests/skill/results/before/summary.md`: one row per scenario, `NN name | k/5`, then each failing reply quoted verbatim (trimmed to the failing sentence). This is the "before" column for the PR description.

---

### Task 1: Extend the fixture

**Files:**
- Modify: `tests/skill/make-fixture.sh` (header comment at lines 4–9; initial commit at lines 21–30; new commit before the final `echo`)
- Modify: `docs/testing.md` (fixture list, "The fixture: a small fake project")

**Interfaces:**
- Produces: fixture branch `feat/retry` whose `$SCOPE hunks --code-only branch` lists `.eslintrc.json`, `config/retry.json`, `docs/retry.md`, `src/cache.js`, `src/http.js`, `src/retry.js`, `src/retry.test.js`. The `src/retry.js` hunk hash still starts with `cdf1b88`.

- [ ] **Step 1: Write the failing check**

```bash
rm -rf "$S/fx" && bash "$REPO/tests/skill/make-fixture.sh" "$S/fx" >/dev/null
cd "$S/fx" && $SCOPE hunks --code-only branch | cut -f2 | sort -u
```

Expected now (fails the target): only `src/cache.js`, `src/http.js`, `src/retry.js`.

- [ ] **Step 2: Add the lint config to the initial commit on `main`**

In `make-fixture.sh`, right after `printf '# Usage\n\nCall getJson(url).\n' > docs/usage.md`, add:

```bash
cat > .eslintrc.json <<'EOF'
{
  "rules": {
    "no-unused-vars": "warn"
  }
}
EOF
```

- [ ] **Step 3: Add the new branch commit**

Insert before `echo "fixture ready: $target (branch feat/retry)"`:

```bash
mkdir -p config
cat > config/retry.json <<'EOF'
{
  "retries": 3,
  "baseMs": 200
}
EOF
cat > src/http.js <<'EOF'
const { retryWithBackoff } = require('./retry');
const { memoizeTtl } = require('./cache');
const retryConfig = require('../config/retry.json');

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

const getJson = memoizeTtl((url) => retryWithBackoff(() => fetchJson(url), retryConfig), 30_000);

module.exports = { getJson };
EOF
cat > src/retry.test.js <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const { retryWithBackoff } = require('./retry');

test('returns the first successful result', async () => {
  let calls = 0;
  const result = await retryWithBackoff(async () => {
    calls += 1;
    if (calls < 2) throw new Error('fail');
    return 'ok';
  }, { retries: 3, baseMs: 1 });
  assert.strictEqual(result, 'ok');
  assert.strictEqual(calls, 2);
});

test('rethrows after the last retry', async () => {
  await assert.rejects(
    retryWithBackoff(async () => { throw new Error('always'); }, { retries: 1, baseMs: 1 }),
    /always/
  );
});
EOF
cat > docs/retry.md <<'EOF'
# Retry

`getJson` retries a failed request with exponential backoff and full jitter.
The limits come from `config/retry.json`: `retries` and `baseMs`.
EOF
cat > .eslintrc.json <<'EOF'
{
  "rules": {
    "no-unused-vars": "error"
  }
}
EOF
git add -A
git commit -qm "feat: read retry limits from config

Adds tests and docs for retry, and makes unused variables a lint error."
```

- [ ] **Step 4: Update the header comment (lines 4–9)**

Replace the block with:

```bash
# Result: repo with branch feat/retry off main. Seeded chunks:
#   src/retry.js       - exponential backoff with jitter; BUG: no upper bound on delay;
#                        doubtful: retries every error, including 4xx
#   src/cache.js       - TTL memoize; weakness: expired entries are never evicted
#   src/http.js        - wires retry + cache into getJson, reads config/retry.json
#   config/retry.json  - retry limits (decision: a config file that changes behavior)
#   src/retry.test.js  - tests retry (support: joins the retry chunk)
#   docs/retry.md      - describes retry (support)
#   .eslintrc.json     - lint rule tweak (support)
#   noise              - package-lock.json, rename docs/usage.md -> docs/guide.md
```

- [ ] **Step 5: Run the check again**

```bash
rm -rf "$S/fx" && bash "$REPO/tests/skill/make-fixture.sh" "$S/fx" >/dev/null
cd "$S/fx" && $SCOPE hunks --code-only branch | cut -f2 | sort -u
$SCOPE hunks --code-only branch | awk -F'\t' '$2 == "src/retry.js" { print substr($1, 1, 7) }'
```

Expected: the 7 files from **Produces**; second command prints `cdf1b88`.

- [ ] **Step 6: Lint**

Run: `cd "$REPO" && shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh tests/skill/*.sh`
Expected: no output, exit 0.

- [ ] **Step 7: Update `docs/testing.md` fixture list**

Replace the four bullets under "The fixture: a small fake project" with:

```markdown
- a retry helper with a growing, random wait, and two planted problems: the wait has no upper limit, and every error is retried, even ones that can never succeed;
- a cache with a planted weakness: old entries are never removed;
- a small file that wires the two together and reads retry limits from a config file;
- the config file itself: a decision that lives outside source code;
- supporting changes: a test for the retry helper, a document that describes it, and a lint rule tweak;
- noise: a lock file and a renamed document.
```

- [ ] **Step 8: Commit**

```bash
cd "$REPO"
git add tests/skill/make-fixture.sh docs/testing.md
git commit -m "test(fixture): add support files and a config decision

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Dossier builder classifies chunks

**Files:**
- Modify: `agents/dossier-builder.md` (Input list lines 9–15; Procedure lines 24–90)
- Modify: `docs/how-it-works.md` (Key terms lines 33–43; "4. Building dossiers" lines 75–90)

**Interfaces:**
- Consumes: the fixture from Task 1.
- Produces: input field `DOSSIERS: decisions | all`; reply line
  `<chunk_id>\t<file>:<start>-<end>\t<importance>\t<complexity>\t<doubt>\t<kind>\t<reason>\t<hunk_hash>[,…]` with `kind` ∈ {`decision`, `support`}; Procedure steps renumbered 1 group, 2 id, 3 score, 4 kind, 5 write dossiers, 6 reply. Task 3 refers to "steps 1–5" and "step 6".

- [ ] **Step 1: Write the builder driver (direct builder run on the fixture)**

Save as `$S/run-builder.sh` (scratchpad, not committed):

```bash
#!/bin/bash
# usage: run-builder.sh <fixture-dir> <decisions|all> <out-dir>
set -euo pipefail
fx=$1; dossiers=$2; out=$3
REPO=/Users/borysshuliak/Desktop/repos/claude-branch-interview
SCOPE="bash $REPO/skills/branch-interview/scripts/scope.sh"
mkdir -p "$out/dossiers"
sys=$(awk 'NR == 1 && /^---$/ { fm = 1; next } fm && /^---$/ { fm = 0; next } !fm' "$REPO/agents/dossier-builder.md")
hunks=$(cd "$fx" && $SCOPE hunks --code-only branch)
prompt="SCOPE: $SCOPE
MODE: branch
PATHS:
DOSSIER_DIR: $out/dossiers
LANGUAGE: en
DOSSIERS: $dossiers
HUNKS:
$hunks"
cd "$fx" && claude -p --setting-sources "" --disable-slash-commands --strict-mcp-config \
  --tools "Read,Grep,Glob,Bash,Write" --dangerously-skip-permissions --model claude-sonnet-5 \
  --add-dir "$out" --system-prompt "$sys" -- "$prompt" > "$out/reply.txt"
cat "$out/reply.txt"; ls "$out/dossiers"
```

- [ ] **Step 2: Run it before the change (expected to fail)**

Run: `bash $S/run-builder.sh "$S/fx" decisions "$S/b1"`
Expected (fails the target): reply lines have 7 columns, no `decision`/`support` column; a dossier file exists for every chunk, including docs and lint.

- [ ] **Step 3: Add the input field**

In `## Input (in your prompt)`, after the `LANGUAGE` bullet, add:

```markdown
- `DOSSIERS`: `decisions` or `all`. Which chunks get a dossier file (Procedure step 5).
```

- [ ] **Step 4: Extend grouping (Procedure step 1)**

Append to step 1:

```markdown
   A hunk that only tests or documents a chunk in your batch joins that chunk.
```

- [ ] **Step 5: Insert the kind step and renumber**

After step 3 (scoring) insert a new step 4, and renumber the old steps 4 and 5 to 5 and 6:

```markdown
4. Set each chunk's kind by the role of the change. File type, language, and location never decide the kind.
   - `decision`: the change records a choice that could reasonably have been made differently, and the choice affects someone outside the change: users, calling code, operators, or other developers. It does at least one of these: changes an interface or behavior that other code or people depend on; changes stored data or its shape; changes how the system is built, deployed, configured, or run; introduces or changes a pattern that other code will follow; moves responsibility between components.
   - `support`: the change follows from a decision made elsewhere and records no choice of its own. It pins, describes, regenerates, or mechanically repeats something.
   A test, configuration, or documentation file is a `decision` when it records a choice of its own. A source file is `support` when it only repeats a choice made elsewhere.
```

- [ ] **Step 6: Make dossier writing depend on `DOSSIERS` (new step 5)**

Change the first line of the old step 4 from `4. Write \`DOSSIER_DIR/<chunk_id>.md\` in exactly this format:` to:

```markdown
5. Write `DOSSIER_DIR/<chunk_id>.md` for every chunk when `DOSSIERS` is `all`, and only for `decision` chunks when it is `decisions`. Use exactly this format:
```

- [ ] **Step 7: Add the kind column to the reply (new step 6)**

Replace the reply block with:

````markdown
6. Reply with one line per chunk, including chunks without a dossier, tab-separated, then `END`:

```
<chunk_id>	<file>:<start>-<end>	<importance>	<complexity>	<doubt>	<kind>	<reason>	<hunk_hash>[,<hunk_hash>…]
END
```
````

- [ ] **Step 8: Run the check again, both modes**

```bash
rm -rf "$S/b1" "$S/b2"
bash $S/run-builder.sh "$S/fx" decisions "$S/b1"
bash $S/run-builder.sh "$S/fx" all "$S/b2"
bash "$REPO/tests/check-dossier.sh" "$S"/b1/dossiers/*.md "$S"/b2/dossiers/*.md
```

Expected for `b1`:
- every reply line has 8 tab-separated fields, field 6 is `decision` or `support`;
- the line holding `src/retry.js` also lists the `src/retry.test.js` hunk hash, its id is `c-cdf1b88`, kind `decision`;
- `config/retry.json` is in a `decision` chunk (alone or with `src/http.js`);
- `docs/retry.md` and `.eslintrc.json` are `support`;
- `b1/dossiers/` holds files only for `decision` chunk ids.

Expected for `b2`: same kinds; a dossier file for every chunk id. `check-dossier.sh`: every line `ok`.

If a kind is wrong, fix the wording of step 4 (role-based, no file-type rules) and rerun. Run each mode 3 times; all runs must meet the expectations.

- [ ] **Step 9: Update `docs/how-it-works.md`**

In Key terms, after the **Chunk** bullet, add:

```markdown
- **Kind.** Every chunk is either a **decision** (it records a choice that affects someone outside the change: an interface, data, how the system runs, a pattern, or who is responsible for what) or **support** (it only follows from a decision elsewhere: a test that pins it, a document that describes it, a regenerated file). The kind depends on the role of the change, not on the file type.
- **Focus.** Which chunks the interview plans: `decisions` (the default, at most 5) or `all` (`--all`).
```

In "4. Building dossiers", replace the numbered list with:

```markdown
1. reads each hunk and the code around it;
2. groups hunks into chunks of meaning; a test or document for a chunk in the same batch joins that chunk;
3. scores each chunk from 1 to 5 on importance (public API, data, security, money, concurrency), complexity, and doubt (smells, possible bugs, missing tests, anything that can grow without a limit);
4. labels each chunk as a decision or support;
5. writes a dossier for each decision chunk (for every chunk with `--all`), with a ready question for each axis, the key points of a good answer, and three hints of rising strength.
```

- [ ] **Step 10: Commit**

```bash
cd "$REPO"
git add agents/dossier-builder.md docs/how-it-works.md
git commit -m "feat(dossier-builder): label chunks as decision or support

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Interviewer plans only decisions

**Files:**
- Create: `tests/skill/scenarios/13-plan-limit.md`
- Modify: `skills/branch-interview/SKILL.md` (frontmatter line 4; Setup steps 1, 6, 7, 9; State file block lines 126–154)
- Modify: `README.md` (Use section), `docs/how-it-works.md` ("5. The plan", "7. Saving progress"), `docs/testing.md` (scenario table)

**Interfaces:**
- Consumes: builder reply format and step numbers from Task 2.
- Produces: `state.md` frontmatter `focus: decisions | all`; per chunk `kind: decision | support`, `dossier: agent | main-session | none`; collapsed line names «Ещё решения» / "More decisions", «Сопровождение» / "Supporting". Task 4 reads `focus`, `kind`, `tail`.

- [ ] **Step 1: Write the scenario**

Create `tests/skill/scenarios/13-plan-limit.md`:

```markdown
## Setup
Setup steps 1–8 are done. Mode: branch. No `--all` in the arguments, so focus is `decisions`. Dossier mode: agents. Language: ru. No saved session. Noise: package-lock.json (lockfile).
Builder replies, parsed (chunk_id, file:lines, importance, complexity, doubt, kind, reason):
c-1a2b3c4  src/orders/checkout.js:10-64  5  4  4  decision  importance — order total is now computed on the server
c-2b3c4d5  src/orders/store.js:1-40  4  4  4  decision  importance — orders move to a new table with a status column
c-3c4d5e6  src/queue/worker.js:5-48  3  4  4  decision  complexity — jobs are retried by the worker, not the producer
c-4d5e6f7  src/api/errors.js:1-30  4  3  3  decision  importance — every error response now carries a code field
c-5e6f7a8  deploy/service.yaml:12-20  3  3  3  decision  importance — the service now runs two replicas
c-6f7a8b9  src/orders/format.js:1-22  3  3  2  decision  importance — prices are formatted in the user's locale
c-7a8b9c0  src/util/ids.js:3-9  1  2  1  decision  complexity — ids switch to a shorter alphabet
c-8b9c0d1  test/orders/checkout.e2e.js:1-120  4  4  4  support  complexity — end-to-end test of checkout
c-9c0d1e2  docs/orders.md:1-80  2  2  3  support  doubt — documents the new order states
c-0d1e2f3  .github/workflows/ci.yml:30-34  1  2  2  support  doubt — CI runs the new e2e test

## Transcript
Interviewer: На каком языке вести интервью: русском или английском?
Engineer: На русском.
Interviewer: (builds the dossiers; the replies above are the result)

## Engineer's last message
Жду план.

## Pass criteria
- Exactly 5 numbered items, in this order: src/orders/checkout.js, src/orders/store.js, src/queue/worker.js, src/api/errors.js, deploy/service.yaml.
- One collapsed line holds src/orders/format.js and src/util/ids.js (more decisions).
- One collapsed line holds the three support chunks (test/orders/checkout.e2e.js, docs/orders.md, .github/workflows/ci.yml).
- Noise (package-lock.json) is in its own collapsed line.
- The reply ends with exactly one question, about dropping or adding chunks.
- The reply is in Russian.

## Fail signals
- test/orders/checkout.e2e.js (sum 12) or any other support chunk is numbered.
- Six or more numbered items.
- src/orders/format.js (sum 8) is numbered.
- The reply asks a question about any chunk's code, or starts the interview.
- A dossier is shown or quoted.
```

- [ ] **Step 2: Run it before the change (expected to fail)**

```bash
cd "$REPO"
bash tests/skill/run-arm.sh control tests/skill/scenarios/13-plan-limit.md 5 tests/skill/results/before/13-control
bash tests/skill/run-arm.sh treatment tests/skill/scenarios/13-plan-limit.md 5 tests/skill/results/before/13-treatment
```

Expected: treatment numbers 6 or more items or numbers the e2e test (the current skill numbers every chunk with sum 5 or more). Grade and note k/5 in `tests/skill/results/before/summary.md`.

- [ ] **Step 3: Frontmatter**

Line 4 becomes:

```yaml
argument-hint: "[branch | last-commit | uncommitted | files <path>...] [--base <ref>] [--inline] [--all]"
```

- [ ] **Step 4: Setup step 1, add Focus**

After the `**Base.**` line, add:

```markdown
   **Focus.** `--all` in the arguments (anywhere, never a path) means `all`: every chunk gets a dossier and can be numbered in the plan. Otherwise it is `decisions`: only `decision` chunks are numbered, at most 5. On resume without `--all`, use the `focus:` value from `D/state.md`, or `all` when that field is missing.
```

- [ ] **Step 5: Setup step 6 (Resume)**

Replace the `changed` bullet with:

```markdown
   - `changed`: set the chunk to `not-reviewed`, clear its answers, rebuild its dossier unless it has `dossier: none`.
```

After the `removed` bullet, add:

```markdown
   If the focus is `all` and `D/state.md` has `focus: decisions`, build dossiers for every `dossier: none` chunk as in step 7 (their hunk rows as one batch, `DOSSIERS: all`), set their `dossier:`, and save `focus: all`.
```

- [ ] **Step 6: Setup step 7 (Dossiers)**

In the agent prompt block, after `LANGUAGE: …`, add the line:

```
   DOSSIERS: <decisions|all, the session focus>
```

Replace `Parse the reply lines up to \`END\`.` with:

```markdown
   Parse the reply lines up to `END`: chunk id, `file:lines`, three scores, kind, reason, hunks. A line whose kind is not `decision` or `support` does not parse.
```

Replace the fallback sentence `If it fails again, write those dossiers yourself in the format from … and mark them \`dossier: main-session\` in \`state.md\`.` with:

```markdown
   If it fails again, read `<this skill's base directory>/../../agents/dossier-builder.md`, follow its Procedure steps 1–5 yourself for that batch as in `inline` mode, and mark the dossiers you write `dossier: main-session` in `state.md`.
```

In the `inline` paragraph, replace `follow its Rules and Procedure steps 1–4 yourself with the same inputs, writing each dossier to \`D/dossiers/<chunk_id>.md\`. Skip its step 5 (the reply): take each chunk's id, \`file:lines\`, scores, reason, and hunks from the dossiers you wrote. Mark every chunk \`dossier: main-session\` in \`state.md\`.` with:

```markdown
   follow its Rules and Procedure steps 1–5 yourself with the same inputs (including `DOSSIERS`), writing each dossier to `D/dossiers/<chunk_id>.md`. Skip its step 6 (the reply): note each chunk's id, `file:lines`, scores, kind, reason, and hunks as you go. Mark chunks with a dossier `dossier: main-session` and chunks without one `dossier: none` in `state.md`.
```

- [ ] **Step 7: Setup step 9 (Plan)**

Replace step 9 with:

```markdown
9. **Plan.** Show a numbered list, `file:lines — reason`, highest score sum first, then the collapsed lines.
   - Focus `decisions`: number at most 5 chunks, taken from `decision` chunks with a sum of 5 or more. On resume, chunks that are `done`, `in-progress`, or `skipped` stay numbered even past the limit; other chunks fill only the places left up to 5. Then one collapsed line for the other `decision` chunks ("More decisions" / «Ещё решения»), one for `support` chunks ("Supporting" / «Сопровождение»), and one for noise. If nothing is numbered, say the scope has no decisions, show the collapsed lines, and ask the engineer which chunks to take; do not start the interview.
   - Focus `all`: number every chunk with a sum of 5 or more. Put the others in one collapsed line, and noise in another.
   Chunks outside the numbered list get `tail: true`. Ask the engineer to drop or add chunks. They may add any chunk from a collapsed line or any `file:lines`, with no limit. For an added chunk without a dossier, or an added `file:lines`, build its dossier as in step 7 for the current dossier mode, with its hunk rows as one batch and `DOSSIERS: all`.
```

- [ ] **Step 8: State file block**

In the `D/state.md` example, after `dossiers: agents | inline` add `focus: decisions | all`. After the `scores:` line add `kind: decision | support`. Change `dossier: agent | main-session` to `dossier: agent | main-session | none`.

- [ ] **Step 9: Run scenario 13 after the change**

```bash
cd "$REPO"
bash tests/skill/run-arm.sh treatment tests/skill/scenarios/13-plan-limit.md 5 tests/skill/results/after/13-treatment
```

Expected: 5/5 pass. If a sample fails, quote the failing sentence, tighten only the step 9 wording that caused it, and rerun until 5/5.

- [ ] **Step 10: Docs**

`README.md`, after the `--inline` paragraph in "Use", add:

```markdown
By default, the interview asks about at most 5 decisions: changes that record a choice affecting others, such as an interface, data, how the system runs, a pattern, or who owns what. Tests, docs, and other changes that only follow from a decision are listed in the plan, and you can add any of them. Add `--all` to plan every chunk instead.
```

In "What it does", replace `It picks the most important, complex, and questionable parts of your change` with `It picks the decisions in your change, ranked by importance, complexity, and doubt,`.

`docs/how-it-works.md`, replace the body of "5. The plan" with:

```markdown
Only decision chunks are numbered, at most 5, ranked by the total of their three scores. You see each as `file:lines` with a one-line reason. Below them are folded lines: other decisions, supporting chunks, and noise. You can drop chunks, add any folded chunk, or add any lines you want to be asked about. A supporting chunk gets its dossier when you add it. With `--all`, every chunk is ranked and numbered, and only low-scoring chunks and noise are folded.
```

In "7. Saving progress", after `its scores, status,` insert `kind,` so it reads `its scores, kind, status, rung per axis, …`.

`docs/testing.md`, add to the scenario table:

```markdown
| 13 Plan limit | Dossiers are built; seven decisions and three supporting chunks | numbers only the top 5 decisions, folds the rest into "more decisions" and "supporting" lines, and asks one question |
```

and add a sentence under the table: `Scenario 13 freezes the plan step, not a question; the fixed dossier and code in its prompt are not used.`

- [ ] **Step 11: Commit**

```bash
cd "$REPO"
git add skills/branch-interview/SKILL.md tests/skill/scenarios/13-plan-limit.md README.md docs/how-it-works.md docs/testing.md
git commit -m "feat: plan only the top 5 decisions by default, --all for every chunk

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Report counts unplanned chunks

**Files:**
- Modify: `skills/branch-interview/report-template.md` (slot table lines 5–19, skeleton lines 21–51, counting paragraph line 53)
- Modify: `docs/how-it-works.md` ("8. The report")

**Interfaces:**
- Consumes: `focus`, `kind`, `tail` in `state.md` from Task 3.
- Produces: report frontmatter `focus:`; summary line "Out of plan" / «Вне плана».

- [ ] **Step 1: Slot table**

After the `changed` row add:

```markdown
| out of plan | Out of plan: {{d}} decisions · {{s}} supporting | Вне плана: {{d}} решений · {{s}} сопровождения |
```

- [ ] **Step 2: Skeleton**

In the frontmatter, after `mode: {{mode}}` add `focus: {{focus}}`. After `{{changed}}` add a line `{{out of plan}}`.

- [ ] **Step 3: Counting paragraph**

Replace `Unfinished chunks are not in \`{{n}}\`: list \`not-reviewed\` and \`in-progress\` chunks under "not reviewed", and \`changed\` chunks only under "changed after review".` with:

```markdown
Unfinished chunks are not in `{{n}}`: list `not-reviewed` and `in-progress` chunks without `tail: true` under "not reviewed", and `changed` chunks only under "changed after review". Chunks with `tail: true` that were never started count only in "out of plan": `{{d}}` is the number of `decision` ones, `{{s}}` the number of `support` ones. Omit "out of plan" when both are 0.
```

- [ ] **Step 4: Docs**

In `docs/how-it-works.md` "8. The report", replace the bullet `- chunks not reviewed yet, and chunks changed after review;` with:

```markdown
- chunks from the plan not reviewed yet, and chunks changed after review;
- how many decisions and supporting chunks stayed out of the plan;
```

- [ ] **Step 5: Commit**

```bash
cd "$REPO"
git add skills/branch-interview/report-template.md docs/how-it-works.md
git commit -m "feat(report): count chunks left out of the plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

The report is verified end to end in Task 5 (E1).

---

### Task 5: End-to-end runs and regression

**Files:**
- Modify: `docs/testing.md` (End-to-end runs checklist)

- [ ] **Step 1: Driver for a headless plugin session**

Save as `$S/e2e.sh` (scratchpad, not committed):

```bash
#!/bin/bash
# usage: e2e.sh <fixture-dir> <transcript-dir> <message> [session-id]
# Prints the session id. Each turn's JSON goes to <transcript-dir>/turn-N.json.
set -euo pipefail
fx=$1; tdir=$2; msg=$3; sid=${4:-}
REPO=/Users/borysshuliak/Desktop/repos/claude-branch-interview
mkdir -p "$tdir"
n=$(find "$tdir" -name 'turn-*.json' | wc -l | tr -d ' '); n=$((n + 1))
args=(-p --plugin-dir "$REPO" --dangerously-skip-permissions --model claude-sonnet-5 --output-format json)
[ -n "$sid" ] && args+=(--resume "$sid")
(cd "$fx" && claude "${args[@]}" -- "$msg") > "$tdir/turn-$n.json"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["result"], file=sys.stderr); print(d["session_id"])' "$tdir/turn-$n.json"
```

Each check below starts from a fresh fixture: `rm -rf "$S/fx" && bash "$REPO/tests/skill/make-fixture.sh" "$S/fx"`. Answer the language question with `Русский`, accept the plan with `Поехали`, and answer interview questions briefly; use `хватит` to reach Finish. `D` is `$S/fx/.branch-interview/<key>`.

- [ ] **Step 2: E1, default focus**

Start: `/branch-interview:branch-interview branch`. Check:
- the numbered plan holds only `decision` chunks, `config/retry.json` among them, at most 5;
- `docs/retry.md` and `.eslintrc.json` are in the "Сопровождение" line; `src/retry.test.js` is not listed separately;
- `ls D/dossiers` has no file for a `support` chunk id;
- `D/state.md` has `focus: decisions`, and every chunk has `kind:`; support chunks have `dossier: none` and `tail: true`;
- after one answered chunk and `хватит`, the report has `focus: decisions`, a «Вне плана: … решений · 2 сопровождения» line (counts match `state.md`), and «Не проверено» lists no tail chunk.

- [ ] **Step 3: E2, add a support chunk**

Same start; at the plan, reply `Добавь docs/retry.md`. Check: `D/dossiers/<its id>.md` now exists, its `state.md` entry has `tail:` removed or false and `dossier:` not `none`, and `bash "$REPO/tests/check-dossier.sh" D/dossiers/<its id>.md` prints `ok`.

- [ ] **Step 4: E3, switch to `--all` on resume**

After E1's session ends, start a new session: `/branch-interview:branch-interview branch --all`, answer `продолжить`. Check: a dossier exists for every chunk id in `state.md`, no `dossier: none` remains, `focus: all` is saved, and the plan numbers every chunk with sum 5 or more.

- [ ] **Step 5: E4, `--inline --all`**

Fresh fixture. Start: `/branch-interview:branch-interview branch --inline --all`. Check: `D/state.md` has `dossiers: inline` and every chunk has `dossier: main-session` (inline mode never dispatches an agent), kinds match E1, every chunk has a dossier, and every dossier passes `check-dossier.sh`.

- [ ] **Step 6: E5, resume of a pre-change session (Review Focus 1)**

Fresh fixture. Run E1 up to the first answered chunk and `хватит`. Then edit `D/state.md`: delete the `focus:` line and every `kind:` line. Start `/branch-interview:branch-interview branch`, answer `продолжить`. Check: the session resumes as `all` (`focus: all` saved), the answered chunk keeps `status: done`, and no dossier file's modification time changed (`ls -l D/dossiers` before and after).

- [ ] **Step 7: E6, scope with no decisions (Review Focus 2)**

Fresh fixture. Start: `/branch-interview:branch-interview files docs/retry.md .eslintrc.json`. Check: the reply says there are no decisions, shows the «Сопровождение» line, asks which chunks to take, and asks no question about code.

- [ ] **Step 8: E7, `--all` after paths (Review Focus 3)**

Fresh fixture. Start: `/branch-interview:branch-interview files src/retry.js docs/retry.md --all`. Check: `D/state.md` has `focus: all` and `paths: src/retry.js docs/retry.md` (no `--all` in `paths`), and both files' chunks are numbered.

- [ ] **Step 9: Regression, scenarios 01–12 after**

```bash
cd "$REPO"
for f in tests/skill/scenarios/[01][0-9]-*.md; do
  n=$(basename "$f" .md)
  case "$n" in 13-*) continue ;; esac
  bash tests/skill/run-arm.sh treatment "$f" 5 "tests/skill/results/after/$n"
done
```

Grade as in Task 0. Expected: every scenario at least its "before" count. A drop means a rule change broke a moment: fix the wording and rerun that scenario.

- [ ] **Step 10: Update the end-to-end checklist in `docs/testing.md`**

Add to the bullet list under "End-to-end runs":

```markdown
- by default, the plan numbers only decision chunks (at most 5), supporting chunks have no dossier until added, and a config file that changes behavior is a decision;
- `--all` on resume builds the missing dossiers and switches the session to every chunk;
- a session saved before focus existed resumes as `--all` without rebuilding anything;
- a scope with only supporting changes asks which chunks to take instead of starting.
```

- [ ] **Step 11: Write the PR summary**

Write `tests/skill/results/summary.md`: model, one row per scenario 01–13 with before/after k/5 (13 also with control), every failing reply quoted verbatim, the E1–E7 results, and what wording changed between runs and why. This text goes into the PR description.

- [ ] **Step 12: Lint, scope tests, commit**

```bash
cd "$REPO"
shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh tests/skill/*.sh
bash tests/scope.test.sh
git add docs/testing.md
git commit -m "docs(testing): add decision-focus end-to-end checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Expected: shellcheck silent, scope tests all pass.
