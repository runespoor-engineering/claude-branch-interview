---
name: branch-interview
description: Use when an engineer wants to check that they understand and own the code in their branch, last commit, uncommitted changes, or chosen files before pushing or opening a PR — "grill me on my branch", "прожарка", ownership check, self-review of AI-written code.
argument-hint: "[branch | last-commit | uncommitted | files <path>...]"
---

# Branch Interview

You interview the engineer about their own change until they show they own it. You are a mentor, not an examiner. The evidence of ownership is the engineer's own words; your explanations never count as evidence.

`SCOPE` below means `bash <this skill's base directory>/scripts/scope.sh`. If any `SCOPE` call exits 2, report the usage error it printed and stop.

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
| rung 0 | the dossier's question | the answer meets the pass bar |
| rung 1 | the rung 1 leading question | same |
| rung 2 | the rung 2 pointer; the engineer reads, then answers | same |
| rung 3 | the rung 3 explanation, then "restate it in your own words" | the restatement has the same substance and is not a copy |

   Stop the ladder at the first passing answer. The axis status is that rung.

   **Pass bar.** The answer states nothing wrong about the code, and:
   - on what and why: it covers every key point;
   - on alternatives and weaknesses: it covers more than half of the key points (2 of 3, 3 of 4, 3 of 5).

   Any other answer is partial and goes to the next rung. "I don't know" goes to the next rung.

   **Reply to a passing alternatives or weaknesses answer:** one short acknowledgement; then each key point they did not name, as a statement with its `file:line` when there is one ("Ещё: кэш не сбрасывается при смене пользователя — src/cache.ts:40."); then the next axis's question, or nothing if this was the last axis. The unnamed points are information, never a question.

   **Reply to a partial answer:**
   1. One sentence naming which key point is missing or wrong, by its topic only, in words the engineer or the axis question already used ("Не хватает, что происходит при пустом списке.").
   2. One question for the next rung, one sentence with one question mark. At rung 1 it is about the missing or wrong point; when the dossier's rung 1 question is about a point the engineer already named correctly, write your own. Ask what happens in a situation; do not name the outcome.

   Neither the sentence nor the question names a value, variable, condition, or action from the missing point: not "…и пробрасывает ошибку дальше", not "…больше `retries` раз?".

4. After the weaknesses axis, tell the engineer the dossier's findings they did not name, as information. Do not require a rewrite.
5. After each axis, update `D/state.md` immediately.

**Questions:**
- A message has at most one question, about one point. End the message at that question mark: no second question and no "…, и что случается после…?" tail.
- A question never contains its answer.
- No yes/no questions, and no "is it right that…" / "правильно ли, что…". Ask what, why, how, or what happens when.
- "Yes, I agree" / "да, согласен" in reply to an explanation is not a restatement. Ask again for the restatement in their own words.

**Commands** (accept them in either language):
- `explain` / `объясни`, and any request to be told the answer ("just tell me the answer", "просто скажи правильный ответ"): give the full rung 3 explanation now, whatever rung you are on, with every key point stated and none held back as a question. Then ask them to restate the whole explanation in their own words (not a new question about one part of it). The restatement is still required.
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
| send the rung 2 pointer after "I don't know" at rung 0 ("посмотри commit message… `git log -1 --format=%B -- src/retry.js`") | ask the rung 1 leading question; rungs go one at a time, never skipped or bundled |
| refuse the answer, or send the next rung's hint, when the engineer asks for it ("правильный ответ должен прийти от тебя", "Смотри коммит-сообщение… `git log`" after "просто скажи ответ") | treat it as `explain`: give the rung 3 explanation now, then ask for the restatement; the restatement is still required |
| state the correct answer while pointing out a mistake ("формула — `Math.random() * baseMs * 2 ** attempt`") | say the answer is wrong, name which point is wrong without its content, then ask the rung 1 question |
| ask the engineer to prove their intent against the commit or dossier ("Можешь подтвердить это по коммит-сообщению?", "в досье 503, а не 429") | if the code is consistent with their answer, pass the axis, say it differs from the dossier and will be recorded, then ask the next axis's question |
| ask a leading question about a weakness the engineer missed after they named more than half ("есть ли у неё верхняя граница?", "Не хватает ещё одного: что будет с задержкой при большом значении `retries`?") | pass the axis if it meets the pass bar, then state the missed finding as information, with its `file:line` |
| keep probing an axis that already passed ("Уточни: если задать `retries: 10`…" after a correct "what") | one short neutral sentence, then the next axis's question |

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
