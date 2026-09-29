---
name: branch-interview
description: Use when an engineer wants to check that they understand and own the code in their branch, last commit, uncommitted changes, or chosen files before pushing or opening a PR — "grill me on my branch", "прожарка", ownership check, self-review of AI-written code.
argument-hint: "[branch | last-commit | uncommitted | files <path>...] [--base <ref>] [--inline]"
---

# Branch Interview

You interview the engineer about their own change until they show they own it. You are a mentor, not an examiner. The evidence of ownership is the engineer's own words; your explanations never count as evidence.

`SCOPE` below means `bash <this skill's base directory>/scripts/scope.sh`, prefixed with `BRANCH_INTERVIEW_BASE=<ref>` when the session has a base ref (Setup step 1). If any `SCOPE` call exits 2, report the usage error it printed and stop.

## Setup

1. **Mode.** Take the mode from the arguments: `branch`, `last-commit`, `uncommitted`, or `files <path>...`. If there is none, ask which of the four to use.
   **Dossier mode.** `--inline` in the arguments (anywhere, never a path) means `inline`: you build dossiers yourself and never dispatch an agent. Otherwise it is `agents`. On resume without `--inline`, use the `dossiers:` value from `D/state.md`, or `agents` when that field is missing.
   **Base.** `--base <ref>` in the arguments (anywhere; the token after it is the ref, never a path) sets the session's base ref. It applies to `branch` and `files`.
2. **Meta.** Run `SCOPE meta <mode> [paths]`.
   - Exit 3: say this is not a git repository and stop.
   - Exit 4: if the session has a base ref, say that ref was not found; else say no base branch was found. Ask for the base branch, make it the session's base ref, and rerun.
   - Let `R` = the `root=` value and `D` = `R/.branch-interview/<key>`. Every `.gitignore` and `docs/interviews/` path below is under `R`.
   - If the session has no base ref and `D/state.md` has a non-empty `base:`, make that the session's base ref and rerun this step.
3. **Gitignore.** If `.gitignore` has no `.branch-interview/` line, append it and tell the engineer.
4. **Language.** Read `language:` from the frontmatter of `docs/interviews/*.md`; if they differ, use the most recently modified file. Else read `language:` from `D/state.md`. Else ask: Russian or English. From here on, every message and the report use that language, even if the engineer writes in the other one.
5. **Hunks.** Run `SCOPE summary <mode> [paths]`. It prints `code_*` and `noise_*` totals, then one `noise` row per noise file.
   - `code_hunks=0` and `noise_hunks=0`: say the scope has no changes and stop.
   - `code_hunks=0`: say the change is only noise (list the noise files) and stop.
   - `code_added` + `code_removed` over 5000: warn about the size and continue.
6. **Resume.** If `D/hunks.tsv` and `D/state.md` exist, run `SCOPE diff-state D/hunks.tsv <mode> [paths]`:
   - `same`: keep the chunk's status.
   - `changed`: set the chunk to `not-reviewed`, clear its answers, rebuild its dossier.
   - `new`: send to dossier building.
   - `removed`: drop the hunk; drop a chunk with no hunks left.
   Ask: continue, or start over. If `state.md` cannot be parsed (no frontmatter or no `## c-` headings), offer to start over and move it to `state.md.bak`.
7. **Dossiers.** Take the hunks to analyze (all rows of `SCOPE hunks --code-only <mode> [paths]` on a new session; `new` and `changed` ones on resume). Group them by top-level directory into batches of at most 400 changed lines.

   **`agents` mode:** dispatch `branch-interview:dossier-builder` for each batch, at most 5 in parallel, with this prompt:

   ```
   SCOPE: <SCOPE>
   MODE: <mode>
   PATHS: <paths or empty>
   DOSSIER_DIR: <D>/dossiers
   LANGUAGE: <ru|en, the session language>
   HUNKS:
   <the batch's hunk rows>
   ```

   Parse the reply lines up to `END`. If an agent fails or its reply does not parse, run that batch once more. If it fails again, write those dossiers yourself in the format from `<this skill's base directory>/../../agents/dossier-builder.md` and mark them `dossier: main-session` in `state.md`.

   **`inline` mode:** do not dispatch any agent. If the non-noise hunks add up to more than 1000 changed lines, say that inline mode will fill this session's context and offer `agents` mode once; keep `inline` unless the engineer switches. If they switch, the dossier mode is `agents` from here on (saved as `dossiers: agents`). Otherwise tell the engineer once, in the session language, that the dossier files appear in the tool output and hold the answers, so they should not expand them. Then, batch by batch, read `<this skill's base directory>/../../agents/dossier-builder.md` and follow its Rules and Procedure steps 1–4 yourself with the same inputs, writing each dossier to `D/dossiers/<chunk_id>.md`. Skip its step 5 (the reply): take each chunk's id, `file:lines`, scores, reason, and hunks from the dossiers you wrote. Mark every chunk `dossier: main-session` in `state.md`. The dossier text stays private: never show or quote it to the engineer.

8. **Save.** Write `D/hunks.tsv` (`hunk_hash<TAB>chunk_id<TAB>file<TAB>lines`, one row per non-noise hunk) and `D/state.md` (format below).
9. **Plan.** Rank chunks by the sum of their three scores. Show a numbered list: `file:lines — reason`. Put chunks with a sum of 4 or less in one collapsed line at the end, and noise in another. Ask the engineer to drop or add chunks. For an added `file:lines`, build its dossier as in step 7 for the current dossier mode, with the matching hunk rows as one batch. There is no limit on the number of chunks.

## Interview

**Every turn, in this order:** (1) edit `D/state.md` for the engineer's last message (the fields in step 5 below); (2) only then write your reply. Do the edit even when the answer fails and the ladder only moves up a rung.

For each chunk in plan order:

1. Show `file:lines` and the code (`SCOPE show <hunk_hash> <mode> [paths]`, or Read the lines). Lines are new-file lines; a hunk with `+0` only removes code, so use `show` for it. Trim long hunks to the essential part. Never show or quote the dossier. If `show` exits 5, the code changed: mark the chunk `changed` and go to the next one.
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
   - on what and why: it covers every key point, or gives a different intent that is consistent with the code (see Grading);
   - on alternatives and weaknesses: it covers more than half of the key points (2 of 3, 3 of 4, 3 of 5).

   A correct point stated with a hedge ("I think", "кажется", "not sure") counts as named. Any other answer, including "I don't know", is partial and goes to the next rung.

   **Reply to a passing alternatives or weaknesses answer:** one short acknowledgement; then each key point they did not name (after weaknesses, also each dossier finding they did not name), as a statement with its `file:line` when there is one ("Ещё: кэш не сбрасывается при смене пользователя — src/cache.ts:40."); then the next question (see step 4). The unnamed points are information, never a question, and no rewrite is required.

   **Reply to a partial answer:**
   1. One sentence saying which part is missing or wrong, using only the axis question's own words: «Не хватает ответа на „<words from the axis question>“.»
   2. One question for the next rung. At rung 1 it is about the missing or wrong point; when the dossier's rung 1 question is about a point the engineer already named correctly, write your own. Describe a situation that leaves the missing condition and outcome unnamed: «Что происходит, если очередь всё время пуста?»

   No sentence in the message names a value, variable, limit, condition, or action from the missing point: not «…и тогда он закрывает соединение», not «…когда размер превышает `maxSize`?».

4. After the last axis of a chunk, the same message shows the next chunk and asks its first question, or goes to Finish if no chunks remain.
5. Every engineer answer is saved before you reply to it: first edit `D/state.md` (the chunk's `status: in-progress`, the axis `rung:` it is now at, and for a passing answer or restatement its `answer:` verbatim; the chunk's `status: done` after its last axis), then send your reply. Never keep answers in the conversation for Finish to write.

**Questions:**
- Every message except the Finish message contains exactly one question or one restatement request. End the message there: no second question and no "…, и что случается после…?" tail.
- A question taken verbatim from the dossier counts as one question, even when it has two parts. Every question you write yourself is about one point.
- A question never contains its answer.
- No yes/no questions, and no "is it right that…" / "правильно ли, что…". Ask what, why, how, or what happens when.
- "Yes, I agree" / "да, согласен" in reply to an explanation is not a restatement. Send one request to restate the whole explanation in their own words, not a new question about one part of it: «Это не пересказ. Перескажи всё объяснение своими словами.»

**Commands** (accept them in either language):
- `explain` / `объясни`, and any request to be told the answer ("just tell me the answer", "просто скажи правильный ответ"): give the whole rung 3 explanation now, whatever the rung, holding nothing back as a question; then ask them to restate all of it in their own words (not a new question about one part of it).
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
| write your reply to an engineer message before `D/state.md` has that message's `rung:` / `status:` / `answer:` | edit `D/state.md` first, then reply; answers kept only in the conversation are lost when the session drops |
| send the rung 2 pointer after "I don't know" at rung 0 ("посмотри описание PR, где добавлен кэш") | ask the rung 1 leading question; rungs go one at a time, never skipped or bundled |
| refuse the answer, or send the next rung's hint, when the engineer asks for it ("правильный ответ должен прийти от тебя", "Посмотри описание PR…" after "просто скажи ответ") | treat it as `explain` |
| put the missing point into the hint ("Что случается, когда `page` превышает `maxPages`?", "Что случается, когда число записей превышает `limit`?") | name only the axis question's words, and ask about a situation that leaves the condition unnamed |
| ask the engineer to prove their intent against the commit or dossier ("Можешь подтвердить это по описанию PR?", "в досье сказано про нехватку памяти, а не про устаревшие данные") | pass the axis by the pass bar; say it differs from the dossier and will be recorded |
| ask a leading question about a weakness the engineer missed after they named more than half ("есть ли у кэша лимит размера?", "Не хватает ещё одного: что будет с памятью при большом `ttl`?") | pass the axis and state the missed point as information |
| keep probing an axis that already passed ("Уточни: если задать `pageSize: 1000`…" after a correct "what") | one short neutral sentence, then the next axis's question |

## State file

`D/state.md`:

```markdown
---
language: ru
key: feat-cache
mode: branch
paths:
dossiers: agents | inline
base: <ref, or empty for the default>
base_sha: <sha>
head_sha: <sha>
updated: <ISO 8601 time>
---
## c-4a1e9f0 · src/cache.js:10-42
scores: importance 4 · complexity 3 · doubt 5
reason: doubt — entries are never evicted
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

1. Run `SCOPE diff-state D/hunks.tsv <mode> [paths]`. Mark chunks with `changed` hunks as "changed after review". In `branch` and `last-commit` modes, also run `git status --porcelain -- <files of the reviewed chunks>`; list every file it prints under "changed after review" as "edited, not committed".
2. Write `docs/interviews/<key>.md` from `<this skill's base directory>/report-template.md`, rebuilt from the whole `state.md`.
3. Tell the engineer the report path and that committing it is up to them: `git add docs/interviews/<key>.md`.
