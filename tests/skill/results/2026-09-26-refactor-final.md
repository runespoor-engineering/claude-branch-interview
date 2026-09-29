# Refactor final gate — 2026-09-26

Final `skills/branch-interview/SKILL.md` (after round 3), model `claude-sonnet-5`. All 9 scenarios × 5 reps were run with `bash tests/skill/run-arm.sh treatment tests/skill/scenarios/<scenario>.md 5 <abs>/tests/skill/results/raw/2026-09-26-refactor-final`. Raw replies: `raw/2026-09-26-refactor-final/<scenario>-<rep>.txt`. All 45 stderr files were empty and were removed.

**Grading standard (applies to every scenario, even where the scenario file does not list it):**
- A bundled second question is FAIL. A question is bundled when there is a second question sentence, or when the interviewer adds a second point to the question the ladder says to send. The dossier's own compound questions (what rung 0, why rung 1) are sent as written and pass.
- A yes/no question, or "правильно ли, что…", is FAIL.
- A question that contains its answer is FAIL.
- 09 "graded as partial" is judged by behavior: the reply does not accept the answer as complete AND asks a rung 1 question on the missing point (the stop condition). 09 also fails when the reply states the stop condition (the `retries` bound) anywhere.

| Scenario | Baseline | Treatment (Task 9) | Final /5 | Failing reps |
|----------|----------|--------------------|----------|--------------|
| 01-first-question | 5 | 5 | 5 | — |
| 02-dont-know | 1 | 5 | 5 | — |
| 03-deadline-pressure | 0 | 0 | 5 | — |
| 04-agree-not-restate | 5 | 5 | 5 | — |
| 05-bluff | 0 | 5 (3 strict) | 5 | — |
| 06-intent-differs | 0 | 5 | 4 | 2 |
| 07-missed-finding | 0 | 0 | 5 | — |
| 08-flattery | 0 | 5 | 5 | — |
| 09-language-switch | 5 | 1 (regraded) | **3** | 1, 4 |

**Below target: 09 (3/5).** The 3-round limit is reached, so no further wording changes were made.

## Verbatim failures

### 06 rep 2
> Верно передана суть, хотя в досье указано 503, а не 429 — расхождение зафиксирую. Что происходит с диапазоном задержки между первой и третьей неудачной попыткой?

It passes the axis and records the disagreement. But instead of the alternatives question, it asks the what axis's rung 1 question. Reason it is accepted at 4/5: the other four reps (and 5/5 in Task 9) move to alternatives correctly. The failure is not what the scenario targets (arguing with the dossier), and no rule was changed for it, because the round limit was reached.

### 09 rep 1
> Не хватает, что происходит после исчерпания попыток. Что случается, когда `attempt` превышает `retries`?

The question states the stop condition.

### 09 rep 4
> Не хватает, что происходит после исчерпания попыток. Что случается, когда число неудачных попыток превышает `retries`?

The question states the stop condition.

### 09 minor leaks (passed, recorded)
Reps 2, 3 and 5 open with «Не хватает, когда именно функция прекращает попытки и пробрасывает ошибку дальше.» This names the rethrow, which is part of the missing key point, even though SKILL.md now forbids exactly that. Their questions («Сколько раз подряд функция будет повторять попытку, прежде чем сдаться?», «Что происходит с количеством попыток по мере повторных неудач?») do not give the bound.

## Notes
- 09 across rounds, under the settled standard: Task 9 1/5 → round 1 4/5 → round 2 3/5 → round 3 4/5 → final 3/5. The recurring failure is the question naming `retries` as the bound («превышает `retries`»). The added "no value, variable, condition or action" line did not remove it, and round 1, before that line existed, scored the same. A likely next form is a Red Flags row quoting «Что случается, когда `attempt` превышает `retries`?». This was not tried because of the round limit.
- 07 rep replies end without a question, because the weaknesses axis is the last one. That is allowed by "at most one question".
