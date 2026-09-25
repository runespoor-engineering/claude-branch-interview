# Branch Interview: Design

Date: 2026-09-26
Status: approved in brainstorming, pending written-spec review

## Goal

Help an engineer confirm that they own the code they are about to push. The skill picks the most important, complex, and questionable parts of a change. It then interviews the engineer about each part: what the code does, why it was added, which alternatives existed, and what the weaknesses of the current solution are. When the engineer does not know, the skill guides them to the answer through a hint ladder. It never hands out the answer first.

## Audience and scope

- The engineer runs the skill on their own code, for themselves. The tone is a mentor's, not an examiner's.
- v1 checks understanding only. It does not require rewriting code. Possible bugs found along the way are reported, not enforced.
- The final report is committed so that the engineer, and optionally reviewers, can see that the interview happened.

## Distribution

The repository is a Claude Code plugin with a marketplace manifest.

```
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
skills/branch-interview/SKILL.md
skills/branch-interview/report-template.md
skills/branch-interview/scripts/scope.sh
agents/dossier-builder.md
tests/scope.test.sh
.github/workflows/ci.yml
```

Install: `/plugin marketplace add BorysShulyak/claude-branch-interview`, then `/plugin install`.

Responsibilities:

- `scope.sh` does all mechanical work: resolving the scope to hunks, hashing, noise detection, and comparing against saved state. It must be deterministic so that resume works.
- `dossier-builder` is a plugin agent that analyzes a batch of files and writes one dossier per chunk.
- `SKILL.md` drives the session: planning, the interview, state updates, and the report.

## Invocation

```
/branch-interview branch             # merge-base with main .. HEAD
/branch-interview last-commit        # HEAD~1 .. HEAD
/branch-interview uncommitted        # staged + unstaged + untracked
/branch-interview files <path>...    # only these files, diffed against merge-base
```

Without an argument, the skill asks which of the four modes to use. The base branch is `main`. If `main` does not exist, the skill uses `origin/HEAD`. If neither exists, it asks.

## Session flow

1. **Preflight.** Confirm this is a git repository and the diff is not empty. If `.branch-interview/` is not in `.gitignore`, add it and tell the engineer.
2. **Language.** Read the `language` frontmatter field of existing reports in `docs/interviews/`; if they disagree, use the most recently modified report. If there are none, read `language` from `state.md`. If neither exists, ask the engineer: Russian or English. The whole session and the report use that language.
3. **Scope.** Run `scope.sh hunks` to get the hunk list.
4. **Resume.** If state exists for this scope key, run `scope.sh diff-state`. Closed chunks with unchanged hunks stay closed. Chunks whose hunks changed are reset to "not reviewed". New hunks are added. The skill offers to continue or to start over.
5. **Dossiers.** Split non-noise files into batches and run `dossier-builder` on each batch in parallel. Each agent writes its dossiers to disk and returns one line per chunk: `id, file:lines, scores, reason`. Small diffs use a single agent; there is one code path.
6. **Plan.** Show the ranked chunk list with the reason each was picked. The engineer can drop chunks or add their own. There is no limit on the number of chunks.
7. **Interview.** One chunk at a time (see Interview). After every axis, update `state.md`, so a dropped session loses nothing.
8. **Finish.** When the list is done, or the engineer says "stop", run `scope.sh diff-state` once more to mark chunks that changed during the session. Then write the report and remind the engineer to commit it.

## Dossiers and ranking

**Batching.** Group files by directory, up to about 400 changed lines per agent, at most 5 agents at a time.

**Noise.** `scope.sh` marks noise before any agent runs: lockfiles (pattern list), files marked `linguist-generated` in `.gitattributes`, files with a `DO NOT EDIT` header, whitespace-only hunks (empty under `-w`), pure renames, and binary files. Noise is shown as one collapsed line in the plan.

**Agent tools.** `Read`, `Grep`, `Glob`, `Bash` limited to `git log`, `git show`, `git blame`, and `git diff`, and `Write` limited to `.branch-interview/<key>/dossiers/`. The agent needs `Write` so that dossier text never enters the main session's context.

**Chunking.** The agent groups the hunks in its batch into chunks of meaning. A chunk can span several hunks and files within the batch.

**Dossier format** (`dossiers/<chunk_id>.md`):

- id, hunk hashes, `file:lines`
- **What:** what the code does.
- **Why:** likely intent, the evidence for it (commit messages, tests, surrounding code), and a confidence level: high, medium, or low. Low means a guess.
- **Alternatives:** two or three options with trade-offs.
- **Weaknesses:** risks and weak points of the current solution.
- **Findings:** possible bugs, for the report only.
- **Questions:** for each of the four axes (what, why, alternatives, weaknesses):
  - the question;
  - key points of a good answer (a rubric, not a model answer);
  - rung 1: a leading question;
  - rung 2: a pointer (`file:line` or a document);
  - rung 3: an explanation.

  An axis can be marked N/A, for example alternatives for a trivial change.

**Scoring.** The agent scores each chunk from 1 to 5 on three axes:

- **importance:** public API, data, security, money, concurrency;
- **complexity:** logic density, non-obvious control flow;
- **doubt:** code smells, possible bugs, unusual choices, missing tests.

Rank is the sum of the three scores. The plan shows the highest-scoring axis as the reason. Chunks with a sum of 4 or less go to a collapsed tail; the engineer can pull them back in.

**The dossier is a hint, not the truth.** The agent infers intent from code and can be wrong. If the engineer explains intent differently, the skill checks the answer against the code, not against the dossier. The author knows their intent better than the agent. Disagreements go into the report.

## Interview

**Opening a chunk.** Show `file:lines` and the code (the hunk, trimmed to the essential part if long). Do not show the dossier.

**Axes, in order:** what, why, alternatives, weaknesses. Skip axes marked N/A. Ask one question per message.

**Hint ladder, per axis:**

1. Ask the question and wait for the answer.
2. If the answer covers the rubric's key points, the axis passes at rung 0.
3. Otherwise (partial, wrong, or "I don't know"), ask the rung 1 leading question.
4. If that fails, give the rung 2 pointer. The engineer reads the code or document and answers again.
5. If that fails, give the rung 3 explanation. The engineer must then restate it in their own words. A restatement passes only if it has the same substance and is not a copy of the explanation.

The ladder stops as soon as an answer passes. The axis status is the rung at which the passing answer came. The chunk status is the worst axis status.

**Commands, available at any time:**

- `explain`: jump to rung 3. The restatement is still required.
- `skip`: mark the current axis or chunk as skipped.
- `stop`: go to Finish.

The skill accepts the same commands in the session language (for example `объясни`, `пропусти`, `хватит`).

**Interviewer rules:**

- A question never contains its answer. No yes/no questions and no "is it right that…" questions.
- "Yes, I agree" in reply to an explanation is not a restatement.
- Grade honestly and without flattery. A partial answer gets partial credit, and the skill says which key point is missing.
- A correct weakness or alternative that is not in the dossier passes and is recorded in the report.
- After the weaknesses axis, reveal the dossier's findings that the engineer did not name. They are information; no rewrite is required.

**Recording.** After each axis, write to `state.md`: the status, the rung, and the engineer's final answer verbatim (or their restatement after rung 3).

## State and report

**Scope key.** Slashes in the branch name become `-`. In detached HEAD, the branch name is replaced by `sha7`.

| Mode | Key |
|------|-----|
| `branch` | `<branch>` |
| `last-commit` | `<branch>-commit-<sha7>` |
| `uncommitted` | `<branch>-uncommitted` |
| `files` | `<branch>-files-<hash6 of sorted paths>` |

**Local state** in `.branch-interview/<key>/` (gitignored):

- `hunks.tsv`: machine-readable, used by `scope.sh`. Columns: `hunk_hash`, `chunk_id`, `file`, `lines`. The skill writes it after the dossier step, joining `scope.sh hunks` output with the chunk ids the agents returned.
- `state.md`: a header (`language`, `mode`, `base_sha`, `head_sha`, `updated`), then per chunk its id, scores, reason, and status, and per axis its rung and the engineer's verbatim answer.
- `dossiers/<chunk_id>.md`.

**Report** in `docs/interviews/<key>.md`, committed by the engineer. The skill writes it from `report-template.md`, in the session language:

```markdown
---
branch: feat/x
mode: branch
base_sha: 1a2b3c4
head_sha: 5d6e7f8
date: 2026-09-26
engineer: <git user.name>
language: en
---
# Branch interview: feat/x

## Summary
12 chunks: knew 5 · with hints 4 · after explanation 2 · skipped 1
Not reviewed (trivial): 7

## Gaps: what to reread
- src/retry.ts:40-78, why: rung 3. Did not know why backoff uses jitter.

## Findings
- src/retry.ts:61: no upper bound on delay.

## Disagreements with the dossier
- src/cache.ts:12: intent explained differently; consistent with the code.

## Chunks
### 1. src/retry.ts:40-78, complexity 5
**What** · rung 0
> engineer's answer, verbatim
**Why** · rung 3 (restatement)
> restatement, verbatim
```

Rules:

- The report is rebuilt from `state.md` every time, so after a resumed session it shows the full picture.
- An early `stop` still produces a report. Unfinished chunks are marked "not reviewed".
- The skill's explanations are not in the report. Only the engineer's words are.
- The verbatim answers show that the interview took place. The file is editable, so it is not tamper-proof evidence.

## `scope.sh`

Bash and git only; no `jq`, `shasum`, or `sha1sum`.

```
scope.sh key        <mode> [paths]              → scope key
scope.sh hunks      <mode> [paths]              → TSV: hunk_hash file start-end +N -M noise
scope.sh diff-state <mode> [paths] <hunks.tsv>  → lines: new|changed|same|removed hunk_hash chunk_id
scope.sh show       <hunk_hash>                 → hunk text for display
```

- **Hash:** `git hash-object --stdin` over the file path plus the hunk's `+`/`-` lines with trailing whitespace stripped. Line numbers are excluded, so shifted code keeps its hash.
- **`changed` vs `new`:** if a hash is missing from saved state but the hunk overlaps an old chunk's file and lines, it is `changed`: the chunk id is kept and its status is reset. Otherwise it is `new`. Saved hashes with no current hunk are `removed`.
- **Untracked files:** `git diff --no-index /dev/null <file>`. The index is never modified (no `git add -N`).

## Error handling

| Situation | Behavior |
|-----------|----------|
| Not a git repository | Explain and exit. |
| Empty diff | Say so and exit. |
| No `main` and no `origin/HEAD` | Ask for the base branch. |
| Detached HEAD | Use `sha7` in the key. |
| Dossier agent fails | Retry once. If it fails again, mark the chunk "dossier missing" and build the dossier in the main session. |
| `state.md` cannot be parsed | Offer to start over; keep the old file with a `.bak` suffix. |
| Diff over about 5000 lines | Warn about the size and continue. |
| Code changes during the session | Detected by the final `diff-state` run; affected chunks are marked in the report. |

## Testing

**`tests/scope.test.sh`** (plain bash) builds fixture repositories in a temporary directory and covers: all four modes; shifted lines keep their hash; an edit yields `changed`; untracked files; each noise rule; renames; a slash in the branch name; detached HEAD.

**CI:** a GitHub Actions workflow runs `shellcheck` and `tests/scope.test.sh`.

**Skill behavior (writing-skills TDD):**

- Fixture: a branch with seeded chunks, one of which contains a real bug.
- A subagent plays the engineer in three roles: knows the code, bluffs, answers "I don't know".
- RED: run the scenarios without the skill and record the failures verbatim. Expected failures: giving the answer immediately, accepting "yes, I agree", asking several questions in one message, flattery, skipping the restatement, trusting the dossier over the author.
- GREEN: run the same scenarios with the skill and confirm compliance.
- Micro-test guidance wording against a no-guidance control, at least 5 reps per variant, reading every flagged match.

## Out of scope for v1

- Requiring the engineer to rewrite code.
- A reviewer or strict mode that grades another engineer.
- Tamper-proof evidence of completion.
- Languages other than Russian and English.
