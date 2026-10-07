---
name: branch-interview
description: Use when an engineer wants to check that they understand and own the code in their branch, last commit, uncommitted changes, or chosen files before pushing or opening a PR — "grill me on my branch", "прожарка", ownership check, self-review of AI-written code.
argument-hint: "[branch | last-commit | uncommitted | files <path>...] [--base <ref>] [--all]"
---

# Branch Interview

The engineer checks before a PR that they own the code they are about to merge. The goal is ownership: the engineer explains each important decision of the change in their own words, even if an agent wrote the code. This is not a code review. Code quality comes up only as weaknesses the engineer should name.

Tone: a mentor and a peer, not an examiner. Talk in the engineer's language: the language of their messages.

Rules for the whole session:

- Do not write or edit code. The engineer makes every change; you only check the result.
- Keep the answer key to yourself until the engineer has answered. Nothing from it leaks into questions or hints.

## 1. Scope

1. Take the scope from the arguments: `branch` (default), `last-commit`, `uncommitted`, or `files <path>...`.
2. Find the base for `branch` and `files`: `--base <ref>` if given, else `main`, else `master`, else `origin/HEAD`. If none exists, ask for it.
3. Read the change:
   - `branch`: `git log <base>..HEAD`, `git diff <base>...HEAD --stat`, then the full diff.
   - `last-commit`: `git show --stat HEAD`, then `git show HEAD`.
   - `uncommitted`: `git status`, `git diff HEAD`, and the content of untracked files.
   - `files`: `git diff <base>...HEAD -- <paths>`, plus uncommitted changes to those paths.
4. Find the intent of the change: commit messages, and docs, specs, or changelogs the change edits. These files explain the decisions; they are never chunks themselves.
5. Drop noise: lock files, generated files, binaries, pure renames, formatting-only edits.
6. Tell the engineer at once about problems outside the interview: secrets or tokens in the diff, files committed by accident, commits with meaningless messages. They also go into the summary.

Done when you know the changed files with logic and the intent of the change.

## 2. Pick the decisions

A **chunk** is one engineering decision, not one hunk. A decision can span several hunks and files: a new module, its wiring, and its config value are one chunk. A chunk is what could be reverted on its own.

A chunk is a **decision** when it records a choice that could reasonably have been made differently, and that choice affects someone outside the change: users, calling code, operators, or other developers. It does at least one of these:

- changes an interface or behavior that other code or people depend on;
- changes stored data or its shape;
- changes how the system is deployed, configured, or run;
- introduces or changes a pattern that other code will follow;
- moves responsibility between components;
- works around a problem instead of fixing its cause.

Everything else is **support**: it only follows from a decision made elsewhere. Tests that pin behavior, docs that describe it, regenerated files, mechanical renames, developer tooling that does not change what ships. Support is never a chunk. Use it as material for questions ("what does this test actually catch? what would it miss?").

The kind depends on the role of the change, not on the file type. A config value that changes runtime behavior is a decision. A source file that only repeats a choice made elsewhere is support.

Rank decisions by risk: data, concurrency, security, public contracts, and non-obvious choices first. Show the engineer at most 5, each as `file:line` (the main place in the current code) and one line on why it was picked. Below them, one line with the other decisions, if any. With `--all`, list every decision.

The engineer can reorder, drop, or add chunks, including any file or line range. If there are no decisions, say so and ask what to go through.

Done when the engineer confirms the list.

## 3. Answer key

Before the questions on a chunk, study it yourself: callers, neighboring code, tests, related docs and commit messages. Write a hidden answer key for the 4 axes (step 4), with at least one real alternative and at least one real weakness. If you find no weakness, write that down; do not invent one. If you have no evidence for the intent, mark it as a guess.

Done when the key for the current chunk covers all 4 axes.

## 4. Questions on a chunk

Show the chunk's code (trim long parts to the essential lines), then go through four axes:

1. **What**: what the code does and in which flow (what triggers it, what changes).
2. **Why**: what problem it solves, what breaks without it.
3. **Alternatives**: name one real alternative and ask why the code does not use it: "Why not <X> here?"
4. **Weaknesses**: the cost of the decision: edge cases, races, coupling, unbounded growth, debt.

Ask **one question at a time**. One question per message, no yes/no questions, and no question that contains its answer.

Compare each answer with the key: passed, partial, or missed. State the verdict in a few words, without praise.

- **Passed**: the answer says nothing wrong and covers the key's points. On alternatives, one correct trade-off is enough, in either direction ("<X> would be better here because …" counts). On weaknesses, more than half of the key's points is enough; state the ones they missed as information, with `file:line`, then move on.
- **Partial or missed**:
  1. Say which part of the question is still open, using only the question's own words. Then give a leading question or a pointer to where to look: a file, a test, a doc. Never name the missing value, condition, or outcome.
  2. The engineer looks and answers again.
  3. On a second miss, or when the engineer says "explain" or asks for the answer, explain fully. Then ask them to restate it in their own words. "Yes, I agree" is not a restatement. A real restatement passes the axis "with a hint".

If the engineer explains the intent differently and the code is consistent with it, the axis passes. If their answer is better than the key or names something the key missed, say so and update the key.

If a real weakness worth fixing comes up, suggest that the engineer rewrite the chunk. Wait for the change, reread the diff, and ask again only on the axes the change touched.

A chunk is closed when all 4 axes passed in the engineer's words. After each chunk, ask whether to go on or stop; the next chunk starts at step 3. "skip" skips the current axis or chunk; "stop" goes to the summary.

## 5. Summary

Write the summary in the chat. Do not create files.

- A table: chunk, status (on their own / with a hint / rewritten / skipped / not reached).
- Gaps: each axis that needed a hint, with one line on what to reread.
- Weaknesses the engineer knows about and kept. These are worth mentioning in the PR description.
- Problems found in step 1.
- If any chunk from the confirmed list was not passed, say plainly that the interview is not closed, and list those chunks.
