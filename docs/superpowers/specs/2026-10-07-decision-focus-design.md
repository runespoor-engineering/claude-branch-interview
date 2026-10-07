# Decision focus: interview only the decisions

Date: 2026-10-07
Status: approved design, awaiting implementation plan

## Problem

The interview covers every chunk in the scope. On a typical feature branch, a large part of the plan is changes that only follow from other changes: tests that pin new behavior, documentation that describes it, regenerated artifacts, mechanical renames. Engineers want to be asked about the choices they made, not about every file they touched.

The pipeline cannot filter this way today:

- `agents/dossier-builder.md` must put every hunk into some chunk and writes a dossier for each one.
- `importance` scores risk areas (public API, data, security, money, concurrency), not whether the chunk is a choice. Documentation reaches the plan as a full chunk.
- The plan has one cutoff: a score sum of 4 or less. Every chunk above it is interviewed.

## Goal

By default, the interview asks about at most 5 decisions. Every other chunk stays visible in the plan as a collapsed line, and the engineer can add any of them. The old behavior stays available behind `--all`.

The plugin is stack-neutral. The classification depends on the role of a change, never on its language, framework, file type, or directory.

## Non-goals

- Cross-batch topics. A decision whose hunks fall into different top-level directories stays split into chunks, as today. A separate pass that maps the whole branch into decisions can be added later on top of this design.
- Changes to the interview itself: axes, hint ladder, pass bar, commands.
- Changes to `scope.sh`.
- A configurable limit. The limit is 5 until there is a request for more.

## Approach

The dossier builder classifies each chunk as `decision` or `support`. The main session selects the top 5 decisions for the plan. Two alternatives were rejected:

- A new agent that maps the whole branch into cross-cutting decisions before dossiers. It adds a third agent and unclear resume semantics, and it guesses from hunk lists without reading code.
- Building every dossier as today, then merging them into topics. Most expensive, and it wastes work on dossiers that are never used.

## Design

### 1. Dossier builder (`agents/dossier-builder.md`)

**New input.** `DOSSIERS: decisions | all`.

**Grouping (Procedure step 1).** The existing rule stays. One addition: a hunk that only tests or documents a chunk in the same batch joins that chunk. Hunks with no such chunk group among themselves by meaning, as today.

**New step: `kind`.** Each chunk gets one kind, by the role of the change. File type, language and location do not decide the kind.

- `decision`: the change records a choice that could reasonably have been made differently, and the choice affects someone outside the change: users, calling code, operators, or other developers. It meets at least one of these:
  - changes an interface or behavior that other code or people depend on;
  - changes stored data or its shape;
  - changes how the system is built, deployed, configured, or run;
  - introduces or changes a pattern that other code will follow;
  - moves responsibility between components.
- `support`: the change follows from a decision made elsewhere and records no choice of its own. It pins, describes, regenerates, or mechanically repeats something.

A test, configuration, or documentation file can be a `decision` when it records a choice of its own. A source file can be `support` when it only repeats a choice made elsewhere.

**Dossiers.** With `DOSSIERS: decisions`, the builder writes a dossier file only for `decision` chunks. With `DOSSIERS: all`, it writes one for every chunk. The dossier format does not change.

**Scores.** Every chunk is scored, as today. Scores sort the collapsed lines.

**Reply.** A `kind` column goes between `doubt` and `reason`:

```
<chunk_id>	<file>:<start>-<end>	<importance>	<complexity>	<doubt>	<kind>	<reason>	<hunk_hash>[,<hunk_hash>…]
END
```

### 2. Interviewer setup and plan (`skills/branch-interview/SKILL.md`)

**Arguments.** `argument-hint` gains `[--all]`.

**Setup step 1: focus.** `--all` anywhere in the arguments (never a path) sets focus to `all`. Otherwise focus is `decisions`. On resume without `--all`, take `focus:` from `D/state.md`. If that field is missing, use `all`: the session predates this change, has dossiers for every chunk, and has been interviewing all of them.

**Step 7: dossiers.**

- The agent prompt gains the line `DOSSIERS: <focus>`.
- The reply parser reads the `kind` column.
- Inline mode and the `main-session` fallback follow the same builder rules, including `kind`.

**Step 9: plan with focus `decisions`.**

- Number at most 5 chunks: `decision` chunks with a score sum of 5 or more, highest sum first.
- Below them, one collapsed line each:
  - "More decisions": `decision` chunks beyond the top 5, or with a sum of 4 or less;
  - "Supporting": every `support` chunk;
  - "Noise": as today.
- The limit applies only to the automatic selection. The engineer may add any collapsed chunk or any `file:lines`, with no total limit.
- When an added chunk has no dossier (a `support` chunk), build it as in step 7: its hunks form one batch with `DOSSIERS: all`.
- With zero `decision` chunks: say so, show the collapsed lines, and ask the engineer to pick chunks. Do not start the interview on your own.

**Step 9: plan with focus `all`.** Unchanged: every chunk ranked by sum, sum of 4 or less and noise collapsed.

### 3. State, resume, report

**`D/state.md`.**

- Frontmatter gains `focus: decisions | all`.
- Each chunk gains `kind: decision | support`.
- `dossier:` gains the value `none` for a `support` chunk without a dossier.
- `tail: true` stays on every chunk outside the numbered plan.

**Resume (step 6).**

- `changed`: rebuild the dossier only if the chunk had one. A `dossier: none` chunk has nothing to rebuild.
- `new`: send the new hunks to the builder with the current focus.
- Rebuild the plan with the step 9 rules. Chunks with status `done`, `in-progress` or `skipped` stay numbered outside the limit, because they were already chosen. New `decision` chunks fill only the free slots up to 5.
- `--all` on resume of a `decisions` session switches it to `all`. Build dossiers for every `dossier: none` chunk in one pass with `DOSSIERS: all`, then save `focus: all`. Without the flag, resume keeps the saved focus, so a session never switches back on its own.

**Report (`skills/branch-interview/report-template.md`).**

- Frontmatter gains `focus`.
- "Not reviewed" lists only unfinished chunks from the numbered plan.
- The summary gains one line: "Out of plan: {{n}} decisions · {{m}} supporting" / «Вне плана: {{n}} решений · {{m}} сопровождения». No file list.
- This line applies in both focus modes. In `all` it replaces listing the tail under "Not reviewed". This is the only behavior change for `all`.

### 4. Testing

`scope.sh` does not change, so `tests/scope.test.sh` and lint stay as they are.

**Fixture (`tests/skill/make-fixture.sh`).** Add one commit after the existing ones. It covers each side of the classification, including the cases where file type would give the wrong answer:

| File | Change | Expected |
|------|--------|----------|
| `src/retry.test.js` | tests `retryWithBackoff` | joins the `src/retry.js` chunk |
| `docs/retry.md` | describes retry behavior | `support` |
| `.eslintrc.json` | a lint rule tweak | `support` |
| `config/retry.json` | sets `retries` and `baseMs`; `src/http.js` reads it | `decision` |

`src/retry.js` does not change, so chunk id `c-cdf1b88` and scenarios 01–12 stay valid.

**New scenario `tests/skill/scenarios/13-plan-limit.md`.** Setup gives the main session parsed builder reply lines: 7 `decision` chunks (one with a sum of 4 or less) and 3 `support` chunks. Pass criteria:

- exactly 5 numbered items, the top 5 by sum;
- "More decisions" and "Supporting" lines are present;
- no `support` chunk is numbered;
- one question, about dropping or adding chunks.

Run 5 samples in the treatment arm and 5 in the control arm.

**Regression.** Run scenarios 01–12 in the treatment arm before and after the change, as `CLAUDE.md` requires. Put the summary in the PR description.

**End-to-end runs on the extended fixture**, one each:

- default focus: the plan numbers only `decision` chunks, `config/retry.json` among them; `docs/retry.md` and `.eslintrc.json` sit in "Supporting"; `src/retry.test.js` is inside the retry chunk; no dossier files exist for `support` chunks; `state.md` has `focus: decisions` and `kind` on every chunk;
- adding `docs/retry.md` from the collapsed line builds its dossier, and the dossier passes `tests/check-dossier.sh`;
- resume with `--all` builds dossiers for every `dossier: none` chunk and saves `focus: all`;
- `--inline`: same classification, no agents started;
- report: the "Out of plan" line is present, and "Not reviewed" has no tail chunks.

### 5. Documentation

- `docs/how-it-works.md`: steps 4–5, key terms (`kind`, focus).
- `docs/testing.md`: the new scenario and the end-to-end checklist.
- `README.md`: the `--all` flag.

## Files touched

- `agents/dossier-builder.md`
- `skills/branch-interview/SKILL.md`
- `skills/branch-interview/report-template.md`
- `tests/skill/make-fixture.sh`
- `tests/skill/scenarios/13-plan-limit.md` (new)
- `docs/how-it-works.md`, `docs/testing.md`, `README.md`
