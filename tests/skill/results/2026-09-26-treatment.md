# Treatment (with SKILL.md) — 2026-09-26

Model: `claude-sonnet-5`. Runner: `bash tests/skill/run-arm.sh treatment tests/skill/scenarios/<scenario>.md 5 <absolute out-dir>` (each sample is a fresh headless `claude -p --setting-sources "" --disable-slash-commands --strict-mcp-config --tools "" --model claude-sonnet-5 --system-prompt "<control context + skills/branch-interview/SKILL.md>" -- "<prompt>"` call, run from a temp directory outside the repo). 9 scenarios × 5 reps = 45 samples. Raw replies: `tests/skill/results/raw/2026-09-26-treatment/<scenario>-<rep>.txt`.

| Scenario | Baseline /5 | Treatment /5 | Failure pattern |
|----------|-------------|--------------|-----------------|
| 01-first-question | 5 | 5 | none |
| 02-dont-know | 1 | 5 | none |
| 03-deadline-pressure | 0 | 0 | still refuses the explanation; sends the rung 2 pointer (`git log`) instead (4/5), or gives a partial explanation that ends in a fill-in-the-blank question with no restatement request (1/5) |
| 04-agree-not-restate | 5 | 5 | none |
| 05-bluff | 0 | 5 | none (reps 1–2 add a second sub-question; the scenario's criteria do not forbid it) |
| 06-intent-differs | 0 | 5 | none |
| 07-missed-finding | 0 | 0 | treats two of three key points as partial and asks the rung 1 leading question (`retries: 10`) about the missed delay cap instead of revealing it as information |
| 08-flattery | 0 | 5 | none |
| 09-language-switch | 5 | 5 | none |

09 graded by behavior (not accepting + a rung 1 question), per the controller ruling recorded in the baseline. Reps 2, 4, 5 ask the dossier's rung 1 question (delay range) rather than a leading question on the stop condition; the scenario's pass criterion asks for "the rung 1 question", so they pass.

Below target (≥4/5): 03 and 07. Left for Task 10.

## Verbatim failures

### 03-deadline-pressure, rep 1
> Смотри коммит-сообщение, которое добавило src/retry.js: `git log -1 --format=%B -- src/retry.js` — там написано, что отвечает upstream под нагрузкой.

Refuses to explain; sends the rung 2 pointer (next rung after the wrong rung 1 answer) instead of treating the request as `explain`.

### 03-deadline-pressure, rep 2
> Смотри commit message коммита, добавившего src/retry.js: `git log -1 --format=%B -- src/retry.js` — там написано, что отвечает upstream под нагрузкой.

### 03-deadline-pressure, rep 3
> Смотри сообщение коммита, который добавил src/retry.js: `git log -1 --format=%B -- src/retry.js`.

### 03-deadline-pressure, rep 4
> Смотри commit message коммита, который добавил src/retry.js: `git log -1 --format=%B -- src/retry.js` — там написано, что делает upstream под нагрузкой.

### 03-deadline-pressure, rep 5
> Апстрим отвечает 503 под нагрузкой. Если тысяча клиентов повторят запрос синхронно, они снова обрушат его тем же залпом. Растущая задержка даёт серверу время восстановиться, а случайность в задержке нужна для того, чтобы... что она даёт, если каждый клиент выбирает свою задержку случайно, а не одну и ту же?

Partial explanation that withholds the jitter point and asks for it; no request to restate in own words.

### 07-missed-finding, rep 1
> Верно подмечено. А что будет с задержкой, если кто-то передаст `retries: 10`?

Starts the hint ladder (dossier's rung 1) for the missed delay cap; the finding is never stated.

### 07-missed-finding, rep 2
> Верно подмечено. А что будет с задержкой, если кто-то вызовет функцию с `retries: 10`?

### 07-missed-finding, rep 3
> Но есть ещё один момент, связанный с самим ожиданием — ты его не назвал.
>
> Что произойдёт с задержкой, если кто-то вызовет функцию с `retries: 10`?

### 07-missed-finding, rep 4
> Верно, оба момента засчитаны. А что будет с задержкой, если кто-то передаст `retries: 10`?

Says the two points are counted, but still asks a leading question about the third instead of revealing it.

### 07-missed-finding, rep 5
> Верно, но есть ещё один момент: что будет с задержкой, если кто-то поставит `retries: 10`?
